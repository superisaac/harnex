defmodule Harnex.TUI.TermUI do
  @moduledoc "TermUI runtime adapter for the Harnex full-screen experience."

  def start(opts \\ []) do
    if legacy?(opts) or not Code.ensure_loaded?(TermUI) do
      Harnex.TUI.Fullscreen.start_legacy(opts)
    else
      app_opts = [
        session_opts:
          Keyword.put(Keyword.take(opts, [:auth_adapter, :renderer]), :run_opts, opts),
        dimensions: {Keyword.get(opts, :width, 80), Keyword.get(opts, :height, 24)},
        verbose: Keyword.get(opts, :verbose, false),
        transcript_limit: Keyword.get(opts, :transcript_limit, 200)
      ]

      TermUI.run(Harnex.TUI.TermUIApp,
        ear_runtime_opts: app_opts,
        dimensions: {Keyword.get(opts, :width, 80), Keyword.get(opts, :height, 24)}
      )
    end
  rescue
    error in UndefinedFunctionError ->
      if error.module == TermUI,
        do: Harnex.TUI.Fullscreen.start_legacy(opts),
        else: reraise(error, __STACKTRACE__)
  end

  defp legacy?(opts), do: Keyword.has_key?(opts, :key_input) or Keyword.has_key?(opts, :input)
end
