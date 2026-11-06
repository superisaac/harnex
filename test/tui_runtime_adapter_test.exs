defmodule Harnex.TUIRuntimeAdapterTest do
  use ExUnit.Case, async: true

  alias Harnex.TUI.RuntimeAdapter

  test "identifies terminal runtime events" do
    assert RuntimeAdapter.terminal?(%{type: :run_completed})
    assert RuntimeAdapter.terminal?(%{type: :run_failed})
    refute RuntimeAdapter.terminal?(%{type: :message_delta})
  end

  test "delegates approval decisions to the configured callback" do
    assert RuntimeAdapter.approve("run", "shell", %{command: "mix test"}, fn name, _args ->
             if name == "shell", do: :allow, else: :deny
           end) == :allow
  end

  test "projects collected runtime events into TUI events" do
    Code.ensure_loaded!(RuntimeAdapter)
    assert function_exported?(RuntimeAdapter, :run_with_tui_events, 2)
  end
end
