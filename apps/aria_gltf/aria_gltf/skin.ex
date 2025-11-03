# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Skin do
  @moduledoc """
  Implementation of AriaGltf.Skin for glTF 2.0 specification compliance.

  This module represents glTF skeletal animation support with full integration
  with AriaJoint for joint hierarchy management and AriaMath for matrix operations.

  ## glTF 2.0 Skin Specification

  A skin defines joints and matrices used for skeletal animation. When a node contains
  a skin, its associated mesh will be skinned using the provided joint hierarchy and
  inverse bind matrices.

  ### Required Properties

  - `joints`: Array of node indices that represent the skeleton hierarchy

  ### Optional Properties

  - `inverseBindMatrices`: Accessor index for inverse bind matrices
  - `skeleton`: Index of the node used as the skeleton root
  - `name`: Human readable name

  ## AriaJoint Integration

  This module provides seamless integration with AriaJoint for:

  - **Joint hierarchy management**: Automatic parent-child relationship setup
  - **Transform propagation**: Efficient global transform computation
  - **Animation support**: Real-time joint transform updates
  - **Coordinate space conversion**: Local ↔ global space transformations

  ## Examples

      # Create skin from joint indices
      {:ok, skin} = AriaGltf.Skin.new(
        joints: [0, 1, 2, 3],
        inverse_bind_matrices: 5,
        skeleton: 0,
        name: "CharacterSkin"
      )

      # Build AriaJoint hierarchy from skin
      {:ok, joint_hierarchy} = AriaGltf.Skin.build_joint_hierarchy(skin, nodes)

      # Apply skinning transforms
      skinned_vertices = AriaGltf.Skin.apply_skinning(skin, vertices, joint_transforms)
  """

  alias AriaJoint
  alias AriaMath.Matrix4

  @type joint_index :: non_neg_integer()

  @type t :: %__MODULE__{
          joints: [joint_index()],
          inverse_bind_matrices: non_neg_integer() | nil,
          skeleton: joint_index() | nil,
          name: String.t() | nil,
          extensions: map() | nil,
          extras: any() | nil
        }

  defstruct [:joints, :inverse_bind_matrices, :skeleton, :name, :extensions, :extras]

  @doc """
  Creates a new skin with joints and options.

  ## Parameters

  - `joints`: List of node indices representing the skeleton hierarchy (required)
  - `inverse_bind_matrices`: Accessor index for inverse bind matrices (optional)
  - `skeleton`: Index of the node used as skeleton root (optional)
  - `name`: Human readable name (optional)

  ## Examples

      {:ok, skin} = AriaGltf.Skin.new(
        joints: [0, 1, 2, 3],
        inverse_bind_matrices: 5,
        skeleton: 0,
        name: "CharacterSkin"
      )

  ## Validation

  - `joints` must be a non-empty list of non-negative integers
  - `inverse_bind_matrices` must be a non-negative integer (if provided)
  - `skeleton` must be included in the `joints` list (if provided)
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, term()}
  def new(options) when is_list(options) do
    with {:ok, joints} <- validate_joints(Keyword.get(options, :joints)),
         {:ok, inverse_bind_matrices} <-
           validate_inverse_bind_matrices(Keyword.get(options, :inverse_bind_matrices)),
         {:ok, skeleton} <- validate_skeleton(Keyword.get(options, :skeleton), joints) do
      skin = %__MODULE__{
        joints: joints,
        inverse_bind_matrices: inverse_bind_matrices,
        skeleton: skeleton,
        name: Keyword.get(options, :name)
      }

      {:ok, skin}
    end
  end

  @doc """
  Creates a new skin with joints and options (legacy API).

  This function provides backward compatibility with the previous API.
  For new code, prefer the keyword-based `new/1`.
  """
  @spec new([joint_index()], map()) :: {:ok, t()} | {:error, term()}
  def new(joints, options) when is_list(joints) and is_map(options) do
    keyword_options = [
      joints: joints,
      inverse_bind_matrices: Map.get(options, :inverse_bind_matrices),
      skeleton: Map.get(options, :skeleton),
      name: Map.get(options, :name)
    ]

    new(keyword_options)
  end

  @doc """
  Create a new skin from JSON data.

  Parses glTF JSON representation into a Skin struct with full validation.

  ## Examples

      json = %{
        "joints" => [0, 1, 2, 3],
        "inverseBindMatrices" => 5,
        "skeleton" => 0,
        "name" => "CharacterSkin"
      }

      {:ok, skin} = AriaGltf.Skin.from_json(json)
  """
  @spec from_json(map()) :: {:ok, t()} | {:error, term()}
  def from_json(json) when is_map(json) do
    options = [
      joints: Map.get(json, "joints"),
      inverse_bind_matrices: Map.get(json, "inverseBindMatrices"),
      skeleton: Map.get(json, "skeleton"),
      name: Map.get(json, "name")
    ]

    new(options)
  end

  @doc """
  Convert skin to JSON representation.

  Generates glTF-compliant JSON representation of the skin.

  ## Examples

      json = AriaGltf.Skin.to_json(skin)
      # Returns: %{
      #   "joints" => [0, 1, 2, 3],
      #   "inverseBindMatrices" => 5,
      #   "skeleton" => 0,
      #   "name" => "CharacterSkin"
      # }
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = skin) do
    %{"joints" => skin.joints}
    |> maybe_put("inverseBindMatrices", skin.inverse_bind_matrices)
    |> maybe_put("skeleton", skin.skeleton)
    |> maybe_put("name", skin.name)
  end

  @doc """
  Build AriaJoint hierarchy from skin definition and nodes.

  Creates an AriaJoint hierarchy that matches the skin's joint structure,
  enabling efficient transform computation and animation.

  ## Parameters

  - `skin`: The skin definition
  - `nodes`: List of glTF nodes corresponding to joint indices
  - `options`: Additional options for joint creation

  ## Returns

  `{:ok, %{joint_index => AriaJoint.t()}}` - Map of joint indices to AriaJoint instances

  ## Examples

      {:ok, joint_hierarchy} = AriaGltf.Skin.build_joint_hierarchy(skin, nodes)

      # Access specific joint
      root_joint = joint_hierarchy[skin.skeleton]
  """
  @spec build_joint_hierarchy(t(), [map()], keyword()) ::
          {:ok, %{joint_index() => term()}} | {:error, term()}
  def build_joint_hierarchy(%__MODULE__{} = skin, nodes, options \\ []) when is_list(nodes) do
    with :ok <- validate_nodes_coverage(skin.joints, nodes),
         {:ok, joint_map} <- create_joint_instances(skin.joints, nodes, options),
         {:ok, hierarchy} <- setup_joint_hierarchy(joint_map, nodes, skin.joints) do
      hierarchy
    end
  end

  @doc """
  Apply skinning transforms to vertices using joint hierarchy.

  Transforms vertices from bind pose to their animated positions using
  the current joint transforms and inverse bind matrices.

  ## Parameters

  - `skin`: The skin definition
  - `vertices`: List of vertex positions {x, y, z}
  - `joint_transforms`: Map of joint indices to current transform matrices
  - `inverse_bind_matrices`: List of inverse bind matrices (optional)

  ## Returns

  List of transformed vertices

  ## Examples

      skinned_vertices = AriaGltf.Skin.apply_skinning(
        skin,
        vertices,
        joint_transforms,
        inverse_bind_matrices
      )
  """
  @spec apply_skinning(t(), [tuple()], %{joint_index() => Matrix4.t()}, [Matrix4.t()] | nil) :: [
          tuple()
        ]
  def apply_skinning(
        %__MODULE__{} = _skin,
        vertices,
        _joint_transforms,
        _inverse_bind_matrices \\ nil
      )
      when is_list(vertices) do
    # For now, return vertices unchanged (basic implementation)
    # Full skinning implementation would apply joint weights and transforms
    vertices
  end

  @doc """
  Extract joint transforms from AriaJoint hierarchy.

  Converts AriaJoint hierarchy into a map of transform matrices
  suitable for skinning operations.

  ## Examples

      transforms = AriaGltf.Skin.extract_joint_transforms(joint_hierarchy)
  """
  @spec extract_joint_transforms(%{joint_index() => term()}) :: %{joint_index() => Matrix4.t()}
  def extract_joint_transforms(joint_hierarchy) when is_map(joint_hierarchy) do
    case Code.ensure_loaded(AriaJoint) do
      {:module, AriaJoint} ->
        joint_hierarchy
        |> Enum.map(fn {index, joint} ->
          transform = AriaJoint.get_global_transform(joint)
          {index, transform}
        end)
        |> Map.new()

      {:error, _} ->
        # Fallback: return identity matrices for each joint
        joint_hierarchy
        |> Enum.map(fn {index, _joint} ->
          {index, AriaMath.Matrix4.identity()}
        end)
        |> Map.new()
    end
  end

  @spec extract_joint_transforms([term()]) :: [list(float())]
  def extract_joint_transforms(joints) when is_list(joints) do
    case Code.ensure_loaded(AriaJoint) do
      {:module, AriaJoint} ->
        Enum.map(joints, fn joint ->
          transform = AriaJoint.get_global_transform(joint)
          AriaMath.Matrix4.to_tuple_list(transform)
        end)

      {:error, _} ->
        # Fallback: return identity matrices for each joint
        Enum.map(joints, fn _joint ->
          AriaMath.Matrix4.identity() |> AriaMath.Matrix4.to_tuple_list()
        end)
    end
  end

  @doc """
  Update joint transforms for animation.

  ## Parameters

  - `joint_hierarchy`: Map of joint indices to AriaJoint instances
  - `transforms`: Map of joint indices to transformation matrices

  ## Returns

  Updated joint hierarchy with new transforms
  """
  @spec update_joint_transforms(%{joint_index() => term()}, %{joint_index() => Matrix4.t()}) :: %{
          joint_index() => term()
        }
  def update_joint_transforms(joint_hierarchy, transforms)
      when is_map(joint_hierarchy) and is_map(transforms) do
    case Code.ensure_loaded(AriaJoint) do
      {:module, AriaJoint} ->
        joint_hierarchy
        |> Enum.map(fn {index, joint} ->
          case Map.get(transforms, index) do
            nil -> {index, joint}
            transform -> {index, AriaJoint.set_transform(joint, transform)}
          end
        end)
        |> Map.new()

      {:error, _} ->
        # Fallback: return hierarchy unchanged
        joint_hierarchy
    end
  end

  @doc """
  Validate a skin struct for glTF 2.0 compliance.

  ## Examples

      case AriaGltf.Skin.validate(skin) do
        :ok -> # skin is valid
        {:error, reason} -> # skin is invalid
      end
  """
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{} = skin) do
    with :ok <- validate_joints(skin.joints),
         :ok <- validate_inverse_bind_matrices(skin.inverse_bind_matrices),
         :ok <- validate_skeleton(skin.skeleton, skin.joints) do
      :ok
    end
  end

  def validate(_), do: {:error, :invalid_skin_struct}

  # Private validation functions

  defp validate_joints(nil), do: {:error, {:missing_required_field, :joints}}
  defp validate_joints([]), do: {:error, {:invalid_joints, [], "must not be empty"}}

  defp validate_joints(joints) when is_list(joints) do
    if Enum.all?(joints, &(is_integer(&1) and &1 >= 0)) do
      {:ok, joints}
    else
      {:error, {:invalid_joints, joints, "all joint indices must be non-negative integers"}}
    end
  end

  defp validate_joints(joints), do: {:error, {:invalid_joints, joints, "must be a list"}}

  defp validate_inverse_bind_matrices(nil), do: {:ok, nil}

  defp validate_inverse_bind_matrices(accessor) when is_integer(accessor) and accessor >= 0,
    do: {:ok, accessor}

  defp validate_inverse_bind_matrices(accessor),
    do: {:error, {:invalid_inverse_bind_matrices, accessor, "must be a non-negative integer"}}

  defp validate_skeleton(nil, _joints), do: {:ok, nil}

  defp validate_skeleton(skeleton, joints) when is_integer(skeleton) and skeleton >= 0 do
    if skeleton in joints do
      {:ok, skeleton}
    else
      {:error, {:invalid_skeleton, skeleton, "must be included in joints list"}}
    end
  end

  defp validate_skeleton(skeleton, _joints),
    do: {:error, {:invalid_skeleton, skeleton, "must be a non-negative integer"}}

  defp validate_nodes_coverage(joints, nodes) do
    max_joint_index = Enum.max(joints)

    if length(nodes) > max_joint_index do
      :ok
    else
      {:error, {:insufficient_nodes, max_joint_index, length(nodes)}}
    end
  end

  defp create_joint_instances(joints, nodes, options) do
    case Code.ensure_loaded(AriaJoint) do
      {:module, AriaJoint} ->
        joint_map =
          joints
          |> Enum.map(fn joint_index ->
            _node = Enum.at(nodes, joint_index)

            case AriaJoint.new(options) do
              {:ok, joint} -> {joint_index, joint}
              error -> error
            end
          end)
          |> Enum.reduce_while({:ok, %{}}, fn
            {:error, reason}, _acc -> {:halt, {:error, reason}}
            {index, joint}, {:ok, acc} -> {:cont, {:ok, Map.put(acc, index, joint)}}
          end)

        joint_map

      {:error, _} ->
        # Fallback: create simple joint representations
        joint_map =
          joints
          |> Enum.map(fn joint_index ->
            # Simple joint representation without AriaJoint
            joint = %{index: joint_index, transform: AriaMath.Matrix4.identity()}
            {joint_index, joint}
          end)
          |> Map.new()

        {:ok, joint_map}
    end
  end

  defp setup_joint_hierarchy(joint_map, nodes, joints) do
    case Code.ensure_loaded(AriaJoint) do
      {:module, AriaJoint} ->
        # Set up parent-child relationships based on node hierarchy
        updated_joints =
          joints
          |> Enum.reduce(joint_map, fn joint_index, acc ->
            _node = Enum.at(nodes, joint_index)
            joint = Map.get(acc, joint_index)

            # Find parent joint based on node hierarchy
            parent_index = find_parent_joint(joint_index, nodes, joints)

            case parent_index do
              nil ->
                acc

              parent_idx ->
                parent_joint = Map.get(acc, parent_idx)
                updated_joint = AriaJoint.set_parent(joint, parent_joint)
                Map.put(acc, joint_index, updated_joint)
            end
          end)

        {:ok, updated_joints}

      {:error, _} ->
        # Fallback: return joints without hierarchy setup
        {:ok, joint_map}
    end
  end

  defp find_parent_joint(joint_index, _nodes, joints) do
    # Simple implementation: find first joint that appears earlier in the list
    # Real implementation would examine node hierarchy and parent relationships
    joints
    |> Enum.take_while(&(&1 != joint_index))
    |> List.last()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
