# ADR-072: Investigate Aria Joint Nested Set Optimization

**Status:** Active
**Date:** 2025-06-30
**Serial:** R25W0722F07

## Context

AriaJoint currently implements transform hierarchy management for EWBIK bone chains using a registry-based system with individual dirty state tracking per node. Godot PR #97538 introduces a significant performance optimization for skeleton bone pose calculation using nested set theory.

### Current AriaJoint Architecture

**Registry-based hierarchy:**

- Parent-child relationships managed through process registry
- Each joint maintains its own dirty flags (dirty_none, dirty_vectors, dirty_local, dirty_global)
- Transform propagation requires recursive traversal through registry lookups
- Global pose calculation involves walking up parent chain

**Performance characteristics:**

- Registry lookups for parent/child access: O(log n) per lookup
- Dirty propagation requires recursive traversal: O(depth) per change
- Global pose calculation: O(depth) per bone request
- Memory scattered across registry entries

### Godot's Nested Set Optimization

**Core innovation (PR #97538):**

- Represents bone hierarchy as nested set with contiguous array storage
- Each bone has `nested_set_offset` (position) and `nested_set_span` (subtree size)
- Dirty flags stored in single array indexed by `nested_set_offset`
- Subtree dirty marking: single array range operation

**Performance improvements observed:**

- `set_and_get_global_poses_forward`: 747.6ms → 27.8ms (26.9x speedup)
- `set_and_get_global_poses_reverse`: 788.4ms → 57.37ms (13.7x speedup)
- `set_and_get_some_global_poses`: 29.64ms → 15.22ms (1.9x speedup)

**Algorithm details:**

```cpp
// Nested set structure
struct Bone {
    int nested_set_offset;  // Position in hierarchy array
    int nested_set_span;    // Size of subtree (self + all descendants)
};

// Efficient subtree dirty marking
void make_subtree_dirty(int bone_idx) {
    int start = bones[bone_idx].nested_set_offset;
    int end = start + bones[bone_idx].nested_set_span;
    for (int i = start; i < end; i++) {
        bone_global_pose_dirty[i] = true;
    }
}
```

## Decision

Investigate implementing nested set hierarchy optimization in AriaJoint to improve performance for large bone chains and frequent transform updates.

## Implementation Plan

### Phase 1: Core Nested Set Structure (HIGH PRIORITY)

**File**: `apps/aria_joint/lib/aria_joint/nested_set.ex`

**Required:**

- [ ] Design nested set data structure for Elixir
- [ ] Implement `build_nested_set/1` from parent-child relationships
- [ ] Add `nested_set_offset` and `nested_set_span` to Joint struct
- [ ] Create `NestedSet.mark_subtree_dirty/3` for efficient propagation
- [ ] Implement `NestedSet.hierarchy_to_nested_set/1` conversion

**Implementation patterns needed:**

- [ ] Contiguous array-based dirty state tracking
- [ ] Efficient subtree operations using offset + span
- [ ] Conversion between registry format and nested set format

### Phase 2: Transform Calculation Optimization (HIGH PRIORITY)

**File**: `apps/aria_joint/lib/aria_joint/joint.ex`

**Missing/Required:**

- [ ] Replace recursive parent lookup with array-based calculation
- [ ] Implement efficient global pose computation using nested set order
- [ ] Add dirty state array management alongside existing per-node flags
- [ ] Optimize `get_global_transform/1` to use nested set traversal
- [ ] Update `set_transform/2` to use efficient subtree dirty marking

**Implementation patterns needed:**

- [ ] Array-based hierarchy traversal instead of registry lookups
- [ ] Batch global pose calculation for dirty bones
- [ ] Contiguous memory access patterns for cache efficiency

### Phase 3: Compatibility and Migration (MEDIUM PRIORITY)

**File**: `apps/aria_joint/lib/aria_joint/joint.ex`

**Required:**

- [ ] Maintain existing external API compatibility
- [ ] Add nested set rebuild on hierarchy changes
- [ ] Implement hybrid approach during migration period
- [ ] Update `set_parent/2` to trigger nested set reconstruction
- [ ] Add performance benchmarks comparing approaches

**Implementation strategy:**

- [ ] Gradual migration path from registry to nested set
- [ ] Performance comparison testing framework
- [ ] Backward compatibility shims during transition

### Phase 4: Advanced Optimizations (LOW PRIORITY)

**Required:**

- [ ] Memory layout optimization for cache efficiency
- [ ] SIMD-friendly array operations where applicable
- [ ] Lazy nested set reconstruction
- [ ] Thread-local storage for temporary calculation arrays

## Success Criteria

### Performance targets

- [ ] **10x improvement** in global pose calculation for deep hierarchies (>20 bones)
- [ ] **5x improvement** in transform propagation for large hierarchies (>100 bones)
- [ ] **50% reduction** in memory allocations during transform updates
- [ ] **No regression** in single bone operations

### Functional requirements

- [ ] All existing AriaJoint external API functions work unchanged
- [ ] Transform accuracy maintained (no precision loss)
- [ ] Parent-child relationships correctly preserved
- [ ] Dirty state propagation semantically equivalent

### Integration requirements

- [ ] Successful compilation of all dependent apps
- [ ] All existing tests pass without modification
- [ ] Performance benchmarks demonstrate expected improvements
- [ ] Memory usage remains reasonable for typical use cases

## Implementation Strategy

### Step 1: Research and Design

1. Study Godot's nested set implementation in detail
2. Design Elixir-native nested set data structures
3. Create performance benchmark baseline for current implementation
4. Define migration strategy and compatibility requirements

### Step 2: Core Implementation

1. Implement nested set construction from existing hierarchy
2. Add array-based dirty state tracking
3. Update transform calculation to use nested set traversal
4. Maintain dual compatibility during transition

### Step 3: Optimization and Testing

1. Implement efficient subtree dirty marking
2. Optimize memory layout and access patterns
3. Add comprehensive performance tests
4. Validate correctness against existing implementation

### Current Focus: Implementation Planning

**Rationale:** Based on investigation of Godot PR #97538, nested set optimization provides substantial performance improvements (10-25x) for bone hierarchy operations.

**Investigation Results:**

**Current AriaJoint Performance (Baseline):**

- Get Global Poses Forward (80 bones): ~1.24ms, 80,645 poses/sec
- Get Global Poses Reverse (80 bones): ~0.922ms, 108,459 poses/sec
- Set All Poses + Get Global (80 bones): ~1.415ms, 141,342 ops/sec
- Set Root + Get All Global (80 bones): ~0.752ms, 132,978 bones/sec
- Memory Pressure Test (80 bones, 50 iterations): 4,000 total ops

**Godot Nested Set Optimization Analysis:**

- Uses nested set model to represent hierarchy as contiguous array
- Each bone has `nested_set_offset` (position) and `nested_set_span` (subtree size)
- Dirty flags stored in single array, indexed by `nested_set_offset`
- Subtree dirty marking: O(span) vs O(depth) recursive traversal
- Performance improvements: 26x for forward operations, 13x for reverse operations

**Next steps:**

1. ✅ Analyze Godot's nested set algorithms and benchmarks
2. Design Elixir data structures for nested set representation
3. Implement core nested set construction and dirty tracking
4. Create optimized transform calculation using array traversal

## Technical Considerations

### Nested Set Theory Application

**Hierarchy representation:**

```
     A(0,7)
    /       \
   B(1,4)   E(5,2)
  /    \       \
 C(2,1) D(3,1)  F(6,1)
```

**Properties:**

- Node's descendants: `nested_set_offset < descendant_offset < nested_set_offset + nested_set_span`
- Subtree size: `nested_set_span` includes node and all descendants
- Parent detection: smallest enclosing span

**Elixir implementation considerations:**

- Use tuples or maps for nested set metadata
- Leverage Enum functions for efficient array operations
- Consider ETS tables for large hierarchy storage
- Process dictionary for thread-local temporary arrays

### Performance Analysis

**Current approach bottlenecks:**

- Registry lookup overhead: O(log n) per parent access
- Recursive dirty propagation: O(depth) per change
- Individual dirty state per node: scattered memory access
- Parent chain traversal for global poses: O(depth) per calculation

**Nested set advantages:**

- Contiguous array access: O(1) per element, cache-friendly
- Range operations for subtree marking: O(span) batch operation
- Depth-first traversal order: optimal for global pose calculation
- Predictable memory layout: better for performance optimization

## Related ADRs

- **ADR-041:** Apps todo file management - umbrella app structure requirements
- **ADR-042:** Systematic cross-app dependency migration - dependency management
- **ADR-017:** Targeted solutions over generalized systems - focused optimization approach

## Consequences

### Benefits

- **Dramatic performance improvement:** 10-25x speedup for transform-heavy workloads
- **Better cache efficiency:** Contiguous memory access patterns
- **Scalability:** Linear performance characteristics for large hierarchies
- **Memory efficiency:** Reduced allocation overhead during updates

### Risks

- **Implementation complexity:** Nested set maintenance adds algorithmic complexity
- **Migration effort:** Significant changes to core AriaJoint architecture
- **Memory overhead:** Additional metadata per bone (offset, span)
- **Debugging difficulty:** Array-based structure less intuitive than tree

### Migration considerations

- **Compatibility preservation:** External API must remain unchanged
- **Performance validation:** Comprehensive benchmarks required
- **Rollback strategy:** Ability to revert to registry-based approach
- **Documentation:** Clear explanation of nested set concepts for maintainers

This optimization represents a significant architectural improvement that could position AriaJoint as a high-performance bone hierarchy system suitable for real-time applications.
