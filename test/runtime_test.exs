defmodule Harnex.RuntimeTest do
  use ExUnit.Case, async: false
  alias Harnex.TestSupport.BlockingAdapter, as: Blocking

  test "synchronous wrappers return validation errors" do
    assert {:error, :empty_prompt} = Harnex.run(" ")
    assert {:error, :invalid_limit} = Harnex.run_with_events("test", timeout: -1)
    assert {:error, :invalid_tool_context} = Harnex.run("test", tool_context: :bad)
    assert {:error, :invalid_workspace} = Harnex.run("test", workspace: :bad)
    assert {:error, :invalid_approval_callback} = Harnex.run("test", approve_tool: :bad)
    assert {:error, :invalid_skills} = Harnex.run("test", skills: [:coding])
    assert {:error, :invalid_skill_roots} = Harnex.run("test", skill_roots: [:cwd])
    assert {:error, :invalid_messages} = Harnex.run("test", messages: :bad)
    assert {:error, :invalid_run_id} = Harnex.run("test", run_id: "")
    assert {:error, :invalid_adapter} = Harnex.run("test", adapter: nil)
    assert {:error, :invalid_adapter} = Harnex.run("test", adapter: 42)
  end

  test "event collection leaves other runs' events in the mailbox" do
    unrelated = Harnex.Events.Event.new("other-run", 1, :run_completed, %{text: "other"})
    send(self(), {:harnex, unrelated})

    assert {:ok, %{text: "own"}, events} =
             Harnex.run_with_events("test",
               adapter: Harnex.Model.Scripted.new([%{text: "own"}])
             )

    assert Enum.all?(events, &(&1.run_id != "other-run"))
    assert_receive {:harnex, ^unrelated}
  end

  test "caller timeout cancels the run and stops its model worker" do
    assert {:error, %{reason: :timeout}, events} =
             Harnex.run_with_events("test", adapter: %Blocking{owner: self()}, timeout: 100)

    assert_receive {:model_started, worker}
    monitor = Process.monitor(worker)
    run_id = hd(events).run_id
    assert_receive {:harnex, %{run_id: ^run_id, type: :run_cancelled}}
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}
  end

  test "cancels a blocked model request and stops its worker" do
    {:ok, run_id, run_pid} =
      Harnex.start_run("test", adapter: %Blocking{owner: self()}, subscriber: self())

    assert_receive {:model_started, worker}
    monitor = Process.monitor(worker)
    run_monitor = Process.monitor(run_pid)

    assert {:ok, %{run_id: ^run_id, status: :running, turns: 0, tool_calls: 0}} =
             Harnex.get_run(run_id)

    assert :ok = Harnex.cancel(run_id)
    assert_receive {:harnex, %{run_id: ^run_id, type: :run_cancelled}}
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}
    assert_receive {:DOWN, ^run_monitor, :process, ^run_pid, :normal}
    refute_receive {:harnex, %{run_id: ^run_id, type: :run_completed}}
  end

  test "deadline interrupts a blocked model request" do
    {:ok, run_id, _pid} =
      Harnex.start_run("test",
        adapter: %Blocking{owner: self()},
        subscriber: self(),
        max_elapsed_ms: 100
      )

    assert_receive {:model_started, worker}
    monitor = Process.monitor(worker)

    assert_receive {:harnex, %{run_id: ^run_id, type: :run_failed, payload: %{reason: :timeout}}},
                   1000

    assert_receive {:DOWN, ^monitor, :process, ^worker, _}
  end
end
