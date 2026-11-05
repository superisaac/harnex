defmodule Harnex.RunStoreTest do
  use ExUnit.Case, async: false

  test "list_runs accepts a nonnegative limit" do
    Harnex.clear_runs()
    Harnex.RunStore.put(%{run_id: "a", status: :completed})
    Harnex.RunStore.put(%{run_id: "b", status: :completed})
    assert [%{run_id: "a"}] = Harnex.list_runs(1)
    assert [] = Harnex.list_runs(0)
    Harnex.delete_run("a")
    Harnex.delete_run("b")
  end

  test "list_runs rejects invalid limits" do
    assert {:error, :invalid_limit} = Harnex.list_runs(-1)
    assert {:error, :invalid_limit} = Harnex.list_runs(:all)
  end

  test "lists snapshots in insertion order" do
    {:ok, store} = Harnex.RunStore.start_link(max_runs: 10, name: nil)
    Harnex.RunStore.put(%{run_id: "z", status: :completed}, store)
    Harnex.RunStore.put(%{run_id: "a", status: :completed}, store)

    assert [%{run_id: "z"}, %{run_id: "a"}] = Harnex.RunStore.list(:all, store)
    GenServer.stop(store)
  end

  test "a custom store evicts older snapshots" do
    {:ok, store} = Harnex.RunStore.start_link(max_runs: 1, name: nil)
    Harnex.RunStore.put(%{run_id: "old", status: :completed}, store)
    Harnex.RunStore.put(%{run_id: "new", status: :completed}, store)
    assert {:error, :not_found} = Harnex.RunStore.get("old", store)
    assert [%{run_id: "new"}] = Harnex.RunStore.list(:all, store)
    GenServer.stop(store)
  end
end
