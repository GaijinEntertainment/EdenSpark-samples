require engine.core
require user_settings

let private musicTrackTransitionDuration = 0.2f

struct SoundSetup {
    soundId : SoundId
    volume : float = 1.0f
}

let clickSound = SoundSetup(soundId = request_sound("assets/sounds/click.mp3"), volume = 0.7f)
let hitSound = SoundSetup(soundId = request_sound("assets/sounds/hit.mp3"), volume = 0.5f)
let pickupSound = SoundSetup(soundId = request_sound("assets/sounds/pickup.mp3"), volume = 1.5f)

let private gameThemeSound = SoundSetup(soundId = request_sound("assets/sounds/game_theme.ogg"), volume = 0.5f)
let private menuThemeSound = SoundSetup(soundId = request_sound("assets/sounds/menu_theme.ogg"), volume = 0.35f)


def play_game_sound(sound : SoundSetup) {
    let soundInstanceId = play_sound(sound.soundId)
    set_volume(soundInstanceId, sound.volume * userSettings.soundsVolume)
    return soundInstanceId
}

struct MusicTrackLoop {
    musicSound : SoundSetup = SoundSetup()

    loopEndTime : float = 0.0f
    volume : float = 1.0f

    /*private*/ musicSoundInstances : SoundHandle[2] // Two instances just for volume adjusting to work correctly.
    /*private*/ curSoundId : int = 0

    def start() {
        musicSoundInstances[0] = play_sound(musicSound.soundId)
        setVolume(volume, 0f)
    }

    def update() {
        let curLoopPos = get_position(musicSoundInstances[curSoundId])
        if (curLoopPos >= loopEndTime) {
            curSoundId = 1 - curSoundId
            musicSoundInstances[curSoundId] = play_sound(musicSound.soundId)
            set_position(musicSoundInstances[curSoundId], curLoopPos - loopEndTime)
            setVolume(volume, 0f)
        }
    }

    def setVolume(volume, change_duration : float) {
        for (soundInstance in musicSoundInstances) {
            if (valid(soundInstance)) {
                set_volume(soundInstance, volume * musicSound.volume, change_duration)
            }
        }
        self.volume = volume
    }
}

enum MusicTrack {
    Game
    Menu
}

var currentMusicTrackId : MusicTrack = MusicTrack.Game

var musicTracks = fixed_array(
    MusicTrackLoop(musicSound = gameThemeSound, loopEndTime = 79.992),
    MusicTrackLoop(musicSound = menuThemeSound, loopEndTime = 79.992)
) // One per MusicTrack.

def switch_music_track(track_id : MusicTrack) {
    currentMusicTrackId = track_id
    musicTracks[int(track_id)].setVolume(userSettings.musicVolume, musicTrackTransitionDuration)
    musicTracks[1 - int(track_id)].setVolume(0f, musicTrackTransitionDuration)
}

def set_music_volume(volume : float) {
    musicTracks[int(currentMusicTrackId)].setVolume(volume, musicTrackTransitionDuration)
}

[export]
def on_initialize() {
    load_user_settings()
    for (track in musicTracks) {
        track.volume = userSettings.musicVolume
        track.start()
    }
}

[export]
def on_update() {
    for (track in musicTracks) {
        track.update()
    }
}
