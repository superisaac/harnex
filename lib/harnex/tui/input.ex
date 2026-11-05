defmodule Harnex.TUI.Input do
  def read_loop(handler), do: read_loop(handler, &IO.gets/1)

  def read_loop(handler, input) when is_function(input, 1) do
    case input.("harnex> ") do
      :eof ->
        handler.({:command, "exit", ""})

      {:error, reason} ->
        {:error, reason}

      line ->
        case handler.(Harnex.TUI.Command.parse(line)) do
          :stop -> :ok
          {:stop, result} -> result
          _ -> read_loop(handler, input)
        end
    end
  end
end
