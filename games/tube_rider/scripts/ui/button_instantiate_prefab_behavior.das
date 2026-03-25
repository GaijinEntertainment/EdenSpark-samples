require engine.core

class ButtonInstantiatePrefabBehavior : Component {
    prefabName : string

    def override on_initialize() : void {
        get_component(nodeId) $(var btn : UIButton?) {
            btn.onClick = @() {
                instantiate_prefab(request_prefab("{prefabName}.prefab"))
            }
        }
        pass
    }
}
