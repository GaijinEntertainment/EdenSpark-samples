require engine.core
require parser


let {
    rate = 48000
    frate = float(rate)
    song1 = "JingleBell:d=8,o=5,b=112:a,a,4a,a,a,4a,a,c6,f.,16g,2a,a#,a#,a#.,16a#,a#,a,a.,16a,a,g,g,a,4g,4c6"
    song2 = "Mozart:d=4,o=6,b=140:32d#.5,32d.5,32d#.5,8f#.5,32g#.5,32f#.5,32f.5,32f#.5,8a#.5,16b5,16a#5,16a5,16a#5,16f6,16d#6,16d6,16d#6,16f6,16d#6,16d6,16d#6,8f#.6,8d#6,8f#6,32c#6,32d#6,16f6,8d#6,8c#6,8d#6,32c#6,32d#6,16f6,8d#6,8c#6,8d#6,32c#6,32d#6,16f6,8d#6,8c#6,8c6,4a#5,16f5,32d#5,16d5,16d#5,4f#5,16g#5,16f#5,16f5,16f#5,4a#5,16b5,16a#5,16a5,16a#5,16f6,16d#6,16d6,16d#6,16f6,16d#6,16d6,16d#6,4f#6,8d#6,8f#6,32c#6,32d#6,16f6,8d#6,8c#6,8d#6,32c#6,32d#6,16f6,8d#6,8c#6,8d#6,32c#6,32d#6,16f6,8d#6,8c#6,8c6,4a#5,"
}
var {
    statusNode : NodeId
    nowPlaying : NodeId
    musicHandle1 : SoundHandle
    musicHandle2 : SoundHandle
    melodyNotes1 : array<tuple<float, float>>
    melodyNotes2 : array<tuple<float, float>>
}


def handle_notes(notes : array<tuple<float, float>>, outerHandle : SoundHandle) : SoundHandle {
    if (is_playing(outerHandle)) {
        stop(outerHandle)
    }

    let handle = play_sound_stream(rate, /*channels*/1)

    for (note in notes) {// array of tuple[frec, msec]
        var sin <- [for (x in range(int(frate * note._1 * 0.001))); sin(PI * note._0 * float(x) / frate)]
        append_to_stream(handle, sin)
    }
    return handle
}


[export]
def on_initialize() {
    show_mouse_cursor(true)

    statusNode = create_debug_text("Press 1 to play JingleBell\nPress 2 to play Mozart", float2(0), MIDDLE_CENTER_ANCHOR)
    nowPlaying = create_debug_text(float2(0, -10), BOTTOM_CENTER_ANCHOR)

    add_component(create_node(), new Camera())

    // parse melodies to arrays of rtttl notes
    melodyNotes1 <- get_notes(song1)
    melodyNotes2 <- get_notes(song2)
}


[export]
def on_update() {

    for (cmd in get_input_command_buffer()) {
        match (cmd) {
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = KeyCode._1)) {
                if (musicHandle1 != INVALID_SOUND_HANDLE) {
                    stop(musicHandle1)
                    update_debug_text(nowPlaying, "")
                    musicHandle1 = INVALID_SOUND_HANDLE
                } else {
                    musicHandle1 = handle_notes(melodyNotes1, musicHandle2)
                    set_volume(musicHandle1, 0.2)
                    update_debug_text(nowPlaying, "Now playing:\n{song1}", float2(500, 0))
                }
            }
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = KeyCode._2)) {
                if (musicHandle2 != INVALID_SOUND_HANDLE) {
                    stop(musicHandle2)
                    update_debug_text(nowPlaying, "")
                    musicHandle2 = INVALID_SOUND_HANDLE
                } else {
                    musicHandle2 = handle_notes(melodyNotes2, musicHandle1)
                    set_volume(musicHandle2, 0.2)
                    update_debug_text(nowPlaying, "Now playing:\n{song2}", float2(500, 0))
                }
            }
        }
    }
}
