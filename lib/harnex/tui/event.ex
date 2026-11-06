defmodule Harnex.TUI.Event do
  @moduledoc """
  Stable, user-observable lifecycle events consumed by the TUI.

  Runtime-specific events should be translated into this structure before they
  reach the renderer. Timestamps are assigned at event creation for replay and
  diagnostics; they do not expose internal reasoning details.
  """

  @type kind ::
          :session_started
          | :user_message
          | :turn_started
          | :assistant_delta
          | :assistant_message_completed
          | :tool_started
          | :tool_output
          | :tool_completed
          | :diff
          | :approval_requested
          | :approval_resolved
          | :turn_completed
          | :turn_failed
          | :turn_cancelled
          | :window_resized
          | :runtime_event

  @type t :: %__MODULE__{kind: kind(), id: String.t(), data: map(), timestamp: DateTime.t()}
  defstruct [:kind, :id, data: %{}, timestamp: nil]

  @spec new(kind(), String.t(), map()) :: t()
  def new(kind, id, data \\ %{}),
    do: %__MODULE__{kind: kind, id: id, data: data, timestamp: DateTime.utc_now()}

  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{kind: kind, id: id}) when is_atom(kind) and is_binary(id) and id != "",
    do: true

  def valid?(_), do: false
end
