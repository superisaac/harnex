defmodule Harnex.TUI.TermUI do
  @moduledoc "TermUI runtime adapter for the Harnex full-screen experience."

  def start(opts \\ []) do
    if legacy?(opts) or not Code.ensure_loaded?(TermUI) do
      Harnex.TUI.Fullscreen.start_legacy(opts)
    else
      exit_ref = make_ref()

      app_opts = [
        session_opts:
          Keyword.put(Keyword.take(opts, [:auth_adapter, :renderer]), :run_opts, opts),
        dimensions: {Keyword.get(opts, :width, 80), Keyword.get(opts, :height, 24)},
        verbose: Keyword.get(opts, :verbose, false),
        transcript_limit: Keyword.get(opts, :transcript_limit, 200),
        workspace: Keyword.get(opts, :workspace, File.cwd!()),
        resume: Keyword.get(opts, :resume),
        exit_reporter: {self(), exit_ref}
      ]

      result =
        TermUI.run(Harnex.TUI.TermUIApp,
          ear_runtime_opts: app_opts,
          dimensions: {Keyword.get(opts, :width, 80), Keyword.get(opts, :height, 24)}
        )

      # TermUI runs on the alternate screen. Print the resume hint only after
      # it has restored the user's original terminal screen.
      receive do
        {:harnex_tui_resume_hint, ^exit_ref, run_id} ->
          IO.puts("to resume run mix harnex.tui --resume #{run_id}")
      after
        0 -> :ok
      end

      result
    end
  rescue
    error in UndefinedFunctionError ->
      if error.module == TermUI,
        do: Harnex.TUI.Fullscreen.start_legacy(opts),
        else: reraise(error, __STACKTRACE__)
  end

  defp legacy?(opts), do: Keyword.has_key?(opts, :key_input) or Keyword.has_key?(opts, :input)
end
