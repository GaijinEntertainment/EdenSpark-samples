// Tiled JSON map parsing (https://doc.mapeditor.org/en/stable/reference/json-map-format/).
//
// Loads maps exported from the Tiled editor as JSON (.tmj) together with their external
// tilesets (.tsj) and resolves tile gids to textures and UV rects. Rendering/spawning
// lives in tiled_scene.das; this module is pure data.
//
// Supported: orthogonal, isometric and hexagonal maps, tile layers with plain (CSV)
// tile data, object layers, atlas tilesets (margin/spacing aware) and image-collection
// tilesets, typed object properties, horizontal/vertical tile flips.
// Not supported: compressed tile data (export with "Tile Layer Format: CSV"),
// staggered maps, embedded tilesets, XML object templates (enable "Detach templates" in
// Tiled's export options), object layers on isometric/hexagonal maps (object pixel
// coordinates use a different projection than tile layers on those orientations - see
// tiled_cell_origin_px in this module). See the main.das header for the full Tiled
// export checklist.
//
// Optional Tiled fields (visible, opacity, parallaxx/parallaxy, ...) get their values
// from the das struct field initializers below when absent in the JSON - from_json runs
// the generated struct ctor on array elements before filling them.

// keeps generated struct constructors alive so from_json can apply field initializers
// to array elements (TiledLayer etc. are never constructed explicitly in script code,
// so dead code elimination would otherwise strip their ctors)
options always_export_initializer

require engine.core
require strings

// --- gid flip flags (stored in the high bits of tile gids) ---

let TILED_FLIP_H = 0x80000000u   //! tile is flipped horizontally
let TILED_FLIP_V = 0x40000000u   //! tile is flipped vertically
let TILED_FLIP_D = 0x20000000u   //! tile is flipped anti-diagonally (rotation)
let TILED_GID_MASK = 0x0FFFFFFFu //! masks the flag bits off, leaving the tile id (Tiled
                                 //! reserves the top 4 bits; 0x10000000 is hex-120-rotation)

// --- structures matching the Tiled JSON format ---

struct TiledPoint {
    x : float
    y : float
}

variant TiledPropertyValue {
    s : string
    f : double
    b : bool
}

struct TiledProperty {
    name : string
    @rename = "type"
    type_ : string
    value : TiledPropertyValue
}

struct TiledObject {
    id : int
    name : string
    @rename = "type"
    type_ : string
    gid : uint             //! 0 = shape object (rect/polygon/point), else tile id + flip flags
    x : float              //! pixels; for tile objects this is the bottom-left corner
    y : float
    width : float          //! pixels
    height : float
    rotation : float       //! degrees, clockwise around (x, y)
    visible : bool = true
    ellipse : bool
    point : bool
    polygon : array<TiledPoint>
    polyline : array<TiledPoint>
    properties : array<TiledProperty>
}

struct TiledLayer {
    id : int
    name : string
    @rename = "type"
    type_ : string          //! "tilelayer" or "objectgroup"
    visible : bool = true
    opacity : float = 1f
    offsetx : float         //! pixels
    offsety : float
    parallaxx : float = 1f  //! 1 = scrolls with the world, 0 = fixed to the camera
    parallaxy : float = 1f
    width : int             //! tile layers only, in tiles
    height : int
    data : array<uint>      //! tile layers only: gids row by row (uint - flip flags use the high bit)
    objects : array<TiledObject>
}

struct TiledTilesetRef {
    firstgid : int
    source : string         //! tileset file path relative to the map file
}

struct TiledMap {
    width : int             //! in tiles
    height : int
    tilewidth : int         //! tile size in pixels
    tileheight : int
    orientation : string    //! "orthogonal", "isometric" or "hexagonal"
    backgroundcolor : string //! "#RRGGBB" or "#AARRGGBB", empty if not set
    parallaxoriginx : float
    parallaxoriginy : float
    hexsidelength : int     //! hexagonal maps only: length of the hex's flat side, in pixels
    staggeraxis : string    //! hexagonal maps only: "x" or "y" - which axis alternates rows/columns
    staggerindex : string   //! hexagonal maps only: "odd" or "even" - which index is shifted
    layers : array<TiledLayer>
    tilesets : array<TiledTilesetRef>
}

