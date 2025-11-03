/* SPDX-License-Identifier: MIT
 * Copyright (c) 2025-present K. S. Ernest (iFire) Lee
 */

#include <erl_nif.h>
#include <string.h>
#include "../thirdparty/ufbx/ufbx.h"

// Helper: Convert ufbx_vec3 to Elixir list [x, y, z]
static ERL_NIF_TERM make_vec3(ErlNifEnv* env, ufbx_vec3 vec) {
    ERL_NIF_TERM x = enif_make_double(env, vec.x);
    ERL_NIF_TERM y = enif_make_double(env, vec.y);
    ERL_NIF_TERM z = enif_make_double(env, vec.z);
    return enif_make_list3(env, x, y, z);
}

// Helper: Convert ufbx_vec4/quat to Elixir list [x, y, z, w]
static ERL_NIF_TERM make_vec4(ErlNifEnv* env, ufbx_vec4 vec) {
    ERL_NIF_TERM x = enif_make_double(env, vec.x);
    ERL_NIF_TERM y = enif_make_double(env, vec.y);
    ERL_NIF_TERM z = enif_make_double(env, vec.z);
    ERL_NIF_TERM w = enif_make_double(env, vec.w);
    return enif_make_list4(env, x, y, z, w);
}

// Helper: Convert ufbx_string to Elixir binary
static ERL_NIF_TERM make_string(ErlNifEnv* env, ufbx_string str) {
    if (str.length == 0) {
        return enif_make_string(env, "", ERL_NIF_LATIN1);
    }
    // Allocate binary and copy string data
    ErlNifBinary bin;
    if (!enif_alloc_binary(str.length, &bin)) {
        return enif_make_atom(env, "error");
    }
    memcpy(bin.data, str.data, str.length);
    ERL_NIF_TERM result = enif_make_binary(env, &bin);
    return result;
}

// Helper: Convert ufbx_vec3_list to Elixir list
static ERL_NIF_TERM make_vec3_list(ErlNifEnv* env, ufbx_vec3_list list) {
    ERL_NIF_TERM result = enif_make_list(env, 0);
    for (size_t i = list.count; i > 0; i--) {
        ERL_NIF_TERM vec = make_vec3(env, list.data[i - 1]);
        result = enif_make_list_cell(env, vec, result);
    }
    return result;
}

// Helper: Convert ufbx_uint32_list to Elixir list
static ERL_NIF_TERM make_uint32_list(ErlNifEnv* env, ufbx_uint32_list list) {
    ERL_NIF_TERM result = enif_make_list(env, 0);
    for (size_t i = list.count; i > 0; i--) {
        ERL_NIF_TERM val = enif_make_uint(env, list.data[i - 1]);
        result = enif_make_list_cell(env, val, result);
    }
    return result;
}

// Extract node data from ufbx_node to Elixir map
static ERL_NIF_TERM extract_node(ErlNifEnv* env, ufbx_node *node, uint32_t node_id) {
    ERL_NIF_TERM keys[10];
    ERL_NIF_TERM values[10];
    size_t idx = 0;
    
    // id
    keys[idx] = enif_make_atom(env, "id");
    values[idx] = enif_make_uint(env, node_id);
    idx++;
    
    // name
    keys[idx] = enif_make_atom(env, "name");
    values[idx] = make_string(env, node->name);
    idx++;
    
    // parent_id (if parent exists, use parent's typed_id)
    if (node->parent) {
        keys[idx] = enif_make_atom(env, "parent_id");
        values[idx] = enif_make_uint(env, node->parent->typed_id);
        idx++;
    }
    
    // children (list of typed_ids)
    if (node->children.count > 0) {
        ERL_NIF_TERM children = enif_make_list(env, 0);
        for (size_t i = node->children.count; i > 0; i--) {
            ERL_NIF_TERM child_id = enif_make_uint(env, node->children.data[i - 1]->typed_id);
            children = enif_make_list_cell(env, child_id, children);
        }
        keys[idx] = enif_make_atom(env, "children");
        values[idx] = children;
        idx++;
    }
    
    // translation from local_transform
    keys[idx] = enif_make_atom(env, "translation");
    values[idx] = make_vec3(env, node->local_transform.translation);
    idx++;
    
    // rotation from local_transform (quaternion)
    keys[idx] = enif_make_atom(env, "rotation");
    ufbx_vec4 rot_vec4;
    rot_vec4.x = node->local_transform.rotation.x;
    rot_vec4.y = node->local_transform.rotation.y;
    rot_vec4.z = node->local_transform.rotation.z;
    rot_vec4.w = node->local_transform.rotation.w;
    values[idx] = make_vec4(env, rot_vec4);
    idx++;
    
    // scale from local_transform
    keys[idx] = enif_make_atom(env, "scale");
    values[idx] = make_vec3(env, node->local_transform.scale);
    idx++;
    
    // mesh_id (if mesh exists)
    if (node->mesh) {
        keys[idx] = enif_make_atom(env, "mesh_id");
        values[idx] = enif_make_uint(env, node->mesh->typed_id);
        idx++;
    }
    
    // Build map manually for compatibility
    ERL_NIF_TERM map = enif_make_new_map(env);
    for (size_t i = 0; i < idx; i++) {
        enif_make_map_put(env, map, keys[i], values[i], &map);
    }
    return map;
}

