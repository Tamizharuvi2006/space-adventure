shader_type canvas_item;

// Explore Sun V4 — Warm Solar Atmosphere Sky
// Inspired by Mars: Mars visual style:
// TOP: bright teal-green (#5ECFB8)
// MID: warm yellow-amber (#D4A83A)
// LOWER-MID: warm orange-coral (#D86832)
// BOTTOM: deep warm red-brown (#7A2010)

uniform vec4 top_color : source_color = vec4(0.37, 0.81, 0.72, 1.0);   // Teal-green
uniform vec4 mid_color : source_color = vec4(0.83, 0.66, 0.23, 1.0);   // Golden amber
uniform vec4 bottom_color : source_color = vec4(0.48, 0.13, 0.06, 1.0); // Deep warm red
uniform vec4 sun_color : source_color = vec4(1.0, 0.97, 0.82, 1.0);   // Bright warm white-yellow
uniform vec2 sun_pos = vec2(0.35, 0.22);  // Solar position in upper sky
uniform float sun_radius = 0.11;
uniform float aspect_ratio = 1.77777778; // Dynamic viewport aspect ratio (W / H)
uniform vec2 cam_offset = vec2(0.0, 0.0); // Celestial parallax offset from camera

void fragment() {
    vec2 uv = UV;
    
    // Three-stop warm atmospheric gradient
    // Top (teal) → Mid (amber) → Bottom (deep red)
    vec4 sky;
    if (uv.y < 0.40) {
        sky = mix(top_color, mid_color, smoothstep(0.0, 0.40, uv.y));
    } else {
        sky = mix(mid_color, bottom_color, smoothstep(0.40, 1.0, uv.y));
    }
    
    // Subtle warm atmospheric haze — slightly lighter in the middle horizon band
    vec4 haze_color = vec4(0.75, 0.45, 0.22, 1.0);
    float haze = smoothstep(0.35, 0.55, uv.y) * (1.0 - smoothstep(0.55, 0.75, uv.y)) * 0.28;
    sky = mix(sky, haze_color, haze);
    
    // Sun disc — crisp circular disc matching any mobile aspect ratio with celestial parallax
    vec2 dynamic_sun = sun_pos - cam_offset;
    vec2 aspect_uv = uv;
    aspect_uv.x *= aspect_ratio;
    vec2 scaled_sun = dynamic_sun;
    scaled_sun.x *= aspect_ratio;
    
    float dist = distance(aspect_uv, scaled_sun);
    
    // Hard sun disc core — crisp white disc like in the reference
    float sun_core = 1.0 - smoothstep(sun_radius * 0.82, sun_radius * 0.98, dist);
    
    // Soft warm glow around the sun (atmospheric scatter)
    float sun_glow = exp(-dist * 6.5) * 0.40;
    float sun_glow2 = exp(-dist * 2.8) * 0.15;
    
    // Apply sun: bright white disc + layered warm glow
    vec4 final_color = mix(sky, sun_color, sun_core * 0.95);
    final_color.rgb += sun_color.rgb * sun_glow * (1.0 - sun_core);
    final_color.rgb += vec3(0.90, 0.60, 0.25) * sun_glow2 * (1.0 - sun_core);
    
    // Faint geometric polygon haze shapes near horizon (atmospheric refraction)
    // Subtle — just a slight lightening in the mid-horizon band
    float atmo_band = smoothstep(0.45, 0.52, uv.y) * (1.0 - smoothstep(0.52, 0.62, uv.y)) * 0.18;
    final_color.rgb = mix(final_color.rgb, vec3(0.80, 0.55, 0.30), atmo_band);
    
    // No visible stars — the atmosphere is too warm/opaque for cold star visibility
    // (stars only visible in the very upper teal sky zone, barely)
    if (uv.y < 0.18) {
        float star_noise = fract(sin(dot(floor(uv * 280.0), vec2(12.9898, 78.233))) * 43758.5453);
        if (star_noise > 0.988) {
            float star_bright = (star_noise - 0.988) * 83.0 * (0.18 - uv.y) / 0.18;
            final_color.rgb += vec3(0.8, 0.9, 1.0) * star_bright * 0.3;
        }
    }
    
    COLOR = final_color;
}
