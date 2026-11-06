defmodule Harnex.TUI.Mention do
  @moduledoc """
  Extracts file mentions from a prompt without filesystem side effects.
  """

  @spec extract(String.t()) :: [String.t()]
  def extract(prompt) do
    Regex.scan(~r/(?:^|\s)@([^\s]+)/, prompt, capture: :all_but_first)
    |> List.flatten()
  end
end
