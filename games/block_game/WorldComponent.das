require engine.core
require BlockComponent

require Level

var glyph_to_block <- {
    "g" => request_prefab("blocks/GrassBlock.prefab"),
    "d" => request_prefab("blocks/DirtBlock.prefab"),
    "r" => request_prefab("blocks/RockBlock.prefab"),
    "w" => request_prefab("blocks/WoodBlock.prefab"),
    "l" => request_prefab("blocks/LeavesBlock.prefab"),
}

class World : Component {

    private grid : array<array<array<Block?>>>
    blockHolder : NodeId

    breakingBlockPrefab : PrefabId

    def override on_initialize() : void {
        var breakingBlock = instantiate_prefab(breakingBlockPrefab, NodeData(parent = nodeId))
        breakingBlock.isActive = false

        grid |> resize(level_width)
        for (xRaw, yDim in count(), grid) {
            let x = xRaw - level_width / 2
            yDim |> resize(level_height)
            for (yRaw, zDim in count(), yDim) {
                let y = yRaw + 1
                zDim |> resize(level_depth)
                for (zRaw, cell in count(), zDim) {
                    let z = zRaw - level_depth / 2
                    let glyph = level_compressed[level_height - yRaw - 1][xRaw][zRaw]
                    if (glyph == "a") {
                        continue
                    }
                    let block_node = instantiate_prefab(glyph_to_block.get_value(glyph), NodeData(
                        position = float3(x, float(y) - 0.5, z),
                        parent = blockHolder
                    ))
                    cell = block_node |> get_component(type<Block>)
                    cell.position = int3(xRaw, yRaw, zRaw)
                }
            }
        }

        for (xRaw, yDim in count(), grid) {
            for (yRaw, zDim in count(), yDim) {
                for (zRaw, cell in count(), zDim) {
                    if (cell == null) {
                        continue
                    }
                    cell.show_all(false)
                    if (xRaw == 0 || grid[xRaw - 1][yRaw][zRaw] == null || !grid[xRaw - 1][yRaw][zRaw].opaque) {
                        cell.show_face(BlockFace.xn, true)
                    }
                    if (xRaw == level_width - 1 || grid[xRaw + 1][yRaw][zRaw] == null || !grid[xRaw + 1][yRaw][zRaw].opaque) {
                        cell.show_face(BlockFace.xp, true)
                    }
                    if (yRaw == 0 || yDim[yRaw - 1][zRaw] == null || !yDim[yRaw - 1][zRaw].opaque) {
                        cell.show_face(BlockFace.yn, true)
                    }
                    if (yRaw == level_height - 1 || yDim[yRaw + 1][zRaw] == null || !yDim[yRaw + 1][zRaw].opaque) {
                        cell.show_face(BlockFace.yp, true)
                    }
                    if (zRaw == 0 || zDim[zRaw - 1] == null || !zDim[zRaw - 1].opaque) {
                        cell.show_face(BlockFace.zn, true)
                    }
                    if (zRaw == level_depth - 1 || zDim[zRaw + 1] == null || !zDim[zRaw + 1].opaque) {
                        cell.show_face(BlockFace.zp, true)
                    }
                }
            }
        }
    }


    def override on_update() {
        for (deadBlockTag in find_components(type<DeadBlock>)) {
            var deadBlock = get_component(deadBlockTag.nodeId, type<Block>)
            let deadBlockPos = deadBlock.position
            grid[deadBlockPos.x][deadBlockPos.y][deadBlockPos.z] = null

            if (deadBlock.opaque) {
                if (deadBlockPos.x > 0) {
                    var neighbor = grid[deadBlockPos.x - 1][deadBlockPos.y][deadBlockPos.z]
                    if (neighbor != null) {
                        neighbor.show_face(BlockFace.xp, true)
                    }
                }
                if (deadBlockPos.x < level_width - 1) {
                    var neighbor = grid[deadBlockPos.x + 1][deadBlockPos.y][deadBlockPos.z]
                    if (neighbor != null) {
                        neighbor.show_face(BlockFace.xn, true)
                    }
                }
                if (deadBlockPos.y > 0) {
                    var neighbor = grid[deadBlockPos.x][deadBlockPos.y - 1][deadBlockPos.z]
                    if (neighbor != null) {
                        neighbor.show_face(BlockFace.yp, true)
                    }
                }
                if (deadBlockPos.y < level_height - 1) {
                    var neighbor = grid[deadBlockPos.x][deadBlockPos.y + 1][deadBlockPos.z]
                    if (neighbor != null) {
                        neighbor.show_face(BlockFace.yn, true)
                    }
                }
                if (deadBlockPos.z > 0) {
                    var neighbor = grid[deadBlockPos.x][deadBlockPos.y][deadBlockPos.z - 1]
                    if (neighbor != null) {
                        neighbor.show_face(BlockFace.zp, true)
                    }
                }
                if (deadBlockPos.z < level_depth - 1) {
                    var neighbor = grid[deadBlockPos.x][deadBlockPos.y][deadBlockPos.z + 1]
                    if (neighbor != null) {
                        neighbor.show_face(BlockFace.zn, true)
                    }
                }
            }
            deadBlock.do_destroy()
        }
    }
}