struct TiledTilesetTile {
    //! per-tile record; in image-collection tilesets each tile has its own image
    id : int
    image : string
    imagewidth : int
    imageheight : int
}

struct TiledTileOffset {
    x : int                 //! pixels, right
    y : int                 //! pixels, down
}

struct TiledTileset {
    name : string
    columns : int
    margin : int            //! pixels around the atlas edge
    spacing : int           //! pixels between atlas tiles
    tilewidth : int
    tileheight : int
    tilecount : int
    image : string          //! atlas tilesets only; empty for image collections
    imagewidth : int
    imageheight : int
    tileoffset : TiledTileOffset //! shifts drawn tiles relative to their cell (0,0 if not set) -
                                 //! isometric/hexagonal tilesets commonly use this since their
                                 //! tile images are taller than the map's tilewidth x tileheight
                                 //! cell (see TiledTileView.offsetPx in this module)
    tiles : array<TiledTilesetTile>
}

// --- loaded map: the map plus its resolved tilesets ---

struct TiledTilesetData {
    firstgid : uint
    baseDir : string        //! directory of the tileset file; tile images are relative to it
    ts : TiledTileset
}

struct TiledMapData {
    map : TiledMap
    tilesets : array<TiledTilesetData> //! sorted by firstgid (Tiled writes them sorted)
}

// --- path helpers ---

def dir_name(path : string) : string {
    //! "maps/desert/desert.tmj" -> "maps/desert"
    var lastSlash = -1
    var idx = find(path, "/")
    while (idx >= 0) {
        lastSlash = idx
        idx = find(path, "/", idx + 1)
    }
    return lastSlash < 0 ? "" : slice(path, 0, lastSlash)
}

def join_path(base : string; rel : string) : string {
    return empty(base) ? rel : "{base}/{rel}"
}

def private resolve_tileset_source(source : string) : string {
    //! Maps keep tileset references exactly as authored in Tiled (usually "<name>.tsx").
    //! The engine only imports .txt/.json as text assets, so converted tilesets live on
    //! disk as "<name>.tsj.json" - resolve the authored reference to that file name.
    if (ends_with(source, ".tsx") || ends_with(source, ".tsj")) {
        return "{slice(source, 0, length(source) - 4)}.tsj.json"
    }
    if (!ends_with(source, ".json")) {
        return "{source}.json"
    }
    return source
}

// --- loading ---

def load_tiled_map(path : string; var out_data : TiledMapData&) : bool {
    //! Loads a Tiled JSON map and all its external tilesets.
    //!
    //! :param path: project-relative path to the map file (the engine imports text assets
    //!              only as .txt/.json, so converted maps are named "<name>.tmj.json")
    //! :param out_data: receives the parsed map
    //!
    //! :returns: true on success
    var mapOk = false
    get_text_asset(request_text(path)) $(content) {
        from_json(string(content), out_data.map)
        mapOk = true
    }
    if (!mapOk || out_data.map.width <= 0 || out_data.map.height <= 0 || out_data.map.tilewidth <= 0 || out_data.map.tileheight <= 0) {
        error("tiled_map: can't load map \"{path}\"")
        return false
    }
    let mapDir = dir_name(path)
    for (tsRef in out_data.map.tilesets) {
        // the source may carry a directory prefix; tile images are relative to the tileset file
        let tsPath = join_path(mapDir, resolve_tileset_source(tsRef.source))
        var tsData = TiledTilesetData(firstgid = uint(tsRef.firstgid), baseDir = dir_name(tsPath))
        var tsOk = false
        get_text_asset(request_text(tsPath)) $(content) {
            from_json(string(content), tsData.ts)
            tsOk = true
        }
        if (!tsOk) {
            error("tiled_map: can't load tileset \"{tsPath}\" referenced by \"{path}\"")
            return false
        }
        out_data.tilesets |> emplace(tsData)
    }
    return true
}

// --- gid resolution ---

struct TiledTileView {
    //! everything needed to draw one tile: texture, UV sub-rect and source size
    found : bool
    texPath : string        //! project-relative texture path
    uv : float4             //! SpriteRenderer uvRect: .xy = uv offset, .zw = uv scale
    sizePx : float2         //! tile source size in pixels
    spriteId : int          //! tilemap id
                            //! only) - used when the texture was sliced with the Sprite Editor
    offsetPx : float2       //! tileset tileoffset in pixels (x right, y down) - see TiledTileOffset
}

