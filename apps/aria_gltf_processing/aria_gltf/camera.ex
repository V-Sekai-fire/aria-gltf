# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Camera.Orthographic do
  @moduledoc """
  An orthographic camera containing properties to create an orthographic projection matrix.

  From glTF 2.0 specification section 5.8.2:
  An orthographic camera defines a orthographic projection matrix using the parameters xmag, ymag, zfar, and znear.
  """

  @type t :: %__MODULE__{
          xmag: number(),
          ymag: number(),
          zfar: number(),
          znear: number(),
          extensions: map() | nil,
          extras: any() | nil
        }

  @enforce_keys [:xmag, :ymag, :zfar, :znear]
  defstruct [
    :xmag,
    :ymag,
    :zfar,
    :znear,
    :extensions,
    :extras
  ]

  @doc """
  Creates a new Orthographic camera struct.

  ## Parameters
  - `xmag`: The horizontal magnification (required)
  - `ymag`: The vertical magnification (required)
  - `zfar`: The distance to the far clipping plane (required)
  - `znear`: The distance to the near clipping plane (required)
  - `extensions`: JSON object with extension-specific objects (optional)
  - `extras`: Application-specific data (optional)

  ## Examples

      iex> AriaGltf.Camera.Orthographic.new(1.0, 1.0, 100.0, 0.01)
      %AriaGltf.Camera.Orthographic{xmag: 1.0, ymag: 1.0, zfar: 100.0, znear: 0.01}
  """
  @spec new(number(), number(), number(), number(), keyword()) :: t()
  def new(xmag, ymag, zfar, znear, opts \\ []) do
    %__MODULE__{
      xmag: xmag,
      ymag: ymag,
      zfar: zfar,
      znear: znear,
      extensions: Keyword.get(opts, :extensions),
      extras: Keyword.get(opts, :extras)
    }
  end

  @doc """
  Validates an Orthographic camera struct.

  ## Validation Rules
  - xmag, ymag, zfar, znear must be numbers
  - zfar > znear > 0

  ## Examples

      iex> ortho = AriaGltf.Camera.Orthographic.new(1.0, 1.0, 100.0, 0.01)
      iex> AriaGltf.Camera.Orthographic.validate(ortho)
      :ok
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = ortho) do
    with :ok <- validate_magnifications(ortho.xmag, ortho.ymag),
         :ok <- validate_clipping_planes(ortho.znear, ortho.zfar) do
      :ok
    end
  end

  @doc """
  Converts an Orthographic camera struct to a map.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = ortho) do
    %{}
    |> Map.put("xmag", ortho.xmag)
    |> Map.put("ymag", ortho.ymag)
    |> Map.put("zfar", ortho.zfar)
    |> Map.put("znear", ortho.znear)
    |> put_if_present("extensions", ortho.extensions)
    |> put_if_present("extras", ortho.extras)
  end

  @doc """
  Creates an Orthographic camera struct from a map.
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
  def from_map(map) when is_map(map) do
    ortho = %__MODULE__{
      xmag: Map.get(map, "xmag"),
      ymag: Map.get(map, "ymag"),
      zfar: Map.get(map, "zfar"),
      znear: Map.get(map, "znear"),
      extensions: Map.get(map, "extensions"),
      extras: Map.get(map, "extras")
    }

    case validate(ortho) do
      :ok -> {:ok, ortho}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private validation functions

  defp validate_magnifications(xmag, ymag) when is_number(xmag) and is_number(ymag), do: :ok
  defp validate_magnifications(_, _), do: {:error, "xmag and ymag must be numbers"}

  defp validate_clipping_planes(znear, zfar)
       when is_number(znear) and is_number(zfar) and zfar > znear and znear > 0,
       do: :ok
  defp validate_clipping_planes(_, _), do: {:error, "zfar must be > znear > 0"}

  # Helper functions

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)
end

defmodule AriaGltf.Camera.Perspective do
  @moduledoc """
  A perspective camera containing properties to create a perspective projection matrix.

  From glTF 2.0 specification section 5.8.1:
  A perspective camera defines a perspective projection matrix using the parameters aspectRatio, yfov, zfar, and znear.
  """

  @type t :: %__MODULE__{
          aspect_ratio: number() | nil,
          yfov: number(),
          zfar: number() | nil,
          znear: number(),
          extensions: map() | nil,
          extras: any() | nil
        }

  @enforce_keys [:yfov, :znear]
  defstruct [
    :aspect_ratio,
    :yfov,
    :zfar,
    :znear,
    :extensions,
    :extras
  ]

  @doc """
  Creates a new Perspective camera struct.

  ## Parameters
  - `yfov`: The vertical field of view in radians (required)
  - `znear`: The distance to the near clipping plane (required)
  - `aspect_ratio`: The aspect ratio of the field of view (optional)
  - `zfar`: The distance to the far clipping plane (optional)
  - `extensions`: JSON object with extension-specific objects (optional)
  - `extras`: Application-specific data (optional)

  ## Examples

      iex> AriaGltf.Camera.Perspective.new(0.7, 0.01, zfar: 100.0)
      %AriaGltf.Camera.Perspective{yfov: 0.7, znear: 0.01, zfar: 100.0}
  """
  @spec new(number(), number(), keyword()) :: t()
  def new(yfov, znear, opts \\ []) do
    %__MODULE__{
      yfov: yfov,
      znear: znear,
      aspect_ratio: Keyword.get(opts, :aspect_ratio),
      zfar: Keyword.get(opts, :zfar),
      extensions: Keyword.get(opts, :extensions),
      extras: Keyword.get(opts, :extras)
    }
  end

  @doc """
  Validates a Perspective camera struct.

  ## Validation Rules
  - yfov, znear must be numbers
  - aspect_ratio must be a number > 0 if present
  - zfar must be a number > znear if present
  - yfov must be > 0
  - znear must be > 0

  ## Examples

      iex> persp = AriaGltf.Camera.Perspective.new(0.7, 0.01, zfar: 100.0)
      iex> AriaGltf.Camera.Perspective.validate(persp)
      :ok
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = persp) do
    with :ok <- validate_yfov(persp.yfov),
         :ok <- validate_znear(persp.znear),
         :ok <- validate_aspect_ratio(persp.aspect_ratio),
         :ok <- validate_zfar(persp.zfar, persp.znear) do
      :ok
    end
  end

  @doc """
  Converts a Perspective camera struct to a map.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = persp) do
    %{}
    |> put_if_present("aspectRatio", persp.aspect_ratio)
    |> Map.put("yfov", persp.yfov)
    |> put_if_present("zfar", persp.zfar)
    |> Map.put("znear", persp.znear)
    |> put_if_present("extensions", persp.extensions)
    |> put_if_present("extras", persp.extras)
  end

  @doc """
  Creates a Perspective camera struct from a map.
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
  def from_map(map) when is_map(map) do
    persp = %__MODULE__{
      aspect_ratio: Map.get(map, "aspectRatio"),
      yfov: Map.get(map, "yfov"),
      zfar: Map.get(map, "zfar"),
      znear: Map.get(map, "znear"),
      extensions: Map.get(map, "extensions"),
      extras: Map.get(map, "extras")
    }

    case validate(persp) do
      :ok -> {:ok, persp}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private validation functions

  defp validate_yfov(yfov) when is_number(yfov) and yfov > 0, do: :ok
  defp validate_yfov(_), do: {:error, "yfov must be a positive number"}

  defp validate_znear(znear) when is_number(znear) and znear > 0, do: :ok
  defp validate_znear(_), do: {:error, "znear must be a positive number"}

  defp validate_aspect_ratio(nil), do: :ok
  defp validate_aspect_ratio(aspect_ratio) when is_number(aspect_ratio) and aspect_ratio > 0, do: :ok
  defp validate_aspect_ratio(_), do: {:error, "aspect_ratio must be a positive number"}

  defp validate_zfar(nil, _znear), do: :ok
  defp validate_zfar(zfar, znear) when is_number(zfar) and zfar > znear, do: :ok
  defp validate_zfar(_, _), do: {:error, "zfar must be greater than znear"}

  # Helper functions

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)
end

