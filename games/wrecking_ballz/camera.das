module camera

require engine.core
require bird
require common

let camEasing = 1f
let minCamWidth = 100f

class CameraFocus : Component {}

class GameCamera : Component {
    prevCamPos : float3 = float3()

    def override on_initialize {
        prevCamPos = float3(birdNestPos, minCamWidth)
        nodeId.worldPosition = float3(prevCamPos.x, prevCamPos.y, 0f)
        nodeId?.Camera.orthographicSize = prevCamPos.z
    }

    def override on_update {
        let dt = get_delta_time()

        // get all the objects that the camera will try to focus
        var minBound : float2 = prevCamPos.xy
        var maxBound : float2 = prevCamPos.xy

        for (camFocus in find_components(type<CameraFocus>)) {
            let position = camFocus.nodeId.worldPosition
            minBound.x = min(minBound.x, position.x)
            minBound.y = min(minBound.y, position.y)
            maxBound.x = max(maxBound.x, position.x)
            maxBound.y = max(maxBound.y, position.y)
        }

        // smooth camera
        let aspect = (get_resolution().y > 0 ? float(get_resolution().x) / float(get_resolution().y) : 0f)
        let newZ = max(maxBound.x - minBound.x, (maxBound.y - minBound.y) * aspect) + 20f
        var newCamPos = float3((minBound + maxBound) / 2f, max(newZ, minCamWidth))
        let curCamPos = approach(prevCamPos, newCamPos, dt, camEasing)
        nodeId.localPosition = float3(curCamPos.xy, 0f)
        (get_component(nodeId, type<Camera>)).orthographicSize = curCamPos.z
        prevCamPos = curCamPos
    }
}
