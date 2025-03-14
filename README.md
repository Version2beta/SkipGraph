# SkipGraph: A General-Purpose Probabilistic Index

## Overview

`SkipGraph` is a **probabilistic multi-level linked structure** designed for **fast approximate nearest neighbor (ANN) search**, **efficient hierarchical indexing**, and **distributed key-value lookups**. It provides **logarithmic search complexity** while supporting **dynamic insertions and deletions**.

This library is **standalone** and can be used for:

- **Efficient search indexing** (e.g., key-value storage, tensor reference storage, routing tables, distributed systems).
- **Clustered data retrieval** (multi-level nearest neighbor lookups).
- **Ordered key-value storage with fast range queries**.

---

## **Key Features**

- **Multi-Level Indexing:** Supports **logarithmic O(log N) lookups**.
- **Flexible Data Storage:** Stores **keys (references) and values** for efficiency.
- **Custom Weight Calculation:** Allows developers to **provide weight functions for insertion and deletion**.
- **General-Purpose API:** Works for **tensor indexing, key-value storage, and hierarchical search**.
- **Efficient Key-Value Lookups:** Supports **range queries and ordered traversal**.
- **Custom Comparison Functions:** Allows developers to provide **custom ranking or similarity functions** for node selection.
- **Supports Classic Skip-Graph Behavior:** If all edge weights are equal and default comparison is used, the structure behaves as a standard ordered Skip-Graph.

---

## Installation

When available in Hex (TO-DO: [publish in Hex](https://hex.pm/docs/publish)), the package can be installed
by adding `skip_graph` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:skip_graph, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/skip_graph>.

---

## **Core Data Structures**

### **1️⃣ SkipGraph Node**

Each node represents a **reference (key) to data**, supporting fast hierarchical search.

```elixir
@type node() :: %{
  key: term(), # Unique identifier (tensor key, key-value reference, etc.)
  value: term(), # Metadata, centroid, or reference
  level: non_neg_integer(),
  neighbors: %{level => [{node(), term()}]} # Term allows flexible weighting
}
```

- **`key`** → The unique identifier (e.g., tensor key, generic key reference).
- **`value`** → Metadata, centroid, or storage reference.
- **`level`** → The height of the node in the skip-graph.
- **`neighbors`** → Pointers to nodes at each level for fast traversal.

### **2️⃣ SkipGraph Structure**

```elixir
@type skip_graph() :: %{
  head: node(),
  max_level: non_neg_integer(),
  size: non_neg_integer()
}
```

- **`head`** → Points to the top-most node.
- **`max_level`** → Controls the maximum depth of the skip-graph.
- **`size`** → Tracks the total number of elements in the structure.

---

## **API Design**

### **1️⃣ Creating & Managing the Skip-Graph**

#### `new/1`

```elixir
@doc """
Creates a new skip-graph with a given max depth.
"""
def new(max_level), do: ...
```

#### `insert/4`

```elixir
@doc """
Inserts a node (e.g., key-value pair) into the skip-graph.
- Randomly determines the level of the node.
- Updates neighbor links.
- Uses `weight_fn` (if provided) to determine edge weights.
"""
def insert(graph, key, value, weight_fn \ fn _a, _b -> 1 end), do: ...
```

#### `delete/3`

```elixir
@doc """
Removes a node from the skip-graph, updating neighbor links.
- Uses `weight_fn` (if provided) to recalculate edge weights for affected neighbors.
"""
def delete(graph, key, weight_fn \ fn _a, _b -> 1 end), do: ...
```

---

### **2️⃣ Searching the Skip-Graph**

#### `search/3`

```elixir
@doc """
Finds the `k` closest nodes for a given key using weighted traversal.
- Uses `compare_fn` (if provided) to rank results.
- Defaults to classic Skip-Graph behavior if weights are equal.
"""
def search(graph, query_key, k, compare_fn \ &default_key_compare/2) do
  graph
  |> traverse(query_key, compare_fn)
  |> Enum.take(k)
end
```

#### `value_search/3`

```elixir
@doc """
Finds the highest-ranked `k` values using a custom comparison function.
If no function is provided:
- Returns `k` exact matches.
- If `k` is `0`, returns **all matches**.
"""
def value_search(graph, query_value, k \ 1, compare_fn \ &default_value_compare/2) do
  graph
  |> traverse(query_value, compare_fn)
  |> Enum.take(if k == 0, do: :infinity, else: k)
end
```

---

### **3️⃣ Optimizations & Adjustments**

#### `adjust_depth/2`

```elixir
@doc """
Dynamically adjusts the depth of the skip-graph based on the number of elements.
"""
def adjust_depth(graph, size), do: ...
```

#### `rebalance/1`

```elixir
@doc """
Rebalances the skip-graph to optimize search efficiency.
"""
def rebalance(graph), do: ...
```

---

## **Some Use Cases**

### **1️⃣ Approximate Nearest Neighbor (ANN) Tensor Search**

- Store tensor embeddings or compressed representations as values while indexing tensor keys.
- Use the skip-graph for fast nearest neighbor lookups by leveraging weighted edges based on similarity scores.
- Multi-level search optimization enables efficient routing to relevant tensor groups before fine-grained ANN refinement.

### **2️⃣ Distributed Routing (Overlay Networks)**

- Efficient key-based routing in **peer-to-peer (P2P) networks**.
- Fast distributed table lookups with **O(log N) complexity**.

### **3️⃣ General Purpose Key-Value Indexing**

- Ordered indexing with **fast range queries**.
- Adaptive depth balancing for **growing datasets**.

---
