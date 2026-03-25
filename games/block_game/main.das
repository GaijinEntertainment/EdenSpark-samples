require engine.core

require WorldComponent
require PlayerComponent


[export]
def on_initialize() {
    set_mouse_cursor_locked(true)
}