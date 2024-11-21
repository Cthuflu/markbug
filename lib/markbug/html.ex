defmodule Markbug.HTML do
  def ast_to_html(ast) do
    node_to_html(ast)
  end

  def node_to_html(ast) when is_list(ast) do
    ast
    |> Enum.map(&node_to_html/1)
  end
  def node_to_html(str) when is_binary(str), do: str
  def node_to_html(ast_node) do
    case ast_node do
      {:header, num, content} ->
        html("h#{num}", [], node_to_html(content))

      {:p, content} ->
        html("p", [], node_to_html(content))

      {:text, content} ->
        node_to_html(content)

      # TODO: Separate emphasis handling
      {:em, sym, content} ->
        emphasis(sym, content)

      {:strong, sym, content} ->
        strong(sym, content)

      {:superscript, content} ->
        html("sup", [], node_to_html(content))

      {:reference, content} ->
        # TODO: Temp
        html("a", [{"href", "#mdfn-#{node_to_name(content)}"}], node_to_html(content))

      {:footnote, anchor, %{caption: caption}} ->
        html("p", [{"id", "mdfn-#{node_to_name(anchor)}"}], [
          html("span", [], node_to_html(anchor)),
          ":",
          html("span", [], node_to_html(caption))
        ])

      {:comment, comment} ->
        ["<!--", comment, "-->"]

      {:image, %{href: src, caption: caption}} ->
        html("div", [], [
          html("img", [{"src", src}], []),
          html("p", [], node_to_html(caption))
        ])

      {:image, %{href: src}} ->
        html("img", [{"src", src}], [])

      {:link, %{caption: caption, href: src}} ->
        html("a", [{"href", src}], node_to_html(caption))

      {:html, tag, attrs, content} ->
        html(tag, attrs, node_to_html(content))

      {:code_span, content} ->
        html("code", [], content)

      {:blockquote, content} ->
        html("blockquote", [], node_to_html(content))

      {:code_block, content} ->
        html("pre", [], escape_text(content))

    end
  end

  defp escape_text(text) when is_list(text) do
    text
    |> Enum.map(&escape_text/1)
  end
  defp escape_text(text) do
    String.replace(text, ~r/<>&"'/, &escape_char/1)
  end

  defp escape_char("<"), do: "&lt;"
  defp escape_char(">"), do: "&gt;"
  defp escape_char("&"), do: "&amp;"
  defp escape_char("\""), do: "&quot;"
  defp escape_char("'"), do: "&#39;"
  defp escape_char(c), do: c

  defp node_to_text(str) when is_binary(str), do: str
  defp node_to_text(ast) when is_list(ast) do
    ast
    |> Enum.map(&node_to_text/1)
  end
  defp node_to_text(ast_node) do
    case ast_node do
      {tag, sym, content} when tag in ~w[em strong]a ->
        [charbin(sym), node_to_text(content), charbin(sym)]

      {:text, content} ->
        node_to_text(content)

    end
  end

  defp charbin(sym) when is_binary(sym), do: sym
  defp charbin(sym), do: <<sym::utf8>>


  defp node_to_name(ast) do
    ast
    |> node_to_html()
    |> List.flatten()
    |> Enum.map(fn el -> String.replace(el, ~r/[\<\>\s\n\t\(\)\/]+/, "-") end)
  end

  defp emphasis(sym, content) do
    {tag, attrs} = case sym do
      ?* -> {"b", []}
      ?_ -> {"i", []}
      "||" -> {"span", [{"class", "spoiler"}]}
      "~~" -> {"s", []}
    end

    html(tag, attrs, node_to_html(content))
  end

  defp strong(sym, content) do
    {tag, attrs} = case sym do
      ?* -> {"i", []}
      ?_ -> {"b", []}
      "||" -> {"span", [{"class", "spoiler"}]}
      "~~" -> {"s", []}
    end
    html(tag, attrs, node_to_html(content))
  end

  defp html(tag, attrs, []) do
    ["<", tag, attributes(attrs), "/>"]
  end

  defp html(tag, attrs, content) do
    ["<", tag, attributes(attrs), ">", content, "</", tag, ">"]
  end

  defp attributes(attrs) do
    attrs
    |> Enum.map_join(fn {key, value} -> [" ", key, "=\"",  escape_text(value), "\""] end)
  end
end
