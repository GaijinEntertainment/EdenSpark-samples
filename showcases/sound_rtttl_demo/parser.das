require daslib/strings_boost
require daslib/utf8_utils


let NOTE <- [
    440.0,  // A
    493.9,  // B
    261.6,  // C
    293.7,  // D
    329.6,  // E
    349.2,  // F
    392.0,  // G
    0.0,    // pad
    466.2,  // A#
    0.0,
    277.2,  // C#
    311.1,  // D#
    0.0,
    370.0,  // F#
    415.3,  // G#
    0.0
]


struct Defaults {
    duration : int = 4
    octave : int = 6
    beatPerMin : float = 63.f
    wholeNote : float
}


def is_correct_duration(duration : int) : bool {
    let checkingResult = duration >= 1 && duration <= 32 && ((duration & (duration - 1)) == 0)
    if (!checkingResult) {
        error("Note parser error: wrong duration {duration}, allowed values 1, 2, 4, 8, 16, 32")
    }
    return checkingResult
}


def is_correct_octave(octave : int) : bool {
    let checkingResult = octave >= 4 && octave <= 7
    if (!checkingResult) {
        error("Note parser error: wrong octave {octave}, allowed values 4, 5, 6, 7")
    }
    return checkingResult
}


def parse_defaults(defaults : string#) : Defaults {
    var parsedDefaults = Defaults()

    var value = 0
    var key = ' '
    for (char in defaults) {
        if (is_number(char)) {
            value *= 10
            value += char - '0'
            if (key == 'd' && is_correct_duration(value)) {
                parsedDefaults.duration = value
            } elif (key == 'o' && is_correct_octave(value)) {
                parsedDefaults.octave = value
            } elif (key == 'b' && float(value) != 0.f) {
                parsedDefaults.beatPerMin = float(value)
            }
        } elif (is_alpha(char)) {
            if (char != 'd' && char != 'o' && char != 'b') {
                error("Note parser error: wrong format of default pair {defaults} at char {string(utf8_encode(uint(char)))}, example d=16,o=4,b=70")
                break
            }
            key = char
            value = 0
        } elif (char == ',' || char == '=') {
            continue
        } else {
            error("Note parser error: wrong format of default pair {defaults} at char {string(utf8_encode(uint(char)))}, example d=16,o=4,b=70")
            break
        }
    }

    parsedDefaults.wholeNote = (60.f * 1000. / parsedDefaults.beatPerMin) * 4.f
    return parsedDefaults
}


def parse_notes(notes : string#, defaults : Defaults) : array<tuple<float, float>> {
    var parseRes : array<tuple<float, float>>
    var duration = 0; var octave = 0; var idx = 0
    var durationMul = 1.0

    var charIdx = -1
    let next_char = $() : int {
        if (++charIdx < length(notes)) {
            return character_at(notes, charIdx)
        } else {
            return -1
        }
    }

    var noteChar = next_char()

    while (noteChar >= 0) {
        while (is_number(noteChar)) {
            duration *= 10
            duration += noteChar - '0'
            noteChar = next_char()
        }
        if (duration == 0 || !is_correct_duration(duration)) {
            duration = defaults.duration
        }

        if (is_alpha(noteChar)) {
            if (noteChar >= 'a' && noteChar <= 'g') {
                idx = noteChar - 'a'
            } else {
                idx = 7
            }
            noteChar = next_char()
        }

        if (noteChar == '#') {
            idx += 8
            noteChar = next_char()
        }

        // not specified: the dot should be AFTER the octave, but sometimes it can be written before
        if (noteChar == '.') {
            durationMul = 1.5
            noteChar = next_char()
        }

        if (is_number(noteChar)) {
            octave = noteChar - '0'
            noteChar = next_char()
        }
        if (octave == 0 || !is_correct_octave(octave)) {
            octave = defaults.octave
        }

        if (noteChar == '.') {
            durationMul = 1.5
            noteChar = next_char()
        }

        if (noteChar == ',' || noteChar < 0) {
            let freq = NOTE[idx] * float(1 << (octave - 4))
            let msec = defaults.wholeNote / float(duration) * durationMul
            push(parseRes, (freq, msec))

            duration = 0; octave = 0; idx = 0
            durationMul = 1.0
        } else {
            error("Note parser error: wrong format of notes at char {string(utf8_encode(uint(noteChar)))} ")
            push(parseRes, (0., 500.)) // replace note with 300ms pause
        }

        noteChar = next_char()
    }

    return <- parseRes
}


def get_notes(rawMelody : string) : array<tuple<float, float>> {
    var parsedNotes <- array<tuple<float, float>>()

    split(rawMelody, ":") $(parts) {
        if (length(parts) == 3) {
            parsedNotes <- parse_notes(parts[2], parse_defaults(parts[1]))
        } else {
            error("Note parser error: wrong format, needs name, defaults and notes parts separated by colon")
        }
    }

    return <- parsedNotes
}
