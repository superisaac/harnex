defmodule Harnex.TUI.SessionStore do
  @moduledoc """
  Versioned append-only persistence for TUI events.

  Records are length-prefixed Erlang terms so a truncated final record can be
  detected without discarding the readable prefix.
  """

  alias Harnex.TUI.{Adapter, Event, State}

  @version 1

  @spec append(Path.t(), Event.t()) :: :ok | {:error, term()}
  def append(path, %Event{} = event) do
    record = :erlang.term_to_binary({@version, event})
    payload = <<byte_size(record)::32, record::binary>>
    File.mkdir_p(Path.dirname(path))
    File.write(path, payload, [:append, :binary])
  end

  @spec load(Path.t()) :: {:ok, [Event.t()], keyword()} | {:error, term()}
  def load(path) do
    case File.read(path) do
      {:ok, binary} -> decode(binary, [], [])
      {:error, :enoent} -> {:ok, [], recovered: false}
      error -> error
    end
  end

  @doc "Loads a session and replays its stable events into a TUI state."
  @spec resume(Path.t(), State.t()) :: {:ok, State.t(), keyword()} | {:error, term()}
  def resume(path, state \\ State.new()) do
    with {:ok, events, metadata} <- load(path) do
      restored = Enum.reduce(events, state, &Adapter.apply(&2, &1))
      {:ok, restored, metadata}
    end
  end

  @doc "Returns the last committed event in a session log, if present."
  @spec last(Path.t()) :: {:ok, Event.t() | nil} | {:error, term()}
  def last(path) do
    with {:ok, events, _metadata} <- load(path), do: {:ok, List.last(events)}
  end

  @spec exists?(Path.t()) :: boolean()
  def exists?(path), do: File.exists?(path)

  @doc "Reconstructs TUI state from the production RunStore snapshot."
  @spec resume_run(String.t(), State.t()) :: {:ok, State.t()} | {:error, term()}
  def resume_run(run_id, state \\ State.new()) do
    case Harnex.RunStore.get(run_id) do
      {:ok, snapshot} -> {:ok, replay_snapshot(state, snapshot)}
      error -> error
    end
  end

  defp replay_snapshot(state, snapshot) do
    state = %{state | session_id: snapshot[:run_id], status: snapshot[:status] || :idle}

    transcript = Map.get(snapshot, :transcript)

    messages =
      if is_struct(transcript),
        do: transcript.messages,
        else: Map.get(transcript || %{}, :messages, [])

    Enum.reduce(messages, state, fn message, acc ->
      kind = if message.role == :user, do: :user_message, else: :assistant_message_completed
      State.append(acc, kind, message.content)
    end)
  end

  defp decode(<<>>, events, warnings),
    do: {:ok, Enum.reverse(events), warnings: warnings, recovered: warnings == []}

  defp decode(<<size::32, rest::binary>>, events, warnings) when byte_size(rest) >= size do
    record = binary_part(rest, 0, size)
    tail = binary_part(rest, size, byte_size(rest) - size)

    case decode_record(record) do
      {:ok, event} ->
        decode(tail, [event | events], warnings)

      {:error, reason} ->
        {:ok, Enum.reverse(events),
         warnings: [{:invalid_record, reason} | warnings], recovered: false}
    end
  end

  defp decode(_truncated, events, warnings),
    do:
      {:ok, Enum.reverse(events),
       warnings: [{:truncated_record, :incomplete} | warnings], recovered: false}

  defp decode_record(record) do
    try do
      case :erlang.binary_to_term(record, [:safe]) do
        {@version, %Event{} = event} -> {:ok, event}
        {version, _event} -> {:error, {:unsupported_version, version}}
        _ -> {:error, :invalid_shape}
      end
    rescue
      _ -> {:error, :invalid_term}
    end
  end
end
