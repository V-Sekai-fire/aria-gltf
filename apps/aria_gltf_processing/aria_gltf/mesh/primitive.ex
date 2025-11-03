# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Mesh.Primitive do
  @moduledoc """
  Geometry to be rendered with the given material.

  From glTF 2.0 specification section 5.24:
  Each primitive corresponds to one GPU draw call. Primitives specify one or more attributes,
  corresponding to the vertex attributes used in the draw calls.
  """

  @type mode :: 0 | 1 | 2 | 3 | 4 | 5 | 6
  @type attributes :: %{String.t() => non_neg_integer()}
  @type targets :: [%{String.t() => non_neg_integer()}]

  @type t :: %__MODULE__{
          attributes: attributes(),
          indices: non_neg_integer() | nil,
          material: non_neg_integer() | nil,
          mode: mode(),
          targets: targets() | nil,
          extensions: map() | nil,
          extras: any() | nil
        }

  @enforce_keys [:attributes]
  defstruct [
    :attributes,
    :indices,
    :material,
    :mode,
    :targets,
    :extensions,
    :extras
  ]

  # Topology mode constants
  @points 0
  @lines 1
  @line_loop 2
  @line_strip 3
  @triangles 4
  @triangle_strip 5
  @triangle_fan 6

  @doc """
  Creates a new Primitive struct.

  ## Parameters
  - `attributes`: A map where each key corresponds to a mesh attribute semantic (required)
  - `indices`: The index of the accessor that contains the vertex indices (optional)
  - `material`: The index of the material to apply to this primitive (optional)
  - `mode`: The topology type of primitives to render (optional, default: 4 - triangles)
  - `targets`: An array of morph targets (optional)
  - `extensions`: JSON object with extension-specific objects (optional)
  - `extras`: Application-specific data (optional)

  ## Examples

      iex> AriaGltf.Mesh.Primitive.new(%{"POSITION" => 0, "NORMAL" => 1})
      %AriaGltf.Mesh.Primitive{
        attributes: %{"POSITION" => 0, "NORMAL" => 1},
        mode: 4
      }

      iex> AriaGltf.Mesh.Primitive.new(%{"POSITION" => 0}, indices: 2, material: 1, mode: 4)
      %AriaGltf.Mesh.Primitive{
        attributes: %{"POSITION" => 0},
        indices: 2,
        material: 1,
        mode: 4
      }
  """
  @spec new(attributes(), keyword()) :: t()
  def new(attributes, opts \\ []) when is_map(attributes) and map_size(attributes) >= 1 do
    %__MODULE__{
      attributes: attributes,
      indices: Keyword.get(opts, :indices),
      material: Keyword.get(opts, :material),
      mode: Keyword.get(opts, :mode, @triangles),
      targets: Keyword.get(opts, :targets),
      extensions: Keyword.get(opts, :extensions),
      extras: Keyword.get(opts, :extras)
    }
  end

  @doc """
  Validates a Primitive struct according to glTF 2.0 specification.

  ## Validation Rules
  - attributes must not be empty
  - mode must be valid topology type
  - all attribute values must be non-negative integers
  - indices must be non-negative integer if present
  - material must be non-negative integer if present

  ## Examples

      iex> primitive = AriaGltf.Mesh.Primitive.new(%{"POSITION" => 0})
      iex> AriaGltf.Mesh.Primitive.validate(primitive)
      :ok
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = primitive) do
    with :ok <- validate_attributes(primitive.attributes),
         :ok <- validate_indices(primitive.indices),
         :ok <- validate_material(primitive.material),
         :ok <- validate_mode(primitive.mode),
         :ok <- validate_targets(primitive.targets) do
      :ok
    end
  end

  @doc """
  Converts a Primitive struct to a map suitable for JSON encoding.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = primitive) do
    %{}
    |> Map.put("attributes", primitive.attributes)
    |> put_if_present("indices", primitive.indices)
    |> put_if_present("material", primitive.material)
    |> put_if_present("mode", primitive.mode, @triangles)
    |> put_if_present("targets", primitive.targets)
    |> put_if_present("extensions", primitive.extensions)
    |> put_if_present("extras", primitive.extras)
  end

  @doc """
  Creates a Primitive struct from a map (typically from JSON parsing).
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
  def from_map(map) when is_map(map) do
    with {:ok, attributes} <- get_required_field(map, "attributes") do
      primitive = %__MODULE__{
        attributes: attributes,
        indices: Map.get(map, "indices"),
        material: Map.get(map, "material"),
        mode: Map.get(map, "mode", @triangles),
        targets: Map.get(map, "targets"),
        extensions: Map.get(map, "extensions"),
        extras: Map.get(map, "extras")
      }

      case validate(primitive) do
        :ok -> {:ok, primitive}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Creates a Primitive struct from JSON data.
  """
  @spec from_json(map()) :: t()
  def from_json(json) do
    case from_map(json) do
      {:ok, primitive} -> primitive
      {:error, _reason} -> raise ArgumentError, "Invalid primitive JSON"
    end
  end

  @doc """
  Converts a Primitive struct to JSON-compatible map.
  """
  @spec to_json(t()) :: map()
  def to_json(primitive), do: to_map(primitive)

  # Private validation functions

  defp validate_attributes(attributes) when is_map(attributes) and map_size(attributes) >= 1 do
    attributes
    |> Enum.reduce_while(:ok, fn {key, value}, :ok ->
      cond do
        not is_binary(key) ->
          {:halt, {:error, "attribute key must be a string"}}

        not is_integer(value) or value < 0 ->
          {:halt, {:error, "attribute value must be a non-negative integer"}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  defp validate_attributes(_), do: {:error, "attributes must be a non-empty map"}

  defp validate_mode(mode)
       when mode in [
              @points,
              @lines,
              @line_loop,
              @line_strip,
              @triangles,
              @triangle_strip,
              @triangle_fan
            ],
       do: :ok

  defp validate_mode(_), do: {:error, "Invalid primitive mode"}

  defp validate_indices(nil), do: :ok
  defp validate_indices(indices) when is_integer(indices) and indices >= 0, do: :ok
  defp validate_indices(_), do: {:error, "indices must be a non-negative integer"}

  defp validate_material(nil), do: :ok
  defp validate_material(material) when is_integer(material) and material >= 0, do: :ok
  defp validate_material(_), do: {:error, "material must be a non-negative integer"}

  defp validate_targets(nil), do: :ok

  defp validate_targets(targets) when is_list(targets) do
    targets
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {target, index}, :ok ->
      case validate_target(target) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, "target #{index}: #{reason}"}}
      end
    end)
  end

  defp validate_targets(_), do: {:error, "targets must be a list"}

  defp validate_target(target) when is_map(target) and map_size(target) >= 1 do
    target
    |> Enum.reduce_while(:ok, fn {key, value}, :ok ->
      cond do
        not is_binary(key) ->
          {:halt, {:error, "target attribute key must be a string"}}

        not is_integer(value) or value < 0 ->
          {:halt, {:error, "target attribute value must be a non-negative integer"}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  defp validate_target(_), do: {:error, "target must be a non-empty map"}

  # Helper functions

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)
  defp put_if_present(map, _key, value, default) when value == default, do: map
  defp put_if_present(map, key, value, _default), do: Map.put(map, key, value)

  defp get_required_field(map, key) do
    case Map.get(map, key) do
      nil -> {:error, "Missing required field: #{key}"}
      value -> {:ok, value}
    end
  end
end
