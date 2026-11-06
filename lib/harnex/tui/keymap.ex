defmodule Harnex.TUI.Keymap do
  @moduledoc """
  Default terminal key bindings and escape-sequence decoding.
  """

  @type action ::
          :submit
          | :newline
          | :backspace
          | :left
          | :right
          | :home
          | :end
          | :interrupt
          | :help
          | {:text, String.t()}
          | :unknown

  @spec decode(binary()) :: action()
  def decode("\r"), do: :submit
  def decode("\n"), do: :newline
  def decode(<<127>>), do: :backspace
  def decode("\e[D"), do: :left
  def decode("\e[C"), do: :right
  def decode("\e[H"), do: :home
  def decode("\e[F"), do: :end
  def decode("\e"), do: :interrupt
  def decode(<<3>>), do: :interrupt
  def decode("?"), do: :help
  def decode(<<text::binary>>) when byte_size(text) > 0, do: {:text, text}
  def decode(_), do: :unknown

  @spec defaults() :: %{binary() => action()}
  def defaults do
    %{
      "enter" => :submit,
      "shift+enter" => :newline,
      "backspace" => :backspace,
      "left" => :left,
      "right" => :right,
      "home" => :home,
      "end" => :end,
      "ctrl-c" => :interrupt,
      "?" => :help
    }
  end
end
