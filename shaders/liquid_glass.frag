#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2  uSize;
uniform float uTime;
uniform float uPress;
uniform float uStateMix;
uniform vec4  uTint;
uniform sampler2D uTexture;

out vec4 fragColor;

vec4 sampleBackdrop(vec2 uv) {
    uv = clamp(uv, vec2(0.001), vec2(0.999));
#ifdef IMPELLER_TARGET_OPENGLES
    uv.y = 1.0 - uv.y;
#endif
    return texture(uTexture, uv);
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uSize;

    float radius = 0.5 * min(uSize.x, uSize.y);
    vec2 center = 0.5 * uSize;
    vec2 p = (fragCoord - center) / radius;
    float d = length(p);

    if (d >= 1.0) {
        fragColor = sampleBackdrop(uv);
        return;
    }

    vec2 dir = d > 0.0001 ? p / d : vec2(0.0);

    // Lens height profile: flat dome center, steep falloff at rim
    float h = sqrt(max(0.0, 1.0 - d * d));

    // Center magnification (liquid dome), slightly deeper when pressed
    float magnify = 0.10 + 0.05 * uPress;
    vec2 lensUv = uv - (p * radius / uSize) * magnify * h;

    // Edge refraction: bend the backdrop outward near the rim
    float rimZone = smoothstep(0.45, 1.0, d);
    float bend = pow(rimZone, 2.2) * (0.14 + 0.06 * uPress);
    vec2 disp = (dir * radius / uSize) * bend;

    // Chromatic aberration at the rim
    float caStrength = 1.0 + rimZone * 0.9;
    float r = sampleBackdrop(lensUv - disp * 1.00 * caStrength).r;
    float g = sampleBackdrop(lensUv - disp * 1.18 * caStrength).g;
    float b = sampleBackdrop(lensUv - disp * 1.36 * caStrength).b;
    vec3 refracted = vec3(r, g, b);

    // Frosted glass body tint
    vec3 glassTint = mix(vec3(1.0), uTint.rgb, 0.35 + 0.45 * uStateMix);
    float bodyAlpha = 0.06 + 0.30 * uStateMix;
    vec3 col = mix(refracted, glassTint, bodyAlpha);

    // Inner shading: subtle darkening toward lower edge (depth)
    float shade = smoothstep(0.2, 1.0, d) * max(0.0, dir.y) * 0.10;
    col -= shade;

    // Moving specular highlight — soft blob orbiting the upper rim
    vec2 lightDir = normalize(vec2(cos(uTime * 0.5) * 0.6, -0.8));
    float spec = pow(max(0.0, dot(dir, lightDir)), 22.0);
    float specBand = smoothstep(0.50, 0.78, d) * (1.0 - smoothstep(0.86, 1.0, d));
    col += vec3(1.0) * spec * specBand * (0.55 + 0.25 * uStateMix);

    // Broad top sheen (iOS glass top light)
    float sheen = smoothstep(0.15, -0.9, p.y) * (1.0 - smoothstep(0.0, 0.95, d));
    col += vec3(1.0) * sheen * 0.10;

    // Bright rim ring — mirror edge of the lens
    float rim = smoothstep(0.90, 0.985, d) * (1.0 - smoothstep(0.985, 1.0, d));
    vec3 rimColor = mix(vec3(1.0), uTint.rgb, 0.5);
    float rimLight = 0.35 + 0.35 * max(0.0, dot(dir, lightDir)) + 0.2 * uStateMix;
    col += rimColor * rim * rimLight;

    // Fresnel-ish edge glow just inside the rim
    float fresnel = pow(rimZone, 3.0) * 0.16;
    col += glassTint * fresnel;

    // Smooth anti-aliased edge to backdrop
    float edgeAA = smoothstep(1.0, 0.985, d);
    vec3 outside = sampleBackdrop(uv).rgb;
    col = mix(outside, col, edgeAA);

    fragColor = vec4(col, 1.0);
}
