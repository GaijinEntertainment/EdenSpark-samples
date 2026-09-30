require engine.render.shader_dsl

var {
    @color skyColor = float3(0.003, 0.005, 0.015)
    @color nebulaColor = float3(0.08, 0.03, 0.14)
    @color starColor = float3(0.9, 0.95, 1.0)
    starDensity = 1.5
    starSize = 0.08
    twinkleSpeed = 2.0
    nebulaScale = 0.06
}

def hash(cell : float2) : float {
    return frac(sin(dot(cell, float2(12.9898, 78.233))) * 43758.5453)
}

// One star at most per grid cell, placed at a random offset; only some cells get a star.
def star_layer(p : float2; density : float; size : float) : float {
    let q = p * density
    let h = hash(floor(q))
    let center = frac(float2(h * 13.7, h * 71.3)) * 0.6 + float2(0.2)
    let glow = smooth_step(size, 0.0, length(frac(q) - center))
    let twinkle = sin(g_Time * twinkleSpeed + h * 100.0) * 0.4 + 0.6
    return glow * step(0.7, h) * twinkle
}

[pixel_shader]
def starfield(inp : UnlitInput) : UnlitOutput {
    let p = inp.worldPos.xy
    let nebula = smooth_step(0.45, 0.9, noise(p * nebulaScale) * 0.7 + noise(p * nebulaScale * 3.0) * 0.3)
    let stars = star_layer(p, starDensity, starSize) + star_layer(p, starDensity * 3.0, starSize * 1.5) * 0.5
    return UnlitOutput(
        color = skyColor + nebulaColor * nebula + starColor * stars
    )
}