defmodule AriaGltf.Camera do
  @moduledoc """
  A camera's projection. A node can reference a camera to apply a transform to place the camera in the scene.

  From glTF 2.0 specification section 5.8:
  A camera defines the projection matrix used for rendering. A camera is defined by an optional name and
  a projection matrix, which can be either perspective or orthographic.
  """

  @type type :: :perspective | :orthographic

  @type t :: %__MODULE__{
          name: String.t() | nil,
          type: type(),
          orthographic: Orthographic.t() | nil,
          perspective: Perspective.t() | nil,
          extensions: map() | nil,
          extras: any() | nil
        }

  @enforce_keys [:type]
  defstruct [
    :name,
    :type,
    :orthographic,
    :perspective,
    :extensions,
    :extras
  ]

  @doc """
  Creates a new Camera struct.

  ## Parameters
  - `type`: The type of projection (required, :perspective or :orthographic)
  - `name`: The user-defined name of this object (optional)
  - `orthographic`: The orthographic projection parameters (optional)
  - `perspective`: The perspective projection parameters (optional)
  - `extensions`: JSON object with extension-specific objects (optional)
  - `extras`: Application-specific data (optional)

  ## Examples

      iex> AriaGltf.Camera.new(:perspective, perspective: %AriaGltf.Camera.Perspective{yfov: 0.7})
      %AriaGltf.Camera{type: :perspective, perspective: %AriaGltf.Camera.Perspective{yfov: 0.7}}

      iex> AriaGltf.Camera.new(:orthographic, orthographic: %AriaGltf.Camera.Orthographic{xmag: 1.0, ymag: 1.0, zfar: 100.0, znear: 0.01})
      %AriaGltf.Camera{type: :orthographic, orthographic: %AriaGltf.Camera.Orthographic{xmag: 1.0, ymag: 1.0, zfar: 100.0, znear: 0.01}}
  """
  @spec new(type(), keyword()) :: t()
  def new(type, opts \\ []) when type in [:perspective, :orthographic] do
    %__MODULE__{
      type: type,
      name: Keyword.get(opts, :name),
      orthographic: Keyword.get(opts, :orthographic),
      perspective: Keyword.get(opts, :perspective),
      extensions: Keyword.get(opts, :extensions),
      extras: Keyword.get(opts, :extras)
    }
  end

  @doc """
  Validates a Camera struct according to glTF 2.0 specification.

  ## Validation Rules
  - type must be valid
  - exactly one of orthographic or perspective must be defined based on type
  - orthographic/perspective parameters must be valid

  ## Examples

      iex> camera = AriaGltf.Camera.new(:perspective, perspective: %AriaGltf.Camera.Perspective{yfov: 0.7, znear: 0.01, zfar: 100.0})
      iex> AriaGltf.Camera.validate(camera)
      :ok
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = camera) do
    with :ok <- validate_type(camera.type),
         :ok <- validate_projection(camera) do
      :ok
    end
  end

  @doc """
  Converts a Camera struct to a map suitable for JSON encoding.

  ## Examples

      iex> camera = AriaGltf.Camera.new(:perspective, name: "Main Camera", perspective: %AriaGltf.Camera.Perspective{yfov: 0.7, znear: 0.01, zfar: 100.0})
      iex> AriaGltf.Camera.to_map(camera)
      %{
        "type" => "perspective",
        "name" => "Main Camera",
        "perspective" => %{"yfov" => 0.7, "znear" => 0.01, "zfar" => 100.0}
      }
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = camera) do
    %{}
    |> Map.put("type", type_to_string(camera.type))
    |> put_if_present("name", camera.name)
    |> put_if_present("orthographic", camera.orthographic, &Orthographic.to_map/1)
    |> put_if_present("perspective", camera.perspective, &Perspective.to_map/1)
    |> put_if_present("extensions", camera.extensions)
    |> put_if_present("extras", camera.extras)
  end

  @doc """
  Creates a Camera struct from a map (typically from JSON parsing).

  ## Examples

      iex> map = %{"type" => "perspective", "perspective" => %{"yfov" => 0.7, "znear" => 0.01, "zfar" => 100.0}}
      iex> AriaGltf.Camera.from_map(map)
      {:ok, %AriaGltf.Camera{type: :perspective, perspective: %AriaGltf.Camera.Perspective{yfov: 0.7, znear: 0.01, zfar: 100.0}}}
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
  def from_map(map) when is_map(map) do
    with {:ok, type} <- parse_type(Map.get(map, "type")),
         {:ok, orthographic} <- parse_orthographic(Map.get(map, "orthographic")),
         {:ok, perspective} <- parse_perspective(Map.get(map, "perspective")) do
      camera = %__MODULE__{
        type: type,
        name: Map.get(map, "name"),
        orthographic: orthographic,
        perspective: perspective,
        extensions: Map.get(map, "extensions"),
        extras: Map.get(map, "extras")
      }

      case validate(camera) do
        :ok -> {:ok, camera}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Creates a Camera struct from JSON data.
  """
  @spec from_json(map()) :: t()
  def from_json(json) do
    case from_map(json) do
      {:ok, camera} -> camera
      {:error, _reason} -> raise ArgumentError, "Invalid camera JSON"
    end
  end

  @doc """
  Converts a Camera struct to JSON-compatible map.
  """
  @spec to_json(t()) :: map()
  def to_json(camera), do: to_map(camera)

  # Private validation functions

  defp validate_type(type) when type in [:perspective, :orthographic], do: :ok
  defp validate_type(_), do: {:error, "Invalid camera type"}

  defp validate_projection(%{type: :perspective, perspective: %AriaGltf.Camera.Perspective{}}), do: :ok
  defp validate_projection(%{type: :orthographic, orthographic: %AriaGltf.Camera.Orthographic{}}), do: :ok
  defp validate_projection(_), do: {:error, "Camera must have matching projection type"}

  # Helper functions

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)
  defp put_if_present(map, key, value, transform_fn) when is_function(transform_fn, 1),
    do: Map.put(map, key, transform_fn.(value))

  defp type_to_string(:perspective), do: "perspective"
  defp type_to_string(:orthographic), do: "orthographic"

  defp parse_type("perspective"), do: {:ok, :perspective}
  defp parse_type("orthographic"), do: {:ok, :orthographic}
  defp parse_type(_), do: {:error, "Invalid camera type string"}

  defp parse_orthographic(nil), do: {:ok, nil}
  defp parse_orthographic(data), do: Orthographic.from_map(data)

  defp parse_perspective(nil), do: {:ok, nil}
  defp parse_perspective(data), do: Perspective.from_map(data)
end
