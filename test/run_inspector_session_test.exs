defmodule Harnex.RunInspectorSessionTest do
  use ExUnit.Case, async: true

  alias Harnex.TUI.Event

  test "formats persisted session events as one readable conversation" do
    events = [
      Event.new(:user_message, "1", %{content: "What is 1 + 5?"}),
      Event.new(:assistant_delta, "2", %{content: "6"}),
      Event.new(:assistant_message_completed, "3", %{content: "6"}),
      Event.new(:turn_completed, "4", %{text: "6"}),
      Event.new(:user_message, "5", %{content: "Multiply it by 3"}),
      Event.new(:assistant_message_completed, "6", %{content: "18"}),
      Event.new(:turn_completed, "7", %{text: "18"})
    ]

    output = Harnex.RunInspector.format_session(events, "run-test")

    assert output =~ "Run run-test"
    assert output =~ "Turns: 2"
    assert output =~ "1. You\n  What is 1 + 5?"
    assert output =~ "2. Assistant\n  6"
    assert output =~ "3. You\n  Multiply it by 3"
    assert output =~ "4. Assistant\n  18"
  end
end
