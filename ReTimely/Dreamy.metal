#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float hash21(float2 p) { return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }

static float noise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + float2(1, 0)), u.x),
               mix(hash21(i + float2(0, 1)), hash21(i + float2(1, 1)), u.x), u.y);
}

static float fbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 3; i++) { v += a * noise(p); p = p * 2.03 + 17.0; a *= 0.5; }
    return v;
}

[[ stitchable ]] half4 dreamy(float2 pos, half4 color, float2 size, float t,
                              half4 top, half4 glowA, half4 glowB, half4 bottom,
                              float4 touch, float4 pop, float bubbleOpacity, float auroraStrength, float gooey) {
    float2 uv = pos / size;
    float aspect = size.x / size.y;
    float2 q = float2(uv.x * aspect, uv.y);

    // Base gradient, slowly warped so it breathes instead of sliding.
    float2 w = q + 0.06 * float2(sin(q.y * 3.1 + t * 0.21), cos(q.x * 2.7 - t * 0.17));
    float3 col = mix(float3(top.rgb), float3(bottom.rgb), smoothstep(-0.1, 1.1, w.y + 0.04 * sin(w.x * 2.3 + t * 0.05)));
    float2 a = float2(aspect * (0.25 + 0.25 * sin(t * 0.06)), 0.40 + 0.18 * cos(t * 0.08));
    float2 b = float2(aspect * (0.75 + 0.20 * cos(t * 0.05)), 0.75 + 0.15 * sin(t * 0.07));
    col = mix(col, float3(glowA.rgb), 0.45 * exp(-dot(w - a, w - a) * 4.0));
    col = mix(col, float3(glowB.rgb), 0.45 * exp(-dot(w - b, w - b) * 3.0));

    // Aurora: curtains with a crisp upper edge, long downward fall-off and vertical rays.
    float3 aurora = float3(0.0);
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float x = q.x * 1.2 + fi * 1.9;
        float line = 0.18 + 0.11 * fi
                   + 0.07 * sin(x * 1.7 + t * (0.08 + 0.03 * fi))
                   + 0.06 * (noise(float2(x * 1.3, t * 0.04 + fi * 5.0)) - 0.5);
        float dy = uv.y - line;
        float curtain = dy < 0.0 ? exp(-dy * dy * 1400.0) : exp(-dy * (7.0 + fi * 2.0));
        float rays = pow(fbm(float2(x * 7.0, uv.y * 0.8 - t * 0.05 + fi)), 1.6) * 1.8;
        float shimmer = 0.65 + 0.35 * sin(x * 2.3 - t * 0.25 + fi * 2.0);
        float3 tint = mix(float3(glowA.rgb), float3(glowB.rgb), saturate(dy * 3.0 + fi * 0.3));
        tint = mix(tint, float3(0.85, 1.0, 0.95), 0.45);
        aurora += tint * curtain * rays * shimmer * (0.40 - fi * 0.09);
    }
    col = 1.0 - (1.0 - col) * (1.0 - saturate(aurora * auroraStrength));

    // Bokeh: soft, filled, faintly lighter discs drifting upward, as in the original.
    // Bubbles sample a plane pushed away from the finger, so they part around it.
    float2 qb = q;
    if (touch.z > 0.0) {
        float2 dv = q - float2(touch.x * aspect, touch.y);
        float dd = length(dv);
        qb -= dv / max(dd, 1e-3) * 0.09 * exp(-dd * dd * 40.0);
    }
    float2 popQ = float2(pop.x * aspect, pop.y);
    float3 light = mix(float3(glowA.rgb), float3(1.0), 0.5);
    int range = gooey > 0.5 ? 1 : 0;
    // Layer 0 is nearest: larger, softer and faster.
    for (int i = 0; i < 4; i++) {
        float L = float(i);
        float scale = 2.2 + L * 2.4;
        float speed = 0.012 - L * 0.002;
        float2 g = float2(qb.x * scale, (qb.y + t * speed) * scale);
        g.x += 0.15 * sin(g.y * 0.7 + t * 0.15 + L * 2.0);
        float2 base = floor(g);
        float best = 0.0, field = 0.0, weighted = 0.0;
        for (int cy = -range; cy <= range; cy++) {
            for (int cx = -range; cx <= range; cx++) {
                float2 id = base + float2(cx, cy);
                float r = hash21(id + L * 13.1);
                if (r >= 0.5) continue;
                float2 o = (float2(hash21(id + 3.1), hash21(id + 7.7)) - 0.5) * 0.4;
                float rad = 0.10 + 0.22 * hash21(id + 5.3);
                float alpha = (0.05 + 0.10 * hash21(id + 9.0)) * (0.8 + 0.2 * sin(t * 0.3 + r * 30.0));
                // A bubble is identified by where its centre was at the moment of the tap.
                float age = t - pop.z;
                if (age >= 0.0 && age < 10.0) {
                    float2 c = float2((id.x + 0.5 + o.x) / scale, (id.y + 0.5 + o.y) / scale - pop.z * speed);
                    if (length(c - popQ) < rad / scale + 0.015) {
                        float burst = saturate(age / 0.25);
                        rad *= 1.0 + 0.5 * burst;
                        alpha *= (1.0 - burst) * (3.0 - 2.0 * burst);
                    }
                }
                float d = length(g - id - 0.5 - o) / rad;
                if (range == 0) {
                    float soft = 0.12 + 0.10 * (3.0 - L);
                    best = max(best, (1.0 - smoothstep(1.0 - soft, 1.0, d)) * alpha);
                } else {
                    float w = exp(-d * d * 1.6);
                    field += w;
                    weighted += w * alpha;
                }
            }
        }
        float a = range == 0 ? best : smoothstep(0.3, 0.5, field) * weighted / max(field, 1e-3);
        col = mix(col, light, a * bubbleOpacity);
    }

    float2 v = uv - 0.5;
    col *= 1.0 - 0.45 * dot(v, v);
    // Grain hides banding on long, low-contrast gradients.
    col += (hash21(pos + fract(t) * 91.0) - 0.5) * 0.018;
    return half4(half3(saturate(col)), 1.0h);
}
