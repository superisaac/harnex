defmodule Harnex.TUI.Loop do
  @moduledoc """
  Dispatches one terminal input sequence through the keymap and TUI state.
  """

  alias Harnex.TUI.{InteractiveInput, Keymap, State}

  @type result :: {:continue, State.t()} | {:interrupt, State.t()} | {:submit, State.t()}

  @spec handle_key(State.t(), binary(), keyword()) :: result()
  def handle_key(state, bytes, _opts \\ []) do
    case InteractiveInput.apply(state, Keymap.decode(bytes)) do
      {:continue, next} -> {:continue, next}
      {:interrupt, next} -> {:interrupt, next}
      {:submit, next, ""} -> {:continue, next}
      {:submit, next, prompt} -> {:submit, next, prompt}
    end
  end
end
