require engine.core


enum BlockFace {
    xp
    xn
    yp
    yn
    zp
    zn
}

class Block : Component {
    @no_export position : int3
    opaque : bool = true
    hardness : float = 1.

    @export private xp : NodeId
    @export private xn : NodeId
    @export private yp : NodeId
    @export private yn : NodeId
    @export private zp : NodeId
    @export private zn : NodeId

    private breakingProgress : float
    private playerHit : bool
    private breakingBlock : BreakingBlock?

    def show_all(show : bool) {
        show_face(BlockFace.xp, show)
        show_face(BlockFace.xn, show)
        show_face(BlockFace.yp, show)
        show_face(BlockFace.yn, show)
        show_face(BlockFace.zp, show)
        show_face(BlockFace.zn, show)
    }

    def do_destroy() {
        remove_node(nodeId)
    }

    def add_breaking() {
        playerHit = true
        if (breakingBlock == null) {
            breakingBlock = find_component(type<BreakingBlock>, InactiveNodes.Include)
            breakingBlock.capture_by(nodeId)
        }
        breakingProgress += get_delta_time()
        breakingBlock.set_progress(breakingProgress / hardness)
        if (breakingProgress >= hardness) {
            breakingBlock.release_from(nodeId)
            breakingBlock = null
            add_component(nodeId, new DeadBlock())
        }
    }

    def show_face(face : BlockFace, show : bool) {
        var faceToShow : NodeId
        match (face) {
            if (BlockFace.xp) {
                faceToShow = xp
            }
            if (BlockFace.xn) {
                faceToShow = xn
            }
            if (BlockFace.yp) {
                faceToShow = yp
            }
            if (BlockFace.yn) {
                faceToShow = yn
            }
            if (BlockFace.zp) {
                faceToShow = zp
            }
            if (BlockFace.zn) {
                faceToShow = zn
            }
        }
        faceToShow.isActive = show
    }

    def override on_update() {
        if (!playerHit && breakingBlock != null) {
            breakingProgress = 0.
            breakingBlock.release_from(nodeId)
            breakingBlock = null
        }
        playerHit = false
    }
}


class DeadBlock : Component { }


class BreakingBlock : Component {
    faces : array<Mesh?>
    stages : array<MaterialId>

    private owner : NodeId

    def set_progress(progress : float) {
        let stageIdx = min(int(ceil(progress * float(length(stages)))), length(stages)) - 1
        for (face in faces) {
            face.materialId = stages[stageIdx]
        }
    }

    def capture_by(newOwner : NodeId) {
        nodeId.isActive = true
        set_parent(nodeId, newOwner, AddChildStrategy.KeepLocalTransform)
        owner = newOwner
    }

    def release_from(oldOwner : NodeId) {
        return if (oldOwner != owner)
        nodeId.isActive = false
        set_parent(nodeId, NodeId(), AddChildStrategy.KeepLocalTransform)
    }
}
