defmodule Harnex.TUITermUIProjectionTest do
  use ExUnit.Case, async: true

  test "TermUIApp keeps the experimental TUI state in sync with runtime events" do
    state = Harnex.TUI.TermUIApp.init(dimensions: {80, 24}, ear_runtime_opts: [])
    event = Harnex.Events.Event.new("run-1", 1, :message_delta, %{text: "hello"})
    projected = Harnex.TUI.TermUIApp.handle_info({:harnex, event}, state)

    assert projected.tui_state.blocks != []
    assert projected.lines == ["hello"]
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
