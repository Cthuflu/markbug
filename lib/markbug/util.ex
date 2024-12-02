defmodule Markbug.Util do
  @moduledoc """
  Utility functions
  """

  @compile {:inline, char_or_bin: 1}
  def char_or_bin(c) when is_binary(c), do: c
  def char_or_bin(c) when is_integer(c), do: <<c::utf8>>
  # def char_or_bin(c), do: c

  def flat_wrap(x) do
    x
    |> List.wrap()
    |> List.flatten()
  end

  def get_line_tokens(stack, acc \\ []) do
    case stack do
      [] ->
        {stack, acc |> Enum.reverse()}
      [:"\n" | _stack] ->
        {stack, acc |> Enum.reverse()}
      [node | stack] ->
        get_line_tokens(stack, [node | acc])
    end
  end

  @compile {:inline, codepoint_size: 1}
  def codepoint_size(c), do: byte_size(<<c::utf8>>)
end
