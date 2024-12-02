defmodule Markbug.Token do
  import Markbug.Util

  def correct_tokens(stack) do
    case stack do
      [] -> []

      [:"\n" | stack] ->
        [:"\n" | correct_tokens(stack)]

      [{:text, text}, {flank, sym} | stack] when flank in ~w[left right]a ->
        correct_tokens([{:text, [text, char_or_bin(sym)] |> List.flatten()} | stack])

      [{flank, sym} | stack] when flank in ~w[left right]a ->
        correct_tokens([{:text, char_or_bin(sym)} | stack])

      [{:text, text}, sym | stack] when is_atom(sym) and sym not in [:"\n"] ->
        correct_tokens([{:text, [text, to_string(sym)] |> List.flatten()} | stack])

      [sym | stack] when is_atom(sym) ->
        correct_tokens([{:text, to_string(sym)} | stack])

      [{:text, t1}, {:text, t2} | stack] ->
        correct_tokens([{:text, [t1, t2] |> List.flatten()} | stack])

      [{em_strong, mark, content} | stack] when em_strong in ~w[em strong]a ->
        correct_tokens([{:text, {em_strong, mark, content}} | stack])

      [{:code_span, content} | stack] ->
        correct_tokens([{:text, {:code_span, content}} | stack])

      [node | stack] ->
        [node | correct_tokens(stack)]
    end
  end

  def make_blocks(stack) do
    group_stack(stack)
    # |> List.flatten()
  end

  def group_stack(stack) do
    case get_next_block(stack) do
      {stack, nil} -> []
        case stack do
          [] -> []
          [node | stack] ->
            [node | group_stack(stack)]
        end

      {stack, node} ->
        [node | group_stack(stack)]
    end
  end

  defp get_next_block(stack) do
    case stack do
      [{:blockquote} | stack] ->
        {stack, line} = seek_newline_token(stack, true)
        {stack, block} = blockquote(stack, [line])
        node = {:blockquote, block |> make_blocks()}
        {stack, node}

      [{:>, tag, attrs} | stack] ->
        {stack, contents} = html(stack, tag)
        node = {:html, tag, attrs, contents}
        {stack, node}

      [{:"/>", tag, attrs} | stack] ->
        node = {:html, tag, attrs}
        {stack, node}

      [{:li, mark, start} | stack] ->
        {stack, line} = seek_newline_token(stack, true)
        {stack, block} = indented(stack, String.length(start) + 2, [line])
        ordered_list(stack, mark, start, [{:li, block |> make_blocks()}])

      [{:ul, sym} | stack] ->
        {stack, line} = seek_newline_token(stack, true)
        {stack, block} = indented(stack, 2, [line])
        unordered_list(stack, sym, [{:li, block |> make_blocks()}])

      _stack ->
        get_next_leaf(stack)
    end
  end

  defp get_next_leaf(stack) do
    case stack do
      [{:header, num} | stack] ->
        header(stack, num)

      [text = {:text, _text} | stack] ->
        {stack, paragraph} = paragraph(stack, [text])
        node = {:p, paragraph}
        {stack, node}

      [{:code_indent_line, line} | stack] ->
        {stack, code_block} = code_indent_merge(stack, [line])
        node = {:code_block, code_block}
        {stack, node}

      # [:"\n", :"\n" | stack] ->
      #   {stack, {:br}}

      [:"\n" | stack] ->
        get_next_block(stack)

      _stack ->
        {stack, nil}
    end
  end

  defp ordered_list(stack, mark, start, acc) do
    case next_ordered_list_item(stack, mark) do
      nil ->
        {stack, {:ol, start, mark, acc |> Enum.reverse()}}

      {stack, next_start} ->
        {stack, line} = seek_newline_token(stack, true)
        {stack, block} = indented(stack, String.length(next_start) + 2, [line])
        ordered_list(stack, mark, start, [{:li, block |> make_blocks()} | acc])
    end
  end

  defp next_ordered_list_item(stack, mark) do
    case stack do
      [:"\n" | stack] ->
        next_ordered_list_item(stack, mark)

      [{:li, ^mark, start} | stack] ->
        {stack, start}

      _stack ->
        nil
    end
  end

  defp unordered_list(stack, sym, acc, tight? \\ true) do
    case next_unordered_list_item(stack, sym, tight?) do
      nil ->
        {stack, {:ul, sym, tight?, acc |> Enum.reverse()}}

      {stack, tight?} ->
        {stack, line} = seek_newline_token(stack, true)
        {stack, block} = indented(stack, 2, [line])
        unordered_list(stack, sym, [{:li, block |> make_blocks()} | acc], tight?)
    end
  end

  defp next_unordered_list_item(stack, sym, tight?) do
    case stack do
      [:"\n", :"\n" | stack] ->
        next_unordered_list_item(stack, sym, false)

      [:"\n" | stack] ->
        next_unordered_list_item(stack, sym, tight?)

      [{:ul, ^sym} | stack] ->
        {stack, tight?}

      _stack ->
        nil
    end
  end

  defp indented(stack, indent, acc)
  defp indented(stack, indent, acc) when indent <= 0, do: {stack, acc |> Enum.reverse()}
  defp indented(stack, indent, acc) do
    case next_indent(stack, indent) do
      {stack, next_indent, next_acc} ->
        {stack, line} = seek_newline_token(stack, true)
        case next_indent - indent do
          res when res <= indent ->
            indented(stack, indent, [line, next_acc | acc])

          res ->
            indented(stack, indent, [line, {:indent, res}, next_acc | acc])
        end

      _stack ->
        {stack, acc |> Enum.reverse() |> List.flatten()}
    end
  end

  defp next_indent(stack, indent, acc \\ []) do
    case stack do
      [{:indent, next_indent} | stack] ->
        if next_indent >= indent do
          {stack, next_indent, acc |> Enum.reverse()}
        else
          nil
        end

      [:"\n" | stack] ->
        next_indent(stack, indent, [:"\n" | acc])

      _stack ->
        nil
    end
  end


  defp header(stack, num) do
    {stack, content} = seek_newline_token(stack, false)
    header = {:header, num, content}
    case stack do
      [:"\n", :"\n" | stack] ->
        {stack, header}

      [:"\n" | stack] ->
        {stack, header}

      _stack ->
        {stack, header}
    end
  end

  def paragraph(stack, acc \\ []) do
    {stack, text} = lazy_continue(stack, acc)
    text = unwrap_text(text)
      |> List.flatten()

    {stack, text}
  end

  defp unwrap_text({:text, text}), do: unwrap_text(text)
  defp unwrap_text(text_list) when is_list(text_list) do
    text_list
    |> Enum.map(&unwrap_text/1)
  end
  defp unwrap_text(text), do: text

  def html(stack, tag, acc \\ []) do
    case stack do
      [{:"</", ^tag} | stack] ->
        {stack, acc |> Enum.reverse()}

      [node | stack] ->
        html(stack, tag, [node | acc])

      [] ->
        {stack, acc |> Enum.reverse()}
    end
  end

  def blockquote(stack, acc \\ []) do
    case next_blockquote(stack) do
      nil ->
        {stack, acc |> Enum.reverse() |> List.flatten()}

      stack ->
        {stack, line} = seek_newline_token(stack, true)
        blockquote(stack, [line, :"\n" | acc])
    end
  end

  defp next_blockquote(stack) do
    case stack do
      [:"\n", {:blockquote} | stack] ->
        stack

      _stack ->
        nil
    end
  end

  defp seek_newline_token(stack, lazy_continue? \\ false, acc \\ []) do
    case stack do
      [:"\n" | _stack] ->
        if lazy_continue? do
          lazy_continue(stack, acc)
        else
          {stack, acc |> Enum.reverse()}
        end

      [token = {:header, _header} | stack] ->
        seek_newline_token(stack, false, [token | acc])

      [token | stack] ->
        seek_newline_token(stack, lazy_continue?, [token | acc])

      _stack ->
        {stack, acc |> Enum.reverse()}
    end
  end

  defp lazy_continue(stack, acc) do
    case stack do
      [text = {:text, _text} | stack] ->
        lazy_continue(stack, [text | acc])

      [:"\n", text = {:text, _text} | stack] ->
        lazy_continue(stack, [text, {:text, " "} | acc])

      [:"\n", {:indent, _indent}, text = {:text, _text} | stack] ->
        lazy_continue(stack, [text, {:text, " "} | acc])

      [{:>, tag, attrs} | stack] ->
        {stack, content} = html(stack, tag, [])
        lazy_continue(stack, [{:text, {:html, tag, attrs, content}} | acc])

      _stack ->
        {stack, acc |> Enum.reverse() |> List.flatten()}
    end
  end

  def code_indent_merge(stack, acc) do
    case seek_code_indent(stack) do
      {stack, lines} ->
        code_indent_merge(stack, [lines | acc])

      _stack ->
        {stack, acc |> Enum.reverse() |> List.flatten()}

    end
  end

  defp seek_code_indent(stack, acc \\ []) do
    case stack do
      [:"\n" | stack] ->
        seek_code_indent(stack, ["\n" | acc])

      [{:code_indent_line, line} | stack] ->
        {stack, [line | acc] |> Enum.reverse()}

      _stack ->
        nil
    end
  end

  @doc """
  Reversed Stack Token Combination
  """
  def squash_stack(stack, inner_stack \\ [])
  def squash_stack([], []), do: []
  def squash_stack([], inner_stack) do
    inner_stack
  end
  def squash_stack([{:left, sym} | stack], [{:text, text}, {:right, sym} | inner_stack]) do
    squash_stack(stack, [{:em, sym, flat_wrap(text)} | inner_stack])
  end
  def squash_stack([{:left, sym} | stack], [{:em, sym, text}, {:right, sym} | inner_stack]) do
    squash_stack(stack, [{:strong, sym, flat_wrap(text)} | inner_stack])
  end

  def squash_stack([{:text, t1} | stack], [{:text, t2} | inner_stack]) do
    squash_stack(stack, [{:text, [t1 | List.wrap(t2)]} | inner_stack])
  end
  def squash_stack(stack, [{:text, t1}, {:text, t2} | inner_stack]) do
    squash_stack(stack, [{:text, [t1 | List.wrap(t2)]} | inner_stack])
  end

  def squash_stack([opener | stack], [{:text, caption}, :"](", {:text, href}, :")" | inner_stack])
    when opener in [:"[", :"!["]
  do
    tag = case opener do
        :"[" -> :link
        :"![" -> :image
      end
    link = {:text, {tag, %{
        caption: caption |> flat_wrap() |> correct_tokens(),
        href: href
      }}}
    squash_stack(stack, [link | inner_stack])
  end
  def squash_stack([:")" | stack], [{:text, href}, :"](", :"![" | inner_stack]) do
    link = {:text, {:image, %{
      href: href
    }}}
    squash_stack(stack, [link | inner_stack])
  end
  def squash_stack([:"[" | stack], [{:text, name}, :"]" | inner_stack]) do
    footnote = {:text, {:reference, name}}
    squash_stack(stack, [footnote | inner_stack])
  end
  def squash_stack([:"[" | stack], [{:text, name}, :"]:" | inner_stack]) do
    {inner_stack, caption} = get_line_tokens(inner_stack)
    footnote = {:footnote, name, %{
      caption: caption |> flat_wrap() |> correct_tokens()
    }}
    squash_stack(stack, [footnote | inner_stack])
  end

  def squash_stack([:^ | stack], [{:text, text} | inner_stack]) do
    squash_stack(stack, [{:text, {:superscript, text}} | inner_stack])
  end

  def squash_stack([:>, {:uri, uri}, {:scheme, scheme}, :< | stack], inner_stack) do
    full_uri = "#{scheme}:#{uri}"
    term = {:text, {:link, %{href: full_uri}}}
    squash_stack(stack, [term | inner_stack])
  end
  def squash_stack([:>, {:email, email}, :< | stack], inner_stack) do
    term = {:text, {:link, %{href: "mailto:#{email}", caption: email}}}
    squash_stack(stack, [term | inner_stack])
  end

  # HTML
  def squash_stack([{:tag_name, tag}, :"<" | stack], [{:tag_open, type, attributes} | inner_stack]) do
    attributes = squash_html_attributes(attributes)
    term = {type, tag, attributes}
    squash_stack(stack, [term | inner_stack])
  end
  def squash_stack([{:unquoted_value, value}, :=, {attr, name}, :"\s" | stack], [{:tag_open, type, attributes} | inner_stack])
    when attr in ~w[attribute denied_attribute]a
  do
    attr = {:unquoted, attr, {name, value}}
    squash_stack(stack, [{:tag_open, type, [attr | attributes]} | inner_stack])
  end
  def squash_stack([{:quoted_value, char, value}, :=, {attr, name}, :"\s" | stack], [{:tag_open, type, attributes} | inner_stack])
    when attr in ~w[attribute denied_attribute]a
  do
    attr = {:quoted, attr, char, {name, value}}
    squash_stack(stack, [{:tag_open, type, [attr | attributes]} | inner_stack])
  end
  def squash_stack([{attr, name}, :"\s" | stack], [{:tag_open, type, attributes} | inner_stack])
    when attr in ~w[attribute denied_attribute]a
  do
    attr = {:name, attr, {name, true}}
    squash_stack(stack, [{:tag_open, type, [attr | attributes]} | inner_stack])
  end
  def squash_stack([:>, {:tag_name, tag}, :"</" | stack], inner_stack) do
    squash_stack(stack, [{:"</", tag} | inner_stack])
  end
  def squash_stack([term | stack], inner_stack) when term in ~w[> />]a do
    squash_stack(stack, [{:tag_open, term, []} | inner_stack])
  end
  def squash_stack([tag_mark | stack], inner_stack = [{:text, _text} | _inner_stack])
    when tag_mark in ~w[< </]a
  do
    stack = [{:text, tag_mark |> to_string()} | stack]
    squash_stack(stack, inner_stack)
  end

  def squash_stack([{:setext, type, _original}, :"\n", {:text, text} | stack], inner_stack) do
    header_type = case type do
        ?= -> 1
        ?- -> 2
      end

    squash_stack(stack, [{:header, header_type, [{:text, text}]} | inner_stack])
  end

  def squash_stack(stack, [em = {em_type, _mark, _text} | inner_stack])
    when em_type in ~w[em strong]a
  do
    squash_stack(stack, [{:text, em} | inner_stack])
  end
  def squash_stack([:"\s" | stack], inner_stack) do
    squash_stack([{:text, " "} | stack], inner_stack)
  end

  def squash_stack([node | stack], inner_stack) do
    squash_stack(stack, [node | inner_stack])
  end

  def squash_html_attributes(attributes) do
    attributes
    |> Enum.map(fn
      {:quoted, :attribute, _char, kv} -> kv
      {:unquoted, :attribute, kv} -> kv
      {:name, :attribute, kv} -> kv
      _ -> []
    end)
  end
end
