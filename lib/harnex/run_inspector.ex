defmodule Harnex.RunInspector do
  @moduledoc """
  Renders a stored run transcript for people, rather than for machines.

  The inspector deliberately formats values as text and never emits JSON.
  """

  alias Harnex.Conversation.Transcript

  @doc "Returns a human-readable report for a run snapshot."
  @spec format(map()) :: String.t()
  def format(snapshot) when is_map(snapshot) do
    messages = messages(snapshot[:transcript])

    [
      "Run #{snapshot[:run_id] || "unknown"}",
      "Status: #{format_value(snapshot[:status] || :unknown)}",
      "Turns: #{snapshot[:turns] || 0}",
      "Tool calls: #{snapshot[:tool_calls] || 0}",
      "",
      "Conversation",
      format_messages(messages)
    ]
    |> Enum.join("\n")
  end

  @doc "Loads and formats a run from memory or its persisted TUI session log."
  @spec report(String.t(), Path.t()) :: {:ok, String.t()} | {:error, :not_found | term()}
  def report(run_id, workspace \\ File.cwd!()) when is_binary(run_id) do
    case Harnex.get_run(run_id) do
      {:ok, snapshot} ->
        {:ok, format(snapshot)}

      {:error, :not_found} ->
        path = Harnex.TUI.SessionStore.path(workspace, run_id)

        case Harnex.TUI.SessionStore.load(path) do
          {:ok, events, _metadata} when events != [] ->
            {:ok, format_session(events, run_id)}

          {:ok, _events, _metadata} ->
            {:error, :not_found}

          error ->
            error
        end

      error ->
        error
    end
  end

  @doc "Returns a human-readable report from a persisted TUI session log."
  @spec format_session([struct()], String.t()) :: String.t()
  def format_session(events, run_id) when is_list(events) do
    {messages, turns, tool_calls, _partial} =
      Enum.reduce(events, {[], 0, 0, nil}, fn event, acc ->
        append_session_event(acc, event)
      end)

    format(%{
      run_id: run_id,
      status: session_status(events),
      turns: turns,
      tool_calls: tool_calls,
      transcript: %{messages: messages}
    })
  end

  defp messages(%Transcript{} = transcript), do: Transcript.to_list(transcript)
  defp messages(%{messages: messages}) when is_list(messages), do: messages
  defp messages(messages) when is_list(messages), do: messages
  defp messages(_), do: []

  defp append_session_event({messages, turns, tool_calls, partial}, event) do
    kind = Map.get(event, :kind)
    data = Map.get(event, :data, %{})

    case kind do
      :user_message ->
        {messages ++ [message(:user, Map.get(data, :content, ""))], turns, tool_calls, nil}

      :assistant_delta ->
        text = (partial || "") <> to_string(Map.get(data, :content, ""))
        {messages, turns, tool_calls, text}

      :assistant_message_completed ->
        text = Map.get(data, :content, partial || "")
        {messages ++ [message(:assistant, text)], turns, tool_calls, nil}

      :tool_started ->
        name = Map.get(data, :name, "unknown tool")
        {messages ++ [message(:assistant, "Tool call: #{name}")], turns, tool_calls + 1, nil}

      :tool_completed ->
        result = Map.get(data, :result, "")
        {messages ++ [message(:tool, "#{format_value(result)}")], turns, tool_calls, nil}

      :turn_completed ->
        {messages, turns + 1, tool_calls, partial}

      _ ->
        {messages, turns, tool_calls, partial}
    end
  end

  defp message(role, content), do: %{role: role, content: content}

  defp session_status(events) do
    events
    |> List.last()
    |> case do
      %{kind: :turn_completed} -> :completed
      %{kind: :turn_failed} -> :failed
      %{kind: :turn_cancelled} -> :cancelled
      _ -> :unknown
    end
  end

  defp format_messages([]), do: "(no messages recorded)"

  defp format_messages(messages) do
    messages
    |> Enum.with_index(1)
    |> Enum.map_join("\n\n", fn {message, index} -> format_message(message, index) end)
  end

  defp format_message(message, index) do
    role = role_label(Map.get(message, :role))
    content = Map.get(message, :content) || ""
    calls = Map.get(message, :tool_calls)
    body = indent(format_value(content))
    calls_text = format_tool_calls(calls)

    ["#{index}. #{role}", body, calls_text]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp format_tool_calls(calls) when is_list(calls) and calls != [] do
    calls
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {call, index} ->
      name = Map.get(call, :name) || Map.get(call, "name") || "unknown tool"
      args = Map.get(call, :args) || Map.get(call, "args")
      "  Tool call #{index}: #{name}(#{format_value(args)})"
    end)
  end

  defp format_tool_calls(_), do: ""

  defp role_label(:user), do: "You"
  defp role_label(:assistant), do: "Assistant"
  defp role_label(:tool), do: "Tool result"
  defp role_label(:system), do: "System"
  defp role_label(role), do: role |> to_string() |> String.capitalize()

  defp indent(text) do
    text
    |> String.split("\n", trim: false)
    |> Enum.map_join("\n", &("  " <> &1))
  end

  defp format_value(value) when is_binary(value), do: value
  defp format_value(value) when is_atom(value), do: Atom.to_string(value)
  defp format_value(value), do: inspect(value, pretty: true, limit: :infinity)
end
