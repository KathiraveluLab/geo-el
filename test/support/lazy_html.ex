defmodule LazyHTML do
  @moduledoc false

  defstruct tree: []

  @type t :: %__MODULE__{tree: list()}

  def from_document(html, _opts \\ []) when is_binary(html) do
    %__MODULE__{tree: Floki.parse_document!(html)}
  end

  def from_fragment(html, _opts \\ []) when is_binary(html) do
    %__MODULE__{tree: Floki.parse_fragment!(html)}
  end

  def from_tree(tree) when is_list(tree) do
    %__MODULE__{tree: tree}
  end

  def from_tree(node) do
    %__MODULE__{tree: [node]}
  end

  def to_tree(%__MODULE__{tree: tree}, _opts \\ []) do
    tree
  end

  def to_html(%__MODULE__{tree: tree}, opts \\ []) do
    LazyHTML.Tree.to_html(tree, opts)
  end

  def query(%__MODULE__{tree: tree}, selector) when is_binary(selector) do
    %__MODULE__{tree: Floki.find(tree, selector)}
  end

  def filter(%__MODULE__{} = lazy, selector) when is_binary(selector) do
    query(lazy, selector)
  end

  def query_by_id(%__MODULE__{tree: tree}, id) when is_binary(id) do
    %__MODULE__{tree: find_by_id(tree, id)}
  end

  def attribute(%__MODULE__{tree: tree}, attr_name) when is_binary(attr_name) do
    Enum.flat_map(tree, fn
      {_tag, attrs, _children} ->
        for {k, v} <- attrs, k == attr_name, do: v

      _ ->
        []
    end)
  end

  def tag(%__MODULE__{tree: tree}) do
    Enum.flat_map(tree, fn
      {tag_name, _attrs, _children} -> [tag_name]
      _ -> []
    end)
  end

  def text(%__MODULE__{tree: tree}) do
    Floki.text(tree)
  end

  def child_nodes(%__MODULE__{tree: tree}) do
    children =
      Enum.flat_map(tree, fn
        {_tag, _attrs, child_list} -> child_list
        _ -> []
      end)

    %__MODULE__{tree: children}
  end

  defp find_by_id(nodes, target_id) when is_list(nodes) do
    Enum.flat_map(nodes, fn
      {_tag, attrs, children} = node ->
        matches_self =
          if Enum.any?(attrs, fn {k, v} -> k == "id" and v == target_id end) do
            [node]
          else
            []
          end

        matches_self ++ find_by_id(children, target_id)

      _ ->
        []
    end)
  end
end
