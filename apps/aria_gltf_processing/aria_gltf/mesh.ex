# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Mesh do
  @moduledoc """
  A set of primitives to be rendered. Its global transform is defined by a node that references it.

  From glTF 2.0 specification section 5.23:
  Meshes are defined as arrays of primitives. Primitives correspond to the data required for GPU
  draw calls. Primitives specify one or more attributes, corresponding to the vertex attributes
  used in the draw calls.
  """

  alias AriaGltf.Mesh.Primitive

  @type t :: %__MODULE__{
          primitives: [Primitive.t()],
          weights: [number()] | nil,
          name: String.t() | nil,
          extensions: map() | nil,
          extras: any() | nil
        }

  @enforce_keys [:primitives]
  defstruct [
    :primitives,
    :weights,
    :name,
    :extensions,
    :extras
  ]

  @doc """
  Creates a new Mesh struct.

  ## Parameters
  - `primitives`: An array of primitives, each defining geometry to be rendered (required)
  - `weights`: Array of weights to be applied to the morph targets (optional)
  - `name`: The user-defined name of this object (optional)
  - `extensions`: JSON object with extension-specific objects (optional)
  - `extras`: Application-specific data (optional)

  ## Examples

      iex> primitive = AriaGltf.Mesh.Primitive.new(%{"POSITION" => 0})
      iex> AriaGltf.Mesh.new([primitive])
      %AriaGltf.Mesh{primitives: [primitive]}

      iex> AriaGltf.Mesh.new([primitive], weights: [0.5, 0.3], name: "Character Mesh")
      %AriaGltf.Mesh{primitives: [primitive], weights: [0.5, 0.3], name: "Character Mesh"}
  """
  @spec new([Primitive.t()], keyword()) :: t()
  def new(primitives, opts \\ []) when is_list(primitives) and length(primitives) >= 1 do
    %__MODULE__{
      primitives: primitives,
      weights: Keyword.get(opts, :weights),
      name: Keyword.get(opts, :name),
      extensions: Keyword.get(opts, :extensions),
      extras: Keyword.get(opts, :extras)
    }
  end

  @doc """
  Validates a Mesh struct according to glTF 2.0 specification.

  ## Validation Rules
  - primitives array must not be empty
  - all primitives must be valid
  - weights array length must match number of morph targets if present

  ## Examples

      iex> primitive = AriaGltf.Mesh.Primitive.new(%{"POSITION" => 0})
      iex> mesh = AriaGltf.Mesh.new([primitive])
      iex> AriaGltf.Mesh.validate(mesh)
      :ok
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = mesh) do
    with :ok <- validate_primitives(mesh.primitives),
         :ok <- validate_weights(mesh.weights, mesh.primitives) do
      :ok
    end
  end

  @doc """
  Converts a Mesh struct to a map suitable for JSON encoding.

  ## Examples

      iex> primitive = AriaGltf.Mesh.Primitive.new(%{"POSITION" => 0})
      iex> mesh = AriaGltf.Mesh.new([primitive], name: "Test Mesh")
      iex> AriaGltf.Mesh.to_map(mesh)
      %{
        "primitives" => [%{"attributes" => %{"POSITION" => 0}}],
        "name" => "Test Mesh"
      }
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = mesh) do
    %{}
    |> Map.put("primitives", Enum.map(mesh.primitives, &Primitive.to_map/1))
    |> put_if_present("weights", mesh.weights)
    |> put_if_present("name", mesh.name)
    |> put_if_present("extensions", mesh.extensions)
    |> put_if_present("extras", mesh.extras)
  end

  @doc """
  Creates a Mesh struct from a map (typically from JSON parsing).

  ## Examples

      iex> map = %{
      ...>   "primitives" => [%{"attributes" => %{"POSITION" => 0}}],
      ...>   "name" => "Test Mesh"
      ...> }
      iex> AriaGltf.Mesh.from_map(map)
      {:ok, %AriaGltf.Mesh{primitives: [%AriaGltf.Mesh.Primitive{}], name: "Test Mesh"}}
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
  def from_map(map) when is_map(map) do
    with {:ok, primitives_data} <- get_required_field(map, "primitives"),
         {:ok, primitives} <- parse_primitives(primitives_data) do
      mesh = %__MODULE__{
        primitives: primitives,
        weights: Map.get(map, "weights"),
        name: Map.get(map, "name"),
        extensions: Map.get(map, "extensions"),
        extras: Map.get(map, "extras")
      }

      case validate(mesh) do
        :ok -> {:ok, mesh}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Converts a Mesh struct to JSON-compatible map.
  """
  @spec to_json(t()) :: map()
  def to_json(mesh), do: to_map(mesh)

  @doc """
  Creates a Mesh struct from JSON data.
  """
  @spec from_json(map()) :: t()
  def from_json(json) when is_map(json) do
    case from_map(json) do
      {:ok, mesh} -> mesh
      {:error, _reason} -> raise ArgumentError, "Invalid mesh JSON"
    end
  end

  # Private validation functions

  defp validate_primitives([]), do: {:error, "primitives array must not be empty"}

  defp validate_primitives(primitives) when is_list(primitives) do
    primitives
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {primitive, index}, :ok ->
      case Primitive.validate(primitive) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, "primitive #{index}: #{reason}"}}
      end
    end)
  end

  defp validate_primitives(_), do: {:error, "primitives must be a list"}

  defp validate_weights(nil, _), do: :ok

  defp validate_weights(weights, primitives) when is_list(weights) do
    # Check if all primitives have the same number of morph targets
    morph_target_counts =
      primitives
      |> Enum.map(fn primitive ->
        case primitive.targets do
          nil -> 0
          targets -> length(targets)
        end
      end)
      |> Enum.uniq()

    case morph_target_counts do
      [count] ->
        if length(weights) == count do
          :ok
        else
          {:error, "weights array length must match number of morph targets"}
        end

      [] ->
        :ok

      _ ->
        {:error, "all primitives must have the same number of morph targets"}
    end
  end

  defp validate_weights(_, _), do: {:error, "weights must be a list of numbers"}

  # Helper functions

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

  defp get_required_field(map, key) do
    case Map.get(map, key) do
      nil -> {:error, "Missing required field: #{key}"}
      value -> {:ok, value}
    end
  end

  defp parse_primitives(primitives_data) when is_list(primitives_data) do
    primitives_data
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {primitive_data, index}, {:ok, acc} ->
      case Primitive.from_map(primitive_data) do
        {:ok, primitive} -> {:cont, {:ok, [primitive | acc]}}
        {:error, reason} -> {:halt, {:error, "primitive #{index}: #{reason}"}}
      end
    end)
    |> case do
      {:ok, primitives} -> {:ok, Enum.reverse(primitives)}
      error -> error
    end
  end

  defp parse_primitives(_), do: {:error, "primitives must be a list"}
end
