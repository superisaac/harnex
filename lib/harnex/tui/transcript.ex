defmodule Harnex.TUI.Transcript do
  @moduledoc """
  Search and filter helpers for transcript blocks.
  """

  @spec search([map()], String.t()) :: [map()]
  def search(blocks, ""), do: blocks

  def search(blocks, query) do
    query = String.downcase(query)

    Enum.filter(blocks, fn block ->
      block
      |> Map.get(:content, "")
      |> IO.iodata_to_binary()
      |> String.downcase()
      |> String.contains?(query)
    end)
  end
end
