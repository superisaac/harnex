defmodule Harnex.TUI.Composer do
  @moduledoc """
  Pure multiline prompt editing operations.
  """

  @type t :: %{text: String.t(), cursor: non_neg_integer()}

  @spec new(String.t()) :: t()
  def new(text \\ ""), do: %{text: text, cursor: String.length(text)}

  @spec insert(t(), String.t()) :: t()
  def insert(%{text: text, cursor: cursor}, value) do
    {left, right} = String.split_at(text, cursor)
    %{text: left <> value <> right, cursor: cursor + String.length(value)}
  end

  @spec newline(t()) :: t()
  def newline(composer), do: insert(composer, "\n")

  @spec backspace(t()) :: t()
  def backspace(%{cursor: 0} = composer), do: composer

  def backspace(%{text: text, cursor: cursor}) do
    {left, right} = String.split_at(text, cursor)
    left = String.slice(left, 0, String.length(left) - 1)
    %{text: left <> right, cursor: cursor - 1}
  end

  @spec move(t(), :left | :right | :home | :end) :: t()
  def move(%{cursor: cursor} = composer, :left), do: %{composer | cursor: max(cursor - 1, 0)}

  def move(%{text: text, cursor: cursor} = composer, :right),
    do: %{composer | cursor: min(cursor + 1, String.length(text))}

  def move(composer, :home), do: %{composer | cursor: 0}
  def move(%{text: text} = composer, :end), do: %{composer | cursor: String.length(text)}

  @spec submit(t()) :: {String.t(), t()}
  def submit(%{text: text}), do: {text, new()}
end
