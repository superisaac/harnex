defmodule Harnex.TUI.Diff do
  @moduledoc """
  Classifies unified diff lines for transcript rendering.
  """

  @spec classify(String.t()) :: :addition | :deletion | :header | :context
  def classify(<<"+++", _::binary>>), do: :header
  def classify(<<"---", _::binary>>), do: :header
  def classify(<<"+", _::binary>>), do: :addition
  def classify(<<"-", _::binary>>), do: :deletion
  def classify(_), do: :context
end