// Extract mesh data from ufbx_mesh to Elixir map
static ERL_NIF_TERM extract_mesh(ErlNifEnv* env, ufbx_mesh *mesh) {
    ERL_NIF_TERM keys[10];
    ERL_NIF_TERM values[10];
    size_t idx = 0;
    
    // id
    keys[idx] = enif_make_atom(env, "id");
    values[idx] = enif_make_uint(env, mesh->typed_id);
    idx++;
    
    // name
    keys[idx] = enif_make_atom(env, "name");
    values[idx] = make_string(env, mesh->name);
    idx++;
    
    // positions (from vertex_position)
    if (mesh->vertex_position.exists && mesh->vertex_position.values.count > 0) {
        ERL_NIF_TERM positions = make_vec3_list(env, mesh->vertex_position.values);
        keys[idx] = enif_make_atom(env, "positions");
        values[idx] = positions;
        idx++;
        
        // indices (from vertex_position.indices)
        if (mesh->vertex_position.indices.count > 0) {
            ERL_NIF_TERM indices = make_uint32_list(env, mesh->vertex_position.indices);
            keys[idx] = enif_make_atom(env, "indices");
            values[idx] = indices;
            idx++;
        }
    }
    
    // normals (from vertex_normal)
    if (mesh->vertex_normal.exists && mesh->vertex_normal.values.count > 0) {
        ERL_NIF_TERM normals = make_vec3_list(env, mesh->vertex_normal.values);
        keys[idx] = enif_make_atom(env, "normals");
        values[idx] = normals;
        idx++;
    }
    
    // texcoords (from vertex_uv)
    if (mesh->vertex_uv.exists && mesh->vertex_uv.values.count > 0) {
        ERL_NIF_TERM texcoords = enif_make_list(env, 0);
        for (size_t i = mesh->vertex_uv.values.count; i > 0; i--) {
            ufbx_vec2 uv = mesh->vertex_uv.values.data[i - 1];
            ERL_NIF_TERM u = enif_make_double(env, uv.x);
            ERL_NIF_TERM v = enif_make_double(env, uv.y);
            ERL_NIF_TERM uv_vec = enif_make_list2(env, u, v);
            texcoords = enif_make_list_cell(env, uv_vec, texcoords);
        }
        keys[idx] = enif_make_atom(env, "texcoords");
        values[idx] = texcoords;
        idx++;
    }
    
    // material_ids
    if (mesh->materials.count > 0) {
        ERL_NIF_TERM material_ids = enif_make_list(env, 0);
        for (size_t i = mesh->materials.count; i > 0; i--) {
            ERL_NIF_TERM mat_id = enif_make_uint(env, mesh->materials.data[i - 1]->typed_id);
            material_ids = enif_make_list_cell(env, mat_id, material_ids);
        }
        keys[idx] = enif_make_atom(env, "material_ids");
        values[idx] = material_ids;
        idx++;
    }
    
    // Build map manually for compatibility
    ERL_NIF_TERM map = enif_make_new_map(env);
    for (size_t i = 0; i < idx; i++) {
        enif_make_map_put(env, map, keys[i], values[i], &map);
    }
    return map;
}

