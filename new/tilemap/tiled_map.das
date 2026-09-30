// Tiled map parsing (https://doc.mapeditor.org/en/stable/reference/) - loads .tmj/.tsj (JSON)
// or .tmx/.tsx (XML) transparently into TiledMapData and resolves gids to textures/UV rects.
// Rendering lives in tiled_scene.das; this module is pure data.
//
// Supported: orthogonal/isometric/hexagonal maps; tile layers as CSV or base64 (zlib/gzip/zstd
// compressed, decoded on load); object layers; embedded and external atlas + image-collection
// tilesets; XML object templates (.tx); typed object properties; tile flips. Not supported:
// object layers on iso/hex maps (different projection than tile layers).
//
// The XML path parses into Tmx* structs (an exact mirror of the TMX/TSX element layout, filled
// by the single from_xml convention) and converts them to the Tiled* structs the JSON path
// fills directly. Everything below Tiled* is XML-only machinery hidden behind load_tiled_map.

// keeps generated struct ctors alive so from_json/from_xml apply field-initializer defaults to
// array elements (structs never constructed explicitly in script would otherwise lose them)
options always_export_initializer

require engine.core
require strings
require daslib/strings_boost // split_by_chars
require public_base64        // base64_decode for base64-encoded tile payloads
require public_compress      // decompress for gzip/zlib-compressed tile payloads
require engine.resources.texture_resource_boost // get_texture_size (atlas size when the tsx omits it)

// --- gid flip flags (stored in the high bits of tile gids) ---

let TILED_FLIP_H = 0x80000000u   //! flipped horizontally
let TILED_FLIP_V = 0x40000000u   //! flipped vertically
let TILED_FLIP_D = 0x20000000u   //! flipped anti-diagonally (rotation)
let TILED_GID_MASK = 0x0FFFFFFFu //! masks off the top-4 flag bits, leaving the tile id

// --- Tiled* structs: the parsed map (shared by the JSON and XML paths) ---

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
    gid : uint             //! 0 = shape object, else tile id + flip flags
    x : float              //! pixels; for tile objects the bottom-left corner
    y : float
    width : float
    height : float
    rotation : float       //! degrees, clockwise
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
    offsetx : float
    offsety : float
    parallaxx : float = 1f  //! 1 = scrolls with the world, 0 = fixed to the camera
    parallaxy : float = 1f
    width : int             //! tile layers only, in tiles
    height : int
    data : array<uint>      //! tile layers only: gids row by row (flip flags in the high bit)
    objects : array<TiledObject>
}

struct TiledTilesetRef {
    firstgid : int
    source : string         //! external tileset file path (empty for an embedded tileset)
    embedded : bool         //! true if the tileset is inlined in the map (no external file)
    inline_ts : TiledTileset //! the embedded tileset's data (valid when `embedded`)
}

struct TiledMap {
    width : int             //! in tiles
    height : int
    tilewidth : int         //! pixels
    tileheight : int
    orientation : string    //! "orthogonal" / "isometric" / "hexagonal"
    backgroundcolor : string //! "#RRGGBB" or "#AARRGGBB", empty if unset
    parallaxoriginx : float
    parallaxoriginy : float
    hexsidelength : int     //! hex maps only
    staggeraxis : string    //! hex maps only: "x" or "y"
    staggerindex : string   //! hex maps only: "odd" or "even"
    layers : array<TiledLayer>
    tilesets : array<TiledTilesetRef>
}

struct TiledTilesetTile {
    //! per-tile record; image-collection tilesets give each tile its own image
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
    margin : int
    spacing : int
    tilewidth : int
    tileheight : int
    tilecount : int
    image : string          //! atlas tilesets only; empty for image collections
    imagewidth : int
    imageheight : int
    tileoffset : TiledTileOffset //! shifts drawn tiles vs their cell (iso/hex use this)
    tiles : array<TiledTilesetTile>
}

struct TiledTilesetData {
    firstgid : uint
    baseDir : string        //! directory of the tileset file; tile images are relative to it
    ts : TiledTileset
}

