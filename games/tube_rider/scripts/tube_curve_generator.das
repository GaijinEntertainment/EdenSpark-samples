require engine.core

struct TubePointTransform {
    rot : quat4
    pos : float3
}

struct TubeCurveGenerator {
    // Changes per segment.
    minMaxSwingChangeDegrees : float2 = float2(3, 10)
    minMaxTubeTwistChangeDegrees : float2 = float2(0, 0)

    momentumCoeff : float = 0.99f

    // TODO: Uncomment 'private' when hot reload supports it.
    /*private*/ ringCount : int = 0
    /*private*/ ringsPerSegment : int = 0

    /*private*/ endRingDist : float = 0f
    /*private*/ endRingIndex : int = 0
    /*private*/ endSegmentDist : float = 0f

    /*private*/ ringTransforms : array<TubePointTransform>

    /*private*/ curRotDelta : quat4 /*= quat4(float4(0f, 0f, 0f, 1f))*/
    /*private*/ segmentTargetRotDelta : quat4 /*= quat4(float4(0f, 0f, 0f, 1f))*/

    def TubeCurveGenerator(ring_count, rings_per_segment : int) {
        ringCount = ring_count
        ringsPerSegment = rings_per_segment
        ringTransforms.resize(ringCount + 2)
        ringTransforms[0].rot = quat4(float4(0f, 0f, 0f, 1f))
        endRingDist = -float(rings_per_segment)
        endSegmentDist = -float(rings_per_segment)

        curRotDelta = quat4(float4(0f, 0f, 0f, 1f))
        segmentTargetRotDelta = quat4(float4(0f, 0f, 0f, 1f))
    }

    def /*private*/ advanceRing() {
        let nextRingRot = curRotDelta * ringTransforms[endRingIndex].rot
        let nextRingPos = ringTransforms[endRingIndex].pos + ringTransforms[endRingIndex].rot * FORWARD

        endRingDist = endRingDist + 1f
        endRingIndex = (endRingIndex + 1) % ringCount
        ringTransforms[endRingIndex].rot = normalize(nextRingRot)
        ringTransforms[endRingIndex].pos = nextRingPos
        curRotDelta = normalize(slerp(segmentTargetRotDelta, curRotDelta, momentumCoeff))
    }

    def /*private*/ advanceSegment() {
        let swingRand = random_float() * 2f - 1f
        let swingChange = (abs(swingRand) * (minMaxSwingChangeDegrees.y - minMaxSwingChangeDegrees.x) + minMaxSwingChangeDegrees.x) * sign(swingRand) * TO_RAD
        let swingChangeRot = quat4(quat4(FORWARD, random_float() * 2f * PI) * RIGHT, swingChange)

        let tubeTwistRand = random_float() * 2f - 1f
        let tubeTwistChange = tubeTwistRand * (minMaxTubeTwistChangeDegrees.y - minMaxTubeTwistChangeDegrees.x) + minMaxTubeTwistChangeDegrees.x * sign(tubeTwistRand) * TO_RAD
        let tubeTwistChangeRot = quat4(FORWARD, tubeTwistChange)

        endSegmentDist += float(ringsPerSegment)
        segmentTargetRotDelta = tubeTwistChangeRot * swingChangeRot
    }

    def advance(dist : float) {
        while (endRingDist <= dist) {
            while (endSegmentDist <= endRingDist) {
                advanceSegment()
            }
            advanceRing()
        }
    }

    def const getCenterTransformAtDistance(dist : float) {
        let startRingDist = endRingDist - float(ringCount)
        if (dist > endRingDist || dist < startRingDist) {
            error("Distance {dist} is out of range [{startRingDist}, {endRingDist}]")
            return TubePointTransform()
        }

        let sampleAt = $(sample_dist : float, callback : block<(ring_from_id : int, ring_to_id : int, t : float) : void>) {
            let ringToId = (endRingIndex - int(endRingDist - dist) + ringCount) % ringCount
            let ringFromId = (ringToId + ringCount - 1) % ringCount
            let t = 1f - fract(endRingDist - dist)
            callback(ringFromId, ringToId, t)
        }

        var result : TubePointTransform
        sampleAt(dist) $(ring_from_id, ring_to_id : int, t : float) {
            result.pos = lerp(ringTransforms[ring_from_id].pos, ringTransforms[ring_to_id].pos, t)
        }
        sampleAt(dist - 0.5) $(ring_from_id, ring_to_id : int, t : float) {
            result.rot = slerp(ringTransforms[ring_from_id].rot, ringTransforms[ring_to_id].rot, t)
        }

        return result
    }
}
