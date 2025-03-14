defmodule SkipGraph do
  @moduledoc """
  A probabilistic multi-level linked structure for fast approximate nearest neighbor (ANN) search,
  efficient hierarchical indexing, and distributed key-value lookups.
  """

  alias SkipGraph.Node

  @type t :: %__MODULE__{
          head: Node.t(),
          max_level: non_neg_integer(),
          size: non_neg_integer()
        }

  defstruct head: nil, max_level: 0, size: 0

  @doc """
  Creates a new skip-graph with a given max depth.
  """
  @spec new(non_neg_integer()) :: t()
  def new(max_level) do
    head = Node.new(:head, nil, max_level)
    %__MODULE__{head: head, max_level: max_level, size: 0}
  end

  @doc """
  Inserts a node (e.g., key-value pair) into the skip-graph.
  - Randomly determines the level of the node.
  - Updates neighbor links.
  - Uses weight_fn (if provided) to determine edge weights.
  """
  @spec insert(t(), term(), term(), (term(), term() -> number())) :: t()
  def insert(graph, key, value, weight_fn \\ fn _a, _b -> 1 end) do
    level = biased_random_level(graph.max_level)
    new_node = Node.new(key, value, level)

    {graph, _} = insert_node(graph, new_node, graph.max_level, weight_fn)
    %{graph | size: graph.size + 1}
  end

  defp insert_node(graph, new_node, level, weight_fn, path \\ []) do
    if level >= 0 do
      {graph, path} = find_insertion_path(graph, new_node, level, path, weight_fn)
      graph = update_neighbors(graph, new_node, level, path, weight_fn)
      insert_node(graph, new_node, level - 1, weight_fn, path)
    else
      {graph, path}
    end
  end

  defp find_insertion_path(graph, new_node, level, path, _weight_fn) do
    neighbors = graph.head.neighbors[level] || []

    Enum.reduce_while(neighbors, {graph, path}, fn {node, _}, {graph, path} ->
      if node.key < new_node.key do
        {:cont, {graph, [node | path]}}
      else
        {:halt, {graph, path}}
      end
    end)
  end

  defp update_neighbors(graph, new_node, level, path, weight_fn) do
    prev_node = List.first(path) || graph.head
    next_nodes = prev_node.neighbors[level] || []

    # Insert the new node after the previous node
    new_prev_neighbors = [{new_node, weight_fn.(prev_node.key, new_node.key)} | next_nodes]
    new_node_neighbors = [{prev_node, weight_fn.(new_node.key, prev_node.key)} | next_nodes]

    # Update the previous node's neighbors
    prev_node = %{prev_node | neighbors: Map.put(prev_node.neighbors, level, new_prev_neighbors)}
    # Update the new node's neighbors
    new_node = %{new_node | neighbors: Map.put(new_node.neighbors, level, new_node_neighbors)}

    # Update the graph with the modified nodes
    graph = update_graph(graph, prev_node)
    graph = update_graph(graph, new_node)
    graph
  end

  @doc """
  Returns the keys of nodes at a given level, ordered by their position in the graph.
  """
  @spec graph_structure(t(), non_neg_integer()) :: [term()]
  def graph_structure(graph, level) do
    neighbors = Map.get(graph.head.neighbors, level, [])

    case neighbors do
      [] -> []
      [{first_node, _} | _] -> traverse_level(first_node, level, [])
    end
  end

  # Helper function to traverse the graph at a specific level
  defp traverse_level(node, level, acc) do
    # Add the current node's key to the accumulator
    acc = [node.key | acc]

    # Get the neighbors at the current level
    neighbors = Map.get(node.neighbors, level, [])

    case neighbors do
      [] ->
        Enum.reverse(acc)

      [{next_node, _} | _] ->
        traverse_level(next_node, level, acc)
    end
  end

  @doc """
  Removes a node from the skip-graph, updating neighbor links.
  - Uses weight_fn (if provided) to recalculate edge weights for affected neighbors.
  """
  @spec delete(t(), term(), (term(), term() -> number())) :: t()
  def delete(graph, key, weight_fn \\ fn _a, _b -> 1 end) do
    case find_node(graph, key) do
      nil -> graph
      node -> delete_node(graph, node, weight_fn)
    end
  end

  defp find_node(graph, key) do
    neighbors = graph.head.neighbors[0] || []

    Enum.find(neighbors, fn {node, _} -> node.key == key end)
    |> case do
      nil -> nil
      {node, _} -> node
    end
  end

  defp delete_node(graph, node, weight_fn) do
    Enum.reduce(0..node.level, graph, fn level, acc ->
      update_neighbors_after_delete(acc, node, level, weight_fn)
    end)
    |> then(fn g -> %{g | size: g.size - 1} end)
  end

  defp update_neighbors_after_delete(graph, node, level, weight_fn) do
    prev_node = find_previous_node(graph, node, level)
    next_nodes = Enum.reject(prev_node.neighbors[level] || [], fn {n, _} -> n.key == node.key end)

    # Update the weights of the remaining neighbors using the weight_fn
    updated_next_nodes =
      Enum.map(next_nodes, fn {n, _} ->
        {n, weight_fn.(prev_node.key, n.key)}
      end)

    # Update the previous node's neighbors
    prev_node = %{prev_node | neighbors: Map.put(prev_node.neighbors, level, updated_next_nodes)}
    update_graph(graph, prev_node)
  end

  defp find_previous_node(graph, node, level) do
    neighbors = graph.head.neighbors[level] || []

    Enum.reduce(neighbors, graph.head, fn {n, _}, acc ->
      if n.key < node.key do
        n
      else
        acc
      end
    end)
  end

  @doc """
  Generates a random level for a new node, following a power-law distribution.
  """
  @spec biased_random_level(non_neg_integer()) :: non_neg_integer()
  def biased_random_level(max_level, level \\ 0) do
    if :rand.uniform() < 0.5 and level < max_level do
      biased_random_level(max_level, level + 1)
    else
      level
    end
  end

  defp update_graph(graph, updated_node) do
    # Update the head node if the updated node is the head
    if graph.head.key == updated_node.key do
      %{graph | head: updated_node}
    else
      # Otherwise, update the head's neighbors to reflect the updated node
      %{graph | head: update_node(graph.head, updated_node)}
    end
  end

  defp update_node(head, updated_node) do
    # Recursively update the head's neighbors to replace the old node with the updated node
    updated_neighbors =
      Enum.reduce(head.neighbors, %{}, fn {level, neighbors}, acc ->
        updated_level_neighbors =
          Enum.map(neighbors, fn {node, weight} ->
            if node.key == updated_node.key do
              {updated_node, weight}
            else
              {node, weight}
            end
          end)

        Map.put(acc, level, updated_level_neighbors)
      end)

    %{head | neighbors: updated_neighbors}
  end
end
