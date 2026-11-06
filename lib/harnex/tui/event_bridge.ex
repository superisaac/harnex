defmodule Harnex.TUI.EventBridge do
  @moduledoc """
  Converts real Agent events into the experimental TUI event model.
  """

  alias Harnex.TUI.Event

  @spec from_runtime(Harnex.Events.Event.t()) :: Event.t()
  def from_runtime(%Harnex.Events.Event{type: type, seq: seq, payload: payload}) do
    {kind, data} = convert(type, payload)
    Event.new(kind, Integer.to_string(seq), data)
  end

  defp convert(:run_started, payload),
    do: {:session_started, Map.put_new(payload, :session_id, payload[:run_id])}

  defp convert(:message_delta, %{text: text}), do: {:assistant_delta, %{content: text}}

  defp convert(:message_completed, %{text: text}),
    do: {:assistant_message_completed, %{content: text}}

  defp convert(:tool_call_started, payload), do: {:tool_started, payload}
  defp convert(:tool_call_completed, payload), do: {:tool_completed, payload}
  defp convert(:tool_call_failed, payload), do: {:turn_failed, payload}
  defp convert(:run_completed, payload), do: {:turn_completed, payload}
  defp convert(:run_cancelled, payload), do: {:turn_cancelled, payload}
  defp convert(:run_failed, payload), do: {:turn_failed, payload}
  defp convert(type, payload), do: {:runtime_event, %{type: type, payload: payload}}
end