def private atlas_uv(ts : TiledTileset; local_id : int) : float4 {
    // Atlas-edge bleeding into a neighboring tile's margin/spacing pixels is guarded by
    // sprite_shader itself (clamps to the tile's own rect), so no half-texel inset is needed here.
    let col = local_id % ts.columns
    let row = local_id / ts.columns
    let px = float(ts.margin + col * (ts.tilewidth + ts.spacing))
    let py = float(ts.margin + row * (ts.tileheight + ts.spacing))
    let iw = float(ts.imagewidth)
    let ih = float(ts.imageheight)
    return float4(px / iw, 1f - (py + float(ts.tileheight)) / ih, float(ts.tilewidth) / iw, float(ts.tileheight) / ih)
}

def find_tileset_index(data : TiledMapData; tile_id : uint) : int {
    //! :returns: index of the tileset owning `tile_id` (gid without flip flags), or -1
    var res = -1
    for (i in range(0, length(data.tilesets))) {
        if (tile_id >= data.tilesets[i].firstgid) {
            res = i
        }
    }
    return res
}

def resolve_tile(data : TiledMapData; raw_gid : uint) : TiledTileView {
    //! Resolves a raw gid (flip flags allowed) to a texture path + UV rect.
    var res = TiledTileView(spriteId = -1)
    let id = raw_gid & TILED_GID_MASK
    if (id == 0u) {
        return res
    }
    let tsIdx = find_tileset_index(data, id)
    if (tsIdx < 0) {
        return res
    }
    let localId = int(id - data.tilesets[tsIdx].firstgid)
    res.offsetPx = float2(float(data.tilesets[tsIdx].ts.tileoffset.x), float(data.tilesets[tsIdx].ts.tileoffset.y))
    if (!empty(data.tilesets[tsIdx].ts.image)) {
        // atlas tileset: cut the tile out of one image
        if (localId >= data.tilesets[tsIdx].ts.tilecount) {
            return res
        }
        res.found = true
        res.texPath = join_path(data.tilesets[tsIdx].baseDir, data.tilesets[tsIdx].ts.image)
        res.uv = atlas_uv(data.tilesets[tsIdx].ts, localId)
        res.sizePx = float2(float(data.tilesets[tsIdx].ts.tilewidth), float(data.tilesets[tsIdx].ts.tileheight))
        res.spriteId = localId
    } else {
        // image-collection tileset: each tile is its own image
        for (tile in data.tilesets[tsIdx].ts.tiles) {
            if (tile.id == localId) {
                res.found = true
                res.texPath = join_path(data.tilesets[tsIdx].baseDir, tile.image)
                res.uv = float4(0f, 0f, 1f, 1f)
                res.sizePx = float2(float(tile.imagewidth), float(tile.imageheight))
                break
            }
        }
    }
    return res
}

// --- tile cell placement (orientation-aware) ---

def tiled_y_unit_px(map : TiledMap) : int {
    //! Pixels per world unit vertically. map.tileheight for orthogonal/hexagonal; isometric
    //! uses tilewidth instead, since tilewidth != tileheight there by design (e.g. 64x32 for a
    //! 2:1 diamond) while the camera projects world units isotropically - using tileheight
    //! would distort every isometric sprite and grid step relative to the other axis.
    return map.orientation == "isometric" ? map.tilewidth : map.tileheight
}

