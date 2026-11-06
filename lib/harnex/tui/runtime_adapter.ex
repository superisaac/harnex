defmodule Harnex.TUI.RuntimeAdapter do
  @moduledoc """
  Thin adapter between the real Harnex run API and TUI consumers.

  Harnex already emits `Harnex.Events.Event` values through subscribers. This
  module keeps the TUI boundary independent from the Agent loop implementation.
  """

  @spec start(String.t(), keyword(), pid()) :: {:ok, String.t(), pid()} | {:error, term()}
  def start(prompt, opts \\ [], subscriber \\ self()) do
    opts = Keyword.put(opts, :subscriber, subscriber)
    opts = Keyword.put_new(opts, :approve_tool, approval_callback(subscriber))
    Harnex.start_run(prompt, opts)
  end

  @spec subscribe(String.t(), pid()) :: :ok | {:error, term()}
  def subscribe(run_id, subscriber \\ self()), do: Harnex.subscribe(run_id, subscriber)

  @spec cancel(String.t()) :: :ok | {:error, term()}
  def cancel(run_id), do: Harnex.cancel(run_id)

  @spec snapshot(String.t()) :: {:ok, map()} | {:error, term()}
  def snapshot(run_id), do: Harnex.get_run(run_id)

  @spec terminal?(map()) :: boolean()
  def terminal?(%{type: type}), do: type in [:run_completed, :run_failed, :run_cancelled]
  def terminal?(_), do: false

  @spec status(String.t()) :: {:ok, map()} | {:error, term()}
  def status(run_id), do: snapshot(run_id)

  @spec approve(String.t(), String.t(), map(), (String.t(), map() -> atom())) :: atom()
  def approve(_run_id, name, args, callback) when is_function(callback, 2),
    do: callback.(name, args)

  defp approval_callback(subscriber) do
    fn name, args ->
      ref = make_ref()
      send(subscriber, {:harnex_approval_request, self(), ref, name, args})

      receive do
        {:harnex_approval_response, ^ref, decision} -> decision
      after
        30_000 -> :deny
      end
    end
  end

  @spec event_to_tui(Harnex.Events.Event.t()) :: Harnex.TUI.Event.t()
  def event_to_tui(event), do: Harnex.TUI.EventBridge.from_runtime(event)

  @spec run_with_events(String.t(), keyword()) :: {:ok, map(), [map()]} | {:error, map(), [map()]}
  def run_with_events(prompt, opts \\ []), do: Harnex.run_with_events(prompt, opts)

  @spec run_with_tui_events(String.t(), keyword()) ::
          {:ok, map(), [Harnex.TUI.Event.t()]} | {:error, map(), [Harnex.TUI.Event.t()]}
  def run_with_tui_events(prompt, opts \\ []) do
    case run_with_events(prompt, opts) do
      {status, payload, events} -> {status, payload, Enum.map(events, &event_to_tui/1)}
      other -> other
    end
  end
end