struct TiledMapData {
    map : TiledMap
    tilesets : array<TiledTilesetData> //! sorted by firstgid
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

// --- gid resolution ---

struct TiledTileView {
    //! everything needed to draw one tile: texture, UV sub-rect and source size
    found : bool
    texPath : string        //! project-relative texture path
    uv : float4             //! SpriteRenderer uvRect: .xy = offset, .zw = scale
    sizePx : float2         //! tile source size in pixels
    spriteId : int          //! tilemap id (atlas only), matches Sprite Editor slice index
    offsetPx : float2       //! tileset tileoffset in pixels (x right, y down)
}

def private atlas_uv(ts : TiledTileset; local_id : int) : float4 {
    // sprite_shader clamps to the tile's own rect, so no half-texel inset for margin/spacing bleed
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
    //! Pixels per vertical world unit. Isometric uses tilewidth (tilewidth != tileheight there
    //! by design, e.g. 64x32) so the isotropic camera doesn't distort sprites; others tileheight.
    return map.orientation == "isometric" ? map.tilewidth : map.tileheight
}

// Top-left pixel corner (Tiled screen space, Y down) of a cell's tilewidth x tileheight box -
// the (col*tilewidth, row*tileheight) of orthogonal maps. Formulas match libtiled's Iso/Hex
// renderers. Object layers on iso/hex are NOT covered (Tiled projects object x/y differently).
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
    //! Map size in world units, accounting for the diamond (iso) / staggered (hex) bounding box.
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

// ============================================================================================
// XML path: Tmx* structs mirror the TMX/TSX element layout so the single from_xml convention
// fills them directly, then convert to the Tiled* structs above. Convention (C++, do not edit):
//   flat field <- same-named attribute; struct field <- same-named child; array<T> <- repeated
//   same-named children; @xml_inner_text <- element text; @rename overrides the name.
// ============================================================================================

struct TmxEmpty {
    unused_ : bool          //! presence marker for empty <ellipse/> / <point/> children
}

struct TmxImage {
    @rename = "source"
    source : string
    width : int
    height : int
}

struct TmxData {
    @rename = "encoding"
    encoding : string        //! "csv" or "base64"
    @rename = "compression"
    compression : string     //! "" (base64 only), "zlib", "gzip" or "zstd"
    @xml_inner_text
    text : string            //! csv: comma-separated gids; base64: encoded (maybe compressed) bytes
}

struct TmxTileOffset {
    x : int
    y : int
}

struct TmxProperty {
    //! value is ALWAYS a string in XML; type (absent => "string") picks the variant arm
    name : string
    @rename = "type"
    type_ : string
    @rename = "value"
    value : string
}

struct TmxProperties {
    @rename = "property"
    property : array<TmxProperty> //! children of the <properties> wrapper
}

struct TmxPoly {
    @rename = "points"
    points : string         //! "x,y x,y ..." (parsed in the converter)
}

struct TmxObject {
    id : int
    name : string
    @rename = "type"
    type_ : string
    gid : uint
    x : float
    y : float
    width : float
    height : float
    rotation : float
    visible : bool = true
    @rename = "template"        //! `template` is a daslang keyword, so the field is template_
    template_ : string          //! .tx template ref; when set the object inherits it (see below)
    @rename = "ellipse"
    ellipse : array<TmxEmpty>   //! non-empty => the object is an ellipse
    @rename = "point"
    point : array<TmxEmpty>     //! non-empty => the object is a point
    @rename = "polygon"
    polygon : array<TmxPoly>
    @rename = "polyline"
    polyline : array<TmxPoly>
    properties : TmxProperties
}

struct TmxTemplate {
    //! root <template> of a .tx file: a base <object> + the <tileset> its gid belongs to.
    //! (.tx is native XML; Tiled never inlines templates into .tmx, so we resolve them here.)
    tileset : TmxTilesetRef        //! the template's own tileset ref (firstgid may differ from map's)
    object : TmxObject = TmxObject() //! base object; explicit ctor so its field defaults (visible=true) hold
}

struct TmxLayer {
    id : int
    name : string
    width : int
    height : int
    opacity : float = 1f
    visible : bool = true
    offsetx : float
    offsety : float
    data : TmxData
}

struct TmxObjectGroup {
    id : int
    name : string
    opacity : float = 1f
    visible : bool = true
    parallaxx : float = 1f
    parallaxy : float = 1f
    offsetx : float
    offsety : float
    @rename = "object"
    object : array<TmxObject>
}

struct TmxTilesetRef {
    firstgid : int
    source : string
}

struct TmxMap {
    //! <map> has both <layer> and <objectgroup> children; one array collects one tag, so they
    //! go into two arrays and the converter appends tile layers then object groups (interleave
    //! order between the two kinds is lost - fine for these samples, each map groups one kind)
    width : int
    height : int
    tilewidth : int
    tileheight : int
    orientation : string
    backgroundcolor : string
    parallaxoriginx : float
    parallaxoriginy : float
    hexsidelength : int
    staggeraxis : string
    staggerindex : string
    @rename = "layer"
    layer : array<TmxLayer>
    @rename = "objectgroup"
    objectgroup : array<TmxObjectGroup>
    @rename = "tileset"
    tileset : array<TmxTileset> //! external (source set) or embedded (inline image/tiles)
}

struct TmxTile {
    id : int
    image : TmxImage        //! nested <image>; absent for atlas <tile> records => stays zero
}

struct TmxTileset {
    name : string
    columns : int           //! 0 for image-collection tilesets
    margin : int
    spacing : int
    tilewidth : int
    tileheight : int
    tilecount : int
    firstgid : int          //! embedded tilesets only
    source : string         //! embedded tilesets only
    image : TmxImage        //! nested top-level <image> (atlas); empty for collections
    tileoffset : TmxTileOffset
    @rename = "tile"
    tile : array<TmxTile>
}

// --- XML parse helpers ---

def private parse_csv_gids(text : string) : array<uint> {
    //! Splits <data encoding="csv"> into gids (uint - flip flags live in the high bit).
    var res : array<uint>
    for (tok in split_by_chars(text, ", \t\n\r")) {
        if (empty(tok)) {
            continue
        }
        var result : ConversionResult
        var offset = 0
        let g = uint(tok, result, offset, false)
        if (result == ConversionResult.ok) {
            res |> push(g)
        }
    }
    return <- res
}

def private parse_binary_gids(bytes : array<uint8>) : array<uint> {
    //! Reads little-endian uint32 gids from a decoded <data encoding="base64"> payload (4 bytes each).
    var res : array<uint>
    let count = length(bytes) / 4
    res |> resize(count)
    for (i in range(count)) {
        let b = i * 4
        res[i] = uint(bytes[b]) | (uint(bytes[b + 1]) << 8u) | (uint(bytes[b + 2]) << 16u) | (uint(bytes[b + 3]) << 24u)
    }
    return <- res
}

def private decode_tile_data(d : TmxData; var gids : array<uint>&) : bool {
    //! Decodes a <data> element into gids. Handles csv and base64, optionally compressed
    //! with zlib, gzip or zstd (CompressFormat.Auto tells them apart by the stream header).
    if (d.encoding == "csv") {
        gids := parse_csv_gids(d.text)
        return true
    }
    if (d.encoding != "base64") {
        return false // unknown encoding (e.g. no encoding = raw <tile> children, not supported here)
    }
    var raw : array<uint8>
    base64_decode(d.text, raw)
    if (d.compression == "zlib" || d.compression == "gzip" || d.compression == "zstd") {
        var inflated : array<uint8>
        if (!decompress(raw, CompressFormat.Auto, inflated)) {
            return false
        }
        gids <- parse_binary_gids(inflated)
    } else {
        gids <- parse_binary_gids(raw) // base64, uncompressed
    }
    return true
}

def private parse_poly_points(points : string) : array<TiledPoint> {
    //! Splits a "x,y x,y ..." points attribute into TiledPoints, two numbers per point.
    var res : array<TiledPoint>
    var pending = 0f
    var haveX = false
    for (tok in split_by_chars(points, ", \t\n\r")) {
        if (empty(tok)) {
            continue
        }
        var result : ConversionResult
        var offset = 0
        let v = float(tok, result, offset)
        if (result != ConversionResult.ok) {
            continue
        }
        if (!haveX) {
            pending = v
            haveX = true
        } else {
            res |> push(TiledPoint(x = pending, y = v))
            haveX = false
        }
    }
    return <- res
}

def private build_property_value(type_ : string; value : string) : TiledPropertyValue {
    //! "bool" => b, "int"/"float" => f, anything else => s.
    if (type_ == "bool") {
        return TiledPropertyValue(b = value == "true")
    }
    if (type_ == "int" || type_ == "float") {
        var result : ConversionResult
        var offset = 0
        let d = double(value, result, offset)
        return TiledPropertyValue(f = result == ConversionResult.ok ? d : 0.0lf)
    }
    return TiledPropertyValue(s = value)
}

// --- Tmx* -> Tiled* converters ---

def private tmx_object_to_tiled(obj : TmxObject) : TiledObject {
    var res = TiledObject()
    res.id = obj.id
    res.name = obj.name
    res.type_ = obj.type_
    res.gid = obj.gid
    res.x = obj.x
    res.y = obj.y
    res.width = obj.width
    res.height = obj.height
    res.rotation = obj.rotation
    res.visible = obj.visible
    res.ellipse = !empty(obj.ellipse)
    res.point = !empty(obj.point)
    for (poly in obj.polygon) {
        res.polygon := parse_poly_points(poly.points)
    }
    for (poly in obj.polyline) {
        res.polyline := parse_poly_points(poly.points)
    }
    for (p in obj.properties.property) {
        let t = empty(p.type_) ? "string" : p.type_
        res.properties |> emplace(TiledProperty(name = p.name, type_ = t,
            value = build_property_value(p.type_, p.value)))
    }
    return <- res
}

def private tmx_to_tiled_map(tmx : TmxMap; var out : TiledMap) {
    out.width = tmx.width
    out.height = tmx.height
    out.tilewidth = tmx.tilewidth
    out.tileheight = tmx.tileheight
    out.orientation = tmx.orientation
    out.backgroundcolor = tmx.backgroundcolor
    out.parallaxoriginx = tmx.parallaxoriginx
    out.parallaxoriginy = tmx.parallaxoriginy
    out.hexsidelength = tmx.hexsidelength
    out.staggeraxis = tmx.staggeraxis
    out.staggerindex = tmx.staggerindex

    for (l in tmx.layer) {
        var tl = TiledLayer()
        tl.type_ = "tilelayer"
        tl.id = l.id
        tl.name = l.name
        tl.width = l.width
        tl.height = l.height
        tl.opacity = l.opacity
        tl.visible = l.visible
        tl.offsetx = l.offsetx
        tl.offsety = l.offsety
        decode_tile_data(l.data, tl.data)
        out.layers |> emplace(tl)
    }

    for (g in tmx.objectgroup) {
        var tl = TiledLayer()
        tl.type_ = "objectgroup"
        tl.id = g.id
        tl.name = g.name
        tl.opacity = g.opacity
        tl.visible = g.visible
        tl.offsetx = g.offsetx
        tl.offsety = g.offsety
        tl.parallaxx = g.parallaxx
        tl.parallaxy = g.parallaxy
        for (o in g.object) {
            tl.objects |> emplace(tmx_object_to_tiled(o))
        }
        out.layers |> emplace(tl)
    }

    for (ref in tmx.tileset) {
        if (empty(ref.source)) {
            var r = TiledTilesetRef(firstgid = ref.firstgid, embedded = true)
            tmx_to_tiled_tileset(ref, r.inline_ts)
            out.tilesets |> emplace(r)
        } else {
            out.tilesets |> emplace(TiledTilesetRef(firstgid = ref.firstgid, source = ref.source))
        }
    }
}

def private tmx_to_tiled_tileset(tmx : TmxTileset; var out : TiledTileset) {
    out.name = tmx.name
    out.columns = tmx.columns
    out.margin = tmx.margin
    out.spacing = tmx.spacing
    out.tilewidth = tmx.tilewidth
    out.tileheight = tmx.tileheight
    out.tilecount = tmx.tilecount
    out.image = tmx.image.source
    out.imagewidth = tmx.image.width
    out.imageheight = tmx.image.height
    out.tileoffset = TiledTileOffset(x = tmx.tileoffset.x, y = tmx.tileoffset.y)
    for (t in tmx.tile) {
        out.tiles |> emplace(TiledTilesetTile(id = t.id, image = t.image.source,
            imagewidth = t.image.width, imageheight = t.image.height))
    }
    derive_tileset_grid(out)
}

def private derive_tileset_grid(var ts : TiledTileset&) {
    //! Old-format atlas tilesets omit columns/tilecount; derive them from the atlas image size.
    if (empty(ts.image) || ts.tilewidth <= 0 || ts.tileheight <= 0) {
        return
    }
    if (ts.columns <= 0) {
        ts.columns = (ts.imagewidth - 2 * ts.margin + ts.spacing) / (ts.tilewidth + ts.spacing)
    }
    if (ts.tilecount <= 0 && ts.columns > 0) {
        let rows = (ts.imageheight - 2 * ts.margin + ts.spacing) / (ts.tileheight + ts.spacing)
        ts.tilecount = ts.columns * rows
    }
}

// --- loading (JSON + XML, transparent) ---

def private text_is_xml(text : string) : bool {
    //! Format by first non-whitespace byte: "<" = XML, else JSON. Beats trusting the extension.
    for (c in text) {
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
            continue
        }
        return c == '<'
    }
    return false
}

