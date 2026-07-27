require engine.core
require engine.arcball_camera


class DayNightToggle : Component {
    dayAngle : float = 45.0
    nightAngle : float = -20.0
    @no_export isDay : bool = true
    @no_export hintNode : NodeId

    def override on_initialize() {
        hintNode = create_debug_text("[T] Day", float2(10, 10), TOP_LEFT_ANCHOR)
        add_and_activate_action_set("day_night", {
            "toggleDayNight" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.T)]
                )
            )
        })
    }

    def override on_update() {
        if (is_action_just_pressed("toggleDayNight")) {
            isDay = !isDay
            let angle = isDay ? dayAngle : nightAngle
            nodeId.localRotation = quat4(angle * PI / 180.0, 0.0, 0.0)
            update_debug_text(hintNode, "[T] {isDay ? "Day" : "Night"}")
        }
    }
}


def label_pos_under(target : NodeId) : float3 {
    let wp = target.worldPosition
    let sy = target.localScale.y
    return float3(wp.x, wp.y - 0.5 * sy - 0.3, wp.z)
}


class HoverLabel : Component {
    cameraNode : NodeId
    @no_export labelNode : NodeId
    @no_export currentTarget : NodeId

    def override on_initialize() {
        let lbl = create_node(NodeData(name = "__hover_label", scale = float3(0.05, 0.05, 0.05)))
        add_component(lbl, new Text3D(text = "", fontSize = 18.0, useDepthScale = false))
        lbl.isActive = false
        labelNode = lbl

        add_and_activate_action_set("hover_label", {
            "MousePos" => Action(
                pointerActions = PointerAction(
                    valueType = ValueType.Accumulate,
                    mouse = MouseInput(active = true)
                )
            )
        })
    }

    def override on_update() {
        get_component(cameraNode) $(cam : Camera?) {
            let ray = cam.screenToRay(get_action_vector2("MousePos"))
            var hitTarget : NodeId
            trace(RayCast(ray = ray)) $(hit) {
                hitTarget = hit.nodeId
            }
            if (hitTarget != currentTarget) {
                currentTarget = hitTarget
                if (valid(hitTarget)) {
                    labelNode.isActive = true
                    labelNode.localPosition = label_pos_under(hitTarget)
                    get_component(labelNode) $(var t : Text3D?) {
                        t.text = hitTarget.name
                    }
                } else {
                    labelNode.isActive = false
                }
            } elif (valid(hitTarget)) {
                labelNode.localPosition = label_pos_under(hitTarget)
            }
        }
    }
}


class ShaderDuplicate : Component {
    nodeToDuplicate : NodeId
    box : float2
    intX : int
    intY : int

    def doit() {
        if (!nodeId.isActive) return
        let size = float3(box.x, 1f, box.y)
        for (i in 0..intX) {
            for (j in 0..intY) {
                let offset = float3(i - intX / 2, 0, j - intY / 2)
                duplicate_node(nodeToDuplicate, NodeData(position = offset * size))
            }
        }
    }
}


struct ShaderEntry {
    name   : string
    meshId : MeshId
    shape  : Shape
}