// Extract material data from ufbx_material to Elixir map
static ERL_NIF_TERM extract_material(ErlNifEnv* env, ufbx_material *material) {
    ERL_NIF_TERM keys[10];
    ERL_NIF_TERM values[10];
    size_t idx = 0;
    
    // id
    keys[idx] = enif_make_atom(env, "id");
    values[idx] = enif_make_uint(env, material->typed_id);
    idx++;
    
    // name
    keys[idx] = enif_make_atom(env, "name");
    values[idx] = make_string(env, material->name);
    idx++;
    
    // diffuse_color (from PBR base_color or FBX diffuse)
    if (material->pbr.base_color.has_value && material->pbr.base_color.value_components >= 3) {
        ufbx_vec3 color = material->pbr.base_color.value_vec3;
        keys[idx] = enif_make_atom(env, "diffuse_color");
        values[idx] = make_vec3(env, color);
        idx++;
    } else if (material->fbx.diffuse_color.has_value && material->fbx.diffuse_color.value_components >= 3) {
        ufbx_vec3 color = material->fbx.diffuse_color.value_vec3;
        keys[idx] = enif_make_atom(env, "diffuse_color");
        values[idx] = make_vec3(env, color);
        idx++;
    }
    
    // specular_color (from PBR specular_color or FBX)
    if (material->pbr.specular_color.has_value && material->pbr.specular_color.value_components >= 3) {
        ufbx_vec3 color = material->pbr.specular_color.value_vec3;
        keys[idx] = enif_make_atom(env, "specular_color");
        values[idx] = make_vec3(env, color);
        idx++;
    } else if (material->fbx.specular_color.has_value && material->fbx.specular_color.value_components >= 3) {
        ufbx_vec3 color = material->fbx.specular_color.value_vec3;
        keys[idx] = enif_make_atom(env, "specular_color");
        values[idx] = make_vec3(env, color);
        idx++;
    }
    
    // emissive_color (from PBR emission_color or FBX)
    if (material->pbr.emission_color.has_value && material->pbr.emission_color.value_components >= 3) {
        ufbx_vec3 color = material->pbr.emission_color.value_vec3;
        keys[idx] = enif_make_atom(env, "emissive_color");
        values[idx] = make_vec3(env, color);
        idx++;
    } else if (material->fbx.emission_color.has_value && material->fbx.emission_color.value_components >= 3) {
        ufbx_vec3 color = material->fbx.emission_color.value_vec3;
        keys[idx] = enif_make_atom(env, "emissive_color");
        values[idx] = make_vec3(env, color);
        idx++;
    }
    
    // Build map manually for compatibility
    ERL_NIF_TERM map = enif_make_new_map(env);
    for (size_t i = 0; i < idx; i++) {
        enif_make_map_put(env, map, keys[i], values[i], &map);
    }
    return map;
}

// Extract texture data from ufbx_texture to Elixir map
static ERL_NIF_TERM extract_texture(ErlNifEnv* env, ufbx_texture *texture) {
    ERL_NIF_TERM keys[5];
    ERL_NIF_TERM values[5];
    size_t idx = 0;
    
    // id
    keys[idx] = enif_make_atom(env, "id");
    values[idx] = enif_make_uint(env, texture->typed_id);
    idx++;
    
    // name
    keys[idx] = enif_make_atom(env, "name");
    values[idx] = make_string(env, texture->name);
    idx++;
    
    // file_path (from filename)
    if (texture->filename.length > 0) {
        keys[idx] = enif_make_atom(env, "file_path");
        values[idx] = make_string(env, texture->filename);
        idx++;
    }
    
    // Build map manually for compatibility
    ERL_NIF_TERM map = enif_make_new_map(env);
    for (size_t i = 0; i < idx; i++) {
        enif_make_map_put(env, map, keys[i], values[i], &map);
    }
    return map;
}

// Extract keyframe from ufbx_baked_vec3 to Elixir map (translation/scale)
static ERL_NIF_TERM extract_vec3_keyframe(ErlNifEnv* env, ufbx_baked_vec3 *key, const char* field_name) {
    ERL_NIF_TERM keys[2];
    ERL_NIF_TERM values[2];
    
    keys[0] = enif_make_atom(env, "time");
    values[0] = enif_make_double(env, key->time);
    
    keys[1] = enif_make_atom(env, field_name);
    values[1] = make_vec3(env, key->value);
    
    ERL_NIF_TERM map = enif_make_new_map(env);
    enif_make_map_put(env, map, keys[0], values[0], &map);
    enif_make_map_put(env, map, keys[1], values[1], &map);
    
    return map;
}

