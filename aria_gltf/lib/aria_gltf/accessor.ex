# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Accessor do
  @moduledoc """
  A typed view into a buffer view that contains raw binary data.

  From glTF 2.0 specification section 5.1:
  An accessor defines a method for retrieving data as typed arrays from within a buffer view.
  The accessor specifies a component type (e.g., float) and a data type (e.g., VEC3 for 3D vectors).
  """

  defmodule Sparse do
    @moduledoc """
    Sparse storage of elements that deviate from their initialization value.
    """

    defmodule Indices do
      @moduledoc """
      An object pointing to a buffer view containing the indices of deviating accessor values.
      """

      @type t :: %__MODULE__{
              buffer_view: non_neg_integer(),
              byte_offset: non_neg_integer(),
              component_type: AriaGltf.Accessor.component_type(),
              extensions: map() | nil,
              extras: any() | nil
            }

      defstruct [
        :buffer_view,
        :byte_offset,
        :component_type,
        :extensions,
        :extras
      ]
    end

    defmodule Values do
      @moduledoc """
      An object pointing to a buffer view containing the deviating accessor values.
      """

      @type t :: %__MODULE__{
              buffer_view: non_neg_integer(),
              byte_offset: non_neg_integer(),
              extensions: map() | nil,
              extras: any() | nil
            }

      defstruct [
        :buffer_view,
        :byte_offset,
        :extensions,
        :extras
      ]
    end

    @type t :: %__MODULE__{
            count: pos_integer(),
            indices: Indices.t(),
            values: Values.t(),
            extensions: map() | nil,
            extras: any() | nil
          }

    defstruct [
      :count,
      :indices,
      :values,
      :extensions,
      :extras
    ]
  end

  @type component_type :: 5120 | 5121 | 5122 | 5123 | 5125 | 5126
  @type accessor_type :: :scalar | :vec2 | :vec3 | :vec4 | :mat2 | :mat3 | :mat4

  @type t :: %__MODULE__{
          buffer_view: non_neg_integer() | nil,
          byte_offset: non_neg_integer(),
          component_type: component_type(),
          normalized: boolean(),
          count: pos_integer(),
          type: accessor_type(),
          max: [number()] | nil,
          min: [number()] | nil,
          sparse: map() | nil,
          name: String.t() | nil,
          extensions: map() | nil,
          extras: any() | nil
        }

  @enforce_keys [:component_type, :count, :type]
  defstruct [
    :buffer_view,
    :byte_offset,
    :component_type,
    :normalized,
    :count,
    :type,
    :max,
    :min,
    :sparse,
    :name,
    :extensions,
    :extras
  ]

  # Component type constants
  @byte 5120
  @unsigned_byte 5121
  @short 5122
  @unsigned_short 5123
  @unsigned_int 5125
  @float 5126

  # Type to component count mapping
  @type_component_counts %{
    scalar: 1,
    vec2: 2,
    vec3: 3,
    vec4: 4,
    mat2: 4,
    mat3: 9,
    mat4: 16
  }

  # Component type to byte size mapping
  @component_byte_sizes %{
    @byte => 1,
    @unsigned_byte => 1,
    @short => 2,
    @unsigned_short => 2,
    @unsigned_int => 4,
    @float => 4
  }

  @doc """
  Creates a new Accessor struct.

  ## Parameters
  - `component_type`: The datatype of the accessor's components (required)
  - `count`: The number of elements referenced by this accessor (required)
  - `type`: Specifies if the accessor's elements are scalars, vectors, or matrices (required)
  - `buffer_view`: The index of the bufferView (optional)
  - `byte_offset`: The offset relative to the start of the buffer view in bytes (optional, default: 0)
  - `normalized`: Specifies whether integer data values are normalized (optional, default: false)
  - `max`: Maximum value of each component (optional)
  - `min`: Minimum value of each component (optional)
  - `sparse`: Sparse storage of elements (optional)
  - `name`: The user-defined name (optional)
  - `extensions`: Extension-specific objects (optional)
  - `extras`: Application-specific data (optional)

  ## Examples

      iex> AriaGltf.Accessor.new(5126, 100, :vec3)
      %AriaGltf.Accessor{
        component_type: 5126,
        count: 100,
        type: :vec3,
        byte_offset: 0,
        normalized: false
      }
  """
  @spec new(component_type(), pos_integer(), accessor_type(), keyword()) :: t()
  def new(component_type, count, type, opts \\ [])
      when component_type in [
             @byte,
             @unsigned_byte,
             @short,
             @unsigned_short,
             @unsigned_int,
             @float
           ] and
             is_integer(count) and count >= 1 and
             type in [:scalar, :vec2, :vec3, :vec4, :mat2, :mat3, :mat4] do
    %__MODULE__{
      component_type: component_type,
      count: count,
      type: type,
      buffer_view: Keyword.get(opts, :buffer_view),
      byte_offset: Keyword.get(opts, :byte_offset, 0),
      normalized: Keyword.get(opts, :normalized, false),
      max: Keyword.get(opts, :max),
      min: Keyword.get(opts, :min),
      sparse: Keyword.get(opts, :sparse),
      name: Keyword.get(opts, :name),
      extensions: Keyword.get(opts, :extensions),
      extras: Keyword.get(opts, :extras)
    }
  end

  @doc """
  Creates a new accessor with buffer view, type, component type, count, and options.
  """
  @spec new(non_neg_integer(), accessor_type(), component_type(), pos_integer(), map()) :: t()
  def new(buffer_view, type, component_type, count, options)
      when is_integer(buffer_view) and
             type in [:scalar, :vec2, :vec3, :vec4, :mat2, :mat3, :mat4] and
             component_type in [
               @byte,
               @unsigned_byte,
               @short,
               @unsigned_short,
               @unsigned_int,
               @float
             ] and
             is_integer(count) and count >= 1 and is_map(options) do
    %__MODULE__{
      buffer_view: buffer_view,
      type: type,
      component_type: component_type,
      count: count,
      byte_offset: Map.get(options, :byte_offset, 0),
      normalized: Map.get(options, :normalized, false),
      max: Map.get(options, :max),
      min: Map.get(options, :min),
      sparse: Map.get(options, :sparse),
      name: Map.get(options, :name),
      extensions: Map.get(options, :extensions),
      extras: Map.get(options, :extras)
    }
  end

  @doc """
  Validates an Accessor struct according to glTF 2.0 specification.

  ## Validation Rules
  - component_type must be valid
  - count must be >= 1
  - type must be valid
  - byte_offset must be multiple of component size
  - normalized must not be true for FLOAT or UNSIGNED_INT
  - max/min arrays must have correct length if present
  - byte_offset must not be defined when buffer_view is undefined

  ## Examples

      iex> accessor = AriaGltf.Accessor.new(5126, 100, :vec3)
      iex> AriaGltf.Accessor.validate(accessor)
      :ok
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = accessor) do
    with :ok <- validate_component_type(accessor.component_type),
         :ok <- validate_count(accessor.count),
         :ok <- validate_type(accessor.type),
         :ok <-
           validate_byte_offset(
             accessor.byte_offset,
             accessor.buffer_view,
             accessor.component_type
           ),
         :ok <- validate_normalized(accessor.normalized, accessor.component_type),
         :ok <- validate_bounds(accessor.max, accessor.min, accessor.type) do
      :ok
    end
  end

  @doc """
  Gets the number of components for a given accessor type.

  ## Examples

      iex> AriaGltf.Accessor.component_count(:vec3)
      3

      iex> AriaGltf.Accessor.component_count(:mat4)
      16
  """
  @spec component_count(accessor_type()) :: pos_integer()
  def component_count(type), do: Map.get(@type_component_counts, type)

  @doc """
  Gets the byte size for a given component type.

  ## Examples

      iex> AriaGltf.Accessor.component_byte_size(5126)
      4

      iex> AriaGltf.Accessor.component_byte_size(5123)
      2
  """
  @spec component_byte_size(component_type()) :: pos_integer()
  def component_byte_size(component_type), do: Map.get(@component_byte_sizes, component_type)

  @doc """
  Calculates the element size in bytes for this accessor.

  ## Examples

      iex> accessor = AriaGltf.Accessor.new(5126, 100, :vec3)
      iex> AriaGltf.Accessor.element_byte_size(accessor)
      12
  """
  @spec element_byte_size(t()) :: pos_integer()
  def element_byte_size(%__MODULE__{} = accessor) do
    component_byte_size(accessor.component_type) * component_count(accessor.type)
  end

  @doc """
  Converts an Accessor struct to a map suitable for JSON encoding.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = accessor) do
    %{}
    |> put_if_present("bufferView", accessor.buffer_view)
    |> put_if_present("byteOffset", accessor.byte_offset, 0)
    |> Map.put("componentType", accessor.component_type)
    |> put_if_present("normalized", accessor.normalized, false)
    |> Map.put("count", accessor.count)
    |> Map.put("type", type_to_string(accessor.type))
    |> put_if_present("max", accessor.max)
    |> put_if_present("min", accessor.min)
    |> put_if_present("sparse", accessor.sparse)
    |> put_if_present("name", accessor.name)
    |> put_if_present("extensions", accessor.extensions)
    |> put_if_present("extras", accessor.extras)
  end

  @doc """
  Creates an Accessor struct from a map (typically from JSON parsing).
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
  def from_map(map) when is_map(map) do
    with {:ok, component_type} <- get_required_field(map, "componentType"),
         {:ok, count} <- get_required_field(map, "count"),
         {:ok, type} <- get_required_field(map, "type"),
         {:ok, type_atom} <- string_to_type(type) do
      accessor = %__MODULE__{
        component_type: component_type,
        count: count,
        type: type_atom,
        buffer_view: Map.get(map, "bufferView"),
        byte_offset: Map.get(map, "byteOffset", 0),
        normalized: Map.get(map, "normalized", false),
        max: Map.get(map, "max"),
        min: Map.get(map, "min"),
        sparse: Map.get(map, "sparse"),
        name: Map.get(map, "name"),
        extensions: Map.get(map, "extensions"),
        extras: Map.get(map, "extras")
      }

      case validate(accessor) do
        :ok -> {:ok, accessor}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Creates an Accessor struct from JSON data.
  """
  @spec from_json(map()) :: t()
  def from_json(json) do
    case from_map(json) do
      {:ok, accessor} -> accessor
      {:error, _reason} -> raise ArgumentError, "Invalid accessor JSON"
    end
  end

  @doc """
  Converts an Accessor struct to JSON-compatible map.
  """
  @spec to_json(t()) :: map()
  def to_json(accessor), do: to_map(accessor)

  # Private validation functions

  defp validate_component_type(type)
       when type in [@byte, @unsigned_byte, @short, @unsigned_short, @unsigned_int, @float],
       do: :ok

  defp validate_component_type(_), do: {:error, "Invalid component type"}

  defp validate_count(count) when is_integer(count) and count >= 1, do: :ok
  defp validate_count(_), do: {:error, "count must be >= 1"}

  defp validate_type(type) when type in [:scalar, :vec2, :vec3, :vec4, :mat2, :mat3, :mat4],
    do: :ok

  defp validate_type(_), do: {:error, "Invalid accessor type"}

  defp validate_byte_offset(byte_offset, buffer_view, component_type) do
    cond do
      is_nil(buffer_view) and byte_offset != 0 ->
        {:error, "byte_offset must not be defined when buffer_view is undefined"}

      not is_integer(byte_offset) or byte_offset < 0 ->
        {:error, "byte_offset must be a non-negative integer"}

      rem(byte_offset, component_byte_size(component_type)) != 0 ->
        {:error, "byte_offset must be a multiple of component type size"}

      true ->
        :ok
    end
  end

  defp validate_normalized(true, component_type) when component_type in [@float, @unsigned_int] do
    {:error, "normalized must not be true for FLOAT or UNSIGNED_INT component types"}
  end

  defp validate_normalized(normalized, _) when is_boolean(normalized), do: :ok
  defp validate_normalized(_, _), do: {:error, "normalized must be a boolean"}

  defp validate_bounds(nil, nil, _), do: :ok

  defp validate_bounds(max, min, type) when is_list(max) and is_list(min) do
    expected_length = component_count(type)

    cond do
      length(max) != expected_length ->
        {:error, "max array length must match accessor type component count"}

      length(min) != expected_length ->
        {:error, "min array length must match accessor type component count"}

      true ->
        :ok
    end
  end

  defp validate_bounds(max, min, _type) when is_list(max) or is_list(min) do
    {:error, "Both max and min must be provided together or both must be nil"}
  end

  defp validate_bounds(_, _, _), do: {:error, "max and min must be lists of numbers"}

  # Helper functions

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)
  defp put_if_present(map, key, value, _default), do: Map.put(map, key, value)
  defp put_if_present(map, _key, value, default) when value == default, do: map

  defp get_required_field(map, key) do
    case Map.get(map, key) do
      nil -> {:error, "Missing required field: #{key}"}
      value -> {:ok, value}
    end
  end

  defp type_to_string(:scalar), do: "SCALAR"
  defp type_to_string(:vec2), do: "VEC2"
  defp type_to_string(:vec3), do: "VEC3"
  defp type_to_string(:vec4), do: "VEC4"
  defp type_to_string(:mat2), do: "MAT2"
  defp type_to_string(:mat3), do: "MAT3"
  defp type_to_string(:mat4), do: "MAT4"

  defp string_to_type("SCALAR"), do: {:ok, :scalar}
  defp string_to_type("VEC2"), do: {:ok, :vec2}
  defp string_to_type("VEC3"), do: {:ok, :vec3}
  defp string_to_type("VEC4"), do: {:ok, :vec4}
  defp string_to_type("MAT2"), do: {:ok, :mat2}
  defp string_to_type("MAT3"), do: {:ok, :mat3}
  defp string_to_type("MAT4"), do: {:ok, :mat4}
  defp string_to_type(_), do: {:error, "Invalid accessor type string"}
end
