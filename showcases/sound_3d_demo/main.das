require engine.core


let {
    gong = request_sound("assets/gong.wav")
    streamingMusicLoop = request_sound("assets/loop_streaming.ogg")
    pcmMusicLoop = request_sound("assets/loop.ogg")
    autoPlay = false
}
var {
    camera : NodeId
    head : NodeId
    musicNode : NodeId
    musicNodeAngle = 0.
    musicNodeAngleSpeed = 0.8
    musicNodePrevPos = float3(0)
    statusNode : NodeId
    musicStatusNode : NodeId
    music3d : bool
    musicHandle : SoundHandle
    currentMusic : SoundId
}

def usage() {
    update_debug_text(statusNode, "<1> play one-shot 3d sound. <3> start/stop 3d streaming sound loop. <5> start/stop 3d sound loop. <7> start/stop 3d streaming sound.
<2> play one-shot 2d sound. <4> start/stop 2d streaming sound loop. <6> start/stop 2d sound loop. <8> start/stop 3d sound.
 - / = change rotation speed
left/right arrow - change music position
space - pause/resume music")
}

[export]
def on_initialize() {
    statusNode = create_debug_text(float2(20, -20), BOTTOM_LEFT_ANCHOR)
    musicStatusNode = create_debug_text(float2(20, 20), TOP_LEFT_ANCHOR)

    usage()

    camera = create_node(NodeData(position = float3(0, 1, -10)))
    add_component(camera, new Camera())

    let renderSettings = create_render_settings()
    (get_component(renderSettings, type<Tonemap>)).active = true

    let sun = create_node(NodeData(rotation = quat4(deg_to_rad(float3(30, -45, 0)))))
    add_component(sun, new DirectionLight())

    head = create_node(NodeData(scale = float3(2.)))
    add_component(head, new Mesh(meshId = SPHERE_MESH_ID))

    let forwardDir = head.worldForward
    let vel = float3(0)
    set_audio_listener_position(head.localPosition, forwardDir, vel) // velocity is optional

    musicNode = create_node(NodeData(position = float3(4, 0, 0)))
    add_component(musicNode, new Mesh(meshId = SPHERE_MESH_ID, color = GREEN_COLOR))

    if (autoPlay) {
        musicHandle = play_3d_sound_loop(pcmMusicLoop, musicNode.localPosition, inverse_distance_attenuation(5.))
    }
}

def toggle_3d_music(res : SoundId, loop = true) {
    let restart = !(is_playing(musicHandle)) || !music3d
    if (is_playing(musicHandle)) {
        stop(musicHandle)
    }
    if (restart) {
        if (loop) {
            musicHandle = play_3d_sound_loop(res, musicNode.localPosition, inverse_distance_attenuation(5.))
        } else {
            musicHandle = play_3d_sound(res, musicNode.localPosition, inverse_distance_attenuation(5.))
        }
        music3d = true
        currentMusic = res
    }
}


def toggle_2d_music(res : SoundId, loop = true) {
    let restart = !(is_playing(musicHandle)) || music3d
    if (is_playing(musicHandle)) {
        stop(musicHandle)
    }
    if (restart) {
        if (loop) {
            musicHandle = play_sound_loop(res)
        } else {
            musicHandle = play_sound(res)
        }
        music3d = false
        currentMusic = res
    }
}

[export]
def on_update() {

    for (cmd in get_input_command_buffer()) {
        match (cmd) {

            // 3d sound
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = KeyCode._1)) {
                play_3d_sound(gong, musicNode.localPosition, inverse_distance_attenuation(5.))
            }
            // 2d sound
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = KeyCode._2)) {
                play_sound(gong)
            }
            // 3d music
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = KeyCode._3)) {
                toggle_3d_music(streamingMusicLoop)
            }
            // 2d music
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = KeyCode._4)) {
                toggle_2d_music(streamingMusicLoop)
            }
            // 3d music
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = KeyCode._5)) {
                toggle_3d_music(pcmMusicLoop)
            }
            // 2d music
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = KeyCode._6)) {
                toggle_2d_music(pcmMusicLoop)
            }
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = KeyCode._7)) {
                toggle_3d_music(streamingMusicLoop, false)
            }
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = KeyCode._8)) {
                toggle_3d_music(pcmMusicLoop, false)
            }
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = KeyCode.Left)) {
                if (is_playing(musicHandle)) {
                    set_position(musicHandle, get_position(musicHandle) - 1.)
                }
            }
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = KeyCode.Right)) {
                if (is_playing(musicHandle)) {
                    set_position(musicHandle, get_position(musicHandle) + 1.)
                }
            }
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = KeyCode.Space)) {
                pause(musicHandle, !is_paused(musicHandle))
            }
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = $v(minus)) && (minus == KeyCode.Minus || minus == KeyCode.Subtract)) {
                musicNodeAngleSpeed *= 0.8
                musicNodeAngleSpeed = clamp(musicNodeAngleSpeed, 0.1, 40.)
            }
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = $v(equal)) && (equal == KeyCode.Equals || equal == KeyCode.Add)) {
                musicNodeAngleSpeed /= 0.8
                musicNodeAngleSpeed = clamp(musicNodeAngleSpeed, 0.1, 40.)
            }
        }
    }
    let vel = (musicNode.localPosition - musicNodePrevPos) / get_delta_time()
    musicNodePrevPos = musicNode.localPosition
    musicNodeAngle += get_delta_time() * musicNodeAngleSpeed
    musicNode.localPosition = float3(cos(musicNodeAngle), 0., sin(musicNodeAngle)) * 2.
    if (music3d) {
        set_3d_sound_position(musicHandle, musicNode.localPosition, vel) // velocity is optional
    }

    if (is_playing(musicHandle) || is_paused(musicHandle)) {
        let pos = get_position(musicHandle)
        let duration = get_duration(musicHandle)
        let prefix = streamingMusicLoop == currentMusic ? "Streaming " : ""
        let dim = music3d ? "3d " : "2d "
        update_debug_text(musicStatusNode, "{prefix}{dim}music\nPosition: {pos:.2f}\nDuration: {duration:.2f}")
    } else {
        update_debug_text(musicStatusNode, "")
    }
}
