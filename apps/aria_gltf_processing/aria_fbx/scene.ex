# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaFbx.Scene do
  @moduledoc """
  FBX scene structures and data types.
  """

  defmodule Node do
    @moduledoc """
    Represents an FBX node in the scene hierarchy.
    """
    @type t :: %__MODULE__{
            id: non_neg_integer(),
            name: String.t(),
            parent_id: non_neg_integer() | nil,
            children: [non_neg_integer()] | nil,
            translation: {float(), float(), float()} | nil,
            rotation: {float(), float(), float(), float()} | nil,
            scale: {float(), float(), float()} | nil,
            mesh_id: non_neg_integer() | nil,
            extensions: map() | nil,
            extras: any() | nil
          }

    defstruct [
      :id,
      :name,
      :parent_id,
      :children,
      :translation,
      :rotation,
      :scale,
      :mesh_id,
      :extensions,
      :extras
    ]

    def to_json(%__MODULE__{} = node) do
      %{
        "id" => node.id,
        "name" => node.name,
        "parentId" => node.parent_id,
        "children" => node.children,
        "translation" => encode_vec3(node.translation),
        "rotation" => encode_vec4(node.rotation),
        "scale" => encode_vec3(node.scale),
        "meshId" => node.mesh_id,
        "extensions" => node.extensions,
        "extras" => node.extras
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.into(%{})
    end

    defp encode_vec3(nil), do: nil
    defp encode_vec3({x, y, z}), do: [x, y, z]

    defp encode_vec4(nil), do: nil
    defp encode_vec4({x, y, z, w}), do: [x, y, z, w]
  end

  defmodule Mesh do
    @moduledoc """
    Represents an FBX mesh with geometry data.
    """
    @type t :: %__MODULE__{
            id: non_neg_integer(),
            name: String.t() | nil,
            positions: [float()] | nil,
            normals: [float()] | nil,
            texcoords: [float()] | nil,
            indices: [non_neg_integer()] | nil,
            material_ids: [non_neg_integer()] | nil,
            extensions: map() | nil,
            extras: any() | nil
          }

    defstruct [
      :id,
      :name,
      :positions,
      :normals,
      :texcoords,
      :indices,
      :material_ids,
      :extensions,
      :extras
    ]

    def to_json(%__MODULE__{} = mesh) do
      %{
        "id" => mesh.id,
        "name" => mesh.name,
        "positions" => mesh.positions,
        "normals" => mesh.normals,
        "texcoords" => mesh.texcoords,
        "indices" => mesh.indices,
        "materialIds" => mesh.material_ids,
        "extensions" => mesh.extensions,
        "extras" => mesh.extras
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.into(%{})
    end
  end

  defmodule Material do
    @moduledoc """
    Represents an FBX material.
    """
    @type t :: %__MODULE__{
            id: non_neg_integer(),
            name: String.t() | nil,
            diffuse_color: {float(), float(), float()} | nil,
            specular_color: {float(), float(), float()} | nil,
            emissive_color: {float(), float(), float()} | nil,
            extensions: map() | nil,
            extras: any() | nil
          }

    defstruct [
      :id,
      :name,
      :diffuse_color,
      :specular_color,
      :emissive_color,
      :extensions,
      :extras
    ]

    def to_json(%__MODULE__{} = material) do
      %{
        "id" => material.id,
        "name" => material.name,
        "diffuseColor" => encode_vec3(material.diffuse_color),
        "specularColor" => encode_vec3(material.specular_color),
        "emissiveColor" => encode_vec3(material.emissive_color),
        "extensions" => material.extensions,
        "extras" => material.extras
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.into(%{})
    end

    defp encode_vec3(nil), do: nil
    defp encode_vec3({x, y, z}), do: [x, y, z]
  end

  defmodule Texture do
    @moduledoc """
    Represents an FBX texture.
    """
    @type t :: %__MODULE__{
            id: non_neg_integer(),
            name: String.t() | nil,
            file_path: String.t() | nil,
            extensions: map() | nil,
            extras: any() | nil
          }

    defstruct [
      :id,
      :name,
      :file_path,
      :extensions,
      :extras
    ]

    def to_json(%__MODULE__{} = texture) do
      %{
        "id" => texture.id,
        "name" => texture.name,
        "filePath" => texture.file_path,
        "extensions" => texture.extensions,
        "extras" => texture.extras
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.into(%{})
    end
  end

  defmodule Animation do
    @moduledoc """
    Represents an FBX animation.
    """
    @type t :: %__MODULE__{
            id: non_neg_integer(),
            name: String.t() | nil,
            node_id: non_neg_integer(),
            keyframes: [Keyframe.t()] | nil,
            extensions: map() | nil,
            extras: any() | nil
          }

    defmodule Keyframe do
      @type t :: %__MODULE__{
              time: float(),
              translation: {float(), float(), float()} | nil,
              rotation: {float(), float(), float(), float()} | nil,
              scale: {float(), float(), float()} | nil
            }

      defstruct [
        :time,
        :translation,
        :rotation,
        :scale
      ]

      def to_json(%__MODULE__{} = keyframe) do
        %{
          "time" => keyframe.time,
          "translation" => encode_vec3(keyframe.translation),
          "rotation" => encode_vec4(keyframe.rotation),
          "scale" => encode_vec3(keyframe.scale)
        }
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)
        |> Enum.into(%{})
      end

      defp encode_vec3(nil), do: nil
      defp encode_vec3({x, y, z}), do: [x, y, z]

      defp encode_vec4(nil), do: nil
      defp encode_vec4({x, y, z, w}), do: [x, y, z, w]
    end

    defstruct [
      :id,
      :name,
      :node_id,
      :keyframes,
      :extensions,
      :extras
    ]

    def to_json(%__MODULE__{} = animation) do
      %{
        "id" => animation.id,
        "name" => animation.name,
        "nodeId" => animation.node_id,
        "keyframes" => encode_optional_list(animation.keyframes, &Keyframe.to_json/1),
        "extensions" => animation.extensions,
        "extras" => animation.extras
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.into(%{})
    end

    defp encode_optional_list(nil, _encoder), do: nil
    defp encode_optional_list(list, encoder) when is_list(list) do
      Enum.map(list, encoder)
    end
  end
end

