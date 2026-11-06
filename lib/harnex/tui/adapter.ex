defmodule Harnex.TUI.Adapter do
  @moduledoc """
  Translates stable agent events into TUI state updates.
  """

  alias Harnex.TUI.{Event, State}

  @spec apply(State.t(), Event.t()) :: State.t()
  def apply(state, %Event{kind: :session_started, data: data}) do
    %{
      state
      | workspace: Map.get(data, :workspace, state.workspace),
        session_id: Map.get(data, :session_id, state.session_id),
        model: Map.get(data, :model, state.model),
        status: :idle
    }
  end

  def apply(state, %Event{kind: :user_message, data: %{content: content}}),
    do: State.append(state, :user_message, content)

  def apply(state, %Event{kind: :turn_started}), do: State.status(state, :working)

  def apply(state, %Event{kind: :assistant_delta, data: %{content: content}}) do
    case List.last(state.blocks) do
      %{kind: :assistant_message, content: previous} ->
        blocks =
          List.replace_at(state.blocks, -1, %{
            kind: :assistant_message,
            content: [previous, content],
            metadata: %{streaming: true}
          })

        %{state | blocks: blocks}

      _ ->
        State.append(state, :assistant_message, content, %{streaming: true})
    end
  end

  def apply(state, %Event{kind: :assistant_message_completed, data: %{content: content}}),
    do: State.append(state, :assistant_message_completed, content)

  def apply(state, %Event{kind: :tool_started, data: data}),
    do: State.append(state, :tool_started, Map.get(data, :command, "tool started"), data)

  def apply(state, %Event{kind: :tool_output, data: data}),
    do: State.append(state, :tool_output, Map.get(data, :content, ""), data)

  def apply(state, %Event{kind: :tool_completed, data: data}),
    do: State.append(state, :tool_completed, Map.get(data, :summary, "tool completed"), data)

  def apply(state, %Event{kind: :diff, data: data}),
    do: State.append(state, :diff, Map.get(data, :content, ""), data)

  def apply(state, %Event{kind: :approval_requested, data: data}) do
    state
    |> State.append(:approval_requested, Map.get(data, :reason, "Approval required"), data)
    |> State.status(:waiting_for_approval)
  end

  def apply(state, %Event{kind: :approval_resolved, data: data}) do
    decision = Map.get(data, :decision, "resolved")
    status = if decision in [:deny, :cancel, "deny", "cancel"], do: :failed, else: :working

    state
    |> State.append(:approval_resolved, to_string(decision), data)
    |> State.status(status)
  end

  def apply(state, %Event{kind: :turn_completed}), do: State.status(state, :completed)

  def apply(state, %Event{kind: :turn_failed, data: data}) do
    state
    |> State.append(:turn_failed, Map.get(data, :reason, "Turn failed"), data)
    |> State.status(:failed)
  end

  def apply(state, %Event{kind: :turn_cancelled}) do
    state
    |> State.append(:turn_cancelled, "Turn cancelled")
    |> State.status(:failed)
  end

  def apply(state, %Event{kind: :window_resized, data: %{width: width}}),
    do: State.append(state, :window_resized, "terminal width: #{width}", %{width: width})

  def apply(state, %Event{kind: :runtime_event, data: data}),
    do: State.append(state, :runtime_event, inspect(data), data)
end