def private tileset_source_candidates(source : string; map_is_xml : bool) : array<string> {
    //! A .tmx and a .tmj reference the same tileset name (e.g. "desert.tsx"), but on disk the
    //! copies keep their format's extension (.tsx.xml vs .tsj.json). Try the map's format first.
    var res : array<string>
    let base = (ends_with(source, ".tsx") || ends_with(source, ".tsj")) ? slice(source, 0, length(source) - 4) : source
    if (map_is_xml) {
        res |> push("{base}.tsx.xml")
        res |> push("{base}.tsj.json")
    } else {
        res |> push("{base}.tsj.json")
        res |> push("{base}.tsx.xml")
    }
    if (!ends_with(source, ".json") && !ends_with(source, ".xml")) {
        res |> push("{source}.xml")
        res |> push("{source}.json")
    }
    res |> push(source)
    return <- res
}

def private template_source_candidates(source : string) : array<string> {
    //! .tx templates are XML; on disk they keep the content and gain ".xml" ("hero.tx.xml").
    var res : array<string>
    res |> push(ends_with(source, ".xml") ? source : "{source}.xml")
    res |> push(source)
    return <- res
}

def private merge_template(var inst : TmxObject; var tpl : TmxTemplate; map_firstgid : int) {
    //! Tiled never inlines templates into .tmx - an instance is just <object template=".." x y id>
    //! and inherits everything else from the .tx. Start from the template's base object, then
    //! overlay the instance's placement (x/y/id, plus rotation/name/type if the instance set
    //! them). The template's gid is in its own firstgid space; rebase it onto the map's.
    var merged <- tpl.object            // take ownership of the template's arrays/props
    merged.x = inst.x
    merged.y = inst.y
    merged.id = inst.id
    if (inst.rotation != 0f) {
        merged.rotation = inst.rotation
    }
    if (!empty(inst.name)) {
        merged.name := inst.name
    }
    if (!empty(inst.type_)) {
        merged.type_ := inst.type_
    }
    merged.template_ = ""
    if (merged.gid != 0u && tpl.tileset.firstgid != map_firstgid) {
        merged.gid = uint(int(merged.gid) - tpl.tileset.firstgid + map_firstgid)
    }
    inst <- merged
}

