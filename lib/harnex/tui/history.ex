defmodule Harnex.TUI.History do
  @moduledoc """
  Prompt history navigation.
  """

  @spec push([String.t()], String.t()) :: [String.t()]
  def push(history, ""), do: history
  def push(history, prompt), do: Enum.uniq([prompt | history])

  @spec get([String.t()], integer()) :: String.t()
  def get(history, index), do: Enum.at(history, index, "")
end
