defmodule Harnex.RegistryTest.Incomplete do
  def name, do: "incomplete"
end

defmodule Harnex.RegistryTest do
  use ExUnit.Case, async: true
  alias Harnex.Tools.{Echo, Registry}

  test "rejects modules missing execution callbacks" do
    assert {:error, :invalid_tool} = Registry.validate([Harnex.RegistryTest.Incomplete])
  end

  test "validates map registrations before starting a run" do
    assert {:error, :invalid_tool_registry} = Harnex.start_run("test", tools: :bad)

    assert {:error, :tool_name_mismatch} =
             Harnex.start_run("test", tools: %{"wrong" => Echo})

    assert {:error, :invalid_tool} = Harnex.start_run("test", tools: %{"bad" => MissingTool})
  end

  test "rejects collisions across map and module registrations" do
    assert {:error, :duplicate_tool_name} =
             Harnex.start_run("test", tools: Registry.new([Echo]), tool_modules: [Echo])

    assert_raise ArgumentError, fn -> Registry.new([Echo, Echo]) end
  end

  test "tool descriptions are sorted by name" do
    registry = Registry.new([Harnex.Tools.FileWrite, Echo])
    assert Enum.map(Registry.descriptions(registry), & &1.name) == ["echo", "file_write"]
  end
end
