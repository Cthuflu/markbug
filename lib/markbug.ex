defmodule Markbug do
  @moduledoc """
  Fast Elixir Markdown Parser
  """

  # @default_opts [
  #   html: [
  #     enabled: false,
  #     sanitizer: nil
  #   ]
  # ]

  @doc """
  Parse a string containing markdown into a manipulatable AST
  """
  def decode(str, opts \\ []) do
    # {:ok, opts} = Keyword.validate(opts, @default_opts)
    Markbug.Decode.parse(str, opts)
  end
end
