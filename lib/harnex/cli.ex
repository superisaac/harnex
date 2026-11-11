defmodule Harnex.CLI do
  @moduledoc """
  Command-line entry point for the standalone `harnex` executable.

  The arguments intentionally match `mix harnex.tui`, so a project can use
  either command without changing its workflow.
  """

  @spec main([String.t()]) :: no_return()
  def main(args) do
    case run(args) do
      :ok ->
        :ok

      {:error, message} ->
        IO.puts(:stderr, "harnex: #{message}")
        System.halt(1)
    end
  end

  @spec run([String.t()], keyword()) :: :ok | {:error, String.t()}
  def run(args, opts \\ []) do
    info = Keyword.get(opts, :info, &IO.puts/1)
    start_app = Keyword.get(opts, :start_app, fn -> Application.ensure_all_started(:harnex) end)

    if "--help" in args or "-h" in args do
      info.(usage())
      :ok
    else
      with {parsed, [], []} <- parse(args),
           :ok <- start_application(start_app),
           parsed <- normalize(parsed),
           result <- Harnex.TUI.start(parsed) do
        case result do
          {:error, reason} -> {:error, "unable to start TUI: #{inspect(reason)}"}
          _ -> :ok
        end
      else
        {:error, message} ->
          {:error, message}

        {_parsed, positional, invalid} ->
          {:error, "invalid options: #{inspect(positional ++ invalid)}"}
      end
    end
  end

  def usage do
    """
    Start the Harnex full-screen terminal UI.

        harnex [--workspace DIR] [--endpoint URL] [--model NAME]
               [--skill-root PATH] [--no-ansi] [--verbose]
               [--resume SESSION_ID]

    The workspace defaults to the current directory.
    """
  end

  defp parse(args) do
    OptionParser.parse(args,
      strict: [
        workspace: :string,
        endpoint: :string,
        model: :string,
        skill_root: :keep,
        no_ansi: :boolean,
        verbose: :boolean,
        resume: :string
      ]
    )
  end

  defp normalize(opts) do
    roots = Keyword.get_values(opts, :skill_root)

    opts
    |> Keyword.delete(:skill_root)
    |> maybe_put_roots(roots)
    |> Keyword.put(:fullscreen, true)
    |> maybe_no_ansi()
  end

  defp maybe_put_roots(opts, []), do: opts
  defp maybe_put_roots(opts, roots), do: Keyword.put(opts, :skill_roots, roots)

  defp maybe_no_ansi(opts),
    do: if(Keyword.get(opts, :no_ansi), do: Keyword.put(opts, :ansi, false), else: opts)

  defp start_application(start_app) do
    case start_app.() do
      {:ok, _apps} -> :ok
      {:error, {:already_started, _app}} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, "unable to start application: #{inspect(reason)}"}
    end
  end
end
