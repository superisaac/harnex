defmodule Harnex.TUI.Approval do
  @moduledoc """
  Approval policy decisions used by the TUI.
  """

  @type mode :: :read_only | :on_request | :auto | :danger_full_access
  @type decision :: :allow_once | :allow_session | :deny | :cancel

  @spec allowed?(mode(), atom()) :: boolean()
  def allowed?(:read_only, operation) when operation in [:read, :inspect], do: true
  def allowed?(:on_request, operation) when operation in [:read, :inspect], do: true
  def allowed?(:auto, operation) when operation in [:read, :inspect, :write], do: true
  def allowed?(:danger_full_access, _operation), do: true
  def allowed?(_, _), do: false

  @spec label(mode()) :: String.t()
  def label(:read_only), do: "read-only"
  def label(:on_request), do: "workspace-write + on-request"
  def label(:auto), do: "workspace-write + auto"
  def label(:danger_full_access), do: "danger-full-access"

  @spec decision_label(decision()) :: String.t()
  def decision_label(:allow_once), do: "Allow once"
  def decision_label(:allow_session), do: "Allow for session"
  def decision_label(:deny), do: "Deny"
  def decision_label(:cancel), do: "Cancel"
end
