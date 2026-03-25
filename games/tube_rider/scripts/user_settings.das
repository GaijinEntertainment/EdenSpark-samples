require engine.core

enum SoundsCategory {
    Music
    SFX
}

enum TurnMode {
    Instant
    Inertial
}

struct UserSettings {
    loaded : bool = false
    musicVolume : float = 1.0f
    soundsVolume : float = 1.0f
    inputSensitivity : float = 0.5f
    turnMode : TurnMode = TurnMode.Inertial
}

var userSettings : UserSettings = UserSettings()

def load_user_settings() {
    if (userSettings.loaded)
        return
    let storage = load_storage("user_settings")
    userSettings.loaded = true
    userSettings.musicVolume = storage.get_or("music_volume", 1.0f)
    userSettings.soundsVolume = storage.get_or("sounds_volume", 1.0f)
    userSettings.inputSensitivity = storage.get_or("input_sensitivity", 0.5f)
    userSettings.turnMode = storage.get_or("turn_mode", int(TurnMode.Inertial)) == int(TurnMode.Inertial) ? \
        TurnMode.Inertial : TurnMode.Instant
}

[export]
def on_initialize() {
    load_user_settings()
}

[export]
def on_exit() {
    var storage = GenericStorage()
    storage.set("music_volume", userSettings.musicVolume)
    storage.set("sounds_volume", userSettings.soundsVolume)
    storage.set("input_sensitivity", userSettings.inputSensitivity)
    storage.set("turn_mode", int(userSettings.turnMode))
    save_storage(storage, "user_settings")
}
