defmodule Harnex.TUI.Permissions do
  @moduledoc """
  Parses the initial permission mode from CLI/config values.
  """

  alias Harnex.TUI.Approval

  @spec parse(String.t()) :: {:ok, Approval.mode()} | {:error, :invalid_mode}
  def parse("read-only"), do: {:ok, :read_only}
  def parse("workspace-write"), do: {:ok, :on_request}
  def parse("workspace-write-auto"), do: {:ok, :auto}
  def parse("danger-full-access"), do: {:ok, :danger_full_access}
  def parse(_), do: {:error, :invalid_mode}
end
