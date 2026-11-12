defmodule Mix.Tasks.Harnex.Inspect do
  use Mix.Task

  @shortdoc "Show a human-readable transcript for a run"
  @moduledoc """
  Displays every recorded user, assistant, and tool exchange for a run.

      mix harnex.inspect RUN_ID
  """

  @impl true
  def run([run_id]) when is_binary(run_id) and run_id != "" do
    Mix.Task.run("app.start")

    case Harnex.RunInspector.report(run_id) do
      {:ok, report} ->
        Mix.shell().info(report)

      {:error, :not_found} ->
        Mix.raise("Run not found: #{run_id}")

      {:error, reason} ->
        Mix.raise("Unable to inspect run #{run_id}: #{inspect(reason)}")
    end
  end

  def run(_args), do: Mix.raise("Usage: mix harnex.inspect RUN_ID")
end
