defmodule Harnex.TUI.Terminal do
  @moduledoc """
  Terminal lifecycle helpers shared by TUI frontends.
  """

  @spec enter(:fullscreen | :scrollback) :: iodata()
  def enter(:fullscreen), do: "\e[?1049h\e[?25l"
  def enter(:scrollback), do: ""

  @spec leave(:fullscreen | :scrollback) :: iodata()
  def leave(:fullscreen), do: "\e[0m\e[?25h\e[?1049l"
  def leave(:scrollback), do: "\e[0m"

  @spec width(non_neg_integer()) :: pos_integer()
  def width(fallback \\ 80) do
    case System.cmd("stty", ["size"], stderr_to_stdout: true) do
      {output, 0} -> output |> String.split() |> List.last() |> String.to_integer()
      _ -> fallback
    end
  rescue
    _ -> fallback
  end
end
