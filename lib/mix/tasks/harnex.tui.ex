defmodule Mix.Tasks.Harnex.Tui do
  use Mix.Task

  @shortdoc "Start the full-screen TermUI terminal"
  @moduledoc """
  Starts the Harnex full-screen terminal UI implemented with TermUI widgets.

      mix harnex.tui [--workspace DIR] [--endpoint URL] [--model NAME]
                  [--skill-root PATH] [--no-ansi] [--verbose]
                  [--resume SESSION_ID]
  """

  @impl true
  def run(args) do
    case Harnex.CLI.run(args,
           info: fn text -> Mix.shell().info(text) end,
           start_app: fn -> Mix.Task.run("app.start") end
         ) do
      :ok -> :ok
      {:error, message} -> Mix.raise(message)
    end
  end
end
