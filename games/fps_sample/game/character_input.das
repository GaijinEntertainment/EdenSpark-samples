require engine.core
require health
require character_look
require character_movement
require weapon_controller

//! How far the view turns per unit of input, until there is a settings menu to set it from
let MOUSE_SENSITIVITY = 0.003
let GAMEPAD_SENSITIVITY = 0.05

//! How far up and down the character may look, in radians
let MIN_PITCH = -80. * TO_RAD
let MAX_PITCH = 80. * TO_RAD

class CharacterInput : Component {
    //! Keyboard and gamepad controls. Add it to the node the human player controls
    //! A bot is the same character without it

    @hint = "Part of the top speed while walking"
    walkFactor : float = 0.55

    @hint = "Part of the top speed while the sprint button is held"
    sprintFactor : float = 1.

    private look : CharacterLook?         //! Access to character look
    private movement : CharacterMovement? //! Access to character movement
    private weapon : WeaponController?    //! Access to character weapon
    private health : Health?              //! Access to character health
    private ammoText : NodeId             //! Ammo counter in the corner of the screen

    def override on_initialize() {
        // grab the mouse
        set_mouse_cursor_locked(true)

        // action sets
        add_and_activate_action_set("fpsPlayer", {
            "move" => Action(
                joystickActions = JoystickAction(
                    keyboardDPads = [KeyboardDPadInput(leftIdx=KeyCode.A, rightIdx=KeyCode.D, upIdx=KeyCode.W, downIdx=KeyCode.S)],
                    sticks = [GamepadStickInput(xIdx=GamepadAxis.LThumbH, yIdx=GamepadAxis.LThumbV)]
                )
            ),
            "look" => Action(
                pointerActions = PointerAction(
                    valueType = ValueType.Delta,
                    mouse = MouseInput(active = true, sensitivity = MOUSE_SENSITIVITY),
                    gamepadPointers = [GamepadPointerInput(xIdx=GamepadAxis.RThumbH, yIdx=GamepadAxis.RThumbV, isYInverted = true, sensitivity = GAMEPAD_SENSITIVITY)]
                )
            ),
            "jump" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Space)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
                )
            ),
            "sprint" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.LShift)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.X)]
                )
            ),
            "fire" => Action(
                buttonActions = ButtonAction(
                    mouseButtons = [MouseButtonInput(idx=MouseButton.Left)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.RightTrigger)]
                )
            ),
            "reload" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.R)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Y)]
                )
            ),
            "weaponPistol" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode._1)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Down)]
                )
            ),
            "weaponRifle" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode._2)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Up)]
                )
            ),
            "thirdPerson" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.C)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.R3)]
                )
            )
        })

        // ammo counter
        ammoText = create_debug_text(float2(-20, 20), TOP_RIGHT_ANCHOR)
        set_text_color(ammoText, float4(0, 0, 0, 1))
    }

    def override on_update() {
        // cache frequently-used components of the same character
        if (look == null) {
            look = nodeId.get_component(type<CharacterLook>)
            movement = nodeId.get_component(type<CharacterMovement>)
            weapon = nodeId.get_component(type<WeaponController>)
            health = nodeId.get_component(type<Health>)
        }

        // controls are only read while the game owns the mouse
        if (is_mouse_cursor_locked()) {
            updateLook()

            // switching the view
            if (is_action_just_pressed("thirdPerson", ModifierMatchMode.Weak)) {
                look.thirdPerson = !look.thirdPerson
            }

            // a dead player only looks around
            if (!health.isDead) {
                updateMove()
                updateWeapon()
            }
        }

        updateAmmoText()
    }

    def private updateLook() {
        let delta = get_action_vector2("look")
        look.lookDelta(delta.x, -delta.y, MIN_PITCH, MAX_PITCH)
    }

    def private updateMove() {
        let inputDir = get_action_vector2("move")
        let moveDir = normalize(FORWARD * inputDir.y + RIGHT * inputDir.x)
        let factor = is_action_pressed("sprint") ? sprintFactor : walkFactor

        movement.input(moveDir * factor, is_action_just_pressed("jump", ModifierMatchMode.Weak))
    }

    def private updateWeapon() {
        // changing weapon slots
        if (is_action_just_pressed("weaponPistol", ModifierMatchMode.Weak)) {
            weapon.equip(PISTOL)
        }
        if (is_action_just_pressed("weaponRifle", ModifierMatchMode.Weak)) {
            weapon.equip(RIFLE)
        }

        if (is_action_just_pressed("reload", ModifierMatchMode.Weak)) {
            weapon.reload()
        }

        // an automatic weapon fires while the trigger is held, others once per press
        let data = weapon.weapon
        if (data.automatic ? is_action_pressed("fire", ModifierMatchMode.Weak) : is_action_just_pressed("fire", ModifierMatchMode.Weak)) {
            weapon.pullTrigger()
        }
    }

    def private updateAmmoText() {
        let data = weapon.weapon
        if (weapon.state == WeaponState.Reloading) {
            update_debug_text(ammoText, "{data.name}: reloading...")
        } else {
            update_debug_text(ammoText, "{data.name}: {weapon.ammo} / {data.magazineSize}")
        }
    }
}
