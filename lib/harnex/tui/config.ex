defmodule Harnex.TUI.Config do
  @moduledoc """
  Validated TUI display and terminal configuration.
  """

  @type t :: %__MODULE__{mode: :fullscreen | :scrollback, status_line: [atom()], theme: atom()}
  defstruct mode: :fullscreen, status_line: [:model, :permission, :status], theme: :default

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct!(__MODULE__,
      mode: Keyword.get(opts, :mode, :fullscreen),
      status_line: Keyword.get(opts, :status_line, [:model, :permission, :status]),
      theme: Keyword.get(opts, :theme, :default)
    )
  end

  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{mode: mode, status_line: fields, theme: theme}) do
    mode in [:fullscreen, :scrollback] and is_list(fields) and is_atom(theme)
  end

  @spec from_env() :: t()
  def from_env do
    mode =
      if System.get_env("HARNEX_TUI_MODE") == "scrollback", do: :scrollback, else: :fullscreen

    new(mode: mode)
  end
end
