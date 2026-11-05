defmodule Harnex.Auth do
  @callback login(String.t(), map()) :: {:ok, map()} | {:error, term()}
end
