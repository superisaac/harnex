defmodule Harnex.TUISessionRuntimeTest do
  use ExUnit.Case, async: true

  test "session uses the runtime adapter to start runs" do
    session =
      Harnex.TUI.Session.new(run_opts: [adapter: Harnex.Model.Scripted.new([%{text: "ok"}])])

    {session, result} = Harnex.TUI.Session.handle(session, {:prompt, "hello"})
    assert is_binary(session.run_id)
    assert result == :ok
    Harnex.cancel(session.run_id)
  end
end
