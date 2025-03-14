defmodule SkipGraph.Node do
  @moduledoc """
  A node in the SkipGraph.

  `key`   - unique identifier
  `value` - associated data
  `level` - how tall this node is in skip list terms
  `neighbors` - map from level -> list of {node, weight}
  """

  defstruct key: nil,
            value: nil,
            level: 0,
            neighbors: %{}

  @type t :: %__MODULE__{
          key: term(),
          value: term(),
          level: non_neg_integer(),
          neighbors: %{non_neg_integer() => [{t(), number()}]}
        }

  def new(key, value, level) do
    # Initialize neighbors with empty lists at each level
    neighs = for l <- 0..level, into: %{}, do: {l, []}
    %__MODULE__{key: key, value: value, level: level, neighbors: neighs}
  end
end
