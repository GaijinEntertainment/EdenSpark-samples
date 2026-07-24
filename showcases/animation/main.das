require engine.core
require engine.arcball_camera

[export]
def on_initialize() {
    show_mouse_cursor(true)
}

class UIAnimationListDropdown : Component {

    model : ModelId
    playerNode : NodeId
    def override on_initialize() {
        get_component(nodeId) $(var dropdown : UIDropDown?) {
            var animations <- get_model_animations(model)
            dropdown.items = [for (it in animations); it.name]
            dropdown.onChange = @ capture(<- animations) (newIndex : int) {
                playerNode.get_component($(var player : SingleAnimationPlayer?) {
                    player.animation = animations[newIndex].animationId
                })
            }
        }
    }
}