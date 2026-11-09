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

  test "auto-approves workspace file reads" do
    root = Path.join(System.tmp_dir!(), "harnex-tui-read-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    File.write!(Path.join(root, "hello.txt"), "hello")

    adapter =
      Harnex.Model.Scripted.new([
        %{tool_calls: [%{id: "read", name: "file_read", args: %{"path" => "hello.txt"}}]},
        %{text: "done"}
      ])

    tools = Harnex.Tools.Registry.new([Harnex.Tools.FileRead])

    assert {:ok, run_id, _pid} =
             RuntimeAdapter.start("read it",
               adapter: adapter,
               tools: tools,
               workspace: root,
               subscriber: self()
             )

    assert_receive {:harnex, %{run_id: ^run_id, type: :run_completed}}, 1_000
    refute_receive {:harnex_approval_request, _, _, "file_read", _}, 50
  end
end
