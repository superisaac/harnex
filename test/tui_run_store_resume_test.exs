defmodule Harnex.TUIRunStoreResumeTest do
  use ExUnit.Case, async: false

  test "TUI resume reads the production RunStore snapshot" do
    Harnex.clear_runs()

    transcript = %Harnex.Conversation.Transcript{
      messages: [
        Harnex.Conversation.Message.new(:user, "hello"),
        Harnex.Conversation.Message.new(:assistant, "world")
      ]
    }

    :ok = Harnex.RunStore.put(%{run_id: "run-resume", status: :completed, transcript: transcript})
    assert {:ok, state} = Harnex.TUI.SessionStore.resume_run("run-resume")
    assert state.session_id == "run-resume"
    assert state.status == :completed
    assert length(state.blocks) == 2
    Harnex.clear_runs()
  end
end
