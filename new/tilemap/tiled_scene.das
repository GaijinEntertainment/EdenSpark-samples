// Spawns a parsed Tiled map (see tiled_map.das) into the scene as sprite nodes.
//
// World mapping: 1 tile = 1 world unit, Tiled pixel Y (down) is flipped to world Y (up),
// so the map occupies world rect (0, 0)..(TiledScene.worldSize) with (0, 0) at the
// bottom-left corner (tiled_world_size in tiled_map.das accounts for the diamond-shaped
// bounding box of isometric maps and the staggered rows/columns of hexagonal maps - it
// is not simply (map.width, map.height) outside the orthogonal case). Layers keep their
// order via SpriteRenderer.renderOrder.
//
// Tile layers become one sprite node per non-empty cell, object layers become one sprite
// per tile object (gid != 0). Shape objects (collision rects, polygons, spawn points)
// are not spawned - they are gameplay data; draw_tiled_objects_debug shows them.
//
// Atlas tiles prefer the engine's Sprite system: slice the tileset texture in the Sprite
// Editor (default "<texture>_<index>" names match Tiled's tile ids) and tiles render via
// spriteId; textures without sprites fall back to uvRect cutting.

require engine.core
require engine.math.quaternion
require tiled_map

struct TiledSceneLayer {
    node : NodeId
    basePos : float3        //! layer node position before the parallax offset
    parallax : float2
}

struct TiledScene {
    //! spawned map: the root node plus what's needed for parallax and camera setup
    root : NodeId
    worldSize : float2      //! map size in world units (tiles)
    parallaxOrigin : float2 //! world point the parallax offsets are relative to
    layers : array<TiledSceneLayer>
}

def private add_tile_sprite(node : NodeId; view : TiledTileView; color : float4; flip_x, flip_y : bool; order : int) {
    //! Attaches a SpriteRenderer for the resolved tile: prefers an engine Sprite when the
    //! atlas was sliced in the Sprite Editor, otherwise cuts the tile out with a UV rect.
    let sprite = view.spriteId < 0 ? SpriteId() : request_sprite(view.texPath, view.spriteId)
    if (valid(sprite)) {
        add_component(node, new SpriteRenderer(
            spriteId = sprite,
            color = color,
            flipX = flip_x,
            flipY = flip_y,
            useTextureSizeForScaling = false,
            renderOrder = order
        ))
    } else {
        add_component(node, new SpriteRenderer(
            textureId = request_texture(view.texPath),
            uvRect = view.uv,
            color = color,
            flipX = flip_x,
            flipY = flip_y,
            useTextureSizeForScaling = false,
            renderOrder = order
        ))
    }
}

def tiled_pixel_to_world(map : TiledMap; px : float; py : float) : float3 {
    //! Converts a point from Tiled pixel coordinates (Y down) to world coordinates (Y up).
    //! Y is flipped against tiled_world_size's height, not map.height (the tile count) - the
    //! two only coincide for orthogonal maps; isometric/hexagonal have a different world-space
    //! height than their tile count. Also see tiled_y_unit_px for the per-pixel divisor.
    return float3(px / float(map.tilewidth), tiled_world_size(map).y - py / float(tiled_y_unit_px(map)), 0f)
}

def spawn_tiled_map(data : TiledMapData; map_name : string) : TiledScene {
    //! Spawns all visible layers of the map under a new root node named `map_name`.
    var scene = TiledScene(
        root = create_node(NodeData(name = map_name)),
        worldSize = tiled_world_size(data.map)
    )
    let origin = tiled_pixel_to_world(data.map, data.map.parallaxoriginx, data.map.parallaxoriginy)
    scene.parallaxOrigin = float2(origin.x, origin.y)
    var order = 0
    for (layer in data.map.layers) {
        if (layer.visible && (layer.type_ == "tilelayer" || layer.type_ == "objectgroup")) {
            spawn_layer(data, layer, order, scene)
        }
        order++
    }
    return <- scene
}

