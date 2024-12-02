defmodule Markbug do
  @moduledoc """
  Fast Elixir Markdown Parser
  """
  import Markbug.Token, only: [squash_stack: 1, correct_tokens: 1, make_blocks: 1]
  alias Markbug.Scan

  @doc """
  Parse a string containing markdown into a manipulatable AST
  """
  def ast(str, opts \\ []) do
    with {:ok, tokens} <- Scan.scan(str, opts),
         ast <- tokens
                |> squash_stack()
                |> correct_tokens()
                |> make_blocks()
    do
      {:ok, ast}
    end
  end

  def ast!(str, opts \\ []) do
    with {:ok, ast} <- ast(str, opts) do
      ast
    end
  end

  @doc """
  Parse a string containing markdown into HTML
  """
  def html(str, opts \\ []) do
    with {:ok, result} <- ast(str, opts) do
      result
      |> Markbug.HTML.from_ast()
    end
  end

  @doc """
  Convert an AST into HTML
  """
  def to_html(ast) do
    ast
    |> Markbug.HTML.from_ast()
  end
end
