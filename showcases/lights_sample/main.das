require engine.core
require engine.free_camera

var camera : NodeId
var renderSettings : NodeId
var pointLight : NodeId
var fillLight : NodeId
var keyLight : NodeId
var backLight : NodeId
var statusNode : NodeId

var sun : NodeId
let sunDirection = float3(PI / 12., PI * 0.75, 0.)

def add_object(scale : float, resId : MeshId, position : float3, color : float4 = float4(1)) {
    let node = create_node(NodeData(position = position, scale = float3(scale)))
    add_component(node, new Mesh(meshId = resId, color = color))
}

def init_world() {

    let cube = create_cube_mesh(CubeInit(width = 2., height = 10., depth = 2.))
    let sphere = create_sphere_mesh(SphereInit(radius = 1.))

    let vase = create_solid_of_revolution_mesh(RevolutionInit(
        points <- [
            float2(0.5, 0.),
            float2(1., 0.1),
            float2(1.1, 0.5),
            float2(1, 1),
            float2(0.4, 1.5),
            float2(0.4, 2.5),
            float2(0.5, 2.6),
            float2(0.5, 2.63),
            float2(0.49, 2.66)
        ]
    ))

    let backdrop = create_extruder_mesh(ExtruderInit(
        polygonPoints <- [
            float2(0., 1.),
            float2(0., 0.2),
            float2(0.01, 0.1),
            float2(0.04, 0.04),
            float2(0.1, 0.01),
            float2(0.2, 0.),
            float2(1., 0.),
            float2(1., -0.1),
            float2(-0.1, -0.1),
            float2(-0.1, 1.)
        ],
        points <- [
            float3(-1., 0., 0.),
            float3(1., 0., 0.)
        ],
        smoothNormals = true
    ))

    add_object(1., cube, float3(0., 5., 0.))
    add_object(3., sphere, float3(0., 3., -11.), color32_to_float4(0xffE75959))
    add_object(3., sphere, float3(-9., 3., -7.), color32_to_float4(0xff59E7A8))
    add_object(3., sphere, float3(9., 3., -7.), color32_to_float4(0xff6459E7))
    add_object(1., vase, float3(0., 10., 0.), color32_to_float4(0xff3B80E7))
    add_object(80., backdrop, float3(0., 0., -55.))

    camera = create_free_camera(float3(0, 20, 40), quat4(float3(PI / 12., PI, 0.)))

    sun = create_node(NodeData(rotation = quat4(sunDirection)))
    add_component(sun, new DirectionLight())

    renderSettings = create_render_settings()

    get_component(renderSettings) $(var shadow : ShadowSettings?) {
        shadow.numCascades = 2
        shadow.cascadeWidth = 2048
        shadow.powWeight = 0.5
        shadow.maxDist = 150.
    }

    get_component(renderSettings) $(var tonemap : Tonemap?) {
        tonemap.active = true
    }

    get_component(renderSettings) $(var ssao : SSAOSettings?) {
        ssao.worldRadius = 4.0
    }

    pointLight = create_node(NodeData(name = "point light", position = float3(0, 0, 0)))
    add_component(pointLight, new PointLight(
        intensity = 100.,
        radius = 15.,
        castShadows = true,
        castShadowsOnlyForStatic = false
    ))

    keyLight = create_node(NodeData(name = "key light", position = float3(-14, 11, 16), rotation = quat4(deg_to_rad(float3(35., 145., 0.)))))
    add_component(keyLight, new SpotLight(
        intensity = 500.,
        radius = 100.,
        angle = PI / 3.,
        attenuation = 0.75,
        castShadows = true,
        castShadowsOnlyForStatic = false
    ))

    fillLight = create_node(NodeData(name = "fill light", position = float3(14, 11, 16), rotation = quat4(deg_to_rad(float3(35., -145., 0.)))))
    add_component(fillLight, new SpotLight(
        intensity = 100.,
        radius = 100.,
        angle = PI / 3.,
        attenuation = 0.8,
        castShadows = true,
        castShadowsOnlyForStatic = false
    ))

    backLight = create_node(NodeData(name = "back light", position = float3(-25, 20, -25), rotation = quat4(deg_to_rad(float3(50, 50., 0.)))))
    add_component(backLight, new SpotLight(
        intensity = 500.,
        radius = 100.,
        angle = PI / 3.,
        attenuation = 0.8,
        castShadows = false,
        castShadowsOnlyForStatic = false
    ))

    statusNode = create_debug_text("Light Sample Scene\nPress Space (or A on gamepad) to switch between Sun and Three-Point", float2(20, -20), BOTTOM_LEFT_ANCHOR)
    statusNode?.UIText.color = color32_to_float4(0xff000000)

    fillLight.isActive = false
    keyLight.isActive = false
    backLight.isActive = false
    sun.isActive = true
}


def init_input() {
    add_and_activate_action_set("basic", {
        "toggleSun" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Space)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
            )
        )
    })
}


[export] def on_initialize() {
    init_world()
    init_input()
}


[export]
def on_update() {
    let t = get_time()
    pointLight.localPosition = float3(5. * sin(t * 2.), 2. * sin(t * 0.2) + 10., 5. * cos(t * 2.))
    get_component(pointLight) $(var light : PointLight?) {
        light.color = float3(sin(t), sin(t + TWO_PI * 1. / 3.), sin(t + TWO_PI * 2. / 3.)) * 0.5 + float3(0.5)
    }

    if (is_action_just_pressed("toggleSun")) {
        fillLight.isActive = sun.isActive
        keyLight.isActive = sun.isActive
        backLight.isActive = sun.isActive
        sun.isActive = !sun.isActive
        renderSettings.get_component($(var sky : Sky?) {
            sky.active = sun.isActive
        })
        renderSettings.get_component($(var ambient : AmbientSettings?) {
            ambient.ambientColor = float3(0.12, 0.12, 0.12)
            ambient.ambientSource = sun.isActive ? AmbientSource.SkyColor : AmbientSource.ConstColor
        })
        statusNode?.UIText.color = sun.isActive ? float4(0, 0, 0, 1) : float4(1)
    }
}
