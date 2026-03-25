require engine.core

let {
    gong = request_sound("assets/gong.wav")
    musicLoop = request_sound("assets/music_loop.wav")
}

var {
    statusNode : NodeId
    reverPreset = ReverbPreset.Generic
    gondHandle : SoundHandle
    musicHandle : SoundHandle
}

let {
    largeHall = ReverbProperties(
        lRoom = -1000,
        lRoomHF = -600,
        flDecayTime = 1.8,
        flDecayHFRatio = 0.7,
        lReflections = -2000,
        flReflectionsDelay = 0.03,
        lReverb = -1400,
        flReverbDelay = 0.06,
        flDiffusion = 100.,
        flDensity = 100.
    )
}

def next_reverb_preset(preset : ReverbPreset) : ReverbPreset {
    var found = false
    for (e in type<ReverbPreset>) {
        return e if (found)
        found = e == preset
    }
    return ReverbPreset.Generic
}


def prev_reverb_preset(preset : ReverbPreset) : ReverbPreset {
    var prev = ReverbPreset.Underwater
    for (e in type<ReverbPreset>) {
        return prev if (e == preset)
        prev = e
    }
    return prev
}

def usage() {
    update_debug_text(statusNode, "Press 1: play one-shot sound\nPress 2: start/stop sound loop\nPress L - large hall preset\nPress Up/Down - change reverb preset: {reverPreset}")
}

[export]
def on_initialize() {
    let camera = create_node(NodeData(position = float3(0, 1, -10)))
    add_component(camera, new Camera())

    statusNode = create_debug_text(float2(0), MIDDLE_CENTER_ANCHOR)
    usage()
}


[export]
def on_update() {

    for (cmd in get_input_command_buffer()) {
        match (cmd) {
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = KeyCode._1)) {
                gondHandle = set_reverb_preset(play_sound(gong), reverPreset)
            }
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = KeyCode._2)) {
                if (is_playing(musicHandle)) {
                    stop(musicHandle)
                } else {
                    musicHandle = set_reverb_preset(play_sound_loop(musicLoop), reverPreset)
                }
            }
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = KeyCode.Down)) {
                reverPreset = next_reverb_preset(reverPreset)
                set_reverb_preset(gondHandle, reverPreset)
                set_reverb_preset(musicHandle, reverPreset)
                usage()
            }
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = KeyCode.Up)) {
                reverPreset = prev_reverb_preset(reverPreset)
                set_reverb_preset(gondHandle, reverPreset)
                set_reverb_preset(musicHandle, reverPreset)
                usage()
            }
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = KeyCode.L)) {
                set_reverb(gondHandle, largeHall)
                set_reverb(musicHandle, largeHall)
                usage()
            }
        }
    }
}

