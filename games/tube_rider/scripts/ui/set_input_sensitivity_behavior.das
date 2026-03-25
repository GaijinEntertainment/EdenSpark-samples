require engine.core
require scripts.user_settings

class SetInputSensitivityBehavior : Component {
    def override on_initialize() : void {
        get_component(nodeId) $(var slider : UIHorizontalSlider?) {
            slider.onChange = @(value : float) {
                userSettings.inputSensitivity = value
            }
            slider.value = userSettings.inputSensitivity
        }
    }
}
