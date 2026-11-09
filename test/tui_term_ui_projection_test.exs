defmodule Harnex.TUITermUIProjectionTest do
  use ExUnit.Case, async: true

  test "TermUIApp keeps the experimental TUI state in sync with runtime events" do
    state = Harnex.TUI.TermUIApp.init(dimensions: {80, 24}, ear_runtime_opts: [])
    event = Harnex.Events.Event.new("run-1", 1, :message_delta, %{text: "hello"})
    projected = Harnex.TUI.TermUIApp.handle_info({:harnex, event}, state)

    assert projected.tui_state.blocks != []
    assert projected.lines == ["hello"]
  end

  test "completed streamed output replaces the temporary assistant block" do
    state = Harnex.TUI.TermUIApp.init(dimensions: {80, 24}, ear_runtime_opts: [])
    delta = Harnex.Events.Event.new("run-1", 1, :message_delta, %{text: "hello"})
    complete = Harnex.Events.Event.new("run-1", 2, :message_completed, %{text: "hello"})

    projected = Harnex.TUI.TermUIApp.handle_info({:harnex, delta}, state)
    projected = Harnex.TUI.TermUIApp.handle_info({:harnex, complete}, projected)

    assert Enum.map(projected.tui_state.blocks, & &1.kind) == [:assistant_message_completed]
    assert projected.lines == ["hello"]
  end

  test "resumed session id survives the next run" do
    state = Harnex.TUI.TermUIApp.init(dimensions: {80, 24}, ear_runtime_opts: [])
    state = %{state | tui_state: %{state.tui_state | session_id: "session-1"}}
    event = Harnex.Events.Event.new("run-2", 1, :run_started, %{run_id: "run-2"})

    projected = Harnex.TUI.TermUIApp.handle_info({:harnex, event}, state)

    assert projected.tui_state.session_id == "session-1"
  end

  test "tool lifecycle events stay in the status line" do
    state = Harnex.TUI.TermUIApp.init(dimensions: {80, 24}, ear_runtime_opts: [])
    started = Harnex.Events.Event.new("run-1", 1, :tool_call_started, %{name: "file_list"})
    completed = Harnex.Events.Event.new("run-1", 2, :tool_call_completed, %{name: "file_list"})

    state = Harnex.TUI.TermUIApp.handle_info({:harnex, started}, state)
    assert state.tui_state.blocks == []
    assert state.status == "Tool: file_list"

    state = Harnex.TUI.TermUIApp.handle_info({:harnex, completed}, state)
    assert state.tui_state.blocks == []
    assert state.status == "Tool completed"
  end

  test "TermUIApp renders structured failure reasons without crashing" do
    state = Harnex.TUI.TermUIApp.init(dimensions: {80, 24}, ear_runtime_opts: [])
    event = Harnex.Events.Event.new("run-1", 1, :run_failed, %{reason: {:transport, :timeout}})

    projected = Harnex.TUI.TermUIApp.handle_info({:harnex, event}, state)

    assert projected.lines == ["{:transport, :timeout}"]
    assert projected.status == "Failed"
  end

  test "TermUIApp handles resize, paging, and transcript copy in fullscreen mode" do
    state = Harnex.TUI.TermUIApp.init(dimensions: {20, 6}, ear_runtime_opts: [])
    state = %{state | lines: Enum.map(1..20, &"line #{&1}")}

    {paged, []} = Harnex.TUI.TermUIApp.update({:key, :page_up, []}, state)
    assert paged.scroll > 0

    {copied, [clipboard]} =
      Harnex.TUI.TermUIApp.update({:key, "o", [:ctrl]}, paged)

    assert copied == paged
    assert %TermUI.Command{kind: :clipboard} = clipboard

    resized = Harnex.TUI.TermUIApp.update({:resize, 40, 10}, state)
    assert resized.dimensions == {40, 10}
    assert %TermUI.Frame{} = Harnex.TUI.TermUIApp.view(resized)
  end

  test "TermUIApp maps mouse wheel events to transcript scrolling" do
    state = Harnex.TUI.TermUIApp.init(dimensions: {20, 6}, ear_runtime_opts: [])

    assert {:msg, {:scroll, :up}} =
             Harnex.TUI.TermUIApp.event_to_msg(TermUI.Event.mouse(:scroll_up, nil, 0, 0), nil)

    {scrolled, []} = Harnex.TUI.TermUIApp.update({:scroll, :up}, state)
    assert scrolled.scroll == 3

    {scrolled, []} = Harnex.TUI.TermUIApp.update({:scroll, :down}, scrolled)
    assert scrolled.scroll == 0
  end

  test "TermUIApp prints a resume hint for the /exit command" do
    state = Harnex.TUI.TermUIApp.init(dimensions: {20, 6}, ear_runtime_opts: [])
    state = %{state | tui_state: %{state.tui_state | session_id: "run-exit"}}

    output =
      ExUnit.CaptureIO.capture_io(fn ->
        {state, []} = Harnex.TUI.TermUIApp.update({:text, "/exit"}, state)
        Harnex.TUI.TermUIApp.update({:key, :enter, []}, state)
      end)

    assert output =~ "to resume run mix harnex.tui --resume run-exit"
  end

  test "TermUIApp reports the resume hint after the terminal is restored" do
    ref = make_ref()

    state =
      Harnex.TUI.TermUIApp.init(
        dimensions: {20, 6},
        ear_runtime_opts: [exit_reporter: {self(), ref}]
      )

    state = %{state | tui_state: %{state.tui_state | session_id: "run-exit"}}
    {state, []} = Harnex.TUI.TermUIApp.update({:text, "/exit"}, state)
    Harnex.TUI.TermUIApp.update({:key, :enter, []}, state)

    assert_receive {:harnex_tui_resume_hint, ^ref, "run-exit"}
  end

  test "exit keeps the resumed session id after a new run starts" do
    ref = make_ref()

    state =
      Harnex.TUI.TermUIApp.init(
        dimensions: {20, 6},
        ear_runtime_opts: [exit_reporter: {self(), ref}]
      )

    session = %{state.session | run_id: "new-run"}

    state = %{
      state
      | session: session,
        tui_state: %{state.tui_state | session_id: "original-run"}
    }

    {state, []} = Harnex.TUI.TermUIApp.update({:text, "/exit"}, state)
    Harnex.TUI.TermUIApp.update({:key, :enter, []}, state)

    assert_receive {:harnex_tui_resume_hint, ^ref, "original-run"}
  end

  test "fullscreen view exposes the new header, styled transcript, and footer" do
    state = Harnex.TUI.TermUIApp.init(dimensions: {60, 12}, ear_runtime_opts: [])
    state = %{state | tui_state: Harnex.TUI.State.submit(state.tui_state, "list files")}
    frame = Harnex.TUI.TermUIApp.view(state)

    assert TermUI.Frame.row_text(frame, 1) =~ "Harnex"
    assert TermUI.Frame.row_text(frame, 1) =~ "workspace-write"
    assert Enum.any?(1..12, &(TermUI.Frame.row_text(frame, &1) =~ "list files"))
    assert Enum.any?(1..12, &(TermUI.Frame.row_text(frame, &1) =~ "Ctrl-O copy"))
  end
end
