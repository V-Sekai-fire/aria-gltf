# AriaEwbik

Entirely Wahba's-problem Based Inverse Kinematics (EWBIK) solver for advanced character animation.

## Overview

AriaEwbik provides sophisticated multi-effector inverse kinematics solving with comprehensive constraint management, collision detection, and anti-uncanny valley features. Built on production-ready mathematical foundations from the Aria umbrella project.

**Current Status**: Phase 1.5 - External API Implementation (Critical Priority)
- ✅ Internal modules complete with 37 tests passing
- ✅ EWBIK decomposition algorithm implemented
- ❌ External API delegation missing (blocking issue)
- 🔄 MultiIK design strategy documented and ready for implementation

## Features

### Core EWBIK Capabilities

- **Multi-Effector IK Solving**: Coordinate multiple effectors simultaneously with priority weighting
- **Skeleton Segmentation**: Intelligent bone chain analysis and processing order determination
- **Motion Propagation**: Hierarchical effector influence calculation and weight distribution
- **Iterative Solving**: Convergence-based solving with performance budget management

### Advanced Constraint Systems

- **Kusudama Constraints**: Cone-based joint orientation limits with continuous boundary handling
- **VRM1 Collision Detection**: Sphere, capsule, and plane collider support following VRM 1.0 specification
- **Anatomical Constraints**: Godot SkeletonProfileHumanoid integration for realistic joint limits
- **Twist Limits**: Joint rotation constraints with nearest valid orientation calculation

### Anti-Uncanny Valley Features

- **VRM1 Self-Collision Prevention**: Comprehensive body part intersection avoidance
- **Anatomical Limit Enforcement**: Human-realistic joint movement constraints
- **Temporal Smoothing**: Frame-to-frame solution stability with previous pose bias
- **Motion Quality Validation**: RMSD-based solution scoring with constraint penalty terms

### Mathematical Foundation

- **AriaJoint Integration**: Production-ready joint hierarchy management (48/48 tests passing)
- **AriaQCP Algorithm**: Quaternion Characteristic Polynomial solver (69/69 tests passing)
- **AriaMath Operations**: IEEE-754 compliant mathematical primitives
- **Coordinate Conversions**: Godot ↔ glTF coordinate system transformations

## Architecture

```
AriaEwbik (External API)
├── Segmentation    # Skeleton analysis using AriaJoint
├── Solver          # Core EWBIK algorithm with AriaQCP
├── Kusudama        # Constraint cone management
├── Propagation     # Motion influence calculation
├── VRM1Colliders   # VRM1 collision detection
├── VRM1CollisionSolver # Collision-aware IK solving
├── GodotSkeletonProfile # Anatomical constraints
├── CoordinateConversion # Godot ↔ glTF transforms
└── ConstraintVisualization # Visual debugging
```

## Dependencies

- **aria_joint**: Joint hierarchy management and transform operations
- **aria_qcp**: Quaternion Characteristic Polynomial (Wahba's problem solver)
- **aria_math**: IEEE-754 compliant mathematical primitives
- **aria_state**: Configuration storage for VRM1 and constraint parameters

## Usage

### Basic IK Solving

```elixir
# Single effector target
{:ok, solved_skeleton} = AriaEwbik.solve_ik(skeleton, effector_targets)

# Multi-effector coordination
targets = [
  {left_hand_joint, target_position_1},
  {right_hand_joint, target_position_2}
]
{:ok, solved_skeleton} = AriaEwbik.solve_multi_effector(skeleton, targets)
```

### Advanced Constraint Integration

```elixir
# With VRM1 collision avoidance
{:ok, solved_skeleton} = AriaEwbik.solve_with_collision_avoidance(
  skeleton,
  targets,
  vrm1_colliders
)

# With anatomical constraints
{:ok, solved_skeleton} = AriaEwbik.apply_godot_anatomical_limits(skeleton)

# With Kusudama constraints
kusudama_cones = [
  %{joint: shoulder_joint, cones: [cone1, cone2]},
  %{joint: elbow_joint, cones: [elbow_cone]}
]
{:ok, constrained_skeleton} = AriaEwbik.create_kusudama_constraint(skeleton, kusudama_cones)
```

### Skeleton Analysis

```elixir
# Analyze skeleton structure
analysis = AriaEwbik.analyze_skeleton(joints)

# Segment bone chains for processing
segments = AriaEwbik.segment_chains(skeleton, effector_list)
```

## Performance Characteristics

- **Multi-effector solving**: Optimized for real-time character animation
- **Joint hierarchy**: Leverages AriaJoint's 160K+ poses/second capability
- **Collision detection**: Efficient VRM1 collider validation
- **Constraint evaluation**: Fast Kusudama cone validation with O(c×j) complexity
- **Memory efficiency**: Registry-based joint state management

## MultiIK Design Strategy

AriaEwbik implements a sophisticated MultiIK (Multi-Effector Inverse Kinematics) approach based on insights from the Godot ManyBoneIK3D implementation:

### Core Design Principles

- **Single Root, Multiple End Effectors**: One skeleton root with multiple target points
- **Automatic Junction Detection**: System identifies branch points in skeleton hierarchy
- **Effector List Splitting**: Chain segmentation at each junction for optimal processing
- **Pole Target Support**: Twist and swing control for natural pose orientation

### Implementation Architecture

```elixir
# ChainIK → ManyBoneIK → BranchIK progression
defmodule AriaEwbik.MultiEffectorSolver do
  def solve_chain_ik(skeleton, single_chain) do
    # Simple chain solving (no branching)
  end

  def solve_many_bone_ik(skeleton, effector_targets) do
    # Complex multi-effector solving with decomposition
  end

  def solve_branch_ik(skeleton, effector_targets, branch_points) do
    # Extended solving for branched skeletons
  end
end
```

### Key Features

- **Decomposition Algorithm**: Eron Gjoni's approach for multi-effector coordination
- **Priority Weighting**: Effector opacity and influence control
- **Real-time Performance**: Optimized for 30+ FPS character animation
- **Complex Rigs**: Support for 100+ joint skeletons

## Development Status

This app is currently under development as part of the comprehensive EWBIK implementation plan.

- **Phase 1**: ✅ Internal modules complete (Segmentation, Solver, Kusudama, Propagation)
- **Phase 1.5**: 🔄 External API implementation (Critical Priority - IN PROGRESS)
- **MultiIK Strategy**: ✅ Documented and ready for implementation

See `todo.md` for detailed implementation progress and roadmap.
See `thirdparty/many_bone_ik/task_with_context.md` for comprehensive MultiIK design strategy.

## Standards Compliance

- **glTF 2.0**: Full compliance for 3D asset interoperability
- **IEEE-754**: Numerical precision and stability requirements
- **VRM 1.0**: Avatar collision detection and constraint specifications
- **Godot Integration**: SkeletonProfileHumanoid anatomical constraint compatibility

## License

MIT License - Copyright (c) 2025-present K. S. Ernest (iFire) Lee

## Attribution

- Many Bone IK implementation ported with attribution to original authors
- Godot Engine reference implementations used under MIT license
- VRM specification implementation follows VRM Consortium guidelines
- Mathematical algorithms implement published academic methods with proper attribution
