defmodule Harnex.TUI.StatusLine do
  @moduledoc """
  Formats configurable footer fields.
  """

  @spec format(map(), [atom()]) :: String.t()
  def format(state, fields) do
    fields |> Enum.map(&field(&1, state)) |> Enum.reject(&(&1 == "")) |> Enum.join("  ")
  end

  defp field(:model, state), do: "model:#{state.model}"
  defp field(:permission, state), do: state.permission
  defp field(:status, state), do: state.status |> Atom.to_string() |> String.upcase()
  defp field(:branch, state), do: if(state.branch, do: "git:#{state.branch}", else: "")

  defp field(:context, state),
    do: if(state.context_used, do: "context:#{state.context_used}", else: "")

  defp field(_, _state), do: ""
end
