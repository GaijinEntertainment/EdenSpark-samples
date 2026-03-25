require engine.core

class MenuCommonBehavior : Component {
    def override on_initialize() : void {
        show_mouse_cursor(true)
        set_mouse_cursor_locked(false)
    }
}
