defmodule Markbug.Decode do
  import Markbug.Util
  import Markbug.Decode.Token

  defguardp is_digit(c)
    when c in ?0..?9

  defguardp is_ascii_letter(c)
    when c in ?a..?z
      or c in ?A..?Z

  defguardp is_punctuation(c)
    when c in ?!..?@
      or c in ?[..?`
      or c in ?{..?~
      or c in 0x2010..0x2027
      or c in 0x2030..0x205E

  defguardp is_whitespace(c)
    when c in ?\t..?\r
      or c in [?\s, 0x85, 0xA0, 0x1680, 0x202F, 0x205F, 0x3000]
      or c in 0x2000..0x200A

  @option_keys ~w[
    html
    html_sanitization
    autolink
    strikeout
    spoiler
    superscript
    footnotes
  ]a

  @option_no_keys @option_keys |> Enum.map(fn key -> :"no_#{key}" end)

  @option_key_trans Enum.zip(@option_no_keys, @option_keys)
    |> Map.new()

  def parse(str, opts \\ %{})
  def parse(str, opts) when is_map(opts) do
    state = %{
      indent: 0,
      edge: 0,
      match_len: 0,
      match_char: nil,
      newline: false,
      decoders: %{},
      options: %{
        html: true,
        html_sanitization: true,
        autolink: true,
        strikeout: true,
        spoiler: true,
        superscript: true,
        footnotes: :cohost,
      } |> Map.merge(opts),
      html: %{
        tags: %{
          mode: :allow,
          allowlist: ~w[b i a p u br span div link
                       table thead tbody tfoot th tr td article blockquote caption
                       center col colgroup details figcaption figure optgroup option
                       hr h1 h2 h3 h4 h5 h6 ol ul li strike],
          denylist: ~w[script style iframe object header html head title body footer frame]
        },
        attributes: %{
          mode: :allow,
          allowlist: ~w[class style rel target],
          denylist: []
        }
      },
      leaf: false,
      leaf_type: nil,
    }

    try do
      container(str, str, 0, [], state)
    catch
      {:error, where} ->
        {:error, where}
    else
      value ->
        {:ok, value}
    end
  end
  def parse(str, opts) when is_list(opts) do
    opts = opts
      |> Enum.map(fn
        key when key in @option_no_keys ->
          key = @option_key_trans[key]
          {key, false}
        key when key in @option_keys ->
          {key, true}
        pair = {key, _val} when key in @option_keys ->
          pair
      end)
      |> Map.new()
    parse(str, opts)
  end

  defp container(data, original, skip, stack, state) do
    state = %{state | leaf: false}
    case data do
      <<c::utf8, rest::binary>> when c in ~c'\n' ->
        newline(rest, original, skip + 1, stack, state)

      <<c::utf8, rest::binary>> when c in ~c'\r' ->
        container(rest, original, skip + 1, stack, state)

      <<c::utf8, rest::binary>> when c in ~c'\s' ->
        indent(rest, original, skip + 1, stack, state, 1)

      # <<c::utf8, rest::binary>> when c in ~c'\t' ->
      #   indent(rest, original, skip + 1, stack, state, 4)

      <<c::utf8, rest::binary>> when c in ~c'#' ->
        atx_header(rest, original, skip, stack, state, 1)

      <<c::utf8, rest::binary>> when c in ~c'>' ->
        stack = stack
          |> push_stack({:blockquote})
        {rest, skip} = skip_space(rest, skip)
        indent(rest, original, skip + 1, stack, state, 0)

      <<c::utf8, rest::binary>> when c in ~c[=] ->
        setext_header(rest, original, skip, stack, %{state | match_char: c}, 1)

      <<c::utf8, rest::binary>> when c in ~c[+-*] ->
        {rest, len} = scan(rest, &(&1 == c), 1)

        case rest do
          "\s" <> rest ->
            {rest, len_dash} = scan(rest, &(&1 == c), 0)

            cond do
              len_dash > 0 ->
                len = len + len_dash
                thematic_break(rest, original, skip, stack, %{state | match_char: c, match_len: len}, len + 1)
              len == 1 ->
                 stack = stack
                  |> push_stack({:ul, c})
                container(rest, original, skip + len + 1, stack, %{state | edge: state.indent})
              true ->
                text(rest, original, skip, stack, state, len + 1)
            end

          _rest ->
            if c == ?* do
              # stack = stack
              #   |> push_stack_mult({:left, c}, len)
              thematic_break(rest, original, skip, stack, %{state | match_char: c, match_len: len}, len)
            else
              setext_header(rest, original, skip, stack, %{state | match_char: c}, len)
            end
        end

      <<c::utf8, rest::binary>> when c in ~c[_] ->
        thematic_break(rest, original, skip, stack, %{state | match_char: c, match_len: 1}, 1)

      <<c::utf8, rest::binary>> when is_digit(c) ->
        numbered_list(rest, original, skip, stack, state, 1)

      _rest ->
        text(data, original, skip, stack, state, 0)
    end
  end

  defp numbered_list(data, original, skip, stack, state, len) do
    case scan(data, &is_digit/1, len) do
      {<<c::utf8, rest::binary>>, len}
        when len <= 9
         and c in ~c[.)]
      ->
        if is_boundary?(rest) do
          term = {:li, c, track_part(original, skip, len)}
          skip = skip + len + 1
          stack = stack
            |> push_stack(term)
          {rest, skip} = skip_space(rest, skip)

          container(rest, original, skip, stack, %{state | edge: state.indent})
        else
          text(rest, original, skip, stack, state, len)
        end

      {rest, len} ->
        text(rest, original, skip, stack, state, len)
    end
  end

  @compile {:inline, is_boundary?: 1}
  defp is_boundary?(data) do
    case data do
      <<c::utf8, _rest::binary>> when is_whitespace(c) ->
        true
      <<>> ->
        true
      _else ->
        false
    end
  end

  @compile {:inline, skip_space: 2}
  defp skip_space(rest, skip) do
    case rest do
      "\s" <> rest ->
        {rest, skip + 1}

      _rest ->
        {rest, skip}
    end
  end

  defp thematic_break(rest, original, skip, stack, state = %{match_char: c, match_len: match_len}, len) do
    {rest, more_len} = scan(rest, &(&1 == c), 0)
    len = len + more_len
    match_len = match_len + more_len
    state = %{state | match_len: match_len}

    case rest do
      "\r\n" <> _rest ->
        if match_len >= 3 do
          stack = stack
            |> push_stack({:br, c})
          container(rest, original, skip + len, stack, %{state | match_char: nil, match_len: 0})
        else
          text(rest, original, skip, stack, state, len)
        end

      "\n" <> _rest ->
        if match_len >= 3 do
          stack = stack
            |> push_stack({:br, c})
          container(rest, original, skip + len, stack, %{state | match_char: nil, match_len: 0})
        else
          text(rest, original, skip, stack, state, len)
        end

      <<>> ->
        if match_len >= 3 do
          stack = stack
            |> push_stack({:br, c})
          container(rest, original, skip + len, stack, %{state | match_char: nil, match_len: 0})
        else
          text(rest, original, skip, stack, state, len)
        end

      <<c::utf8, rest::binary>> when c in ~c[\s\t] ->
        if match_len >= 3 do
          {rest, more_len} = scan(rest, &(&1 in [c, ?\s, ?\t]), 1)
          thematic_break(rest, original, skip, stack, state, len + more_len)
        else
          thematic_break(rest, original, skip, stack, state, len + 1)
        end

      _rest ->
        if c in ~c[_*] and match_len == len do
          stack = stack
            |> push_stack_mult({:left, c}, match_len)
          text(rest, original, skip + len, stack, %{state | match_char: nil, match_len: 0})
        else
          text(rest, original, skip, stack, %{state | match_char: nil, match_len: 0}, len)
        end
    end
  end

  defp atx_header("#" <> rest, original, skip, stack, state, len) do
    len = len + 1
    if len <= 6 do
      atx_header(rest, original, skip, stack, state, len)
    else
      text(rest, original, skip, stack, state, len)
    end
  end
  defp atx_header(data, original, skip, stack, state, len) do
    case data do
      <<c::utf8, rest::binary>> when c in ~c[\s\t] ->
        state = %{state | leaf: true, leaf_type: :header}
        stack = stack
          |> push_stack({:header, len})
        text(rest, original, skip + len + 1, stack, state, 0)

      _rest ->
        text(data, original, skip, stack, state, len)
    end
  end

  defp setext_header(rest, original, skip, stack, state = %{match_char: match_char}, len) do
    case rest do
      <<^match_char::utf8, rest::binary>> ->
        setext_header(rest, original, skip, stack, state, len + 1)
      "\r\n" <> _rest ->
        term = track_part(original, skip, len)
        stack = stack
          |> push_stack({:setext, match_char, term})
        container(rest, original, skip + len, stack, %{state | match_char: nil})
      "\n" <> _rest ->
        term = track_part(original, skip, len)
        stack = stack
          |> push_stack({:setext, match_char, term})
        container(rest, original, skip + len, stack, %{state | match_char: nil})
      <<>> ->
        term = track_part(original, skip, len)
        stack = stack
          |> push_stack({:setext, match_char, term})
        container(rest, original, skip + len, stack, %{state | match_char: nil})
      _rest ->
        text(rest, original, skip, stack, %{state | match_char: nil}, len)
    end
  end

  # defp backtick("`" <> rest, original, skip, stack, state, len) do
  #   backtick(rest, original, skip, stack, state, len + 1)
  # end
  defp backtick(data, original, skip, stack, state, len) do
    {rest, len} = count_char(data, ?`, len)
    state = %{state | match_len: len, match_char: ?`}
    case len do
      len when len in [1, 2] ->
        # TODO: Figure out a way around backtracking
        code_span(rest, original, skip, stack, state, 0)
      _ ->
        code_fence(rest, original, skip + len, stack, state, 0)
    end
  end

  defp text(data, original, skip, stack, state, len \\ 0)
  defp text(data, original, skip, stack, state, len) do
    case data do
      <<0x00, rest::binary>> ->
        term = text_part(original, skip, len)
        skip = skip + len
        stack = stack
          |> push_stack(term)
          |> push_stack({:text, <<0xFF, 0xFD>>})

        text(rest, original, skip + 1, stack, state, 0)

      <<c::utf8, _rest::binary>> when c in ~c[\r\n] ->
        term = text_part(original, skip, len)
        stack = stack
          |> push_stack(term)
        container(data, original, skip + len, stack, state)

      <<c::utf8, rest::binary>> when c in ~c[<] ->
        term = text_part(original, skip, len)
        skip = skip + len
        stack = stack
          |> push_stack(term)
          |> push_stack(:"<")
        autolink_or_html(rest, original, skip + 1, stack, state)

      <<c::utf8, rest::binary>> when c in ~c[`] ->
        term = text_part(original, skip, len)
        stack = stack
          |> push_stack(term)
        backtick(rest, original, skip + len, stack, state, 1)

      <<c::utf8, rest::binary>> when c in ~c[~] ->
        {rest, count} = count_char(rest, ?~, 1)
        case count do
          _ when count == 1
            when count == 2
             and not state.options.strikeout
          ->
            text(rest, original, skip, stack, state, len + count)
          2 ->
            term = text_part(original, skip, len)
            skip = skip + len
            stack = stack
              |> push_stack(term)
            sym = "~~"
            stack = case check_last(original, skip) do
              c
                # when is_punctuation(c)
                when is_whitespace(c)
                when is_nil(c)
              ->
                stack
                |> push_stack({:left, sym})
              c
                when is_punctuation(c)
              ->
                stack
                |> push_stack(sym)
              _c ->
                stack
                |> push_stack({:right, sym})
            end
            text(rest, original, skip + count, stack, state)
          _ ->
            code_fence(rest, original, skip + count, stack, %{state | match_len: count, match_char: ?~}, 0)
        end

      <<c::utf8, rest::binary>> when c in ~c[|] ->
        {rest, count} = count_char(rest, ?|, 1)
        if count == 2 and state.options.spoiler do
          term = text_part(original, skip, len)
          skip = skip + len
          stack = stack
            |> push_stack(term)
          sym = "||"
          stack = case check_last(original, skip) do
            c
              # when is_punctuation(c)
              when is_whitespace(c)
              when is_nil(c)
            ->
              stack
              |> push_stack({:left, sym})
            c
              when is_punctuation(c)
            ->
              stack
              |> push_stack(sym)
            _c ->
              stack
              |> push_stack({:right, sym})
          end
          text(rest, original, skip + count, stack, state, 0)
        else
          text(rest, original, skip, stack, state, len + count)
        end

      <<sym::utf8, rest::binary>> when sym in ~c[*_] ->
        term = text_part(original, skip, len)
        skip = skip + len
        # <<sym::utf8>> = binary_part(original, skip, 1)
        # sym = <<sym::utf8>>
        stack = stack
          |> push_stack(term)
        stack = case check_last(original, skip) do
            c
              # when is_punctuation(c)
              when is_whitespace(c)
              when is_nil(c)
            ->
              stack
              |> push_stack({:left, sym})
            c
              when is_punctuation(c)
            ->
              stack
              |> push_stack(sym)
            _c ->
              stack
              |> push_stack({:right, sym})
          end

        text(rest, original, skip + 1, stack, state, 0)

      <<c::utf8, _rest::binary>> when c in ~c[\\] ->
        term = text_part(original, skip, len)
        skip = skip + len
        stack = stack
          |> push_stack(term)
        escape?(data, original, skip, stack, state)

      <<c::utf8, _rest::binary>> when c in ~c[!\[\]\)] ->
        term = text_part(original, skip, len)
        skip = skip + len
        stack = stack
          |> push_stack(term)
        link?(data, original, skip, stack, state)

      <<c::utf8, rest::binary>> when c in ~c[\s] ->
        stack = if len == 0 do
            stack |> push_stack(:space)
          else
            stack
          end
        text(rest, original, skip, stack, state, len + 1)

      <<c::utf8, rest::binary>> when c in ~c[^] ->
        if state.options.superscript do
          term = text_part(original, skip, len)
          skip = skip + len
          stack = stack
            |> push_stack(term)
            |> push_stack(:"^")
          text(rest, original, skip + 1, stack, state, 0)
        else
          text(rest, original, skip, stack, state, len + 1)
        end

      <<char::utf8, rest::binary>> when char <= 0xFF ->
        state = state |> reset_newline()
        text(rest, original, skip, stack, state, len + 1)
      <<char::utf8, rest::binary>> when char <= 0x7FF ->
        state = state |> reset_newline()
        text(rest, original, skip, stack, state, len + 2)
      <<char::utf8, rest::binary>> when char <= 0xFFFF ->
        state = state |> reset_newline()
        text(rest, original, skip, stack, state, len + 3)
      <<_char::utf8, rest::binary>> ->
        state = state |> reset_newline()
        text(rest, original, skip, stack, state, len + 4)

      <<_::binary>> ->
        term = text_part(original, skip, len)
        continue(data, original, skip + len, stack, state, term)
    end
  end

  defp link?(data, original, skip, stack, state) do
    state = state |> set_newline()
    case data do
      "![" <> rest ->
        stack = stack
          |> push_stack(:"![")
        text(rest, original, skip + 2, stack, state, 0)
      "[" <> rest ->
        stack = stack
          |> push_stack(:"[")
        text(rest, original, skip + 1, stack, state, 0)
      "](" <> rest ->
        stack = stack
          |> push_stack(:"](")
        text(rest, original, skip + 2, stack, state, 0)
      "]:" <> rest ->
        stack = stack
          |> push_stack(:"]:")
        text(rest, original, skip + 2, stack, state, 0)
      "]" <> rest ->
        stack = stack
          |> push_stack(:"]")
        text(rest, original, skip + 1, stack, state, 0)

      ")" <> rest ->
        stack = stack
          |> push_stack(:")")
        text(rest, original, skip + 1, stack, state, 0)
      <<_::utf8, rest::binary>> ->
        text(rest, original, skip, stack, state, 1)
    end
  end

  defguardp is_html_tag(c)
    when is_ascii_letter(c)
      or is_digit(c)
      or c == ?-

  defguardp is_html_attribute_name(c)
    when is_html_tag(c)
      or c in ~c[:._]

  defp autolink_or_html(data, original, skip, stack, state, len \\ 0)
  defp autolink_or_html(data, original, skip, stack, state = %{options: options}, 0) do
    case data do
      <<c::utf8, rest::binary>>
        when is_ascii_letter(c)
      ->
        autolink_or_html(rest, original, skip, stack, state, 1)

      "/" <> rest when options.html ->
        stack = stack
          |> pop_stack()
          |> push_stack(:"</")
        html_tag_name(rest, original, skip + 1, stack, state)

      "!" <> rest when options.html ->
        stack = stack
          |> pop_stack()
          |> push_stack(:"<!")
        html_declaration(rest, original, skip + 1, stack, state)

      _data ->
        text(data, original, skip, stack, state, 0)
    end
  end
  defp autolink_or_html(data, original, skip, stack, state = %{options: options}, len) do
    case data do
      <<c::utf8, rest::binary>> when is_html_tag(c) ->
        autolink_or_html(rest, original, skip, stack, state, len + 1)

      <<c::utf8, rest::binary>> when is_ascii_letter(c) ->
        autolink_or_html(rest, original, skip, stack, state, len + 1)

      <<c::utf8, _rest::binary>>
        when options.html
         and c in ~c[\s\r\n\t\/>]
      ->
        html_tag_name(data, original, skip, stack, state, len)

      <<c::utf8, _rest::binary>>
        when options.autolink
         and (
          is_html_tag(c)
          or c in ~c[:+.]
         )
      ->
        autolink_scheme(data, original, skip, stack, state, len)

      _data ->
        text(data, original, skip, stack, state, len)

    end
  end

  defp escape?("\\" <> rest, original, skip, stack, state) do
    case rest do
      <<char::utf8, rest::binary>> when char in ~c[!"#$%&'()*+,-./:;<=>?@\[\\\]^_`{|}~] ->
        stack = stack
          |> push_stack({:text, <<char::utf8>>})
        text(rest, original, skip + 2, stack, state, 0)
      "\r\n" <> rest ->
        stack = stack
          |> push_stack(:"\n")
        newline(rest, original, skip + 3, stack, state)
      "\n" <> rest ->
        stack = stack
          |> push_stack(:"\n")
        newline(rest, original, skip + 2, stack, state)
      _rest ->
        text(rest, original, skip, stack, state, 1)
    end
  end

  defp newline(rest, original, skip, stack, state) do
    stack = stack
      |> push_stack(:"\n")
    state = %{state | indent: 0, leaf_type: nil} |> set_newline()
    container(rest, original, skip, stack, state)
  end

  @compile {:inline, reset_newline: 1}
  defp reset_newline(state = %{newline: _nl_st}), do: %{state | newline: false}

  @compile {:inline, set_newline: 1}
  defp set_newline(false), do: :soft
  defp set_newline(:soft), do: :hard
  defp set_newline(:hard), do: :hard
  defp set_newline(state = %{newline: nl_st}), do: %{state | newline: set_newline(nl_st)}

  defp indent(data, original, skip, stack, state = %{edge: edge}, len)
    when len >= edge + 4
  do
    stack = if len > 4 do
        stack
        |> push_stack({:indent, edge})
      else
        stack
      end
    code_indent(data, original, skip, stack, state)
  end
  defp indent(data, original, skip, stack, state, len) do
    case data do
      <<?\s, rest::binary>> ->
        indent(rest, original, skip + 1, stack, state, len + 1)
      <<?\t, rest::binary>> ->
        indent(rest, original, skip + 1, stack, state, len + 4)
      data when len == 0 ->
        container(data, original, skip, stack, state)

      data ->
        stack = stack
          |> push_stack({:indent, len})
        state = %{state | edge: len, indent: len}
        container(data, original, skip, stack, state)
    end
  end

  defp code_indent(data, original, skip, stack, state) do
    {rest, len} = seek_eol(data, 0)
    term = track_part(original, skip, len)
    skip = skip + len
    stack = stack
      |> push_stack({:code_indent_line, term})

    container(rest, original, skip, stack, state)
  end

  defp code_span(_data, original, skip, stack, state = %{newline: :hard, match_len: match_len}, _len) do
    backtrack(original, skip, stack, %{state | match_len: 0}, match_len)
  end
  defp code_span(data, original, skip, stack, state = %{match_len: match_len}, len) do
    case data do
      "`" <> rest ->
        {rest, count} = count_char(rest, ?`, 1)
        if match_len == count do
          skip = skip + count
          term = track_part(original, skip, len)
            # |> String.replace(~r/(\r\n|\n)/, " ")
          stack = stack
            |> push_stack({:text, {:code_span, term}})
          text(rest, original, skip + len + count, stack, %{state | match_len: 0}, 0)
        else
          code_span(rest, original, skip, stack, state, len + count)
        end
      "\r\n" <> rest ->
        code_span(rest, original, skip, stack, state |> set_newline(), len + 2)
      "\n" <> rest ->
        code_span(rest, original, skip, stack, state |> set_newline(), len + 1)
      <<_c::utf8, rest::binary>> ->
        code_span(rest, original, skip, stack, state, len + 1)
      _data ->
        backtrack(original, skip, stack, %{state | match_len: 0}, match_len)
    end
  end

  # @compile {:inline, backtrack: 5}
  defp backtrack(original, skip, stack, state, match_len)
  defp backtrack(original, skip, stack, state, match_len) do
    matched = text_part(original, skip, match_len)
    data = binary_part(original, skip + match_len, byte_size(original) - skip - match_len)
    stack = stack
      |> push_stack(matched)
    text(data, original, skip + match_len, stack, state)
  end


  defp code_fence(data, original, skip, stack, state = %{leaf: true}, len) do
    text(data, original, skip - state.match_len, stack, state, len + state.match_len)
  end
  defp code_fence(data, original, skip, stack, state = %{match_len: match_len, match_char: match_char}, len) do
    case data do
      <<char::utf8, rest::binary>> when char == match_char ->
        {rest, count} = count_char(rest, char, 1)
        if count >= match_len do
          term = track_part(original, skip, len)
          text(rest, original, skip + len + count, [{:code_fence, term} | stack], %{state | match_len: 0, match_char: nil}, 0)
        else
          code_fence(rest, original, skip, stack, state, len + count)
        end
      <<_char::utf8, rest::binary>> ->
        code_fence(rest, original, skip, stack, state, len + 1)
      _data ->
        # Handle empty
        term = track_part(original, skip, len)
        text(data, original, skip + len, [{:code_fence, term} | stack], %{state | match_len: 0, match_char: nil}, 0)
    end
  end

  defp autolink_scheme(data, original, skip, stack, state, len)
  defp autolink_scheme(data, original, skip, stack, state, len) do
    case data do
      <<c::utf8, rest::binary>>
        when is_html_tag(c)
          or c in ~c[+.]
      ->
        autolink_scheme(rest, original, skip, stack, state, len + 1)

      ":" <> rest
        when len > 2
      ->
        term = track_part(original, skip, len)
        stack = stack
          |> push_stack({:scheme, term})
        autolink_uri(rest, original, skip + len + 1, stack, state)

      _data ->
        text(data, original, skip, stack, state, len)
    end
  end

  defp autolink_uri(data, original, skip, stack, state, len \\ 0)
  defp autolink_uri(data, original, skip, stack, state, len) do
    case data do
      ">" <> rest ->
        term = track_part(original, skip, len)
        stack = stack
          |> push_stack({:uri, term})
          |> push_stack(:">")
        text(rest, original, skip + len + 1, stack, state)

      <<c::utf8, rest::binary>>
        when c not in 0..0x20 # Ascii control characters and space
         and c != 0x7F
      ->
        autolink_uri(rest, original, skip, stack, state, len + 1)

      _data ->
        text(data, original, skip, stack, state, len)
    end
  end

  defp comment(data, original, skip, stack, state, len \\ 0)
  defp comment(data, original, skip, stack, state, 0) do
    case data do
      ">" <> rest ->
        stack = stack
          |> pop_stack()
          |> push_stack({:comment, ""})
        text(rest, original, skip + 1, stack, state, 0)

      "->" <> rest ->
        stack = stack
          |> pop_stack()
          |> push_stack({:comment, ""})
        text(rest, original, skip + 2, stack, state, 0)

      "-->" <> rest ->
        stack = stack
          |> pop_stack()
          |> push_stack({:comment, ""})
        text(rest, original, skip + 3, stack, state, 0)

      <<_c::utf8, rest::binary>> ->
        comment(rest, original, skip, stack, state, 1)

      _data ->
        text(data, original, skip, stack, state, 0)
    end
  end
  defp comment(data, original, skip, stack, state, len) do
    case data do
      "-->" <> rest ->
        term = track_part(original, skip, len)
        skip = skip + len
        stack = stack
          |> pop_stack()
          |> push_stack({:comment, term})
          # |> push_stack(:"-->")
        text(rest, original, skip + 3, stack, state, 0)

      <<_c::utf8, rest::binary>> ->
        comment(rest, original, skip, stack, state, len + 1)

      _data ->
        term = track_part(original, skip, len)
        skip = skip + len
        stack = stack
          |> pop_stack()
          |> push_stack({:comment, term})
          # |> push_stack(:"-->")
        text(data, original, skip, stack, state)
    end
  end

  defp html_declaration(data, original, skip, stack, state, len \\ 0)
  defp html_declaration(data, original, skip, stack, state, 0) do
    case data do
      "--" <> rest ->
        stack = stack
          |> pop_stack()
          |> push_stack(:"<!--")
        comment(rest, original, skip + 2, stack, state)

      # "[CDATA[" <> rest ->
      #   cdata(data, original, skip, stack, state)

      <<c::utf8, rest::binary>>
        when is_ascii_letter(c)
      ->
        html_declaration(rest, original, skip, stack, state, 1)

      _data ->
        text(data, original, skip, stack, state, 0)
    end
  end
  defp html_declaration(data, original, skip, stack, state, len) do
    case data do
      <<c::utf8, rest::binary>>
        when c not in ~c[>]
      ->
        html_declaration(rest, original, skip, stack, state, len + 1)

      ">" <> rest ->
        term = track_part(original, skip, len)
        stack = stack
          |> push_stack({:html_declaration, term})
          |> push_stack(:">")

        text(rest, original, skip + len + 1, stack, state)

      _data ->
        text(data, original, skip, stack, state, len)
    end
  end

  defp html_tag_name(data, original, skip, stack, state, len \\ 0)
  defp html_tag_name(data, original, skip, stack, state, len) do
    case data do
      <<c::utf8, rest::binary>>
        when len > 1
         and is_html_tag(c)
      ->
        html_tag_name(rest, original, skip, stack, state, len + 1)

      <<c::utf8, rest::binary>>
        when is_ascii_letter(c)
      ->
        html_tag_name(rest, original, skip, stack, state, len + 1)

      _data ->
        term = binary_part(original, skip, len)
        with {:ok, tag_name} <- check_tag_list(term, state) do
          stack = stack
          |> push_stack({:tag_name, tag_name})
          html_tag(data, original, skip + len, stack, state)
        else
          {:error, _not_allowed} ->
            stack = stack
            |> push_stack({:text, term})
            text(data, original, skip + len, stack, state)
        end
    end
  end

  defp html_tag(data, original, skip, stack, state)
  defp html_tag(data, original, skip, stack, state) do
    case data do
      <<c::utf8, rest::binary>> when c in ~c[\s\t] ->
        stack = stack
          |> push_stack(:"\s")
        html_tag(rest, original, skip + 1, stack, state)

      "/>" <> rest ->
        stack = stack
          |> push_stack(:"/>")
        text(rest, original, skip + 2, stack, state)

      ">" <> rest ->
        stack = stack
          |> push_stack(:">")
        text(rest, original, skip + 1, stack, state)

      <<c::utf8, rest::binary>>
        when is_ascii_letter(c)
          or c in ~c[:_]
      ->
        html_tag_attribute(rest, original, skip, stack, state, 1)

      _data ->
        text(data, original, skip, stack, state)

    end
  end

  defp html_tag_attribute(data, original, skip, stack, state, len)
  defp html_tag_attribute(data, original, skip, stack, state, len) do
    case data do
      <<c::utf8, rest::binary>>
        when is_html_attribute_name(c)
      ->
        html_tag_attribute(rest, original, skip, stack, state, len + 1)

      "=" <> rest ->
        term = binary_part(original, skip, len)
        stack = with {:ok, attr} <- check_attribute_list(term, state) do
          stack
          |> push_stack({:attribute, attr})
        else
          {:error, _not_allowed} ->
            stack
            |> push_stack({:denied_attribute, term})
        end
        |> push_stack(:"=")
        html_tag_attribute_value(rest, original, skip + len + 1, stack, state)

      _data ->
        term = binary_part(original, skip, len)
        stack = with {:ok, attr} <- check_attribute_list(term, state) do
          stack
          |> push_stack({:attribute, attr})
        else
          {:error, _not_allowed} ->
            stack
            |> push_stack({:denied_attribute, term})
        end
        html_tag(data, original, skip + len, stack, state)

    end
  end

  defguardp is_unquoted_attribute(c)
    when c not in ~c[\s\t\r\n"'=<>`]

  defp html_tag_attribute_value(data, original, skip, stack, state)
  defp html_tag_attribute_value(data, original, skip, stack, state) do
    case data do
      "\"" <> rest ->
        with {:ok, {rest, len}} <- quoted_scan(rest, ?") do
          term = track_part(original, skip + 1, len)
          stack = stack
            |> push_stack({:quoted_value, ?", term})
          html_tag(rest, original, skip + len + 2, stack, state)
        else
          :error -> text(rest, original, skip, stack, state, 1)
        end

      "'" <> rest ->
        with {:ok, {rest, len}} <- quoted_scan(rest, ?') do
          term = track_part(original, skip + 1, len)
          stack = stack
            |> push_stack({:quoted_value, ?', term})
          html_tag(rest, original, skip + len + 2, stack, state)
        else
          :error -> text(rest, original, skip, stack, state, 1)
        end

      <<c::utf8, rest::binary>>
        when is_unquoted_attribute(c)
      ->
        {rest, len} = scan(rest, &is_unquoted_attribute/1, 1)
        term = track_part(original, skip, len)
        stack = stack
          |> push_stack({:unquoted_value, term})
        html_tag(rest, original, skip + len, stack, state)

      _data ->
        text(data, original, skip, stack, state)
    end
  end

  defp continue(data, original, skip, stack, state, term) do
    stack = stack
      |> push_stack(term)
    case data do
      "" ->
        stack
        |> squash_stack()
        |> correct_tokens()
        |> make_blocks()
      _ ->
        container(data, original, skip, stack, state)
    end
  end

  # Quotes are the one place where backtracking is necessary
  defp quoted_scan(data, char, count \\ 0) do
    case scan(data, fn c -> c != char end, 0) do
      {<<^char::utf8, rest::binary>>, len} ->
        {:ok, {rest, len + count}}

      {_rest, _len} ->
        :error
    end
  end

  defp seek_eol(data, len) do
    case data do
      <<?\n, _rest::binary>> ->
        {data, len}
      "\r\n" <> _rest ->
        {data, len}
      <<_char::utf8, rest::binary>> ->
        seek_eol(rest, len + 1)
      _data ->
        {data, len}
    end
  end

  @compile {:inline, scan: 3}
  defp scan(_data, scan_fun, _len) when not is_function(scan_fun, 1) do
    raise ArgumentError, message: "Invalid scan_fun/1"
  end
  defp scan(data = "\r\n\r\n" <> _rest, _scan_fun, len), do: {data, len}
  defp scan(data = "\n\n" <> _rest, _scan_fun, len), do: {data, len}
  defp scan(data = <<c::utf8, rest::binary>>, scan_fun, len) do
    if scan_fun.(c) do
      scan(rest, scan_fun, len + 1)
    else
      {data, len}
    end
  end
  defp scan(data, _scan_fun, len), do: {data, len}

  @compile {:inline, count_char: 3}
  defp count_char(data, char, len) do
    scan_fun = fn
        c -> c == char
      end
    scan(data, scan_fun, len)
  end

  @compile {:inline, push_stack: 2}
  defp push_stack(stack, term)
    when term == []
    when term == nil
  do
    stack
  end
  defp push_stack(stack, :space) do
    case stack do
      [{:left, term} | stack] ->
        [{:text, char_or_bin(term)} | push_stack(stack, :space)]
      _stack ->
        stack
    end
  end
  defp push_stack(stack, term)
    when is_integer(term)
    when is_binary(term)
  do
    case stack do
      [] ->
        [{:left, term} | stack]

      [comp_term | _stack] when is_atom(comp_term) ->
        [{:left, term} | stack]

      # [:"\n" | _stack] ->
      #   [{:left, term} | stack]

      [{flank, _char} | _stack] when flank in ~w[left right]a ->
        [{flank, term} | stack]

      _stack ->
        [{:right, term} | stack]
    end
  end
  defp push_stack(stack, term) do
    [term | stack]
  end

  defp push_stack_mult(stack, term, amt) do
    Enum.reduce(1..amt, stack, fn _index, stack -> stack |> push_stack(term) end)
  end

  @compile {:inline, pop_stack: 1}
  defp pop_stack([_term | stack]), do: stack
  defp pop_stack(stack), do: stack


  # defp serialize_text({:text, text}) do
  #   text
  #   |> List.wrap()
  #   |> List.flatten()
  #   |> Enum.chunk_by(&is_binary/1)
  #   |> Enum.map(fn
  #     [head | _tail] = wordlist when is_binary(head) ->
  #       Enum.join(wordlist)
  #     other_node ->
  #       other_node
  #   end)
  # end

  defp check_tag_list(tag, _state = %{html: _html_opts = %{tags: %{mode: mode, allowlist: allowlist, denylist: denylist}}}) do
    case mode do
      :allow ->
        tag in allowlist

      :deny ->
        tag in denylist
    end
    |> if do
      {:ok, tag}
    else
      {:error, :not_allowed}
    end
  end
  defp check_tag_list(tag, _state) do
    {:ok, tag}
  end

  defp check_attribute_list(attr, _state = %{html: _html_opts = %{attributes: %{mode: mode, allowlist: allowlist, denylist: denylist}}}) do
    case mode do
      :allow ->
        attr in allowlist

      :deny ->
        attr in denylist
    end
    |> if do
      {:ok, attr}
    else
      {:error, :not_allowed}
    end
  end
  defp check_attribute_list(attr, _state) do
    {:ok, attr}
  end

  @compile {:inline, text_part: 3}
  defp text_part(original, skip, len)
  defp text_part(_original, _skip, 0), do: []
  defp text_part(original, skip, len), do: {:text, track_part(original, skip, len)}

  @compile {:inline, track_part: 3}
  defp track_part(original, skip, len)
  defp track_part(_original, _skip, 0), do: []
  defp track_part(original, skip, len), do: binary_part(original, skip, len)
  # defp track_part(_original, skip, len), do: {:<<>>, skip, len}

  @compile {:inline, check_last: 2}
  def check_last(original, skip)
  def check_last(original, skip) do
    last_pos = skip - 1
    if last_pos < 0 do
      nil
    else
      <<c::utf8>> = binary_part(original, last_pos, 1)
      c
    end
  end


end
