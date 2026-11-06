defmodule Harnex.TUI.InteractiveInput do
  @moduledoc """
  Pure key-action handling for the fullscreen TUI.
  """

  alias Harnex.TUI.{Composer, State}

  @type result ::
          {:continue, State.t()}
          | {:submit, State.t(), String.t()}
          | {:interrupt, State.t()}

  @spec apply(State.t(), atom() | {:text, String.t()}) :: result()
  def apply(state, {:text, text}),
    do: {:continue, put_draft(state, Composer.insert(composer(state), text))}

  def apply(state, :newline), do: {:continue, put_draft(state, Composer.newline(composer(state)))}

  def apply(state, :backspace),
    do: {:continue, put_draft(state, Composer.backspace(composer(state)))}

  def apply(state, action) when action in [:left, :right, :home, :end],
    do: {:continue, put_draft(state, Composer.move(composer(state), action))}

  def apply(state, :submit) do
    {prompt, _composer} = Composer.submit(composer(state))
    {:submit, %{state | draft: "", cursor: 0}, prompt}
  end

  def apply(state, :interrupt), do: {:interrupt, State.status(state, :failed)}

  def apply(state, :help),
    do: {:continue, State.append(state, :help, "Enter submits; Shift+Enter inserts a newline.")}

  def apply(state, _unknown), do: {:continue, state}

  defp composer(state), do: %{text: state.draft, cursor: state.cursor}
  defp put_draft(state, composer), do: %{state | draft: composer.text, cursor: composer.cursor}
end
