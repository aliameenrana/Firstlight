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

constant float kScale[4] = { 2.2, 4.6, 7.0, 9.4 };
constant float kSpeed[4] = { 0.012, 0.010, 0.008, 0.006 };

static float2 bubbleSpace(float2 q, float t, int i) {
    float2 g = float2(q.x * kScale[i], (q.y + t * kSpeed[i]) * kScale[i]);
    g.x += 0.15 * sin(g.y * 0.7 + t * 0.15 + float(i) * 2.0);
    return g;
}

// Returns the bubble's normalised distance from its centre (>= 1 means outside) and fills its alpha.
static float bubble(float2 id, float2 g, int i, thread float &alpha, float t) {
    float r = hash21(id + float(i) * 13.1);
    if (r >= 0.5) return 9.0;
    float2 o = (float2(hash21(id + 3.1), hash21(id + 7.7)) - 0.5) * 0.4;
    float rad = 0.10 + 0.22 * hash21(id + 5.3);
    alpha = (0.05 + 0.10 * hash21(id + 9.0)) * (0.8 + 0.2 * sin(t * 0.3 + r * 30.0));
    return length(g - id - 0.5 - o) / rad;
}

[[ stitchable ]] half4 dreamy(float2 pos, half4 color, float2 size, float t,
                              half4 top, half4 glowA, half4 glowB, half4 bottom, float4 pop) {
    float2 uv = pos / size;
    float aspect = size.x / size.y;
    float2 q = float2(uv.x * aspect, uv.y);

    float3 col = mix(float3(top.rgb), float3(bottom.rgb), smoothstep(-0.1, 1.1, uv.y + 0.04 * sin(q.x * 2.3 + t * 0.05)));
    float2 a = float2(aspect * (0.25 + 0.25 * sin(t * 0.06)), 0.40 + 0.18 * cos(t * 0.08));
    float2 b = float2(aspect * (0.75 + 0.20 * cos(t * 0.05)), 0.75 + 0.15 * sin(t * 0.07));
    col = mix(col, float3(glowA.rgb), 0.45 * exp(-dot(q - a, q - a) * 4.0));
    col = mix(col, float3(glowB.rgb), 0.45 * exp(-dot(q - b, q - b) * 3.0));

    // Northern lights: curtains with a crisp upper edge, a long downward fall-off and noise-driven rays.
    if (uv.y < 0.95) {
        float3 aurora = float3(0.0);
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            float x = q.x * 1.2 + fi * 1.9;
            float line = 0.18 + 0.11 * fi + 0.07 * sin(x * 1.7 + t * (0.08 + 0.03 * fi))
                       + 0.06 * (noise(float2(x * 1.3, t * 0.04 + fi * 5.0)) - 0.5);
            float dy = uv.y - line;
            // Each strip has a 5% chance per ~25 s window of a ray that hangs further down,
            // easing in and out over the window and across the strip so it never pops.
            float strip = floor(x * 9.0);
            float phase = t * 0.04 + hash21(float2(strip, fi));
            float across = sin(3.14159 * fract(x * 9.0));
            float spike = hash21(float2(strip, floor(phase) + fi * 7.0)) > 0.95 ? sin(3.14159 * fract(phase)) * across * across : 0.0;
            float fall = (7.0 + fi * 2.0) * (1.0 - 0.45 * spike);
            float curtain = dy < 0.0 ? exp(-dy * dy * 1400.0) : exp(-dy * fall);
            float rays = pow(fbm(float2(x * 7.0, uv.y * 0.8 - t * 0.05 + fi)), 1.6) * 1.8;
            float shimmer = 0.65 + 0.35 * sin(x * 2.3 - t * 0.25 + fi * 2.0);
            float3 tint = mix(mix(float3(glowA.rgb), float3(glowB.rgb), saturate(dy * 3.0 + fi * 0.3)), float3(0.85, 1.0, 0.95), 0.45);
            aurora += tint * curtain * rays * shimmer * (0.8 - fi * 0.18);
        }
        col = 1.0 - (1.0 - col) * (1.0 - saturate(aurora * smoothstep(0.95, 0.7, uv.y)));
    }

    // Lava lamp: blobs on slow vertical paths, summed as a metaball field so they merge and pinch apart.
    if (pop.w > 0.5) {
        float field = 0.0;
        float3 tint = float3(0.0);
        float tw = 0.0;
        // Wax is drawn from the theme's own glow colours, lifted slightly, so it sits inside the gradient instead of on it.
        float3 waxes[3] = { float3(glowA.rgb), float3(glowB.rgb), mix(float3(glowA.rgb), float3(top.rgb), 0.5) };
        for (int k = 0; k < 12; k++) {
            float fk = float(k);
            float h = hash21(float2(fk, 3.7));
            float2 c = float2(aspect * (0.15 + 0.7 * hash21(float2(fk, 1.3)) + 0.06 * sin(t * 0.05 + fk * 2.1)),
                              0.5 + 0.42 * sin(t * (0.018 + 0.012 * h) + fk * 1.7));
            float r = 0.022 + 0.018 * hash21(float2(fk, 8.1));
            float2 d = q - c;
            // Stretched vertically while moving, like wax in a lamp.
            d.y *= 0.85;
            float w = r * r / (dot(d, d) + 1e-4);
            field += w;
            tint += waxes[k % 3] * w * w * w;
            tw += w * w * w;
        }
        // Cubing each blob's weight keeps its own colour and confines blending to the neck where blobs merge.
        float3 wax = mix(tint / max(tw, 1e-6), float3(1.0), 0.12);
        float body = smoothstep(0.7, 1.15, field);
        float glow = smoothstep(0.4, 0.9, field) * (1.0 - body);
        // Brighter towards the core reads as lit, rounded wax instead of a flat cut-out.
        float core = saturate((field - 1.0) * 0.35);
        wax = mix(wax, float3(1.0), core * 0.25);
        col = mix(col, wax, body * 0.16 + glow * 0.04);
        float2 v = uv - 0.5;
        col *= 1.0 - 0.45 * dot(v, v);
        col += (hash21(pos + fract(t) * 91.0) - 0.5) * 0.018;
        return half4(half3(saturate(col)), 1.0h);
    }

    // Which bubble, if any, was under the tap at the moment it happened.
    float age = t - pop.z;
    float2 popQ = float2(pop.x * aspect, pop.y);
    float2 popped[4] = { float2(-1e4), float2(-1e4), float2(-1e4), float2(-1e4) };
    bool hit = false;
    if (age >= 0.0 && age < 10.0) {
        for (int i = 0; i < 4; i++) {
            float2 g = bubbleSpace(popQ, pop.z, i);
            float al;
            if (bubble(floor(g), g, i, al, pop.z) < 1.0) { popped[i] = floor(g); hit = true; }
        }
    }

    // Bokeh: soft, filled, faintly lighter discs drifting upward. Layer 0 is nearest.
    float3 light = mix(float3(glowA.rgb), float3(1.0), 0.5);
    for (int i = 0; i < 4; i++) {
        float2 g = bubbleSpace(q, t, i);
        float2 id = floor(g);
        if (all(id == popped[i])) continue;
        float al = 0.0;
        float d = bubble(id, g, i, al, t);
        float soft = 0.12 + 0.10 * (3.0 - float(i));
        col = mix(col, light, (1.0 - smoothstep(1.0 - soft, 1.0, d)) * al * 0.8);
    }

    // Pop: droplets burst outward, slow down, fall slightly and fade.
    if (hit && age < 0.7) {
        float fade = 1.0 - age / 0.7;
        float spread = 1.0 - exp(-age * 7.0);
        for (int k = 0; k < 14; k++) {
            float fk = float(k);
            float ang = fk * 0.4488 + hash21(float2(fk, pop.z)) * 0.4;
            float reach = 0.05 + 0.07 * hash21(float2(pop.z, fk));
            float2 p = popQ + float2(cos(ang), sin(ang)) * reach * spread + float2(0.0, 0.04 * age * age);
            float r = 0.006 * fade + 0.001;
            float opacity = 0.02 + 0.02 * hash21(float2(fk, 5.0));
            col = mix(col, light, opacity * fade * (1.0 - smoothstep(r * 0.4, r, length(q - p))));
        }
    }

    float2 v = uv - 0.5;
    col *= 1.0 - 0.45 * dot(v, v);
    // Grain hides banding on long, low-contrast gradients.
    col += (hash21(pos + fract(t) * 91.0) - 0.5) * 0.018;
    return half4(half3(saturate(col)), 1.0h);
}
