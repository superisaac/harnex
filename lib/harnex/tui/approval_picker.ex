defmodule Harnex.TUI.ApprovalPicker do
  @moduledoc """
  Keyboard navigation for approval decisions.
  """

  alias Harnex.TUI.Approval

  @decisions [:allow_once, :allow_session, :deny, :cancel]
  @spec move(non_neg_integer(), :up | :down) :: non_neg_integer()
  def move(index, :up), do: max(index - 1, 0)
  def move(index, :down), do: min(index + 1, length(@decisions) - 1)

  @spec selected(non_neg_integer()) :: Approval.decision()
  def selected(index), do: Enum.at(@decisions, min(index, length(@decisions) - 1))

  @spec labels() :: [String.t()]
  def labels, do: Enum.map(@decisions, &Approval.decision_label/1)
end
