require engine.core
require engine.free_camera

let terrainFolderPath = "assets/terrain"

let worldScale = float3(1000f, 1f, 1000f)
let worldOffset = float3(-worldScale.x, 0f, -worldScale.z) * 0.5f
let worldSize = float3(worldScale.x, 100f, worldScale.z)

let waterHeight = 2f

let grassTexOffset = 0u
let grassTexCnt = 2u
let grassNoiseFrequency = 0.3f
let rockTexOffset = grassTexOffset + grassTexCnt
let rockTexCnt = 2u
let rockNoiseFrequency = 0.5f

var freeCamera : NodeId

def height_to_biome_id(height_unorm, noise_val, uniformity : float, biome_offset, biome_cnt : uint) {
    if (biome_cnt <= 1u) {
        return biome_offset
    }
    let biomeVal = height_unorm * float(biome_cnt - 1u)
    let densityNext = fract(biomeVal)
    return uint(biomeVal) + (noise_val < lerp(densityNext, 0.5f, uniformity) ? 1u : 0u) + biome_offset
}

def create_terrain() {
    let heightmapTexPath = terrainFolderPath + "/heightmap.jpg"

    var heightmapData : array<float>
    var heightmapTexSize = int2(0, 0)

    var biomeMaskData : array<uint>

    var treesNode = create_node(NodeData(name = "trees", position = float3(0, 0, 0)))
    var treePrefab = request_prefab("assets/trees/spruce/spruce.fbx")

    get_image_content(heightmapTexPath) $(var bitmap : Bitmap) {
        heightmapTexSize = int2(bitmap.w, bitmap.h)
        let nPixels = heightmapTexSize.x * heightmapTexSize.y

        heightmapData.resize(nPixels)
        biomeMaskData.resize(nPixels)

        for (i in 0 .. nPixels) {
            heightmapData[i] = pow(float(bitmap.pixels[i] & 0xFF) / 255f, 2f)
            let hmapVal = heightmapData[i]
            let tcX = float(i % heightmapTexSize.x) / float(heightmapTexSize.x)
            let tcY = 1f - float(i / heightmapTexSize.x) / float(heightmapTexSize.y)
            let worldPos = float3(tcX, hmapVal, tcY) * worldSize + worldOffset

            let transitionStart = 0.1
            let transitionLen = 0.3
            let transitionEnd = transitionStart + transitionLen
            let grassTexDensity = saturate(1f - (hmapVal - transitionStart) / transitionLen)
            let rockTexDensity = 1f - grassTexDensity

            let grassNoise = perlin_noise(worldPos * grassNoiseFrequency)
            let rockNoise = perlin_noise(worldPos * rockNoiseFrequency)

            let selectVal = (grassNoise + rockNoise) * 0.5f
            if (selectVal < grassTexDensity) {
                let treesDensity = (worldPos.y > waterHeight ? 1f : 0f) * 0.05f
                let treeRand = random_float()
                if (treeRand < treesDensity) {
                    let treeInstance = instantiate_prefab(treePrefab, NodeData(
                        parent = treesNode,
                        position = worldPos,
                        rotation = quat4(0f, treeRand * PI * 2f / treesDensity, 0f),
                        scale = float3(1.0f, 1.0f, 1.0f) * 1.5f
                    ))
                }

                biomeMaskData[i] = height_to_biome_id(hmapVal / transitionEnd, grassNoise, 0.25, grassTexOffset, grassTexCnt)
            } else {
                biomeMaskData[i] = height_to_biome_id((hmapVal - transitionStart) / (1f - transitionStart), rockNoise, 0.5, rockTexOffset, rockTexCnt)
            }
        }
    }

    if (heightmapTexSize.x == 0 || heightmapTexSize.y == 0) {
        return
    }

    let terrainMesh = create_plane_mesh(PlaneInit(cells = 512))
    let terrainNode = create_node(NodeData(position = float3(0, 0, 0), scale = worldScale))

    let biomeMaskTex = create_texture(heightmapTexSize.x, heightmapTexSize.y, biomeMaskData,
        TextureDeclaration(sRGB = false, generateMipLevels = false, filter = TextureFilter.Point))
    let heightmapTex = create_texture(heightmapTexSize.x, heightmapTexSize.y, heightmapData,
        TextureDeclaration(sRGB = false, generateMipLevels = false, filter = TextureFilter.Bilinear, format = TextureFormat.R32F))


    let terrainMaterial = create_material(MaterialImport(
        shaderName = "heightmap_shader",
        diffuse = request_texture(terrainFolderPath + "/diffuse.tex2darray"),
        normal = request_texture(terrainFolderPath + "/normal.tex2darray"),
        specular = request_texture(terrainFolderPath + "/specular.tex2darray"),
        ao = biomeMaskTex,
        emission = heightmapTex,
        properties = MaterialProperties("tiling", 100f, "max_height", worldSize.y)
    ))


    add_component(terrainNode, new Mesh(
        meshId = terrainMesh,
        materialId = terrainMaterial,
        visibility = MeshVisibility.FullVisibility | MeshVisibility.DisableCulling
    ))
}

[export]
def on_initialize() {
    set_random_seed(3)
    create_terrain()

    let freeCameraPos = float3(0, 750, -950)
    toggle_free_camera(freeCamera, freeCameraPos, quat4(look_at(freeCameraPos, float3(0, 0, -100), float3(0, 1, 0))), true)

    let sun = create_node(NodeData(rotation = quat4(PI / 3f, -PI * 0.25f, PI / 3f)))
    add_component(sun, new DirectionLight())

    let water = create_node(NodeData(position = float3(0, waterHeight, 0), scale = worldScale))
    let waterMaterial = request_material("assets/water/water.material")
    add_component(water, new Mesh(meshId = create_plane_mesh(PlaneInit(cells = 1)), materialId = waterMaterial))

    let renderSettings = create_render_settings()

    get_component(renderSettings) $(var shadows : ShadowSettings?) {
        shadows.cascadeWidth = 2048
        shadows.maxDist = 1000f
        shadows.powWeight = 0.9f
    }

    get_component(renderSettings) $(var ssao : SSAOSettings?) {
        ssao.active = true
        ssao.method = SSAOMethod.GTAO
    }

    get_component(renderSettings) $(var ssr : SSRSettings?) {
        ssr.active = true
    }

    get_component(renderSettings) $(var tonemap : Tonemap?) {
        tonemap.active = true
    }

    get_component(renderSettings) $(var aa : AntiAliasing?) {
        aa.active = true
        aa.mode = AntiAliasingMode.MSAA
        aa.msaa_quality = MSAAQuality.MSAA_8x
    }
}
