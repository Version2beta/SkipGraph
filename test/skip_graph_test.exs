defmodule SkipGraphTest do
  use ExUnit.Case
  alias SkipGraph

  describe "SkipGraph.new/1" do
    test "creates a new skip-graph with the correct max level" do
      graph = SkipGraph.new(5)

      assert %SkipGraph{max_level: 5, size: 0} = graph
      assert graph.head.key == :head
      assert graph.head.level == 5
    end
  end

  describe "SkipGraph.insert/4" do
    test "inserts a single node correctly" do
      graph = SkipGraph.new(5)
      updated_graph = SkipGraph.insert(graph, :a, "value_a")

      assert updated_graph.size == 1
      assert updated_graph.head != nil

      # Ensure the head node has the correct neighbors
      neighbors = Map.get(updated_graph.head.neighbors, 0, [])
      assert Enum.map(neighbors, fn {n, _} -> n.key end) == [:a]

      # Ensure the new node has the correct neighbors
      new_node = Enum.at(neighbors, 0) |> elem(0)
      assert new_node.key == :a
      assert new_node.value == "value_a"
      assert Map.get(new_node.neighbors, 0, []) == [{updated_graph.head, 1}]
    end

    test "inserts multiple nodes in the correct order" do
      graph = SkipGraph.new(5)

      graph = SkipGraph.insert(graph, :b, "value_b")
      graph = SkipGraph.insert(graph, :a, "value_a")
      graph = SkipGraph.insert(graph, :c, "value_c")

      # Ensure correct insertion order
      neighbors = Map.get(graph.head.neighbors, 0, [])
      assert Enum.map(neighbors, fn {n, _} -> n.key end) == [:a, :b, :c]

      # Ensure each node has the correct neighbors
      assert Enum.all?(neighbors, fn {n, _} ->
               case n.key do
                 :a -> Map.get(n.neighbors, 0, []) == [{graph.head, 1}]
                 :b -> Map.get(n.neighbors, 0, []) == [{graph.head, 1}]
                 :c -> Map.get(n.neighbors, 0, []) == [{graph.head, 1}]
                 _ -> false
               end
             end)
    end
  end

  describe "SkipGraph.delete/3" do
    test "deletes an existing node and updates neighbors" do
      graph = SkipGraph.new(5)

      graph = SkipGraph.insert(graph, :a, "value_a")
      graph = SkipGraph.insert(graph, :b, "value_b")
      graph = SkipGraph.insert(graph, :c, "value_c")

      # Ensure the graph has 3 nodes before deletion
      assert count_nodes(graph) == 3

      updated_graph = SkipGraph.delete(graph, :b)

      # Ensure size is reduced
      assert updated_graph.size == 2

      # Ensure :b is no longer present
      neighbors = Map.get(updated_graph.head.neighbors, 0, [])
      assert Enum.map(neighbors, fn {n, _} -> n.key end) == [:a, :c]

      # Ensure the graph has 2 nodes after deletion
      assert count_nodes(updated_graph) == 2

      # Ensure :b is not in any node's neighbors
      assert Enum.all?(updated_graph.head.neighbors[0], fn {n, _} -> n.key != :b end)
    end

    test "deleting a non-existent node does not modify the graph" do
      graph = SkipGraph.new(5)

      graph = SkipGraph.insert(graph, :a, "value_a")
      graph = SkipGraph.insert(graph, :b, "value_b")

      unchanged_graph = SkipGraph.delete(graph, :z)

      assert unchanged_graph.size == 2
    end
  end

  test "generates levels following a power-law distribution" do
    max_level = 5
    results = Enum.map(1..10_000, fn _ -> apply(SkipGraph, :biased_random_level, [max_level]) end)

    counts = Enum.frequencies(results)

    assert counts[0] > counts[1]
    assert counts[1] > counts[2]
    assert counts[2] > counts[3]
  end

  # Helper function to count the number of nodes in the graph
  defp count_nodes(graph) do
    Enum.reduce(graph.head.neighbors[0], 0, fn {_, _}, acc -> acc + 1 end)
  end

  defp create_test_graph do
    %SkipGraph{
      head: %SkipGraph.Node{
        key: :head,
        value: nil,
        level: 2,
        neighbors: %{
          0 => [
            {%SkipGraph.Node{
               key: :a,
               value: "value_a",
               level: 1,
               neighbors: %{
                 0 => [
                   {%SkipGraph.Node{
                      key: :b,
                      value: "value_b",
                      level: 0,
                      neighbors: %{
                        0 => [
                          {%SkipGraph.Node{
                             key: :c,
                             value: "value_c",
                             level: 1,
                             neighbors: %{0 => []}
                           }, 1}
                        ]
                      }
                    }, 1}
                 ],
                 1 => [
                   {%SkipGraph.Node{
                      key: :c,
                      value: "value_c",
                      level: 1,
                      neighbors: %{0 => []}
                    }, 1}
                 ]
               }
             }, 1}
          ],
          1 => [
            {%SkipGraph.Node{
               key: :a,
               value: "value_a",
               level: 1,
               neighbors: %{
                 0 => [
                   {%SkipGraph.Node{
                      key: :b,
                      value: "value_b",
                      level: 0,
                      neighbors: %{
                        0 => [
                          {%SkipGraph.Node{
                             key: :c,
                             value: "value_c",
                             level: 1,
                             neighbors: %{0 => []}
                           }, 1}
                        ]
                      }
                    }, 1}
                 ],
                 1 => [
                   {%SkipGraph.Node{
                      key: :c,
                      value: "value_c",
                      level: 1,
                      neighbors: %{0 => []}
                    }, 1}
                 ]
               }
             }, 1}
          ],
          2 => []
        }
      },
      max_level: 2,
      size: 3
    }
  end

  describe "SkipGraph.graph_structure/2" do
    test "returns the correct structure at each level" do
      graph = create_test_graph()

      assert SkipGraph.graph_structure(graph, 2) == []
      assert SkipGraph.graph_structure(graph, 1) == [:a, :c]
      assert SkipGraph.graph_structure(graph, 0) == [:a, :b, :c]
    end
  end
end
