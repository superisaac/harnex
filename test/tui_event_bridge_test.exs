defmodule Harnex.TUIEventBridgeTest do
  use ExUnit.Case, async: true

  test "maps runtime message events to TUI events" do
    runtime = Harnex.Events.Event.new("run-1", 1, :message_delta, %{text: "hello"})
    event = Harnex.TUI.EventBridge.from_runtime(runtime)
    assert event.kind == :assistant_delta
    assert event.data.content == "hello"
  end

  test "maps terminal run events" do
    runtime = Harnex.Events.Event.new("run-1", 2, :run_completed, %{text: "done"})
    assert Harnex.TUI.EventBridge.from_runtime(runtime).kind == :turn_completed
  end

  test "keeps unknown runtime events visible without exposing private shape" do
    runtime = Harnex.Events.Event.new("run-1", 3, :usage, %{tokens: 10})
    event = Harnex.TUI.EventBridge.from_runtime(runtime)
    assert event.kind == :runtime_event
    assert event.data.type == :usage
  end
end
