require engine.core
require weapon_controller
require character_look

class WeaponVisual : Component {
    //! The visual part of the weapon the player holds, in the first person view

    private controller : WeaponController? //! Access to weapon
    private look : CharacterLook?          //! Access to character look
    private activeViewmodel : NodeId       //! Currently visible node of the weapon

    def override on_initialize() {
        // cache frequently-used components of the same character
        var parent = nodeId.parent
        while (!!parent && controller == null) {
            controller = parent.get_component(type<WeaponController>)
            if (look == null) {
                look = parent.get_component(type<CharacterLook>)
            }
            parent = parent.parent
        }
    }

    def override on_update() {
        if (controller == null) {
            return
        }

        // the weapon is only in hands while the view is in the eyes
        if (look != null && look.isThirdPerson()) {
            hideActiveViewmodel()
            return
        }

        // show current weapon
        updateActiveViewmodel()
    }

    def private hideActiveViewmodel() {
        if (!!activeViewmodel) {
            activeViewmodel.isActive = false
            activeViewmodel = NodeId()
        }
    }

    def private updateActiveViewmodel() {
        // show current weapon model
        let node = find_child(nodeId, controller.weapon.viewmodelNode)
        if (node == activeViewmodel) {
            return
        }

        hideActiveViewmodel()
        activeViewmodel = node
        activeViewmodel.isActive = true
    }
}

class WeaponRecoil : Component {
    //! Kicks the node it sits on when the weapon fires
    //! Put it on a weapon model, in the first person prefab or on the character model

    private controller : WeaponController? //! Access to weapon
    private restRotation : float3          //! Rotation of the model between the shots

    def override on_initialize() {
        // cache frequently-used components of the same character
        var parent = nodeId.parent
        while (!!parent && controller == null) {
            controller = parent.get_component(type<WeaponController>)
            parent = parent.parent
        }

        restRotation = quat_to_euler(nodeId.localRotation)
    }

    def override on_update() {
        if (controller == null || !controller.isShotFired()) {
            return
        }

        // simple animation of recoil
        let kickedRotation = restRotation - float3(controller.weapon.recoilStrength, 0., 0.)
        var recoilTween = rotation_tween(nodeId, kickedRotation, controller.weapon.recoilDuration)
        set_loops(recoilTween, 1, LoopType.Yoyo)
    }
}