// Extract keyframe from ufbx_baked_quat to Elixir map (rotation)
static ERL_NIF_TERM extract_quat_keyframe(ErlNifEnv* env, ufbx_baked_quat *key) {
    ERL_NIF_TERM keys[2];
    ERL_NIF_TERM values[2];
    
    keys[0] = enif_make_atom(env, "time");
    values[0] = enif_make_double(env, key->time);
    
    // Convert ufbx_quat to vec4 format [x, y, z, w]
    keys[1] = enif_make_atom(env, "rotation");
    ERL_NIF_TERM x = enif_make_double(env, key->value.x);
    ERL_NIF_TERM y = enif_make_double(env, key->value.y);
    ERL_NIF_TERM z = enif_make_double(env, key->value.z);
    ERL_NIF_TERM w = enif_make_double(env, key->value.w);
    values[1] = enif_make_list4(env, x, y, z, w);
    
    ERL_NIF_TERM map = enif_make_new_map(env);
    enif_make_map_put(env, map, keys[0], values[0], &map);
    enif_make_map_put(env, map, keys[1], values[1], &map);
    
    return map;
}

// Extract animation data from ufbx_baked_anim to Elixir map
static ERL_NIF_TERM extract_animation(ErlNifEnv* env, ufbx_baked_anim *baked, ufbx_anim_stack *anim_stack) {
    ERL_NIF_TERM keys[4];
    ERL_NIF_TERM values[4];
    size_t idx = 0;
    
    // id (use anim_stack typed_id)
    keys[idx] = enif_make_atom(env, "id");
    values[idx] = enif_make_uint(env, anim_stack->typed_id);
    idx++;
    
    // name
    keys[idx] = enif_make_atom(env, "name");
    values[idx] = make_string(env, anim_stack->name);
    idx++;
    
    // Extract keyframes per node
    ERL_NIF_TERM all_keyframes = enif_make_list(env, 0);
    
    for (size_t i = baked->nodes.count; i > 0; i--) {
        ufbx_baked_node *baked_node = &baked->nodes.data[i - 1];
        uint32_t node_id = baked_node->typed_id;
        
        // Extract translation keyframes
        for (size_t j = baked_node->translation_keys.count; j > 0; j--) {
            ufbx_baked_vec3 *trans_key = &baked_node->translation_keys.data[j - 1];
            ERL_NIF_TERM keyframe = extract_vec3_keyframe(env, trans_key, "translation");
            
            // Add node_id to keyframe
            ERL_NIF_TERM keyframe_map = enif_make_new_map(env);
            ERL_NIF_TERM node_id_key = enif_make_atom(env, "node_id");
            ERL_NIF_TERM node_id_val = enif_make_uint(env, node_id);
            enif_make_map_put(env, keyframe_map, node_id_key, node_id_val, &keyframe_map);
            
            // Copy keyframe fields into map
            ERL_NIF_TERM value;
            if (enif_get_map_value(env, keyframe, enif_make_atom(env, "time"), &value)) {
                enif_make_map_put(env, keyframe_map, enif_make_atom(env, "time"), value, &keyframe_map);
            }
            if (enif_get_map_value(env, keyframe, enif_make_atom(env, "translation"), &value)) {
                enif_make_map_put(env, keyframe_map, enif_make_atom(env, "translation"), value, &keyframe_map);
            }
            
            all_keyframes = enif_make_list_cell(env, keyframe_map, all_keyframes);
        }
        
        // Extract rotation keyframes
        for (size_t j = baked_node->rotation_keys.count; j > 0; j--) {
            ufbx_baked_quat *rot_key = &baked_node->rotation_keys.data[j - 1];
            ERL_NIF_TERM keyframe = extract_quat_keyframe(env, rot_key);
            
            // Add node_id to keyframe
            ERL_NIF_TERM keyframe_map = enif_make_new_map(env);
            ERL_NIF_TERM node_id_key = enif_make_atom(env, "node_id");
            ERL_NIF_TERM node_id_val = enif_make_uint(env, node_id);
            enif_make_map_put(env, keyframe_map, node_id_key, node_id_val, &keyframe_map);
            
            // Copy keyframe fields into map
            ERL_NIF_TERM value;
            if (enif_get_map_value(env, keyframe, enif_make_atom(env, "time"), &value)) {
                enif_make_map_put(env, keyframe_map, enif_make_atom(env, "time"), value, &keyframe_map);
            }
            if (enif_get_map_value(env, keyframe, enif_make_atom(env, "rotation"), &value)) {
                enif_make_map_put(env, keyframe_map, enif_make_atom(env, "rotation"), value, &keyframe_map);
            }
            
            all_keyframes = enif_make_list_cell(env, keyframe_map, all_keyframes);
        }
        
        // Extract scale keyframes
        for (size_t j = baked_node->scale_keys.count; j > 0; j--) {
            ufbx_baked_vec3 *scale_key = &baked_node->scale_keys.data[j - 1];
            ERL_NIF_TERM keyframe = extract_vec3_keyframe(env, scale_key, "scale");
            
            // Add node_id to keyframe
            ERL_NIF_TERM keyframe_map = enif_make_new_map(env);
            ERL_NIF_TERM node_id_key = enif_make_atom(env, "node_id");
            ERL_NIF_TERM node_id_val = enif_make_uint(env, node_id);
            enif_make_map_put(env, keyframe_map, node_id_key, node_id_val, &keyframe_map);
            
            // Copy keyframe fields into map
            ERL_NIF_TERM value;
            if (enif_get_map_value(env, keyframe, enif_make_atom(env, "time"), &value)) {
                enif_make_map_put(env, keyframe_map, enif_make_atom(env, "time"), value, &keyframe_map);
            }
            if (enif_get_map_value(env, keyframe, enif_make_atom(env, "scale"), &value)) {
                enif_make_map_put(env, keyframe_map, enif_make_atom(env, "scale"), value, &keyframe_map);
            }
            
            all_keyframes = enif_make_list_cell(env, keyframe_map, all_keyframes);
        }
    }
    
    // keyframes
    keys[idx] = enif_make_atom(env, "keyframes");
    values[idx] = all_keyframes;
    idx++;
    
    // Build map manually
    ERL_NIF_TERM map = enif_make_new_map(env);
    for (size_t i = 0; i < idx; i++) {
        enif_make_map_put(env, map, keys[i], values[i], &map);
    }
    
    return map;
}

