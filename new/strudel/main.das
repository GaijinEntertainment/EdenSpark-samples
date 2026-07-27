require engine.core

let NUM_LAYERS = 6

var {
    layerHandles : StrudelHandle[6]
    layerOn : bool[6]
    statusNode : NodeId
}


def onoff(idx : int) : string {
    return layerOn[idx] ? "ON" : "--"
}


def update_status() {
    update_debug_text(statusNode, "Strudel layers - press 1-6 to toggle\n[1] drone {onoff(0)}   [2] pad {onoff(1)}   [3] choir {onoff(2)}   [4] arps {onoff(3)}   [5] arps hi {onoff(4)}   [6] sub {onoff(5)}")
}


def play_layer(idx : int) {
    if (layerOn[idx]) {
        return
    }
    layerOn[idx] = true
    if (idx == 0) {
        // Layer 1: deep ocean drone - low sine foundation, very slow root movement
        layerHandles[0] = strudel_play(
            note_pattern("<c1 g1 f1 eb1 bb0 f1>", "sine")
                |> slow(32.0)
                |> set_gain(0.3)
                |> set_attack(6.0) |> set_release(8.0)
                |> set_lpf(180.0)
                |> set_room(1.0) |> set_roomsize(10.0)
                |> set_orbit(1)
        )
    } elif (idx == 1) {
        // Layer 2: warm mid pad - filtered saw with a slow filter sweep
        layerHandles[1] = strudel_play(
            note_pattern("<c2 eb2 g2 bb2 f2 ab2 g2 eb2>", "sawtooth")
                |> slow(24.0)
                |> set_gain(0.1)
                |> set_attack(4.0) |> set_decay(2.0) |> set_sustain(0.7) |> set_release(6.0)
                |> set_lpf(signal_sine() |> signal_range(250.0, 800.0) |> slow(32.0))
                |> set_hpf(80.0)
                |> set_room(0.9) |> set_roomsize(8.0)
                |> set_pan(signal_sine() |> signal_range(0.3, 0.7) |> slow(20.0))
                |> set_orbit(2)
        )
    } elif (idx == 2) {
        // Layer 3: choral texture - FM voices drifting through reverb and delay
        layerHandles[2] = strudel_play(
            note_pattern("<g3 c4 eb4 f4 bb3 g3 ab3 c4>", "sine")
                |> set_fm(2.0) |> set_fmh(3.0)
                |> slow(28.0)
                |> set_gain(0.08)
                |> set_attack(6.0) |> set_decay(3.0) |> set_sustain(0.5) |> set_release(10.0)
                |> set_lpf(1200.0)
                |> set_room(1.0) |> set_roomsize(10.0)
                |> set_delay(0.3) |> set_delaytime(0.8) |> set_delayfeedback(0.45)
                |> set_orbit(3)
        )
    } elif (idx == 3) {
        // Layer 4: bubble arpeggios - sparse high notes with a heavy delay tail
        layerHandles[3] = strudel_play(
            s("0 ~ ~ 4 ~ 2 ~ ~ 6 ~ 3 ~")
                |> set_scale("C4:pentatonic")
                |> set_sound("triangle")
                |> slow(6.0)
                |> set_gain(signal_perlin() |> signal_range(0.03, 0.12) |> slow(10.0))
                |> set_attack(0.01) |> set_decay(0.4) |> set_sustain(0.05) |> set_release(2.0)
                |> set_lpf(3000.0)
                |> set_pan(signal_sine() |> signal_range(0.15, 0.85) |> slow(7.0))
                |> set_room(0.8) |> set_roomsize(6.0)
                |> set_delay(0.55) |> set_delaytime(0.5) |> set_delayfeedback(0.65)
                |> set_orbit(4)
        )
    } elif (idx == 4) {
        // Layer 5: second arpeggio layer - higher, sparser, offset timing
        layerHandles[4] = strudel_play(
            s("~ 5 ~ ~ 1 ~ ~ ~ 3 ~ ~ 7")
                |> set_scale("C5:pentatonic")
                |> set_sound("sine")
                |> slow(8.0)
                |> set_gain(signal_perlin() |> signal_range(0.02, 0.08) |> slow(14.0))
                |> set_attack(0.02) |> set_decay(0.3) |> set_sustain(0.0) |> set_release(3.0)
                |> set_lpf(4000.0)
                |> set_pan(signal_sine() |> signal_range(0.1, 0.9) |> slow(11.0))
                |> set_room(0.9) |> set_roomsize(9.0)
                |> set_delay(0.4) |> set_delaytime(0.75) |> set_delayfeedback(0.55)
                |> set_orbit(4)
        )
    } else {
        // Layer 6: sub-harmonic pulse - barely audible low throb
        layerHandles[5] = strudel_play(
            note_pattern("<c1 c1 f0 f0>", "sine")
                |> slow(48.0)
                |> set_gain(signal_sine() |> signal_range(0.0, 0.15) |> slow(16.0))
                |> set_attack(8.0) |> set_release(10.0)
                |> set_lpf(100.0)
                |> set_orbit(1)
        )
    }
    update_status()
}


def stop_layer(idx : int) {
    if (!layerOn[idx]) {
        return
    }
    layerOn[idx] = false
    strudel_fade(layerHandles[idx], 0.0, 2.0)
    update_status()
}


def toggle_layer(idx : int) {
    if (layerOn[idx]) {
        stop_layer(idx)
    } else {
        play_layer(idx)
    }
}


[cheat]
def s_play() {
    s_stop()
    strudel_cps(0.25)
    for (i in range(NUM_LAYERS)) {
        play_layer(i)
    }
}


[cheat]
def s_stop() {
    for (i in range(NUM_LAYERS)) {
        strudel_stop(layerHandles[i])
        layerOn[i] = false
    }
    update_status()
}


[cheat]
def s_pause(val : bool = true) {
    strudel_pause(val)
}


[cheat]
def s_volume(val : float) {
    strudel_volume(val)
}


[export]
def on_initialize() {
    let camera = create_node(NodeData(position = float3(0, 0, -1)))
    add_component(camera, new Camera(
        orthographic = true,
        orthographicSize = 1.0,
        fovAxis = FovAxis.Vertical,
        fov = TO_RAD * 90f,
        backgroundColor = float3(0.01, 0.02, 0.05)
    ))

    statusNode = create_debug_text(float2(10, 10), TOP_LEFT_ANCHOR)
    s_play()
}


[export]
def on_update() {
    for (cmd in get_input_command_buffer()) {
        match (cmd) {
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = $v(key)) && int(key) >= int(KeyCode._1) && int(key) <= int(KeyCode._6)) {
                toggle_layer(int(key) - int(KeyCode._1))
            }
        }
    }
}
