require engine.core
require scripts.sound
require scripts.user_settings

class SetVolumeBehavior : Component {
    soundsCategory : SoundsCategory
    def override on_initialize() : void {
        get_component(nodeId) $(var slider : UIHorizontalSlider?) {
            slider.onChange = @(value : float) {
                if (soundsCategory == SoundsCategory.Music) {
                    userSettings.musicVolume = value
                    set_music_volume(value)
                } else {
                    userSettings.soundsVolume = value
                }
            }
            slider.value = soundsCategory == SoundsCategory.Music ? userSettings.musicVolume : userSettings.soundsVolume
        }
    }
}