// Helper: Extract scene data from ufbx_scene to Elixir map
static ERL_NIF_TERM extract_scene_data(ErlNifEnv* env, ufbx_scene *scene) {
    // Build nodes list
    ERL_NIF_TERM nodes = enif_make_list(env, 0);
    for (size_t i = scene->nodes.count; i > 0; i--) {
        ufbx_node *node = scene->nodes.data[i - 1];
        ERL_NIF_TERM node_term = extract_node(env, node, node->typed_id);
        nodes = enif_make_list_cell(env, node_term, nodes);
    }
    
    // Build meshes list
    ERL_NIF_TERM meshes = enif_make_list(env, 0);
    for (size_t i = scene->meshes.count; i > 0; i--) {
        ufbx_mesh *mesh = scene->meshes.data[i - 1];
        ERL_NIF_TERM mesh_term = extract_mesh(env, mesh);
        meshes = enif_make_list_cell(env, mesh_term, meshes);
    }
    
    // Build materials list
    ERL_NIF_TERM materials = enif_make_list(env, 0);
    for (size_t i = scene->materials.count; i > 0; i--) {
        ufbx_material *material = scene->materials.data[i - 1];
        ERL_NIF_TERM material_term = extract_material(env, material);
        materials = enif_make_list_cell(env, material_term, materials);
    }
    
    // Build textures list
    ERL_NIF_TERM textures = enif_make_list(env, 0);
    for (size_t i = scene->textures.count; i > 0; i--) {
        ufbx_texture *texture = scene->textures.data[i - 1];
        ERL_NIF_TERM texture_term = extract_texture(env, texture);
        textures = enif_make_list_cell(env, texture_term, textures);
    }
    
    // Extract animations from anim_stacks
    ERL_NIF_TERM animations = enif_make_list(env, 0);
    ufbx_bake_opts bake_opts = {0};
    bake_opts.resample_rate = 30.0; // 30 FPS default
    
    for (size_t i = scene->anim_stacks.count; i > 0; i--) {
        ufbx_anim_stack *anim_stack = scene->anim_stacks.data[i - 1];
        
        // Bake animation
        ufbx_error error;
        ufbx_baked_anim *baked = ufbx_bake_anim(scene, anim_stack->anim, &bake_opts, &error);
        
        if (baked) {
            ERL_NIF_TERM animation_term = extract_animation(env, baked, anim_stack);
            animations = enif_make_list_cell(env, animation_term, animations);
            ufbx_free_baked_anim(baked);
        }
    }
    
    // Build version string from metadata
    char version_str[32];
    snprintf(version_str, sizeof(version_str), "FBX %u.%u", 
             scene->metadata.version / 1000, 
             (scene->metadata.version % 1000) / 100);
    
    // Build result map
    ERL_NIF_TERM keys[6];
    ERL_NIF_TERM values[6];
    keys[0] = enif_make_atom(env, "version");
    values[0] = enif_make_string(env, version_str, ERL_NIF_LATIN1);
    keys[1] = enif_make_atom(env, "nodes");
    values[1] = nodes;
    keys[2] = enif_make_atom(env, "meshes");
    values[2] = meshes;
    keys[3] = enif_make_atom(env, "materials");
    values[3] = materials;
    keys[4] = enif_make_atom(env, "textures");
    values[4] = textures;
    keys[5] = enif_make_atom(env, "animations");
    values[5] = animations;
    
    // Build map manually for compatibility
    ERL_NIF_TERM scene_data = enif_make_new_map(env);
    for (size_t i = 0; i < 6; i++) {
        enif_make_map_put(env, scene_data, keys[i], values[i], &scene_data);
    }
    
    return scene_data;
}

