defmodule Harnex.TUI.TermUIApp do
  use TermUI.Elm

  alias Harnex.TUI.{Adapter, ApprovalPicker, Command, EventBridge, Session, State}
  alias TermUI.Style

  defstruct session: nil,
            lines: [],
            input: nil,
            dimensions: {80, 24},
            scroll: 0,
            status: "Ready",
            tui_state: nil,
            approval: nil,
            verbose: false,
            transcript_limit: 200

  def init(opts) do
    dimensions = Keyword.get(opts, :dimensions, {80, 24})
    app_opts = Keyword.get(opts, :ear_runtime_opts, [])
    session_opts = Keyword.put(Keyword.get(app_opts, :session_opts, []), :subscriber, self())

    %__MODULE__{
      session: Session.new(session_opts),
      input: new_input(),
      tui_state: State.new(mode: :fullscreen, workspace: File.cwd!()),
      dimensions: dimensions,
      verbose: Keyword.get(app_opts, :verbose, false),
      transcript_limit: Keyword.get(app_opts, :transcript_limit, 200)
    }
  end

  def event_to_msg(%TermUI.Event.Key{key: key, modifiers: modifiers}, _),
    do: {:msg, {:key, key, modifiers}}

  def event_to_msg(%TermUI.Event.Text{text: text}, _), do: {:msg, {:text, text}}
  def event_to_msg(%TermUI.Event.Paste{content: text}, _), do: {:msg, {:text, text}}

  def event_to_msg(%TermUI.Event.Resize{width: width, height: height}, _),
    do: {:msg, {:resize, width, height}}

  def event_to_msg(_, _), do: :ignore

  def handle_info({:harnex, event}, state), do: apply_event(state, event)

  def handle_info({:harnex_approval_request, pid, ref, name, args}, state) do
    state = %{state | approval: %{pid: pid, ref: ref, name: name, args: args, index: 0}}

    %{
      state
      | lines:
          state.lines ++
            [
              "Approval required: #{name} #{inspect(args)}",
              "Choose: " <> Enum.join(ApprovalPicker.labels(), " | ")
            ]
    }
  end

  def handle_info(_, _state), do: :noreply

  def update({:text, text}, state), do: update_input(state, TermUI.Event.text(text))

  def update({:clipboard_result, :ok}, state), do: {%{state | status: "Copied"}, []}

  def update({:clipboard_result, _reason}, state),
    do: {%{state | status: "Clipboard unavailable"}, []}

  def update({:key, :ctrl_c, _modifiers}, state), do: cancel_or_exit(state)

  def update({:key, key, _modifiers}, %{approval: approval} = state)
      when is_map(approval) and key in [:up, :down, :enter],
      do: update_approval(state, approval, key)

  def update({:key, key, modifiers}, state)
      when key in ["o", :o] and modifiers in [[:ctrl], [:control]],
      do: {state, [TermUI.Clipboard.copy(copy_text(state), on_result: &{:clipboard_result, &1})]}

  def update({:key, :page_up, _modifiers}, state),
    do: {%{state | scroll: state.scroll + page_size(state)}, []}

  def update({:key, :page_down, _modifiers}, state),
    do: {%{state | scroll: max(state.scroll - page_size(state), 0)}, []}

  def update({:key, key, modifiers}, state)
      when key in ["c", :c] and (modifiers == [:ctrl] or modifiers == [:control]),
      do: cancel_or_exit(state)

  def update({:key, key, modifiers}, state),
    do: update_input(state, TermUI.Event.key(key, modifiers: modifiers))

  def update({:key, key}, state), do: update_input(state, TermUI.Event.key(key))
  def update({:resize, width, height}, state), do: %{state | dimensions: {width, height}}
  def update(_, state), do: state

  defp update_approval(state, approval, :up) do
    %{state | approval: %{approval | index: ApprovalPicker.move(approval.index, :up)}}
  end

  defp update_approval(state, approval, :down) do
    %{state | approval: %{approval | index: ApprovalPicker.move(approval.index, :down)}}
  end

  defp update_approval(state, approval, :enter) do
    decision = ApprovalPicker.selected(approval.index)
    send(approval.pid, {:harnex_approval_response, approval.ref, decision_to_runtime(decision)})

    %{
      state
      | approval: nil,
        lines: state.lines ++ ["Approval: #{ApprovalPicker.labels() |> Enum.at(approval.index)}"]
    }
  end

  defp decision_to_runtime(:allow_once), do: :allow
  defp decision_to_runtime(:allow_session), do: :allow
  defp decision_to_runtime(:deny), do: :deny
  defp decision_to_runtime(:cancel), do: :deny

  defp apply_event(state, event) do
    projected =
      case event do
        %Harnex.Events.Event{} = runtime_event ->
          Adapter.apply(state.tui_state, EventBridge.from_runtime(runtime_event))

        _ ->
          state.tui_state
      end

    state
    |> Map.put(:tui_state, projected)
    |> apply_event_legacy(event)
    |> sync_projection(projected)
  end

  defp sync_projection(state, %State{status: status, blocks: blocks}) do
    status = status |> Atom.to_string() |> String.capitalize()
    projected_lines = Enum.map(blocks, &IO.iodata_to_binary(&1.content))
    %{state | status: status, lines: Enum.take(projected_lines, -state.transcript_limit)}
  end

  defp cancel_or_exit(%{session: %{run_id: nil}} = state) do
    {%{state | session: %{state.session | running: false}}, [TermUI.Command.shutdown()]}
  end

  defp cancel_or_exit(state) do
    {session, _result} = Session.handle(state.session, {:command, "cancel", ""})
    {%{state | session: session, status: "Cancelled"}, []}
  end

  defp update_input(state, event) do
    {input, messages} = TermUI.Widget.TextInput.update(event, state.input)
    state = %{state | input: input}

    Enum.reduce(messages, {state, []}, fn
      {:submit, prompt}, {_state, _commands} -> submit(state, prompt)
      _, {state, commands} -> {state, commands}
    end)
  end

  defp submit(state, ""), do: {state, []}

  defp submit(state, prompt) do
    {session, result} = Session.handle(state.session, Command.parse(prompt))

    state = %{
      state
      | session: session,
        input: new_input(),
        tui_state: State.submit(state.tui_state, prompt)
    }

    if session.running,
      do:
        {state
         |> append("You: #{prompt}")
         |> append_stream("\nAssistant: ")
         |> apply_result(result), []},
      else: {state, [TermUI.Command.shutdown()]}
  end

  def view(%__MODULE__{dimensions: {width, height}} = state) do
    width = max(width, 1)
    height = max(height, 1)
    header = header_rows(state, width)
    footer = footer_rows(state, width)
    approval = approval_rows(state, width)
    visible = max(height - length(header) - length(footer) - length(approval) - 1, 1)
    wrapped = transcript_rows(state, width)
    offset = max(length(wrapped) - visible - state.scroll, 0)
    body = Enum.slice(wrapped, offset, visible)
    body = body ++ List.duplicate("", max(visible - length(body), 0))
    {input_row, cursor_column} = TermUI.Widget.TextInput.row(state.input, max(width - 2, 1))
    rows = header ++ body ++ [input_row_row(input_row, width)] ++ approval ++ footer

    TermUI.Frame.from_rows(rows, width, height,
      cursor: {min(cursor_column + 2, width), min(length(header) + length(body) + 1, height)}
    )
  end

  defp header_rows(state, width) do
    tui = state.tui_state
    workspace = Path.basename(tui.workspace || File.cwd!())
    title = " Harnex  #{workspace}  ·  #{tui.model}  ·  #{tui.permission}"

    [
      styled_row(title, width, Style.new(fg: :cyan, attrs: [:bold])),
      styled_row(String.duplicate("─", width), width, Style.new(fg: :bright_black))
    ]
  end

  defp footer_rows(state, width) do
    status = state.status |> to_string() |> String.upcase()
    scroll = if state.scroll > 0, do: "  ↑ scroll #{state.scroll}", else: ""

    [
      styled_row(
        " #{status}#{scroll}  Ctrl-C cancel  Ctrl-O copy  PgUp/PgDn scroll",
        width,
        Style.new(fg: :bright_black)
      )
    ]
  end

  defp input_row_row(input, width),
    do: styled_row("❯ " <> input, width, Style.new(fg: :bright_white, attrs: [:bold]))

  defp approval_rows(%{approval: nil}, _width), do: []

  defp approval_rows(%{approval: approval}, width) do
    labels = ApprovalPicker.labels()

    choices =
      labels
      |> Enum.with_index()
      |> Enum.map(fn {label, index} ->
        marker = if index == approval.index, do: "❯ ", else: "  "

        style =
          if index == approval.index,
            do: Style.new(fg: :black, bg: :cyan, attrs: [:bold]),
            else: Style.new(fg: :yellow)

        styled_row(marker <> label, width, style)
      end)

    [
      styled_row(
        " Approval required: #{approval.name}",
        width,
        Style.new(fg: :yellow, attrs: [:bold])
      )
      | choices
    ]
  end

  defp transcript_rows(%{tui_state: %State{blocks: blocks}}, width) when blocks != [] do
    Enum.flat_map(blocks, &block_rows(&1, width))
  end

  defp transcript_rows(state, width),
    do: Enum.flat_map(state.lines, &styled_wrap(&1, width, Style.new()))

  defp block_rows(%{kind: kind, content: content}, width) do
    {prefix, style} = block_style(kind)
    content = IO.iodata_to_binary(content)

    content
    |> String.split("\n", trim: false)
    |> Enum.flat_map(&styled_wrap(prefix <> &1, width, style))
  end

  defp block_style(:user_message), do: {"› ", Style.new(fg: :cyan, attrs: [:bold])}
  defp block_style(:assistant_message), do: {"  ", Style.new(fg: :white)}
  defp block_style(:assistant_message_completed), do: {"  ", Style.new(fg: :bright_white)}
  defp block_style(:tool_started), do: {"▸ ", Style.new(fg: :yellow, attrs: [:bold])}
  defp block_style(:tool_output), do: {"│ ", Style.new(fg: :bright_black)}
  defp block_style(:tool_completed), do: {"✓ ", Style.new(fg: :green)}
  defp block_style(:approval_requested), do: {"⚠ ", Style.new(fg: :yellow, attrs: [:bold])}
  defp block_style(:turn_failed), do: {"✗ ", Style.new(fg: :red, attrs: [:bold])}
  defp block_style(:turn_cancelled), do: {"! ", Style.new(fg: :yellow)}
  defp block_style(_), do: {"  ", Style.new()}

  defp styled_row(text, width, style), do: [{TermUI.Frame.fit(text, width), style}]

  defp styled_wrap(text, width, style) do
    rows = text |> String.graphemes() |> Enum.chunk_every(max(width, 1))
    if rows == [], do: [[{"", style}]], else: Enum.map(rows, &[{Enum.join(&1), style}])
  end

  defp page_size(%{dimensions: {_width, height}}), do: max(height - 3, 1)

  defp copy_text(state), do: Enum.join(state.lines, "\n")

  defp apply_result(state, :clear), do: %{state | lines: []}
  defp apply_result(state, {:message, text}), do: append(state, text)
  defp apply_result(state, {:error, error}), do: append(state, "Error: #{inspect(error)}")

  defp apply_result(state, {:help, commands}),
    do:
      append(
        state,
        Enum.map_join(Enum.sort(commands), "\n", fn {name, description} ->
          "/#{name} - #{description}"
        end)
      )

  defp apply_result(state, {:skills, skills, errors}),
    do:
      append(
        state,
        Enum.map_join(skills, "\n", &"#{&1.name} - #{&1.path}") <>
          if(errors == [], do: "", else: "\nSkill warnings: #{length(errors)}")
      )

  defp apply_result(state, _), do: state

  defp apply_event_legacy(state, %{type: :message_delta, payload: %{text: text}}),
    do: append_stream(state, text)

  defp apply_event_legacy(state, %{type: :run_started}), do: %{state | status: "Running"}
  defp apply_event_legacy(state, %{type: :run_completed}), do: %{state | status: "Ready"}
  defp apply_event_legacy(state, %{type: :run_cancelled}), do: %{state | status: "Cancelled"}

  defp apply_event_legacy(state, %{type: :run_failed, payload: %{reason: reason}}),
    do: %{state | status: "Failed: #{inspect(reason)}"}

  defp apply_event_legacy(state, _), do: state

  defp append(state, text),
    do: %{
      state
      | lines: Enum.take(state.lines ++ String.split(text, "\n"), -state.transcript_limit)
    }

  defp append_stream(state, text) do
    {prefix, tail} =
      case Enum.split(state.lines, -1) do
        {prefix, [tail]} -> {prefix, tail}
        _ -> {[], ""}
      end

    lines = prefix ++ String.split(tail <> text, "\n", trim: false)
    %{state | lines: Enum.take(lines, -state.transcript_limit)}
  end

  defp new_input, do: TermUI.Widget.TextInput.init(placeholder: "Type a prompt or /command")
end
