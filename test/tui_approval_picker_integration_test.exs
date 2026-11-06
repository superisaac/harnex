defmodule Harnex.TUIApprovalPickerIntegrationTest do
  use ExUnit.Case, async: true

  test "TermUIApp sends the picker decision back to the waiting runtime task" do
    state = Harnex.TUI.TermUIApp.init(dimensions: {80, 24}, ear_runtime_opts: [])
    ref = make_ref()

    state =
      Harnex.TUI.TermUIApp.handle_info(
        {:harnex_approval_request, self(), ref, "shell", %{command: "mix test"}},
        state
      )

    state = Harnex.TUI.TermUIApp.update({:key, :down, []}, state)
    _state = Harnex.TUI.TermUIApp.update({:key, :enter, []}, state)

    assert_receive {:harnex_approval_response, ^ref, :allow}
  end
end
