require engine.core
require scripts.ui.button_close_with_action_behavior

def show_confirm_box(text : string, var on_confirm_cb : lambda<() : void>) {
    let confirmBoxPrefab = request_prefab("prefabs/ui/confirm_box.prefab")
    let confirmBoxNode = instantiate_prefab(confirmBoxPrefab)
    let confirmButton = find_child_recursive(confirmBoxNode, "confirm_button")
    let textNode = find_child_recursive(confirmBoxNode, "text")
    confirmButton.get_component(type<ButtonCloseWithActionBehavior>).action <- on_confirm_cb
    textNode.get_component(type<UIText>).text = text
}
