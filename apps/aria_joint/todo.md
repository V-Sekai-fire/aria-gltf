Perfect! Let me create a detailed implementation plan for optimizing `aria_joint` with Nx integration.

## Implementation Plan: Nx-Powered Joint Optimization

### Phase 1: Foundation Setup (1-2 days)

**Add Nx Dependency**

```elixir
# In apps/aria_joint/mix.exs
{:nx, "~> 0.7"}
```

**Create Nx-based Matrix Module**

```elixir
# apps/aria_joint/lib/aria_joint/nx_matrix.ex
defmodule AriaJoint.NxMatrix do
  # Tensor-based 4x4 matrix operations
  # Batch processing capabilities
  # SIMD-optimized transforms
end
```

### Phase 2: Tensor-Based Hierarchy Storage (2-3 days)

**New Hierarchy Manager**

```elixir
defmodule AriaJoint.TensorHierarchy do
  # Store bone data as tensors instead of individual structs
  # Shape: {num_bones, 4, 4} for transforms
  # Shape: {num_bones} for parent indices
  # Shape: {num_bones} for dirty flags
end
```

**Key Data Structures:**

- `local_transforms`: `{N, 4, 4}` tensor of local transforms
- `global_transforms`: `{N, 4, 4}` tensor of computed globals
- `parent_indices`: `{N}` tensor mapping child→parent
- `dirty_mask`: `{N}` boolean tensor for dirty tracking

### Phase 3: Batch Transform Computation (2-3 days)

**Vectorized Global Transform Calculation**

```elixir
def compute_global_transforms(hierarchy) do
  # Use Nx.indexed_add and cumulative operations
  # Process entire chains in parallel
  # 10-20x faster than individual matrix mults
end
```

**Optimized Dirty Propagation**

```elixir
def propagate_dirty_flags(hierarchy, changed_indices) do
  # Vectorized flag propagation through hierarchy
  # Single tensor operation instead of recursive calls
end
```

### Phase 4: Registry Optimization (1-2 days)

**Hybrid Storage Strategy**

- Keep Nx tensors for bulk operations
- Maintain Registry for individual node access
- Batch sync between tensor and registry states

**Reduced Registry Pressure**

- Cache frequently accessed nodes
- Batch registry updates
- Lazy synchronization

### Phase 5: API Compatibility Layer (1-2 days)

**Maintain Existing API**

```elixir
# Existing Joint.set_transform/2 still works
# But internally uses tensor operations
# Automatic batching for multiple operations
```

**Performance Monitoring**

- Benchmark comparisons
- Memory usage tracking
- Automatic fallback for small hierarchies

## Expected Performance Improvements

### Small Hierarchies (< 20 bones)

- **Registry optimization**: 20-30% improvement
- **Reduced allocations**: 15-25% improvement

### Medium Hierarchies (20-100 bones)

- **Nx batch operations**: 2-3x improvement
- **Vectorized propagation**: 3-5x improvement

### Large Hierarchies (100+ bones)

- **SIMD acceleration**: 5-10x improvement
- **Memory locality**: 2-3x improvement
- **Combined effect**: 10-20x improvement

## Implementation Priority

1. **Start with Registry optimization** (immediate 20-30% gain)
2. **Add Nx for matrix operations** (2-5x gain for medium hierarchies)
3. **Full tensor hierarchy** (10-20x gain for large hierarchies)

## Risk Mitigation

- **Gradual migration**: Keep existing API working
- **Performance gates**: Only use Nx when beneficial
- **Fallback mechanisms**: Registry-only mode for debugging
- **Comprehensive testing**: Ensure numerical accuracy

Would you like me to start with Phase 1 (foundation setup) or would you prefer to focus on a specific optimization area first? I can also create the ADR to track this optimization work.
