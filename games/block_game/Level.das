require engine.core

// Map dimensions
let level_width  : int = 32
let level_height : int = 16
let level_depth  : int = 32

// Terrain shape (perlin_noise returns [0..1])
let SURFACE_BASE      : int   = 4
let SURFACE_VARIATION : int   = 2
let NOISE_SCALE       : float = 0.15

// Prop spawning — one prop per chunk
let CHUNK_SIZE   : int = 8
let TRUNK_HEIGHT : int = 4


struct Prop {
    x : int = -1
    z : int = -1
}


////  Hash for prop placement  ////////////////////////////////////////////////

def prop_hash(ix : int, iy : int) : int {
    var n = ix * 1619 + iy * 31337 + 1013904223
    n ^= n >> 8
    n *= 1664525
    n ^= n >> 8
    return n & 255
}


////  Surface height  /////////////////////////////////////////////////////////

def get_surface_y(xRaw : int, zRaw : int) : int {
    let noiseVal = perlin_noise(float2(float(xRaw) * NOISE_SCALE, float(zRaw) * NOISE_SCALE))
    return SURFACE_BASE + int(noiseVal * float(SURFACE_VARIATION))
}


////  Chunk prop spawning  ////////////////////////////////////////////////////

let PROP_BBOX_RADIUS : int = 2

def prop_x_in_chunk(cx : int, cz : int) : int {
    return 1 + (prop_hash(cx, cz) % (CHUNK_SIZE - 2))
}

def prop_z_in_chunk(cx : int, cz : int) : int {
    return 1 + (prop_hash(cx ^ 127, cz ^ 255) % (CHUNK_SIZE - 2))
}

// XZ bbox check only — no Y. Returns the prop covering (xRaw, zRaw), or Prop() if none.
def find_prop_for(xRaw : int, zRaw : int) : Prop {
    let cx = xRaw / CHUNK_SIZE
    let cz = zRaw / CHUNK_SIZE
    let numChunksX = level_width  / CHUNK_SIZE
    let numChunksZ = level_depth  / CHUNK_SIZE
    var result = Prop()
    for (dcx in -1 .. 2) {
        for (dcz in -1 .. 2) {
            if (result.x >= 0) {
                continue
            }
            let ncx = cx + dcx
            let ncz = cz + dcz
            if (ncx < 0 || ncz < 0 || ncx >= numChunksX || ncz >= numChunksZ) {
                continue
            }
            let propX = ncx * CHUNK_SIZE + prop_x_in_chunk(ncx, ncz)
            let propZ = ncz * CHUNK_SIZE + prop_z_in_chunk(ncx, ncz)
            let dx = (xRaw >= propX ? xRaw - propX : propX - xRaw)
            let dz = (zRaw >= propZ ? zRaw - propZ : propZ - zRaw)
            if (dx <= PROP_BBOX_RADIUS && dz <= PROP_BBOX_RADIUS) {
                result = Prop(x = propX, z = propZ)
            }
        }
    }
    return result
}


////  Per-prop block generation  /////////////////////////////////////////////

def get_tree_block(xRaw : int, yRaw : int, zRaw : int, propX : int, propZ : int) : string {
    let trunkBase = get_surface_y(propX, propZ) + 1
    let trunkTop  = trunkBase + TRUNK_HEIGHT - 1
    let dx = (xRaw >= propX ? xRaw - propX : propX - xRaw)
    let dz = (zRaw >= propZ ? zRaw - propZ : propZ - zRaw)
    if (dx == 0 && dz == 0 && yRaw >= trunkBase && yRaw <= trunkTop) {
        return "w"
    }
    if (yRaw >= trunkTop - 1 && yRaw <= trunkTop + 1) {
        if (yRaw == trunkTop + 1) {
            if (dx <= 1 && dz <= 1) {
                return "l"
            }
        } elif (dx <= 2 && dz <= 2 && (dx < 2 || dz < 2)) {
            return "l"
        }
    }
    return "a"
}


////  Block type query  ///////////////////////////////////////////////////////

def get_block_type(xRaw : int, yRaw : int, zRaw : int) : string {
    let surfaceY = get_surface_y(xRaw, zRaw)
    if (yRaw > surfaceY) {
        let prop = find_prop_for(xRaw, zRaw)
        if (prop.x >= 0) {
            return get_tree_block(xRaw, yRaw, zRaw, prop.x, prop.z)
        }
        return "a"
    } elif (yRaw == surfaceY) {
        return "g"
    } elif (yRaw >= surfaceY - 2) {
        return "d"
    } else {
        return "r"
    }
}
