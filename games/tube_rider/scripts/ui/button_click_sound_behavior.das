require engine.core
require scripts.sound

class ButtonClickSoundBehavior : Component {
    def override on_initialize() : void {
        add_ui_event_listener(nodeId, UIMouseEventType.MouseClick, @@(evt : UIMouseEvent) {
            if (evt.phase == UIInputEventPhase.Target && evt.mouseButton == MouseButton.Left) {
                play_game_sound(clickSound)
            }
        })
    }
}
