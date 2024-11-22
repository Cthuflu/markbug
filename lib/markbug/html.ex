defmodule Markbug.HTML do
  def ast_to_html(ast) do
    node_to_html(ast)
  end

  def node_to_html(ast) when is_list(ast) do
    ast
    |> Enum.map(&node_to_html/1)
  end
  def node_to_html(str) when is_binary(str), do: escape_text(str)
  def node_to_html(ast_node) do
    case ast_node do
      {:header, num, content} ->
        html("h#{num}", [], node_to_html(content))

      {:p, content} ->
        html("p", [], node_to_html(content))

      {:text, content} ->
        node_to_html(content)

      # TODO: Module-based emphasis/strong handling
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
        node_name = "mdfn-#{node_to_name(anchor)}"
        html("p", [{"id", node_name}], [
          html("span", [{"class", "footnote"}],
            html("a", [{"href", node_name}], node_to_html(anchor))
          ),
          ":",
          html("span", [{"class", "footnote-caption"}], node_to_html(caption))
        ])

      {:comment, comment} ->
        ["<!-- ", comment, " -->"]

      {:image, %{href: src, caption: caption}} ->
        html("article", [{"class", "image-caption"}], [
          html("img", [{"src", src}], []),
          html("p", [], node_to_html(caption)),
        ])

      {:image, %{href: src}} ->
        html("img", [{"src", src}], [])

      {:link, %{caption: caption, href: src}} ->
        html("a", [{"href", src}], node_to_html(caption))

      {:link, %{href: src}} ->
        html("a", [{"href", src}], node_to_html(src))

      {:html, tag, attrs, content} ->
        html(tag, attrs, node_to_html(content))

      {:code_span, content} ->
        html("code", [], escape_text(content))

      {:blockquote, content} ->
        html("blockquote", [], node_to_html(content))

      {:code_block, content} ->
        html("pre", [], escape_text(content))

      {:ol, start, _mark, items} ->
        html("ol", [{"start", start}], node_to_html(items))

      {:li, content} ->
        html("li", [], node_to_html(content))

      {:ul, mark, _tight?, content} ->
        html("ul", [{"style", "list-style-type: '#{charbin(mark)} ';"}], node_to_html(content))

      {:br, char} ->
        html("hr", [{"style", "content: '#{charbin(char)}'"}], [])

      # TODO: Cleanup
      {:setext, char, _str} ->
        html("hr", [{"style", "content: '#{charbin(char)}'"}], [])

      :"\n" ->
        "\n"

    end
  end

  defp escape_text(text) when is_list(text) do
    text
    |> Enum.map(&escape_text/1)
  end
  defp escape_text(text) do
    String.replace(text, ~r/[<>&"']/, &escape_char/1)
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

  @compile {:inline, charbin: 1}
  defp charbin(sym) when is_binary(sym), do: sym
  defp charbin(sym), do: <<sym::utf8>>

  defp node_to_name(ast) do
    [ast
    |> node_to_html()]
    |> List.flatten()
    |> Enum.map(fn el -> String.replace(el, ~r/[\<\>\s\n\t\(\)\/]+/, "-") |> String.downcase() end)
  end

  defp emphasis(sym, content) do
    {tag, attrs} = case sym do
      ?* -> {"b", []}
      ?_ -> {"i", []}
      "||" -> {"span", [{"class", "spoiler"}]}
      "~~" -> {"s", []}
    end

    html(tag, attrs, [charbin(sym), node_to_html(content), charbin(sym)])
  end

  defp strong(sym, content) do
    {tag, attrs} = case sym do
      ?* -> {"i", []}
      ?_ -> {"b", []}
      "||" -> {"span", [{"class", "spoiler"}]}
      "~~" -> {"s", []}
    end
    html(tag, attrs, [charbin(sym), node_to_html(content), charbin(sym)])
  end

  defp html(tag, attrs, []) do
    [tag, attributes(attrs)]
    |> wrap("<", "/>")
  end
  defp html(tag, attrs, content) do
    content
    |> wrap(open_tag(tag, attrs), close_tag(tag))
  end

  defp open_tag(tag, []), do: ["<", tag, ">"]
  defp open_tag(tag, attrs) do
    [tag, attributes(attrs)]
    |> wrap("<", ">")
  end

  defp close_tag(tag) do
    tag
    |> wrap("</",">")
  end

  defp attributes(attrs) do
    attrs
    |> Enum.map_join(fn {key, value} -> [" ", key, "=\"",  escape_text(value), "\""] end)
  end

  def wrap(content, mark_l, mark_r) do
    [mark_l, content, mark_r]
  end
  def wrap(content, mark) do
    [mark, content, mark]
  end
end
