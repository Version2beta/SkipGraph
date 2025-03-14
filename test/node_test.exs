defmodule SkipGraph.NodeTest do
  use ExUnit.Case
  alias SkipGraph.Node

  describe "Node.new/3" do
    test "creates a node with given key, value, and level" do
      node = Node.new(:test_key, "test_value", 3)

      assert node.key == :test_key
      assert node.value == "test_value"
      assert node.level == 3
      # Levels 0 to 3
      assert length(Map.keys(node.neighbors)) == 4
    end
  end
end