def private spawn_layer(data : TiledMapData; layer : TiledLayer; order : int; var scene : TiledScene) {
    let basePos = float3(layer.offsetx / float(data.map.tilewidth), -layer.offsety / float(data.map.tileheight), 0f)
    let layerNode = create_node(NodeData(name = layer.name, parent = scene.root, position = basePos))
    scene.layers |> push(TiledSceneLayer(node = layerNode, basePos = basePos, parallax = float2(layer.parallaxx, layer.parallaxy)))
    if (layer.type_ == "tilelayer") {
        spawn_tile_layer(data, layer, layerNode, order)
    } else {
        spawn_object_layer(data, layer, layerNode, order)
    }
}

def private spawn_tile_layer(data : TiledMapData; layer : TiledLayer; parent : NodeId; order : int) {
    let color = float4(1f, 1f, 1f, layer.opacity)
    for (row in range(0, layer.height)) {
        for (col in range(0, layer.width)) {
            let idx = row * layer.width + col
            if (idx >= length(layer.data)) {
                continue
            }
            let raw = layer.data[idx]
            let view = resolve_tile(data, raw)
            if (!view.found) {
                if ((raw & TILED_GID_MASK) != 0u) {
                    print("tiled_scene: unresolved gid {raw & TILED_GID_MASK} at {col},{row} in layer \"{layer.name}\"\n")
                }
                continue
            }
            if ((raw & TILED_FLIP_D) != 0u) {
                print("tiled_scene: diagonal flip is not supported (tile {col},{row} in layer \"{layer.name}\")\n")
            }
            // top-left pixel corner of this cell's tilewidth x tileheight bounding box (orientation-aware)
            let originPx = tiled_cell_origin_px(data.map, col, row)
            let cellBottomLeft = tiled_pixel_to_world(data.map, originPx.x, originPx.y + float(data.map.tileheight))
            // oversized tiles (tile art bigger than the cell - common for hex/isometric
            // tilesets) are anchored to the cell's bottom-left, then nudged by tileoffset
            let w = view.sizePx.x / float(data.map.tilewidth)
            let h = view.sizePx.y / float(tiled_y_unit_px(data.map))
            let offsetX = view.offsetPx.x / float(data.map.tilewidth)
            let offsetY = view.offsetPx.y / float(tiled_y_unit_px(data.map))
            let node = create_node(NodeData(
                name = "tile_{col}_{row}",
                parent = parent,
                position = float3(cellBottomLeft.x + w * 0.5f + offsetX, cellBottomLeft.y + h * 0.5f - offsetY, 0f),
                scale = float3(w, h, 1f)
            ))
            add_tile_sprite(node, view, color, (raw & TILED_FLIP_H) != 0u, (raw & TILED_FLIP_V) != 0u, order)
        }
    }
}

def private spawn_object_layer(data : TiledMapData; layer : TiledLayer; parent : NodeId; order : int) {
    let color = float4(1f, 1f, 1f, layer.opacity)
    for (obj in layer.objects) {
        if (!obj.visible || obj.gid == 0u) {
            continue
        }
        let view = resolve_tile(data, obj.gid)
        if (!view.found) {
            print("tiled_scene: unresolved gid {obj.gid & TILED_GID_MASK} for object \"{obj.name}\" (id {obj.id})\n")
            continue
        }
        // tile objects: (x, y) is the bottom-left corner, rotation is clockwise around it;
        // explicit width/height stretch the tile image
        let w = (obj.width > 0f ? obj.width : view.sizePx.x) / float(data.map.tilewidth)
        let h = (obj.height > 0f ? obj.height : view.sizePx.y) / float(tiled_y_unit_px(data.map))
        let offsetX = view.offsetPx.x / float(data.map.tilewidth)
        let offsetY = view.offsetPx.y / float(tiled_y_unit_px(data.map))
        let objNode = create_node(NodeData(
            name = empty(obj.name) ? "obj_{obj.id}" : obj.name,
            parent = parent,
            position = tiled_pixel_to_world(data.map, obj.x, obj.y),
            rotation = quat4(0f, 0f, -obj.rotation * TO_RAD)
        ))
        let spriteNode = create_node(NodeData(
            name = "sprite",
            parent = objNode,
            position = float3(w * 0.5f + offsetX, h * 0.5f - offsetY, 0f),
            scale = float3(w, h, 1f)
        ))
        add_tile_sprite(spriteNode, view, color, (obj.gid & TILED_FLIP_H) != 0u, (obj.gid & TILED_FLIP_V) != 0u, order)
    }
}

