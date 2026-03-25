require engine.core


[export]
def on_initialize() {
    show_mouse_cursor()

    let camera = create_node(NodeData(name = "camera"))
    add_component(camera, new Camera())

    add_ui_event_listener(UIFocusEventType.FocusIn, @@focus_evt)
    add_ui_event_listener(UIFocusEventType.FocusOut, @@focus_evt)
}

[export]
def on_post_initialize() {

    for (button in find_components(type<UIButton>)) {
        button.onClick = @() { print("Button {button.nodeId} clicked!"); }
    }

    for (checkbox in find_components(type<UICheckbox>)) {
        checkbox.onChange = @(v : bool) { print("Checkbox \"{checkbox.nodeId}\" toggled to {v}!"); }
    }

    for (textInput in find_components(type<UITextInput>)) {
        textInput.onChange = @(v : string) { print("Text of input \"{textInput.nodeId}\" changed to \"{v}\"!"); }
    }

    for (dropdown in find_components(type<UIDropDown>)) {
        dropdown.onChange = @(v : int) { print("Selected item of dropdown \"{dropdown.nodeId}\" changed to {dropdown.items[v]}!"); }
    }

    for (horizontalSlider in find_components(type<UIHorizontalSlider>)) {
        horizontalSlider.onChange = @(v : float) { print("Value of horizontal slider \"{horizontalSlider.nodeId}\" changed to {v}!"); }
    }

    for (verticalSlider in find_components(type<UIVerticalSlider>)) {
        verticalSlider.onChange = @(v : float) { print("Value of vertical slider \"{verticalSlider.nodeId}\" changed to {v}!"); }
    }

    for (scrollArea in find_components(type<UIScrollArea>)) {
        scrollArea.onScroll = @(offset : float2) { print("Scroll area \"{scrollArea.nodeId}\" scrolled to offset {offset}!"); }
    }
}


def focus_evt(evt : UIFocusEvent) {
    print("{evt.eventType} on {evt.target}")
}
