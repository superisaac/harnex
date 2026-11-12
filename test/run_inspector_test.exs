defmodule Harnex.RunInspectorTest do
  use ExUnit.Case, async: true

  alias Harnex.Conversation.{Message, Transcript}

  test "formats a transcript as readable conversation text" do
    transcript =
      Transcript.new()
      |> Transcript.append(Message.new(:user, "Explain this"))
      |> Transcript.append(
        Message.new(:assistant, "I will inspect it.",
          tool_calls: [%{id: "call-1", name: "file_read", args: %{path: "README.md"}}]
        )
      )
      |> Transcript.append(Message.new(:tool, "{:ok, \"contents\"}", tool_call_id: "call-1"))
      |> Transcript.append(Message.new(:assistant, "Here is the explanation."))

    output =
      Harnex.RunInspector.format(%{
        run_id: "run-test",
        status: :completed,
        turns: 2,
        tool_calls: 1,
        transcript: transcript
      })

    assert output =~ "Run run-test"
    assert output =~ "1. You\n  Explain this"
    assert output =~ "2. Assistant\n  I will inspect it."
    assert output =~ "Tool call 1: file_read(%{path: \"README.md\"})"
    assert output =~ "3. Tool result"
    assert output =~ "4. Assistant\n  Here is the explanation."
    refute output =~ "{\"run_id\""
  end

  test "handles snapshots without a transcript" do
    output = Harnex.RunInspector.format(%{run_id: "empty", status: :failed})
    assert output =~ "(no messages recorded)"
  end
end
