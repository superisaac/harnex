defmodule Harnex.TUI.Scroll do
  @moduledoc """
  Pure transcript scroll position operations.
  """

  @spec move(non_neg_integer(), non_neg_integer(), :up | :down | :top | :bottom) ::
          non_neg_integer()
  def move(_position, _total, :top), do: 0
  def move(_position, total, :bottom), do: max(total - 1, 0)
  def move(position, total, :up), do: max(position - 1, 0) |> min(max(total - 1, 0))
  def move(position, total, :down), do: min(position + 1, max(total - 1, 0))
  def move(position, total, :page_up), do: max(position - 10, 0) |> min(max(total - 1, 0))
  def move(position, total, :page_down), do: min(position + 10, max(total - 1, 0))
end