// Returns the top-left pixel corner (Tiled screen space, Y down) of a tile layer cell's
// tilewidth x tileheight bounding box - the same role (col*tilewidth, row*tileheight) plays
// for orthogonal maps. Formulas match Tiled's own IsometricRenderer/HexagonalRenderer (libtiled).
//
// Object layers are not covered: Tiled projects object x/y through a different per-orientation
// pixel space than tile layers (see IsometricRenderer::pixelToScreenCoords) - isometric/hexagonal
// maps with object layers will place objects incorrectly.
def tiled_cell_origin_px(map : TiledMap; col : int; row : int) : float2 {
    if (map.orientation == "isometric") {
        let originX = float(map.height) * float(map.tilewidth) * 0.5f
        let topX = (float(col) - float(row)) * float(map.tilewidth) * 0.5f + originX
        let topY = (float(col) + float(row)) * float(map.tileheight) * 0.5f
        return float2(topX - float(map.tilewidth) * 0.5f, topY)
    }
    if (map.orientation == "hexagonal") {
        let staggerX = map.staggeraxis == "x"
        let staggerEven = map.staggerindex == "even"
        let sideLenX = staggerX ? map.hexsidelength : 0
        let sideLenY = staggerX ? 0 : map.hexsidelength
        let sideOffX = (map.tilewidth - sideLenX) / 2
        let sideOffY = (map.tileheight - sideLenY) / 2
        let columnWidth = sideOffX + sideLenX
        let rowHeight = sideOffY + sideLenY
        if (staggerX) {
            let doStaggerX = ((col & 1) != 0) != staggerEven
            var py = row * map.tileheight
            if (doStaggerX) {
                py += rowHeight
            }
            return float2(float(col * columnWidth), float(py))
        } else {
            let doStaggerY = ((row & 1) != 0) != staggerEven
            var px = col * map.tilewidth
            if (doStaggerY) {
                px += columnWidth
            }
            return float2(float(px), float(row * rowHeight))
        }
    }
    // orthogonal (default)
    return float2(float(col * map.tilewidth), float(row * map.tileheight))
}

def tiled_world_size(map : TiledMap) : float2 {
    //! Map size in world units (tiles), accounting for the non-rectangular bounding boxes
    //! of isometric (diamond) and hexagonal (staggered) maps. Orthogonal maps are simply
    //! (map.width, map.height).
    if (map.orientation == "isometric") {
        let side = float(map.width + map.height)
        let widthPx = side * float(map.tilewidth) * 0.5f
        let heightPx = side * float(map.tileheight) * 0.5f
        return float2(widthPx / float(map.tilewidth), heightPx / float(tiled_y_unit_px(map)))
    }
    if (map.orientation == "hexagonal") {
        let staggerX = map.staggeraxis == "x"
        let sideLenX = staggerX ? map.hexsidelength : 0
        let sideLenY = staggerX ? 0 : map.hexsidelength
        let sideOffX = (map.tilewidth - sideLenX) / 2
        let sideOffY = (map.tileheight - sideLenY) / 2
        let columnWidth = sideOffX + sideLenX
        let rowHeight = sideOffY + sideLenY
        var widthPx = 0
        var heightPx = 0
        if (staggerX) {
            widthPx = map.width * columnWidth + sideOffX
            heightPx = map.height * (map.tileheight + sideLenY)
            if (map.width > 1) {
                heightPx += rowHeight
            }
        } else {
            widthPx = map.width * (map.tilewidth + sideLenX)
            if (map.height > 1) {
                widthPx += columnWidth
            }
            heightPx = map.height * rowHeight + sideOffY
        }
        return float2(float(widthPx) / float(map.tilewidth), float(heightPx) / float(map.tileheight))
    }
    // orthogonal (default)
    return float2(float(map.width), float(map.height))
}

// --- properties ---

def get_property_string(obj : TiledObject; prop_name : string) : string {
    for (p in obj.properties) {
        if (p.name == prop_name) {
            return p.value ?as s ?? ""
        }
    }
    return ""
}

def get_property_float(obj : TiledObject; prop_name : string; def_value = 0f) : float {
    for (p in obj.properties) {
        if (p.name == prop_name) {
            return float(p.value ?as f ?? double(def_value))
        }
    }
    return def_value
}

// --- misc ---

def parse_tiled_color(color : string) : float4 {
    //! Parses Tiled's "#RRGGBB" / "#AARRGGBB" color strings. Alpha defaults to 1.
    let hexStr = starts_with(color, "#") ? slice(color, 1) : color
    var result : ConversionResult
    var offset = 0
    let v = uint(hexStr, result, offset, true)
    if (result != ConversionResult.ok) {
        return float4(1f)
    }
    let r = float((v >> 16u) & 0xFFu) / 255f
    let g = float((v >> 8u) & 0xFFu) / 255f
    let b = float(v & 0xFFu) / 255f
    let a = length(hexStr) > 6 ? float((v >> 24u) & 0xFFu) / 255f : 1f
    return float4(r, g, b, a)
}
