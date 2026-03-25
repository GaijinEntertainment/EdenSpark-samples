

require engine.core


let sampleRate = 44100
let bufferPlayTime = 1.0
let pixelResolution : int2 = int2(1600, 100)
let freq = 329.6

var sound : SoundHandle
var waveToDraw : array<float>
var currentEnvelope = EnvelopeValues()

// var lastStep = 0


struct EnvelopeValues {
    attack : float = 0.1
    decay : float = 0.1
    sustain : float = 0.7
    release : float = 0.1

    def operator ==(other : EnvelopeValues) : bool {
        return attack == other.attack && decay == other.decay && sustain == other.sustain && release == other.release
    }

    def operator !=(other : EnvelopeValues) : bool {
        return !(self == other)
    }
}


class SFXComopnent : Component {
    attackSlider : NodeId
    decaySlider : NodeId
    sustainSlider : NodeId
    releaseSlider : NodeId
}

def getEnvelopeFromSFXComponent(nodeId : NodeId) : EnvelopeValues {
    var result = EnvelopeValues()

    get_component(nodeId) $(var sfxComponent : SFXComopnent?) {
        result.attack = sfxComponent.attackSlider?.UIHorizontalSlider.value
        result.decay = sfxComponent.decaySlider?.UIHorizontalSlider.value
        result.sustain = sfxComponent.sustainSlider?.UIHorizontalSlider.value
        result.release = sfxComponent.releaseSlider?.UIHorizontalSlider.value
    }

    return result
}

class SFXPreviewComponent : Component {
    textureId : TextureId
    private bitmap : Bitmap

    def override on_initialize() {
        textureId = create_texture(pixelResolution.x, pixelResolution.y, array<uint>(), TextureDeclaration(
            filter = TextureFilter.Bilinear,
            generateMipLevels = false,
            addressing = TextureAddress.Clamp
        ))
        bitmap <- Bitmap(pixelResolution.x, pixelResolution.y)

        get_component(nodeId) $(var image : UIImage?) {
            image.textureId = textureId
        }

        clearBitmap(bitmap)
        drawWave(bitmap, waveToDraw)
        update_texture(bitmap, textureId)
    }

    def override on_update() {
        let envelopeValues = getEnvelopeFromSFXComponent(nodeId.parent)

        if (currentEnvelope != envelopeValues) {
            currentEnvelope = envelopeValues
            waveToDraw = generateSineWave(pixelResolution.x, 30.0, bufferPlayTime, currentEnvelope)

            clearBitmap(bitmap)
            drawWave(bitmap, waveToDraw)
            update_texture(bitmap, textureId)
        }
    }
}

def sampler(frequency : float, t : float) : float {
    let period = 1.0 / frequency
    return sin(2.0 * PI / period * t)
}

def envelope(var sample : float, t : float, duration : float, values : EnvelopeValues) : float {
    let attackTime = values.attack
    let decayTime = values.decay
    let sustainGain = values.sustain
    let releaseTime = values.release

    if (t < attackTime) {
        sample *= lerp(t, 0.0, attackTime, 0.0, 1.0)
    } elif (t < attackTime + decayTime) {
        sample *= lerp(t, attackTime, attackTime + decayTime, 1.0, sustainGain)
    } elif (t < duration - releaseTime) {
        sample *= sustainGain
    } else {
        sample *= lerp(t, duration - releaseTime, duration, sustainGain, 0.0)
    }

    return sample
}

def lerp(t, a, b, c, d : float) : float {
    return c + (d - c) * (t - a) / (b - a)
}

def generateSineWave(sampleRate : int, frequency : float, duration : float, envelopeValues : EnvelopeValues <- EnvelopeValues()) : array<float> {
    var wave : array<float>

    for (i in range(0, sampleRate)) {
        let t = float(i) / float(sampleRate)
        let t1 = (float(i) * duration) / float(sampleRate)
        let sample = sampler(frequency, t) |> envelope(t, duration, envelopeValues)

        wave.push(sample)
    }

    return <- wave
}

def clearBitmap(var bitmap : Bitmap) {
    for (i in range(bitmap.pixels.length())) {
        bitmap.pixels[i] = 0u
    }
}

def drawWave(var bitmap : Bitmap, wave : array<float>) {
    if (wave.length() < 2) {
        return
    }

    let step : int = pixelResolution.x / wave.length()
    var x : int = 0

    for (i in range(0, wave.length() - 1)) {
        let halfRes : float = float(pixelResolution.y) * 0.5
        let from = int2(x, round((wave[i] + 1.0) * halfRes) |> int())
        let to = int2(x + step, round((wave[i + 1] + 1.0) * halfRes) |> int())

        antialiased_line(bitmap, from, to, 0xFF3ECE00, 3.0)
        x += step
    }
}

def handlePlayInfiniteWaveRequest() {
    if (is_action_pressed("playSound")) {
        print("playing")

        if (get_stream_queue(sound) < 2) {
            if (is_stopped(sound)) {
                sound = play_sound_stream(sampleRate, 1)
            }

            var inscope wave = generateSineWave(sampleRate, freq, bufferPlayTime)
            append_to_stream(sound) <| wave
        }
    }
    elif (is_playing(sound) && get_stream_queue(sound) > 0) {
        print("stopped")
        stop(sound)
        // lastStep = 0
    }
}

def handlePlayFiniteWaveRequest() {
    if (is_action_just_pressed("playSound")) {
        print("playing")

        stop(sound)
        // lastStep = 0

        var wave = generateSineWave(sampleRate, freq, bufferPlayTime, currentEnvelope)
        sound = play_sound(sampleRate, 1) <| wave
    }
}

[export]
def on_initialize() {
    add_and_activate_action_set("basic", {
        "playSound" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.F)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
            )
        )
    })
    let camera = create_node() <| NodeData(name = "camera", position = float3(0, 0, -1))
    add_component(camera, new Camera())

    sound = play_sound_stream(sampleRate, 1)
    waveToDraw = generateSineWave(pixelResolution.x, 30.0, bufferPlayTime)

    let canvas = create_node() <| NodeData(name = "canvas")
    canvas.add_component(new UICanvas(
        screenMode = ScreenMode.Fullscreen
    ))

    let node = request_prefab("synth.prefab") |> instantiate_prefab(NodeData(parent = canvas))

    show_mouse_cursor(true)
}

[export]
def on_update() {
    handlePlayFiniteWaveRequest()
}
