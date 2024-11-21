defmodule Markbug do
  @moduledoc """
  Fast Elixir Markdown Parser
  """

  import Markbug.Decode.Token, only: [squash_stack: 1, correct_tokens: 1, make_blocks: 1]

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
    with {:ok, tokens} <- Markbug.Decode.parse(str, opts),
         ast <- tokens
                |> squash_stack()
                |> correct_tokens()
                |> make_blocks()
    do
      {:ok, ast}
    end
  end

  def decode!(str, opts \\ []) do
    case decode(str, opts) do
      {:ok, ast} -> ast
      _error -> throw Exception
    end
  end

  def ast_to_html(ast) do
    Markbug.HTML.ast_to_html(ast)
  end
end
