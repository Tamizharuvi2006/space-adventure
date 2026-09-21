shader_type canvas_item;

// Explore Sun V8 — Cinematic Alien Planet Sky
// Param names match background.gd set_shader_parameter calls exactly.

uniform vec4 sky_color     : source_color = vec4(0.04, 0.03, 0.08, 1.0); // Upper sky (dark)
uniform vec4 horizon_color : source_color = vec4(0.24, 0.08, 0.06, 1.0); // Mid horizon
uniform vec4 bottom_color  : source_color = vec4(0.55, 0.22, 0.08, 1.0); // Warm ground glow
uniform vec4 sun_color     : source_color = vec4(1.00, 0.78, 0.35, 1.0); // Sun disc
uniform vec2 sun_pos       = vec2(0.52, 0.15);
uniform float sun_radius   = 0.13;
uniform float aspect_ratio = 1.77777778;
uniform vec2  cam_offset   = vec2(0.0, 0.0);
uniform float haze_intensity = 0.30;

void fragment() {
    vec2 uv = SCREEN_UV;

    // ── 3-stop sky gradient: dark upper → warm horizon → glowing ground ──────
    vec4 sky;
    if (uv.y < 0.45) {
        sky = mix(sky_color, horizon_color, smoothstep(0.0, 0.45, uv.y));
    } else {
        sky = mix(horizon_color, bottom_color, smoothstep(0.45, 1.0, uv.y));
    }

    // ── Atmospheric haze band near horizon ────────────────────────────────────
    float haze = smoothstep(0.28, 0.48, uv.y) * (1.0 - smoothstep(0.48, 0.72, uv.y));
    vec4 haze_col = mix(horizon_color, bottom_color, 0.45);
    sky = mix(sky, haze_col, haze * haze_intensity * 0.55);

    // ── Sun disc with multi-layer cinematic glow ──────────────────────────────
    vec2 dyn_sun = sun_pos - cam_offset;
    vec2 asp_uv  = vec2(uv.x * aspect_ratio, uv.y);
    vec2 asp_sun = vec2(dyn_sun.x * aspect_ratio, dyn_sun.y);
    float dist   = distance(asp_uv, asp_sun);

    // Hard crisp disc core
    float sun_core   = 1.0 - smoothstep(sun_radius * 0.80, sun_radius * 0.96, dist);
    // Inner warm glow
    float glow_inner = exp(-dist * 5.5) * 0.55;
    // Wide atmospheric scatter bloom
    float glow_outer = exp(-dist * 2.0) * 0.28;
    // Subtle wide corona
    float corona     = exp(-dist * 0.85) * 0.14;

    vec4 final = mix(sky, sun_color, sun_core * 0.96);
    final.rgb += sun_color.rgb * glow_inner * (1.0 - sun_core * 0.8);
    final.rgb += mix(sun_color.rgb, vec3(0.95, 0.52, 0.18), 0.55) * glow_outer;
    final.rgb += vec3(0.78, 0.38, 0.14) * corona;

    // ── Stars: dense, small, atmospheric extinction near horizon ─────────────
    float star_vis = clamp(1.0 - smoothstep(0.0, 0.32, uv.y), 0.0, 1.0);
    // Suppress stars near the sun disc
    float sun_prox = 1.0 - clamp(exp(-dist * 1.6) * 2.8, 0.0, 1.0);
    star_vis *= sun_prox;

    if (star_vis > 0.01) {
        vec2 star_uv = vec2(uv.x * aspect_ratio, uv.y);
        // Fine grid — small stars
        float n1 = fract(sin(dot(floor(star_uv * 240.0), vec2(12.9898, 78.233))) * 43758.5453);
        if (n1 > 0.974) {
            float bright = (n1 - 0.974) / 0.026;
            float twinkle = fract(sin(dot(floor(star_uv * 240.0), vec2(45.23, 95.48))) * 21341.9);
            final.rgb += vec3(0.82, 0.88, 1.0) * bright * star_vis * (0.45 + twinkle * 0.55);
        }
        // Coarser grid — slightly larger stars
        float n2 = fract(sin(dot(floor(star_uv * 120.0), vec2(93.98, 24.23))) * 73258.5453);
        if (n2 > 0.988) {
            float bright = (n2 - 0.988) / 0.012;
            final.rgb += vec3(0.90, 0.92, 1.0) * bright * 1.6 * star_vis;
        }
    }

    COLOR = final;
}