def private resolve_tmx_templates(var tmx : TmxMap; map_dir : string) {
    //! Loads each <object template=".tx"> and merges it in place. The map has one tileset ref
    //! for objects here, so its firstgid is the rebase target for template gids.
    let mapFirstgid = empty(tmx.tileset) ? 1 : tmx.tileset[0].firstgid
    for (g in tmx.objectgroup) {
        for (o in g.object) {
            if (empty(o.template_)) {
                continue
            }
            var loaded = false
            for (cand in template_source_candidates(join_path(map_dir, o.template_))) {
                get_text_asset(request_text(cand)) $(content) {
                    var tpl = TmxTemplate()
                    from_xml(string(content), tpl)
                    merge_template(o, tpl, mapFirstgid)
                    loaded = true
                }
                if (loaded) {
                    break
                }
            }
            if (!loaded) {
                error("tiled_map: can't load object template \"{o.template_}\"")
            }
        }
    }
}

def private parse_tiled_map_text(text : string; map_dir : string; var out : TiledMap&) : bool {
    if (text_is_xml(text)) {
        var tmx : TmxMap
        from_xml(text, tmx)
        resolve_tmx_templates(tmx, map_dir)
        tmx_to_tiled_map(tmx, out)
    } else {
        from_json(text, out)
    }
    return out.width > 0 && out.height > 0 && out.tilewidth > 0 && out.tileheight > 0
}

