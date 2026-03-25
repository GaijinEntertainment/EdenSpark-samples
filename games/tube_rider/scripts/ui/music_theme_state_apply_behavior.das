require engine.core
require scripts.sound

class MusicTrackApplyBehavior : Component {
    stateToApply : MusicTrack

    def override on_initialize() : void {
        switch_music_track(stateToApply)
    }
}
