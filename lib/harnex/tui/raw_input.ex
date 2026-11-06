defmodule Harnex.TUI.RawInput do
  @moduledoc """
  Small, dependency-free raw terminal input decoder.
  """

  @spec decode(binary()) :: [binary()]
  def decode(buffer), do: decode(buffer, [])

  defp decode(<<>>, acc), do: Enum.reverse(acc)

  defp decode(<<27, ?[, code, rest::binary>>, acc) when code in [?A, ?B, ?C, ?D, ?H, ?F],
    do: decode(rest, [<<27, ?[, code>> | acc])

  defp decode(<<char::utf8, rest::binary>>, acc), do: decode(rest, [<<char::utf8>> | acc])
  defp decode(<<byte, rest::binary>>, acc), do: decode(rest, [<<byte>> | acc])
end
