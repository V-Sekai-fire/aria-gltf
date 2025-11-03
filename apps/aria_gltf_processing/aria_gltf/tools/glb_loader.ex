# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Tools.GlbLoader do
  @moduledoc """
  Enhanced GLB loader with desync chunking integration.
  
  Provides desync-based chunking and reassembly for efficient GLB storage.
  """

  require Logger
  alias AriaGltf.Import

  @desync_chunk_store "priv/desync_store"

  @doc """
  Loads a GLB file with optional desync chunking support.
  
  Attempts to load from desync store first, falls back to direct loading.
  """
  @spec load_glb(String.t(), keyword()) :: {:ok, AriaGltf.Document.t()} | {:error, term()}
  def load_glb(uri, opts \\ []) do
    use_desync = Keyword.get(opts, :use_desync, false)
    
    if use_desync && Code.ensure_loaded?(AriaStorage.Desync) do
      load_with_desync(uri, opts)
    else
      Import.from_file(uri, opts)
    end
  end

  defp load_with_desync(uri, opts) do
    alias AriaStorage.Desync
    
    index_path = Path.join(@desync_chunk_store, Path.basename(uri) <> ".caibx")
    output_path = Path.join(Path.dirname(uri), Path.basename(uri, ".glb") <> "_desync.glb")
    File.mkdir_p!(@desync_chunk_store)

    # Try desync extract first
    case Desync.extract(index_path, output_path, @desync_chunk_store) do
      {:ok, _stdout} ->
        Logger.info("Successfully extracted GLB from desync: #{output_path}")
        case Import.from_file(output_path, opts) do
          {:ok, document} ->
            {:ok, document}
          {:error, reason} ->
            Logger.warning("Failed to load reassembled GLB: #{reason}")
            fallback_to_direct_loading(uri, opts)
        end

      {:error, _reason} ->
        Logger.info("Desync extract failed, falling back to direct loading")
        fallback_to_direct_loading(uri, opts)
    end
  end

  defp fallback_to_direct_loading(uri, opts) do
    case Import.from_file(uri, opts) do
      {:ok, document} ->
        # Store in desync after loading (if available)
        if Code.ensure_loaded?(AriaStorage.Desync) do
          alias AriaStorage.Desync
          index_path = Path.join(@desync_chunk_store, Path.basename(uri) <> ".caibx")
          File.mkdir_p!(@desync_chunk_store)

          case Desync.make(uri, index_path, @desync_chunk_store) do
            {:ok, _stdout} ->
              {:ok, document}
            {:error, reason} ->
              Logger.warning("Failed to chunk GLB with desync: #{reason}")
              {:ok, document}
          end
        else
          {:ok, document}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end

