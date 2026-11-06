defmodule Harnex.TUIFullscreenManualTest do
  use ExUnit.Case, async: true

  alias Harnex.TUI.Fullscreen

  test "ctrl-o exposes transcript copy and parses the shortcut" do
    state = %{Fullscreen.new() | lines: ["hello", "world"]}
    assert Fullscreen.parse_key(<<15>>) == :ctrl_o
    assert Fullscreen.copy_text(state) == "hello\nworld"
    assert {^state, {:copy, "hello\nworld"}} = Fullscreen.handle_key(state, :ctrl_o)
  end

  test "raw input, resize and scroll paths are available without a live terminal" do
    state = %{Fullscreen.new(width: 80, height: 24) | lines: Enum.map(1..50, &to_string/1)}
    assert Fullscreen.parse_key("\e[5~") == :page_up
    assert Fullscreen.parse_key("\e[6~") == :page_down
    assert {scrolled, :none} = Fullscreen.handle_key(state, :page_up)
    assert scrolled.scroll > 0
    assert Fullscreen.render_frame(%{scrolled | width: 40, height: 10}) =~ "[Ready]"
  end
end
