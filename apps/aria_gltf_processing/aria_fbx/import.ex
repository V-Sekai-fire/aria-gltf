# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaFbx.Import do
  @moduledoc """
  FBX file import functionality.

  Provides functions to load FBX files using the ufbx library via NIFs
  and convert them to FBXDocument structures, aligned with the
  AriaGltf.Import API.
  """

  alias AriaFbx.{Document, Nif, Parser}

  @doc """
  Loads an FBX file from disk and returns an FBXDocument.

  ## Options

  - `:validate` - Whether to validate the FBX file (default: `true`)

  ## Examples

      {:ok, document} = AriaFbx.Import.from_file("/path/to/model.fbx")
      {:error, reason} = AriaFbx.Import.from_file("/path/to/invalid.fbx")

      # Skip validation
      {:ok, document} = AriaFbx.Import.from_file("/path/to/model.fbx", validate: false)
  """
  @spec from_file(String.t(), keyword()) :: {:ok, Document.t()} | {:error, term()}
  def from_file(file_path, opts \\ []) when is_binary(file_path) do
    validate? = Keyword.get(opts, :validate, true)

    # Handle NIF errors gracefully (NIF may raise if not loaded or on file errors)
    try do
      case Nif.load_fbx(file_path) do
        {:ok, ufbx_data} ->
          case Parser.from_ufbx_scene(ufbx_data) do
            {:ok, document} ->
              if validate? do
                case validate_document(document) do
                  :ok -> {:ok, document}
                  {:error, reason} -> {:error, reason}
                end
              else
                {:ok, document}
              end

            {:error, reason} ->
              {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e in [ArgumentError, RuntimeError] ->
        {:error, Exception.message(e)}
    end
  end

  # Validate FBX document structure
  defp validate_document(%Document{} = document) do
    with :ok <- validate_version(document.version),
         :ok <- validate_node_references(document),
         :ok <- validate_mesh_references(document) do
      :ok
    end
  end

  defp validate_document(_), do: {:error, :invalid_document}

  # Validate document version
  defp validate_version(version) when is_binary(version) and version != "", do: :ok
  defp validate_version(_), do: {:error, "FBX document version is required and must be a non-empty string"}

  # Validate node references (mesh_id, parent_id, children)
  defp validate_node_references(%Document{nodes: nil}), do: :ok
  defp validate_node_references(%Document{nodes: nodes}) when is_list(nodes) do
    node_ids = Enum.map(nodes, & &1.id) |> MapSet.new()

    # Check that all referenced mesh_ids exist (if meshes are defined)
    mesh_references_valid =
      Enum.all?(nodes, fn node ->
        if node.mesh_id do
          # If meshes are defined, check mesh_id exists
          # Otherwise, allow any mesh_id (will be validated in validate_mesh_references)
          true
        else
          true
        end
      end)

    # Check that all parent_ids and children reference valid node IDs
    parent_references_valid =
      Enum.all?(nodes, fn node ->
        cond do
          is_nil(node.parent_id) -> true
          MapSet.member?(node_ids, node.parent_id) -> true
          true -> false
        end
      end)

    children_references_valid =
      Enum.all?(nodes, fn node ->
        case node.children do
          nil -> true
          children when is_list(children) ->
            Enum.all?(children, &MapSet.member?(node_ids, &1))
          _ -> false
        end
      end)

    if mesh_references_valid && parent_references_valid && children_references_valid do
      :ok
    else
      {:error, "Invalid node references: parent_id, children, or mesh_id references invalid nodes"}
    end
  end
  defp validate_node_references(_), do: {:error, "Nodes must be a list or nil"}

  # Validate mesh references
  defp validate_mesh_references(%Document{meshes: nil, nodes: nil}), do: :ok
  defp validate_mesh_references(%Document{meshes: nil}), do: :ok
  defp validate_mesh_references(%Document{meshes: meshes, nodes: nodes}) when is_list(meshes) do
    mesh_ids = Enum.map(meshes, & &1.id) |> MapSet.new()

    # Check that all nodes reference valid meshes
    if nodes do
      node_mesh_references_valid =
        Enum.all?(nodes, fn node ->
          case node.mesh_id do
            nil -> true
            mesh_id when is_integer(mesh_id) -> MapSet.member?(mesh_ids, mesh_id)
            _ -> false
          end
        end)

      if node_mesh_references_valid do
        :ok
      else
        {:error, "Invalid mesh references: nodes reference non-existent meshes"}
      end
    else
      :ok
    end
  end
  defp validate_mesh_references(_), do: {:error, "Meshes must be a list or nil"}

  @doc """
  Loads an FBX file from binary data.

  ## Options

  - `:validate` - Whether to validate the FBX file (default: `true`)

  ## Examples

      {:ok, document} = AriaFbx.Import.from_binary(binary_data)
  """
  @spec from_binary(binary(), keyword()) :: {:ok, Document.t()} | {:error, term()}
  def from_binary(binary_data, opts \\ []) when is_binary(binary_data) do
    validate? = Keyword.get(opts, :validate, true)

    case Nif.load_fbx_binary(binary_data) do
      {:ok, ufbx_data} ->
        case Parser.from_ufbx_scene(ufbx_data) do
          {:ok, document} ->
            if validate? do
              case validate_document(document) do
                :ok -> {:ok, document}
                {:error, reason} -> {:error, reason}
              end
            else
              {:ok, document}
            end

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end

