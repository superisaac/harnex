defmodule Harnex.CLITest do
  use ExUnit.Case, async: true

  test "prints help without starting the application" do
    test_pid = self()

    assert :ok =
             Harnex.CLI.run(["--help"],
               info: fn text -> send(test_pid, {:help, text}) end,
               start_app: fn -> raise "application should not start" end
             )

    assert_receive {:help, text}
    assert text =~ "harnex [--workspace DIR]"
  end

  test "rejects positional and unknown arguments" do
    assert {:error, message} = Harnex.CLI.run(["project", "--unknown"])
    assert message =~ "invalid options"
  end
end
