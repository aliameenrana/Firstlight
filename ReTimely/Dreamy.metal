#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float hash21(float2 p) { return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }

[[ stitchable ]] half4 dreamy(float2 pos, half4 color, float2 size, float t,
                              half4 top, half4 glowA, half4 glowB, half4 bottom) {
    float2 uv = pos / size;
    float aspect = size.x / size.y;
    float2 q = float2(uv.x * aspect, uv.y);

    // Slow domain warp so the gradient breathes instead of sliding.
    float2 w = q + 0.07 * float2(sin(q.y * 3.1 + t * 0.21), cos(q.x * 2.7 - t * 0.17));
    w += 0.03 * float2(sin(w.y * 7.0 - t * 0.13), cos(w.x * 6.0 + t * 0.11));

    float3 col = mix(float3(top.rgb), float3(bottom.rgb), smoothstep(-0.05, 1.05, w.y));

    float2 a = float2(aspect * (0.30 + 0.22 * sin(t * 0.070)), 0.32 + 0.18 * cos(t * 0.090));
    float2 b = float2(aspect * (0.72 + 0.20 * cos(t * 0.050)), 0.70 + 0.16 * sin(t * 0.080));
    col = mix(col, float3(glowA.rgb), 0.70 * exp(-dot(w - a, w - a) * 4.5));
    col = mix(col, float3(glowB.rgb), 0.60 * exp(-dot(w - b, w - b) * 3.5));

    // Soft light falling from the top edge.
    float rays = 0.5 + 0.5 * sin(q.x * 9.0 + sin(t * 0.1) * 2.0) * sin(q.x * 4.0 - t * 0.07);
    col += float3(1.0) * 0.06 * rays * smoothstep(0.55, 0.0, uv.y);

    // Rising bubbles in three depth layers.
    float bubbles = 0.0;
    for (int i = 0; i < 3; i++) {
        float layer = float(i);
        float scale = 5.0 + layer * 5.0;
        float2 g = float2(q.x * scale, (q.y + t * (0.012 + 0.010 * layer)) * scale);
        float2 id = floor(g);
        float2 f = fract(g) - 0.5;
        float r = hash21(id + layer * 17.0);
        if (r > 0.6) {
            float2 o = (float2(hash21(id + 3.1), hash21(id + 7.7)) - 0.5) * 0.6;
            o.x += 0.12 * sin(t * 0.6 + r * 20.0);
            float rad = 0.03 + 0.07 * hash21(id + 1.3);
            float d = length(f - o);
            float core = smoothstep(rad, rad * 0.3, d);
            float halo = smoothstep(rad * 3.0, rad, d) * 0.25;
            float twinkle = 0.55 + 0.45 * sin(t * (0.7 + r) + r * 40.0);
            bubbles += (core + halo) * twinkle * (0.35 + 0.4 * hash21(id + 9.0)) / (1.0 + layer * 0.5);
        }
    }
    col += bubbles * 0.45 * mix(float3(1.0), float3(glowA.rgb), 0.35);

    float2 v = uv - 0.5;
    col *= 1.0 - 0.5 * dot(v, v);
    // Grain hides banding on long, low-contrast gradients.
    col += (hash21(pos + fract(t) * 91.0) - 0.5) * 0.02;
    return half4(half3(col), 1.0h);
}
