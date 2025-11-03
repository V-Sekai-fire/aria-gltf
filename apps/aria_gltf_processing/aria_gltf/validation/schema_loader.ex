# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Validation.SchemaLoader do
  @moduledoc """
  Loads and caches glTF 2.0 JSON schema files.

  This module loads JSON schema files from the glTF specification directory
  and provides them for validation. Schemas are cached after first load.
  """

  alias AriaGltf.Validation.SchemaCache

  @schema_base_path Path.join([
                      :code.priv_dir(:aria_gltf_processing),
                      "../../thirdparty/glTF/specification/2.0/schema"
                    ])

  @doc """
  Loads the main glTF schema.

  ## Returns

  `{:ok, schema_map}` or `{:error, reason}`

  ## Examples

      {:ok, schema} = AriaGltf.Validation.SchemaLoader.load_gltf_schema()
  """
  @spec load_gltf_schema() :: {:ok, map()} | {:error, term()}
  def load_gltf_schema do
    load_schema("glTF.schema.json")
  end

  @doc """
  Loads a schema file by name.

  ## Parameters

  - `schema_name`: Name of the schema file (e.g., "accessor.schema.json")

  ## Returns

  `{:ok, schema_map}` or `{:error, reason}`

  ## Examples

      {:ok, schema} = AriaGltf.Validation.SchemaLoader.load_schema("accessor.schema.json")
  """
  @spec load_schema(String.t()) :: {:ok, map()} | {:error, term()}
  def load_schema(schema_name) when is_binary(schema_name) do
    # Check cache first
    case SchemaCache.get(schema_name) do
      nil ->
        # Load from file
        load_schema_from_file(schema_name)

      cached_schema ->
        {:ok, cached_schema}
    end
  end

  @doc """
  Preloads all glTF core schemas into cache.

  This improves validation performance by loading all schemas upfront.

  ## Returns

  `:ok` or `{:error, reason}`

  ## Examples

      :ok = AriaGltf.Validation.SchemaLoader.preload_schemas()
  """
  @spec preload_schemas() :: :ok | {:error, term()}
  def preload_schemas do
    core_schemas = [
      "glTF.schema.json",
      "asset.schema.json",
      "accessor.schema.json",
      "buffer.schema.json",
      "bufferView.schema.json",
      "camera.schema.json",
      "image.schema.json",
      "material.schema.json",
      "mesh.schema.json",
      "node.schema.json",
      "sampler.schema.json",
      "scene.schema.json",
      "skin.schema.json",
      "texture.schema.json",
      "animation.schema.json"
    ]

    results =
      core_schemas
      |> Enum.map(&load_schema/1)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      :ok
    else
      errors = Enum.filter(results, &match?({:error, _}, &1))
      {:error, {:preload_failed, errors}}
    end
  end

  @doc """
  Gets the base path where schema files are located.

  ## Returns

  String path to schema directory

  ## Examples

      path = AriaGltf.Validation.SchemaLoader.schema_base_path()
  """
  @spec schema_base_path() :: String.t()
  def schema_base_path do
    @schema_base_path
    |> Enum.filter(& &1)
    |> Path.join()
    |> Path.expand()
  end

  # Load schema from file and cache it
  defp load_schema_from_file(schema_name) do
    schema_path = Path.join(schema_base_path(), schema_name)

    case File.read(schema_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, schema} ->
            # Cache the schema
            SchemaCache.put(schema_name, schema)
            {:ok, schema}

          {:error, reason} ->
            {:error, {:json_parse_error, reason}}
        end

      {:error, reason} ->
        {:error, {:file_read_error, reason, schema_path}}
    end
  end

  @doc """
  Clears the schema cache.

  Useful for testing or when schemas need to be reloaded.

  ## Examples

      AriaGltf.Validation.SchemaLoader.clear_cache()
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    SchemaCache.clear()
    :ok
  end
end

