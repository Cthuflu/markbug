defmodule MarkbugTest.ASTMatch do
  @moduledoc """
  This module provides some conveniences for AST matches
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      import MarkbugTest.ASTMatch
    end
  end

  def p(content), do: {:p, List.wrap(content)}
  def em(ty, content), do: {:em, ty, List.wrap(content)}
  def strong(ty, content), do: {:strong, ty, List.wrap(content)}
  def code_span(content), do: {:code_span, content}

  def ast_test(text) do
    Markbug.ast!(text)
    |> transform_ast()
  end

  # Merge iostreamable text
  defp transform_ast(ast_node) when is_list(ast_node) do
    ast_node
    |> Stream.chunk_by(&is_binary/1)
    |> Enum.flat_map(fn
      text = [t1 | _rest] when is_binary(t1) ->
        [:erlang.list_to_binary(text)]

      other_nodes ->
        other_nodes
        |> Enum.map(&transform_ast/1)
    end)
  end
  defp transform_ast({:p, content}), do: {:p, transform_ast(content)}
  defp transform_ast({:em, mark, content}), do: {:em, mark, transform_ast(content)}
  defp transform_ast({:strong, mark, content}), do: {:strong, mark, transform_ast(content)}
  defp transform_ast({:code_span, content}), do: {:code_span, transform_ast(content)}
  defp transform_ast(content), do: content

  defmacro assert_ast(left, right) do
    quote do
      assert ast_test(unquote(left)) == List.wrap(unquote(right))
    end
  end


end