def private parse_tiled_tileset_text(text : string; var out : TiledTileset&) {
    if (text_is_xml(text)) {
        var tmx : TmxTileset
        from_xml(text, tmx)
        tmx_to_tiled_tileset(tmx, out)
    } else {
        from_json(text, out)
    }
}

def load_tiled_map(path : string; var out_data : TiledMapData&) : bool {
    //! Loads a Tiled map (JSON .tmj or XML .tmx) and its external tilesets, format-transparent.
    //! On-disk copies keep the Tiled export content but gain a text-asset extension the engine
    //! imports: "<name>.tmj.json" / "<name>.tsj.json" (JSON) or "<name>.tmx.xml" / ".tsx.xml".
    let mapDir = dir_name(path)
    var mapOk = false
    var mapIsXml = false
    get_text_asset(request_text(path)) $(content) {
        let text = string(content)
        mapIsXml = text_is_xml(text)
        mapOk = parse_tiled_map_text(text, mapDir, out_data.map)
    }
    if (!mapOk) {
        error("tiled_map: can't load map \"{path}\"")
        return false
    }
    for (tsRef in out_data.map.tilesets) {
        if (tsRef.embedded) {
            // inlined in the map; its tile images are relative to the map's own directory
            var tsData = TiledTilesetData(firstgid = uint(tsRef.firstgid), baseDir = mapDir)
            tsData.ts := tsRef.inline_ts
            out_data.tilesets |> emplace(tsData)
            continue
        }
        var tsOk = false
        for (cand in tileset_source_candidates(tsRef.source, mapIsXml)) {
            let tsPath = join_path(mapDir, cand)
            get_text_asset(request_text(tsPath)) $(content) {
                var tsData = TiledTilesetData(firstgid = uint(tsRef.firstgid), baseDir = dir_name(tsPath))
                parse_tiled_tileset_text(string(content), tsData.ts)
                out_data.tilesets |> emplace(tsData)
                tsOk = true
            }
            if (tsOk) {
                break
            }
        }
        if (!tsOk) {
            error("tiled_map: can't load tileset \"{tsRef.source}\" referenced by \"{path}\"")
            return false
        }
    }
    // Some old-format tilesets omit the atlas <image> width/height (and columns/tilecount). Fill
    // them from the actual texture so gid resolution works. Iterate by index to mutate in place.
    for (i in range(length(out_data.tilesets))) {
        if (empty(out_data.tilesets[i].ts.image) || out_data.tilesets[i].ts.imagewidth > 0) {
            continue
        }
        let texPath = join_path(out_data.tilesets[i].baseDir, out_data.tilesets[i].ts.image)
        get_texture_size(request_texture(texPath)) <| $(size : int2) {
            out_data.tilesets[i].ts.imagewidth = size.x
            out_data.tilesets[i].ts.imageheight = size.y
            derive_tileset_grid(out_data.tilesets[i].ts)
        }
    }
    return true
}
