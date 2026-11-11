defmodule GeoEl.Globe.YamlParser do
  @moduledoc """
  Pure-Elixir YAML parser supporting mappings, sequences, quoted and block scalars,
  flow mappings, and comments for teacher-editable waypoint question banks.
  """

  @type yaml_value ::
          nil
          | boolean()
          | integer()
          | float()
          | String.t()
          | [yaml_value()]
          | %{optional(String.t()) => yaml_value()}

  @doc """
  Parses a UTF-8 YAML document string into Elixir maps, lists, and scalar values.
  Returns `{:ok, value}` or `{:error, reason}` with line-level diagnostics.
  """
  @spec parse(String.t()) :: {:ok, yaml_value()} | {:error, String.t()}
  def parse(content) when is_binary(content) do
    with {:ok, tokens} <- preprocess(content) do
      case tokens do
        [] ->
          {:ok, %{}}

        [{_line, indent, _text} | _] ->
          {value, rest} = parse_block(tokens, indent)

          if rest != [] do
            {line_num, _, text} = hd(rest)
            {:error, "Line #{line_num}: unexpected trailing YAML content: #{text}"}
          else
            {:ok, value}
          end
      end
    end
  rescue
    e in ArgumentError -> {:error, Exception.message(e)}
  end

  defp preprocess(content) do
    normalized =
      content
      |> String.trim_leading(<<0xEF, 0xBB, 0xBF>>)
      |> String.replace("\r\n", "\n")
      |> String.replace("\r", "\n")

    lines =
      normalized
      |> String.split("\n")
      |> Enum.with_index(1)

    Enum.reduce_while(lines, {:ok, []}, fn {raw_line, line_num}, {:ok, acc} ->
      leading_ws =
        case Regex.run(~r/^([ \t]*)/, raw_line) do
          [_, ws] -> ws
          _ -> ""
        end

      if String.contains?(leading_ws, "\t") do
        {:halt,
         {:error,
          "Line #{line_num}: tabs are not permitted for YAML indentation; please use spaces."}}
      else
        indent = String.length(leading_ws)
        trimmed_left = String.slice(raw_line, indent, String.length(raw_line) - indent)
        stripped = strip_inline_comment(trimmed_left) |> String.trim_trailing()

        if stripped == "" or (indent == 0 and stripped in ["---", "..."]) do
          {:cont, {:ok, acc}}
        else
          {:cont, {:ok, [{line_num, indent, stripped} | acc]}}
        end
      end
    end)
    |> case do
      {:ok, rev} -> {:ok, Enum.reverse(rev)}
      err -> err
    end
  end

  defp parse_block([], _min_indent), do: {nil, []}

  defp parse_block([{_line, indent, text} | _] = lines, min_indent) do
    if sequence_line?(text) do
      parse_sequence(lines, indent)
    else
      parse_mapping(lines, min_indent)
    end
  end

  defp parse_sequence(lines, seq_indent) do
    {items_rev, rest} = do_parse_sequence(lines, seq_indent, [])
    {Enum.reverse(items_rev), rest}
  end

  defp do_parse_sequence([], _seq_indent, acc), do: {acc, []}

  defp do_parse_sequence([{line_num, indent, text} | rest] = lines, seq_indent, acc) do
    cond do
      indent < seq_indent ->
        {acc, lines}

      indent > seq_indent ->
        raise ArgumentError, "Line #{line_num}: unexpected indentation inside YAML list: #{text}"

      text == "-" ->
        case rest do
          [{_next_line, next_indent, _} | _] when next_indent > seq_indent ->
            {item, remaining} = parse_block(rest, next_indent)
            do_parse_sequence(remaining, seq_indent, [item | acc])

          _ ->
            do_parse_sequence(rest, seq_indent, [nil | acc])
        end

      String.starts_with?(text, "- ") ->
        inline = String.slice(text, 2, String.length(text) - 2) |> String.trim_leading()
        leading_spaces = count_leading_spaces_after_dash(text)
        inline_indent = indent + 1 + leading_spaces
        synthetic = [{line_num, inline_indent, inline} | rest]

        {item, remaining} =
          if mapping_line?(inline) do
            parse_mapping(synthetic, inline_indent)
          else
            parse_scalar_or_inline(inline, line_num, rest, indent)
          end

        do_parse_sequence(remaining, seq_indent, [item | acc])

      true ->
        {acc, lines}
    end
  end

  defp parse_mapping(lines, map_indent) do
    {map, rest} = do_parse_mapping(lines, map_indent, %{})
    {map, rest}
  end

  defp do_parse_mapping([], _map_indent, acc), do: {acc, []}

  defp do_parse_mapping([{line_num, indent, text} | rest] = lines, map_indent, acc) do
    cond do
      indent < map_indent ->
        {acc, lines}

      indent > map_indent ->
        raise ArgumentError,
              "Line #{line_num}: unexpected indentation inside YAML mapping: #{text}"

      sequence_line?(text) ->
        {acc, lines}

      true ->
        {key, raw_val} = split_key_value!(text, line_num)

        {val, remaining} =
          cond do
            raw_val == "" ->
              parse_nested_for_empty_value(rest, indent)

            block_scalar_indicator?(raw_val) ->
              parse_block_scalar(raw_val, line_num, rest, indent)

            true ->
              parse_scalar_or_inline(raw_val, line_num, rest, indent)
          end

        do_parse_mapping(remaining, map_indent, Map.put(acc, key, val))
    end
  end

  defp parse_nested_for_empty_value([], _parent_indent), do: {nil, []}

  defp parse_nested_for_empty_value([{_line, next_indent, next_text} | _] = rest, parent_indent) do
    cond do
      next_indent > parent_indent ->
        parse_block(rest, next_indent)

      next_indent == parent_indent and sequence_line?(next_text) ->
        parse_sequence(rest, next_indent)

      true ->
        {nil, rest}
    end
  end

  defp parse_scalar_or_inline(raw_val, line_num, rest, parent_indent) do
    trimmed = String.trim(raw_val)

    cond do
      String.starts_with?(trimmed, "{") and String.ends_with?(trimmed, "}") ->
        {parse_flow_mapping(trimmed, line_num), rest}

      String.starts_with?(trimmed, "\"") ->
        {parse_double_quoted(trimmed, line_num), rest}

      String.starts_with?(trimmed, "'") ->
        {parse_single_quoted(trimmed, line_num), rest}

      true ->
        {cont_lines, remaining} = collect_plain_continuations(rest, parent_indent, [])

        joined =
          case cont_lines do
            [] -> trimmed
            parts -> Enum.join([trimmed | parts], " ")
          end

        {convert_plain_scalar(joined), remaining}
    end
  end

  defp collect_plain_continuations([], _parent_indent, acc), do: {Enum.reverse(acc), []}

  defp collect_plain_continuations([{_line, indent, text} | rest] = lines, parent_indent, acc) do
    if indent > parent_indent and not sequence_line?(text) and not mapping_line?(text) do
      collect_plain_continuations(rest, parent_indent, [String.trim(text) | acc])
    else
      {Enum.reverse(acc), lines}
    end
  end

  defp parse_block_scalar(indicator, line_num, rest, parent_indent) do
    style = String.first(indicator)

    case rest do
      [{_next_line, content_indent, _} | _] when content_indent > parent_indent ->
        {lines_rev, remaining} = collect_block_scalar_lines(rest, parent_indent, [])
        text_lines = Enum.reverse(lines_rev)

        joined =
          if style == "|" do
            Enum.join(text_lines, "\n")
          else
            Enum.join(text_lines, " ")
          end

        text =
          if String.ends_with?(indicator, "+") do
            joined <> "\n"
          else
            String.trim_trailing(joined)
          end

        {text, remaining}

      _ ->
        raise ArgumentError, "Line #{line_num}: expected indented text after '#{indicator}'"
    end
  end

  defp collect_block_scalar_lines([], _parent_indent, acc), do: {acc, []}

  defp collect_block_scalar_lines([{_line, indent, text} | rest] = lines, parent_indent, acc) do
    if indent > parent_indent do
      collect_block_scalar_lines(rest, parent_indent, [text | acc])
    else
      {acc, lines}
    end
  end

  defp parse_flow_mapping(text, line_num) do
    inner =
      text
      |> String.slice(1, String.length(text) - 2)
      |> String.trim()

    if inner == "" do
      %{}
    else
      inner
      |> split_flow_entries(line_num)
      |> Enum.reduce(%{}, fn entry, acc ->
        {key, raw_val} = split_key_value!(String.trim(entry), line_num)
        val = parse_flow_scalar(String.trim(raw_val), line_num)
        Map.put(acc, key, val)
      end)
    end
  end

  defp split_flow_entries(text, line_num) do
    do_split_flow(String.graphemes(text), nil, false, [], [], line_num)
  end

  defp do_split_flow([], quote_char, _escaped, current, acc, line_num) do
    if quote_char != nil do
      raise ArgumentError, "Line #{line_num}: unterminated quote inside flow mapping"
    end

    last = current |> Enum.reverse() |> Enum.join()
    Enum.reverse([last | acc]) |> Enum.reject(&(String.trim(&1) == ""))
  end

  defp do_split_flow([ch | rest], nil, _escaped, current, acc, line_num)
       when ch in ["\"", "'"] do
    do_split_flow(rest, ch, false, [ch | current], acc, line_num)
  end

  defp do_split_flow(["," | rest], nil, _escaped, current, acc, line_num) do
    part = current |> Enum.reverse() |> Enum.join()
    do_split_flow(rest, nil, false, [], [part | acc], line_num)
  end

  defp do_split_flow([ch | rest], nil, _escaped, current, acc, line_num) do
    do_split_flow(rest, nil, false, [ch | current], acc, line_num)
  end

  defp do_split_flow(["\\" | rest], "\"", false, current, acc, line_num) do
    do_split_flow(rest, "\"", true, ["\\" | current], acc, line_num)
  end

  defp do_split_flow([ch | rest], "\"", true, current, acc, line_num) do
    do_split_flow(rest, "\"", false, [ch | current], acc, line_num)
  end

  defp do_split_flow(["\"", ch2 | rest], "\"", false, current, acc, line_num) do
    do_split_flow([ch2 | rest], nil, false, ["\"" | current], acc, line_num)
  end

  defp do_split_flow(["\""], "\"", false, current, acc, line_num) do
    do_split_flow([], nil, false, ["\"" | current], acc, line_num)
  end

  defp do_split_flow(["'", "'" | rest], "'", false, current, acc, line_num) do
    do_split_flow(rest, "'", false, ["'", "'" | current], acc, line_num)
  end

  defp do_split_flow(["'" | rest], "'", false, current, acc, line_num) do
    do_split_flow(rest, nil, false, ["'" | current], acc, line_num)
  end

  defp do_split_flow([ch | rest], quote_char, _escaped, current, acc, line_num) do
    do_split_flow(rest, quote_char, false, [ch | current], acc, line_num)
  end

  defp parse_flow_scalar(val, line_num) do
    cond do
      String.starts_with?(val, "\"") -> parse_double_quoted(val, line_num)
      String.starts_with?(val, "'") -> parse_single_quoted(val, line_num)
      true -> convert_plain_scalar(val)
    end
  end

  defp parse_double_quoted(text, line_num) do
    if not String.ends_with?(text, "\"") or String.length(text) < 2 do
      raise ArgumentError, "Line #{line_num}: unterminated double-quoted string: #{text}"
    end

    inner = String.slice(text, 1, String.length(text) - 2)
    unescape_double_quoted(String.graphemes(inner), [])
  end

  defp unescape_double_quoted([], acc), do: acc |> Enum.reverse() |> Enum.join()

  defp unescape_double_quoted(["\\", "\"" | rest], acc),
    do: unescape_double_quoted(rest, ["\"" | acc])

  defp unescape_double_quoted(["\\", "\\" | rest], acc),
    do: unescape_double_quoted(rest, ["\\" | acc])

  defp unescape_double_quoted(["\\", "n" | rest], acc),
    do: unescape_double_quoted(rest, ["\n" | acc])

  defp unescape_double_quoted(["\\", "t" | rest], acc),
    do: unescape_double_quoted(rest, ["\t" | acc])

  defp unescape_double_quoted(["\\", "r" | rest], acc),
    do: unescape_double_quoted(rest, ["\r" | acc])

  defp unescape_double_quoted(["\\", ch | rest], acc),
    do: unescape_double_quoted(rest, [ch | acc])

  defp unescape_double_quoted([ch | rest], acc), do: unescape_double_quoted(rest, [ch | acc])

  defp parse_single_quoted(text, line_num) do
    if not String.ends_with?(text, "'") or String.length(text) < 2 do
      raise ArgumentError, "Line #{line_num}: unterminated single-quoted string: #{text}"
    end

    inner = String.slice(text, 1, String.length(text) - 2)
    String.replace(inner, "''", "'")
  end

  defp convert_plain_scalar(val) do
    cond do
      val in ["null", "Null", "NULL", "~"] ->
        nil

      val in ["true", "True", "TRUE"] ->
        true

      val in ["false", "False", "FALSE"] ->
        false

      Regex.match?(~r/^[+-]?\d+$/, val) ->
        String.to_integer(val)

      Regex.match?(~r/^[+-]?(?:\d+\.\d*|\.\d+)(?:[eE][+-]?\d+)?$/, val) ->
        normalized = normalize_float_literal(val)
        {num, ""} = Float.parse(normalized)
        num

      true ->
        val
    end
  end

  defp normalize_float_literal("." <> rest), do: "0." <> rest
  defp normalize_float_literal("+." <> rest), do: "+0." <> rest
  defp normalize_float_literal("-." <> rest), do: "-0." <> rest
  defp normalize_float_literal(other), do: other

  defp split_key_value!(text, line_num) do
    cond do
      String.ends_with?(text, ":") ->
        key = String.slice(text, 0, String.length(text) - 1) |> unquote_key()
        {key, ""}

      true ->
        case String.split(text, ": ", parts: 2) do
          [raw_key, raw_val] ->
            {unquote_key(raw_key), String.trim_leading(raw_val)}

          _ ->
            raise ArgumentError,
                  "Line #{line_num}: expected 'key: value' mapping entry, got: #{text}"
        end
    end
  end

  defp unquote_key(raw_key) do
    trimmed = String.trim(raw_key)

    cond do
      String.starts_with?(trimmed, "\"") and String.ends_with?(trimmed, "\"") ->
        String.slice(trimmed, 1, String.length(trimmed) - 2)

      String.starts_with?(trimmed, "'") and String.ends_with?(trimmed, "'") ->
        String.slice(trimmed, 1, String.length(trimmed) - 2)

      true ->
        trimmed
    end
  end

  defp strip_inline_comment(line) do
    do_strip_comment(String.graphemes(line), nil, false, true, [])
  end

  defp do_strip_comment([], _q, _esc, _prev_ws, acc), do: acc |> Enum.reverse() |> Enum.join()

  defp do_strip_comment(["#" | _rest], nil, false, true, acc) do
    acc |> Enum.reverse() |> Enum.join()
  end

  defp do_strip_comment([ch | rest], nil, false, _prev_ws, acc) when ch in ["\"", "'"] do
    do_strip_comment(rest, ch, false, false, [ch | acc])
  end

  defp do_strip_comment([ch | rest], nil, false, _prev_ws, acc) do
    do_strip_comment(rest, nil, false, ch == " " or ch == "\t", [ch | acc])
  end

  defp do_strip_comment(["\\" | rest], "\"", false, _prev_ws, acc) do
    do_strip_comment(rest, "\"", true, false, ["\\" | acc])
  end

  defp do_strip_comment([ch | rest], "\"", true, _prev_ws, acc) do
    do_strip_comment(rest, "\"", false, false, [ch | acc])
  end

  defp do_strip_comment(["\"" | rest], "\"", false, _prev_ws, acc) do
    do_strip_comment(rest, nil, false, false, ["\"" | acc])
  end

  defp do_strip_comment(["'", "'" | rest], "'", false, _prev_ws, acc) do
    do_strip_comment(rest, "'", false, false, ["'", "'" | acc])
  end

  defp do_strip_comment(["'" | rest], "'", false, _prev_ws, acc) do
    do_strip_comment(rest, nil, false, false, ["'" | acc])
  end

  defp do_strip_comment([ch | rest], q, _esc, _prev_ws, acc) do
    do_strip_comment(rest, q, false, false, [ch | acc])
  end

  defp sequence_line?(text), do: text == "-" or String.starts_with?(text, "- ")

  defp mapping_line?(text) do
    not sequence_line?(text) and
      (String.contains?(text, ": ") or String.ends_with?(text, ":")) and
      not String.starts_with?(text, "\"") and
      not String.starts_with?(text, "'")
  end

  defp block_scalar_indicator?(val) do
    val in ["|", "|-", "|+", ">", ">-", ">+"]
  end

  defp count_leading_spaces_after_dash(text) do
    after_dash = String.slice(text, 1, String.length(text) - 1)
    String.length(after_dash) - String.length(String.trim_leading(after_dash, " "))
  end
end
