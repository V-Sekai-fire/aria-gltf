# ARIA glTF

glTF 2.0 processing library with joint hierarchy management and inverse kinematics.

## Structure

This is an umbrella project containing:

- **aria_gltf**: Core glTF 2.0 parsing, validation, and processing
- **aria_joint**: Transform hierarchy management for joints/bones
- **aria_ewbik**: Entirely Wahba's-problem Based Inverse Kinematics solver

## Dependencies

- `aria_math`: From GitHub (https://github.com/V-Sekai-fire/aria-math.git)

## Setup

```bash
mix deps.get
mix compile
```

## Testing

```bash
mix test
```
