require engine.serializer.generic_storage
require engine.math_core
module trackSegment public

require trackSegmentGen public


def get_end_of_segment(desc : TrackSegmentDescription, initial_point : float3, initial_angle : float) : float3 {
    var p = initial_point
    for (i in range(desc.subdivCount)) {
        var t = float(i) / float(desc.subdivCount)
        var angle = initial_angle + desc.rotation * t
        var cos_angle = cos(angle)
        var sin_angle = sin(angle)
        p += float3(cos_angle, 0.0, -sin_angle) * desc.subdivLength
    }
    return p
}


def get_center_line_points(desc : TrackSegmentDescription, initial_point : float3, initial_angle : float) : array<float3> {
    var points : array<float3>
    var p = initial_point
    for (i in range(desc.subdivCount)) {
        var t = float(i) / float(desc.subdivCount)
        var angle = initial_angle + desc.rotation * t
        var cos_angle = cos(angle)
        var sin_angle = sin(angle)
        p += float3(cos_angle, 0.0, -sin_angle) * desc.subdivLength
        push(points, p)
    }
    return <- points
}


def get_points_for_decor(desc : TrackSegmentDescription, initial_point : float3, initial_angle : float) : array<float3> {
    var points : array<float3>
    var p = initial_point
    for (i in range(desc.subdivCount)) {
        var t = float(i) / float(desc.subdivCount)
        var width = lerp(desc.startWidth, desc.endWidth, smoothstep(t))
        var angle = initial_angle + desc.rotation * t
        var cos_angle = cos(angle)
        var sin_angle = sin(angle)
        var x = (random_bool() ? width + 3.0 : -width - 3.0) * random_range(1.0, 1.1)
        var position = p + x * float3(sin_angle, 0.0, cos_angle)
        position += random_range(float3(-0.5, 0.0, -0.5), float3(0.5, 0.0, 0.5))
        push(points, position)
        p += float3(cos_angle, 0.0, -sin_angle) * desc.subdivLength
    }
    return <- points
}


def get_collision_segments(desc : TrackSegmentDescription, initial_point : float3, initial_angle : float) : array<float4> {
    var points : array<float4>
    var p = initial_point
    var prevLeftP, prevRightP : float3
    for (i in range(desc.subdivCount + 1)) {
        var t = float(i) / float(desc.subdivCount)
        var width = lerp(desc.startWidth, desc.endWidth, smoothstep(t))
        var angle = initial_angle + desc.rotation * t
        var cos_angle = cos(angle)
        var sin_angle = sin(angle)
        var leftP = p - width * float3(sin_angle, 0.0, cos_angle)
        var rightP = p + width * float3(sin_angle, 0.0, cos_angle)
        p += float3(cos_angle, 0.0, -sin_angle) * desc.subdivLength
        if (i == 0) {
            prevLeftP = leftP
            prevRightP = rightP
        } else {
            push(points, float4(prevLeftP.x, prevLeftP.z, leftP.x, leftP.z))
            push(points, float4(prevRightP.x, prevRightP.z, rightP.x, rightP.z))
            prevLeftP = leftP
            prevRightP = rightP
        }
    }
    return <- points
}


def get_points_for_tree_walls(desc : TrackSegmentDescription, initial_point : float3, initial_angle : float, var left_dist : float&, var right_dist : float&) : array<float4> {
    var points : array<float4>
    var p = initial_point
    let treeWallLen = 15.0
    let distFromTrack = 13.0

    var prevLeftP, prevRightP : float3

    for (i in range(desc.subdivCount)) {
        var t = float(i) / float(desc.subdivCount)
        var width = lerp(desc.startWidth, desc.endWidth, smoothstep(t))
        var angle = initial_angle + desc.rotation * t
        var cos_angle = cos(angle)
        var sin_angle = sin(angle)
        var leftP = p - distFromTrack * float3(sin_angle, 0.0, cos_angle)
        var rightP = p + distFromTrack * float3(sin_angle, 0.0, cos_angle)

        if (i == 0) {
            prevLeftP = leftP
            prevRightP = rightP
            left_dist += desc.subdivLength
            right_dist += desc.subdivLength
        }

        left_dist += length(prevLeftP - leftP)
        right_dist += length(prevRightP - rightP)

        if (left_dist >= treeWallLen) {
            left_dist -= treeWallLen
            push(points, float4(leftP, angle))
        }

        if (right_dist >= treeWallLen) {
            right_dist -= treeWallLen
            push(points, float4(rightP, angle))
        }
        p += float3(cos_angle, 0.0, -sin_angle) * desc.subdivLength

        prevRightP = rightP
        prevLeftP = leftP
    }

    return <- points
}