def update_tiled_parallax(scene : TiledScene; camera_pos : float2) {
    //! Applies Tiled layer parallax: call once per frame with the camera world position.
    //! Layers with parallax factor 1 (the default) are never touched.
    for (l in scene.layers) {
        if (l.parallax.x != 1f || l.parallax.y != 1f) {
            let off = (camera_pos - scene.parallaxOrigin) * (float2(1f, 1f) - l.parallax)
            l.node.localPosition = l.basePos + float3(off.x, off.y, 0f)
        }
    }
}

def draw_tiled_objects_debug(data : TiledMapData; color : float4 = float4(1f, 1f, 0f, 1f)) {
    //! Debug-draws shape objects (rects, polygons, points) of visible object layers -
    //! the gameplay data that spawn_tiled_map deliberately does not turn into sprites.
    //! Layer offsets/parallax are not applied here.
    for (layer in data.map.layers) {
        if (!layer.visible || layer.type_ != "objectgroup") {
            continue
        }
        for (obj in layer.objects) {
            if (!obj.visible || obj.gid != 0u) {
                continue
            }
            if (!empty(obj.polygon)) {
                for (i in range(0, length(obj.polygon))) {
                    let j = (i + 1) % length(obj.polygon)
                    let w0 = tiled_pixel_to_world(data.map, obj.x + obj.polygon[i].x, obj.y + obj.polygon[i].y)
                    let w1 = tiled_pixel_to_world(data.map, obj.x + obj.polygon[j].x, obj.y + obj.polygon[j].y)
                    draw_line(w0, w1, color, 1)
                }
            } elif (!empty(obj.polyline)) {
                for (i in range(0, length(obj.polyline) - 1)) {
                    let w0 = tiled_pixel_to_world(data.map, obj.x + obj.polyline[i].x, obj.y + obj.polyline[i].y)
                    let w1 = tiled_pixel_to_world(data.map, obj.x + obj.polyline[i + 1].x, obj.y + obj.polyline[i + 1].y)
                    draw_line(w0, w1, color, 1)
                }
            } elif (obj.width > 0f || obj.height > 0f) {
                let c0 = tiled_pixel_to_world(data.map, obj.x, obj.y)
                let c1 = tiled_pixel_to_world(data.map, obj.x + obj.width, obj.y)
                let c2 = tiled_pixel_to_world(data.map, obj.x + obj.width, obj.y + obj.height)
                let c3 = tiled_pixel_to_world(data.map, obj.x, obj.y + obj.height)
                draw_line(c0, c1, color, 1)
                draw_line(c1, c2, color, 1)
                draw_line(c2, c3, color, 1)
                draw_line(c3, c0, color, 1)
                if (!empty(obj.name)) {
                    let mid = tiled_pixel_to_world(data.map, obj.x + obj.width * 0.5f, obj.y - 8f)
                    draw_debug_text(obj.name, mid, color, 1, 14f)
                }
            } else {
                let wp = tiled_pixel_to_world(data.map, obj.x, obj.y)
                draw_line(wp - float3(0.2f, 0f, 0f), wp + float3(0.2f, 0f, 0f), color, 1)
                draw_line(wp - float3(0f, 0.2f, 0f), wp + float3(0f, 0.2f, 0f), color, 1)
                if (!empty(obj.name)) {
                    draw_debug_text(obj.name, wp + float3(0f, 0.3f, 0f), color, 1, 14f)
                }
            }
        }
    }
}
