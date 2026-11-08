defimpl Enumerable, for: LazyHTML do
  def count(%LazyHTML{tree: tree}) do
    {:ok, length(tree)}
  end

  def member?(%LazyHTML{tree: tree}, %LazyHTML{tree: [node]}) do
    {:ok, Enum.member?(tree, node)}
  end

  def member?(_lazy, _other) do
    {:ok, false}
  end

  def slice(%LazyHTML{tree: tree}) do
    size = length(tree)

    {:ok, size,
     fn start, len, step ->
       tree
       |> Enum.slice(start, len * step)
       |> Enum.take_every(step)
       |> Enum.map(&%LazyHTML{tree: [&1]})
     end}
  end

  def reduce(%LazyHTML{tree: tree}, acc, fun) do
    items = Enum.map(tree, &%LazyHTML{tree: [&1]})
    Enumerable.List.reduce(items, acc, fun)
  end
end
