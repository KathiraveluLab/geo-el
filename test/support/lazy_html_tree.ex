defmodule LazyHTML.Tree do
  @moduledoc false

  def to_html(tree, opts \\ []) when is_list(tree) do
    skip_ws = Keyword.get(opts, :skip_whitespace_nodes, false)

    cleaned =
      if skip_ws do
        prune_whitespace(tree)
      else
        tree
      end

    Floki.raw_html(cleaned)
  end

  def postwalk(tree, fun) when is_function(fun, 1) do
    {result, _} =
      postwalk(tree, nil, fn node, nil ->
        {fun.(node), nil}
      end)

    result
  end

  def postwalk(tree, acc, fun) when is_function(fun, 2) do
    do_postwalk(tree, acc, fun)
  end

  defp do_postwalk([], acc, _fun), do: {[], acc}

  defp do_postwalk([node | rest], acc, fun) do
    case do_postwalk(node, acc, fun) do
      {nodes, acc} when is_list(nodes) ->
        {rest_nodes, acc} = do_postwalk(rest, acc, fun)
        {nodes ++ rest_nodes, acc}

      {single_node, acc} ->
        {rest_nodes, acc} = do_postwalk(rest, acc, fun)
        {[single_node | rest_nodes], acc}
    end
  end

  defp do_postwalk({tag, attrs, children}, acc, fun) do
    {new_children, acc} = do_postwalk(children, acc, fun)
    fun.({tag, attrs, new_children}, acc)
  end

  defp do_postwalk(node, acc, fun) do
    fun.(node, acc)
  end

  defp prune_whitespace(nodes) when is_list(nodes) do
    nodes
    |> Enum.reject(fn
      text when is_binary(text) -> String.trim(text) == ""
      _ -> false
    end)
    |> Enum.map(fn
      {tag, attrs, children} -> {tag, attrs, prune_whitespace(children)}
      other -> other
    end)
  end
end