static ERL_NIF_TERM load_fbx_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    ErlNifBinary file_path_bin;
    ufbx_error error;
    ufbx_scene *scene;
    
    // Get file path from Elixir
    if (!enif_inspect_binary(env, argv[0], &file_path_bin)) {
        return enif_make_badarg(env);
    }
    
    // Null-terminate the path
    char file_path[file_path_bin.size + 1];
    memcpy(file_path, file_path_bin.data, file_path_bin.size);
    file_path[file_path_bin.size] = '\0';
    
    // Load FBX file using ufbx
    ufbx_load_opts opts = { 0 };
    scene = ufbx_load_file(file_path, &opts, &error);
    
    if (!scene) {
        // Return error tuple
        return enif_make_tuple2(env,
            enif_make_atom(env, "error"),
            enif_make_string(env, error.description.data, ERL_NIF_LATIN1));
    }
    
    // Extract scene data
    ERL_NIF_TERM scene_data = extract_scene_data(env, scene);
    
    // Free scene
    ufbx_free_scene(scene);
    
    // Return ok tuple with scene data
    return enif_make_tuple2(env,
        enif_make_atom(env, "ok"),
        scene_data);
}

// Load FBX from binary data
static ERL_NIF_TERM load_fbx_binary_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    ErlNifBinary data_bin;
    ufbx_error error;
    ufbx_scene *scene;
    
    // Get binary data from Elixir
    if (!enif_inspect_binary(env, argv[0], &data_bin)) {
        return enif_make_badarg(env);
    }
    
    // Load FBX from memory using ufbx
    ufbx_load_opts opts = { 0 };
    scene = ufbx_load_memory(data_bin.data, data_bin.size, &opts, &error);
    
    if (!scene) {
        // Return error tuple
        return enif_make_tuple2(env,
            enif_make_atom(env, "error"),
            enif_make_string(env, error.description.data, ERL_NIF_LATIN1));
    }
    
    // Extract scene data
    ERL_NIF_TERM scene_data = extract_scene_data(env, scene);
    
    // Free scene
    ufbx_free_scene(scene);
    
    // Return ok tuple with scene data
    return enif_make_tuple2(env,
        enif_make_atom(env, "ok"),
        scene_data);
}

static ErlNifFunc nif_funcs[] = {
    {"load_fbx", 1, load_fbx_nif},
    {"load_fbx_binary", 1, load_fbx_binary_nif}
};

ERL_NIF_INIT(Elixir.AriaFbx.Nif, nif_funcs, NULL, NULL, NULL, NULL)