[export]
def on_post_initialize() {
    show_mouse_cursor(true)

    let bunnyMesh = request_mesh_from_model("stanford-bunny.obj", "defaultobject")
    let bunnyShape = mesh_shape(request_collision_from_model("stanford-bunny.obj", "defaultobject"))
    let sphereShape = sphere_shape(0.5)
    let boxShape = box_shape(float3(1, 1, 1))

    var entries = [
        ShaderEntry(name = "fresnel_emission", meshId = bunnyMesh, shape = bunnyShape),
        ShaderEntry(name = "hologram", meshId = SPHERE_MESH_ID, shape = sphereShape),
        ShaderEntry(name = "force_field", meshId = SPHERE_MESH_ID, shape = sphereShape),
        ShaderEntry(name = "iridescent", meshId = bunnyMesh, shape = bunnyShape),
        ShaderEntry(name = "lava", meshId = bunnyMesh, shape = bunnyShape),
        ShaderEntry(name = "water", meshId = UV_SPHERE_MESH_ID, shape = sphereShape),
        ShaderEntry(name = "toon", meshId = bunnyMesh, shape = bunnyShape),
        ShaderEntry(name = "cel_shading", meshId = bunnyMesh, shape = bunnyShape),
        ShaderEntry(name = "outline", meshId = bunnyMesh, shape = bunnyShape),
        ShaderEntry(name = "cells", meshId = UV_SPHERE_MESH_ID, shape = sphereShape),
        ShaderEntry(name = "glitch", meshId = UV_SPHERE_MESH_ID, shape = sphereShape),
        ShaderEntry(name = "dissolve", meshId = UV_SPHERE_MESH_ID, shape = sphereShape),
        ShaderEntry(name = "triplanar", meshId = UV_SPHERE_MESH_ID, shape = sphereShape),
        ShaderEntry(name = "wipe_3d", meshId = UV_SPHERE_MESH_ID, shape = sphereShape),
        ShaderEntry(name = "wipe_vertical_3d", meshId = UV_SPHERE_MESH_ID, shape = sphereShape),
        ShaderEntry(name = "dissolve_wipe_vertical_3d", meshId = UV_SPHERE_MESH_ID, shape = sphereShape),
        ShaderEntry(name = "dissolve_wipe_3d", meshId = UV_SPHERE_MESH_ID, shape = sphereShape),
        ShaderEntry(name = "burn_3d", meshId = UV_SPHERE_MESH_ID, shape = sphereShape),
        ShaderEntry(name = "freeze_3d", meshId = bunnyMesh, shape = bunnyShape),
        ShaderEntry(name = "poison_3d", meshId = bunnyMesh, shape = bunnyShape),
        ShaderEntry(name = "shield_hit_3d", meshId = SPHERE_MESH_ID, shape = sphereShape),
        ShaderEntry(name = "electric_3d", meshId = bunnyMesh, shape = bunnyShape),
        ShaderEntry(name = "rage_3d", meshId = bunnyMesh, shape = bunnyShape),
        ShaderEntry(name = "stun_3d", meshId = bunnyMesh, shape = bunnyShape),
        ShaderEntry(name = "heal_3d", meshId = bunnyMesh, shape = bunnyShape),
        ShaderEntry(name = "raymarch_spheres", meshId = CUBE_MESH_ID, shape = boxShape),
        ShaderEntry(name = "depth_fog_3d",    meshId = SPHERE_MESH_ID, shape = sphereShape),
        ShaderEntry(name = "scene_refraction", meshId = SPHERE_MESH_ID, shape = sphereShape),
    ]

    let count = length(entries)
    let perRow = ceili(sqrt(float(count)))
    let rows = (count + perRow - 1) / perRow
    let spacing = 2.0

    let samplesNode = find_child("samples")

    for (i, entry in range(count), entries) {
        let col = i % perRow
        let row = i / perRow
        let x = (float(col) - float(perRow - 1) * 0.5) * spacing
        let z = (float(row) - float(rows - 1) * 0.5) * spacing
        let isBunny = entry.meshId == bunnyMesh
        let sc = isBunny ? float3(0.5, 0.5, 0.5) : float3(1, 1, 1)
        let yOff = isBunny ? 0.0 : 0.5
        let obj = create_node(NodeData(
            name = entry.name,
            parent = samplesNode,
            position = float3(x, yOff, z),
            scale = sc
        ))
        let mat = request_material("materials/{entry.name}.material")
        add_component(obj, new Mesh(meshId = entry.meshId, materialId = mat))
        add_component(obj, new Collider(shape = entry.shape))
    }

    var dup = get_component(find_child("duplicator"), type<ShaderDuplicate>)
    if (dup != null) {
        dup.doit()
    }

    let cameraNode = find_child("camera")
    let hoverNode = create_node(NodeData(name = "hover_label_controller"))
    add_component(hoverNode, new HoverLabel(cameraNode = cameraNode))
}
