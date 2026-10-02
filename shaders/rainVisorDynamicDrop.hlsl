/*
    RealVisor Dynamic Rain Drop — visor surface layer (2026-10-02)

    One render.mesh draws the visor surface mesh (pin.Tex.x < -2.5 marks it;
    the legacy per-drop quads and micro-layer quads were removed, see
    docs/RAINFX_WATER_FIELD.md §10). Layers, top to bottom:
      water field (heads + trail canvas)  -> pending layer gOver
      trail film / ridge (wiped paths)
      micro pattern disks (baked, pop-in)
      haze + smear class facet film       (never writes depth)
    A second pass with gDynamicDropDepthOnly = 1 writes visor depth where the
    solid element (gSolidA) is opaque enough (docs/RAINFX_IMPACT_SPLASH.md §8-9).
    Kept diagnostics: WF debug, smear debug 1-4, micro debug, haze debug,
    trail-mask debug.
*/

// All tx*/gDynamicDrop* inputs are injected by render.mesh({
// textures/values = ... }). Do not redeclare them in this file.

// Exact point read of the baked micro pattern (docs/RAINFX_MICRO_PATTERN.md
// "Point reads"). A custom `SamplerState x { Filter = POINT; }` block is
// effect syntax and is ignored by the compiler, so the former point sampler
// most likely filtered LINEARLY: the packed class / gate / radius codes of
// neighbouring texels were blended at every disk border.
// Load() is point-exact by definition.
float4 rainMicroPoint(float2 uv)
{
    if (gDynamicDropMicroPointLoad < 0.5)
        return txDynamicMicroPattern.SampleLevel(samLinearClamp, uv, 0.0);
    uint w, h;
    txDynamicMicroPattern.GetDimensions(w, h);
    int2 p = clamp(int2(saturate(uv) * float2(w, h)), int2(0, 0),
        int2(w, h) - 1);
    return txDynamicMicroPattern.Load(int3(p, 0));
}

// Match far shot pixels to the current WeatherFX fog tone. Transfer only
// bounded cloud luminance from the shot; never copy its mismatched sky hue.
float3 rainDynamicWeatherSkyTone(float3 scene, float2 uv)
{
    float depth = txDynamicShotDepth.SampleLevel(
        samLinearClamp, saturate(uv), 0.0).r;
    if (depth <= 0.99999)
        return scene;
    float3 broad = txDynamicSnapshot.SampleLevel(
        samLinearClamp, saturate(uv), 9.0).rgb;
    float3 weights = float3(0.2126, 0.7152, 0.0722);
    float contrast = clamp(
        1.0 + (dot(scene, weights)
            / max(dot(broad, weights), 0.02) - 1.0) * 0.25,
        0.95, 1.12);
    return gDynamicDropWeatherFogColor * contrast;
}

// Water field tap: the higher of head canvas and trail canvas wins, so a
// head moving over its own trail keeps its own radius code.
float4 rainWaterFieldTap(float2 uv)
{
    float4 head = txDynamicBirthMask.SampleLevel(samLinearClamp, uv, 0.0);
    if (gDynamicDropWFTrail > 0.5)
    {
        float4 trail = txDynamicWaterTrail.SampleLevel(samLinearClamp,
            uv, 0.0);
        if (trail.g > head.g)
            return trail;
    }
    return head;
}

// Haze / condensation film (docs/RAINFX_HAZE.md). Procedural in visor UV
// (no texture binding): R = mist density, B = reveal order, G/A = speckle
// refraction vector. Rain reveals it; wipes and water tracks clear lanes.
float rainHazeHash(float2 p)
{
    p = frac(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return frac(p.x * p.y);
}

float rainHazeNoise(float2 x)
{
    float2 i = floor(x);
    float2 f = frac(x);
    f = f * f * (3.0 - 2.0 * f);
    return lerp(lerp(rainHazeHash(i), rainHazeHash(i + float2(1.0, 0.0)), f.x),
        lerp(rainHazeHash(i + float2(0.0, 1.0)),
            rainHazeHash(i + float2(1.0, 1.0)), f.x), f.y);
}

float rainHazeFbm(float2 x)
{
    float sum = 0.0;
    float total = 0.0;
    float a = 0.5;
    [unroll] for (int o = 0; o < 4; ++o)
    {
        sum += a * rainHazeNoise(x);
        total += a;
        x = x * 2.03 + 17.1;
        a *= 0.5;
    }
    return sum / total;
}

float4 rainHazeField(float2 uv)
{
    float mist = saturate((rainHazeFbm(uv * gDynamicDropHazeMistCells)
        - 0.25) / 0.5);
    float2 cell = floor(uv * gDynamicDropHazeSpeckleCells);
    float order = saturate((rainHazeFbm(uv * gDynamicDropHazeOrderCells
        + 31.7) - 0.25) / 0.5 * 0.85 + rainHazeHash(cell + 11.3) * 0.15);
    return float4(mist, rainHazeHash(cell + 3.1), order,
        rainHazeHash(cell + 7.7));
}
// Smear mask v3 (docs/RAINFX_SMEAR_MASK.md §v3). Evaluated once per visor
// pixel in main() and kept in statics for the haze/micro helpers.
// Texture (shared slot, see realvisor.lua): R = reveal order (shown where
// R <= reveal), G = blend degree inside the revealed region.
#define txDynamicSmearMask txDynamicWeatherScreen
static float gSmearMask = 0.0;   // revealed region 0..1
static float gSmearG = 0.0;      // blend degree (G)
static float gSmearK = 0.0;      // region x G: the effect amount
static float gSmearR = 0.0;      // raw R (debug)
static float3 gSmearColor = float3(0.0, 0.0, 0.0); // turbid colour
// Weakened WF trail waiting to be composited over the layers beneath.
static float4 gOver = float4(0.0, 0.0, 0.0, 0.0);
static float gOverMix = 0.0;
// Opacity of the solid water / micro element of this pixel, haze and smear
// facet film EXCLUDED. The exact depth pass writes depth on this only, so a
// pure haze pixel never hides car glass behind it (2026-10-02 fix: haze
// erased the yellow windscreen and showed the asphalt).
static float gSolidA = 0.0;

float rainSmearRidged(float2 x)
{
    return 1.0 - abs(rainHazeNoise(x) * 2.0 - 1.0);
}

// Procedural stand-in for the texture: x = R (reveal order), y = G.
float2 rainSmearProcedural(float2 uv)
{
    float2 p = uv * gDynamicDropSmearMaskCells;
    float2 w = float2(rainHazeNoise(p * 0.5), rainHazeNoise(p * 0.5 + 5.2))
        - 0.5;
    float2 pw = p + w * (2.0 * gDynamicDropSmearMaskWarp);
    float n = rainHazeNoise(pw) * 0.55 + rainHazeNoise(pw * 2.03 + 3.1) * 0.30
        + rainHazeNoise(pw * 4.11 + 7.7) * 0.15;
    // n: median 0.46, std 0.15 -> R spread over 0..1, high n first.
    float rr = saturate((0.80 - n) / 0.50);
    float2 q = uv * gDynamicDropSmearFillCells;
    float2 qw = (float2(rainHazeNoise(uv * 23.0), rainHazeNoise(uv * 23.0
        + 9.4)) - 0.5) * 9.0;
    float g = saturate(rainSmearRidged(q + qw) * 0.7 + rainHazeNoise(uv
        * gDynamicDropSmearFillPatchCells * 0.5 + 8.1) * 0.3);
    return float2(rr, g);
}

// v8 (docs/RAINFX_SMEAR_MASK.md): inside the region every feature follows
// G' - low G' = invisible, high G' = as outside. `hide` = how fully.
float rainSmearVis(float hide)
{
    return lerp(1.0, gSmearG, saturate(gSmearMask * hide));
}

// Wipe-type paths (micro clearing, film, ridge, haze wipes): weak where G'
// is low, exactly like the micro drops (v8; v3-v7 weakened them evenly,
// which read as stronger wipes in the low-G areas where micro is hidden).
float rainSmearWipe(float clearance)
{
    return clearance * rainSmearVis(gDynamicDropSmearPathWeaken);
}

// Composite the pending weakened trail (gOver) over a lower layer.
// v5: the water keeps its own alpha (silhouette, rim, glint survive) and
// its colour is mixed with the layer beneath by gOverMix x coverage.
float4 rainOver(float4 under)
{
    float3 waterRgb = lerp(gOver.rgb, under.rgb,
        saturate(gOverMix) * under.a);
    float outA = gOver.a + (1.0 - gOver.a) * under.a;
    return gOver.a <= 0.0 ? under : float4((gOver.a * waterRgb
        + (1.0 - gOver.a) * under.a * under.rgb) / max(outA, 1e-4), outA);
}

// Returns premultiplied-ready (rgb, amount). amount = 0 where no haze.
float4 rainHazeEvalBase(float2 posH, float2 patternUV)
{
    float amount = 0.0;
    float4 hz = float4(0.0, 0.5, 1.0, 0.5);
    if (gDynamicDropHazeEnabled > 0.5)
    {
        hz = rainHazeField(patternUV);
        float soft = max(gDynamicDropHazeRevealSoft, 0.001);
        float reveal = smoothstep(hz.b - soft, hz.b + soft,
            gDynamicDropHazeRain);
        amount = reveal * lerp(1.0, hz.r, gDynamicDropHazeMottle)
            * gDynamicDropHazeStrength;
        if (gDynamicDropTrailMaskWipeEnabled > 0.5)
        {
            float wipe = txDynamicTrailMask.SampleLevel(samLinearClamp,
                patternUV, 0.0).g;
            amount *= 1.0 - smoothstep(0.05, 0.60,
                saturate(rainSmearWipe(wipe)
                    * gDynamicDropTrailMaskWipeStrength));
        }
        if (gDynamicDropWFTrail > 0.5)
        {
            float water = txDynamicWaterTrail.SampleLevel(samLinearClamp,
                patternUV, 0.0).g;
            amount *= 1.0 - gDynamicDropHazeTrailClear
                * (1.0 - gDynamicDropSmearTrailMix * gSmearMask)
                * rainSmearVis(gDynamicDropSmearTrailHide)
                * smoothstep(0.03, max(gDynamicDropWFThreshold, 0.05), water);
        }
    }
    if (amount < 0.003)
        return float4(0.0, 0.0, 0.0, 0.0);
    if (gDynamicDropHazeDebug > 0.5)
        return float4(0.15, 0.55, 1.0, saturate(amount * 1.5));
    float2 resolutionRatio = gDynamicDropInvRenderTargetSize
        / gDynamicDropInvScreenSize;
    float2 sceneUV = posH * gDynamicDropInvScreenSize
        * lerp(float2(1.0, 1.0), resolutionRatio, 0.98);
    // Condensation beads: tiny per-cell refraction, then scattering blur.
    float2 speck = (hz.ga * 2.0 - 1.0) * gDynamicDropHazeSpecklePixels
        * gDynamicDropInvRenderTargetSize;
    float2 uv = saturate(sceneUV + speck);
    float3 color = txDynamicSnapshot.SampleLevel(samLinearClamp, uv,
        gDynamicDropHazeMip).rgb;
    if (gDynamicDropHazeSkyCorrection > 0.5)
        color = rainDynamicWeatherSkyTone(color, uv);
    // Forward scattering lifts the film toward the ambient fog tone.
    color = lerp(color, gDynamicDropWeatherFogColor, gDynamicDropHazeVeil);
    return float4(color, saturate(amount));
}

// The smear itself is never drawn on bare glass (user design v3: only its
// region shows, through what it does to the water).
// v7: the smear class facets lie on bare glass inside the region as a faint
// film over the haze (part of the "under" layer, never depth-writing).
float4 rainHazeEval(float2 posH, float2 patternUV)
{
    float4 haze = rainHazeEvalBase(posH, patternUV);
    float fa = saturate(gDynamicDropSmearFacetAlpha * gSmearMask
        * lerp(0.5, 1.0, gSmearG));
    if (fa <= 0.001)
        return haze;
    float outA = fa + (1.0 - fa) * haze.a;
    return float4((fa * gSmearColor + (1.0 - fa) * haze.a * haze.rgb)
        / max(outA, 1e-4), outA);
}

// Gap pixels (no micro disk): haze alone, or nothing.
float4 rainHazeOrClip(float2 posH, float2 patternUV)
{
    float4 haze = rainOver(rainHazeEval(posH, patternUV));
    clip(haze.a - 0.003);
    return haze;
}

// Micro pattern v2 decode (docs/RAINFX_MICRO_PATTERN.md): B packs the
// winner's gate (high 4 bits) and radius (low 4 bits). Point-sampled only.
float rainMicroGate(float packedB)
{
    float code = floor(packedB * 255.0 + 0.5);
    return (floor(code / 16.0) + 0.5) / 16.0;
}

float rainMicroRadiusCells(float packedB)
{
    float code = floor(packedB * 255.0 + 0.5);
    float q = code - floor(code / 16.0) * 16.0;
    return lerp(gDynamicDropMicroRadiusMin, gDynamicDropMicroRadiusMax,
        (q + 0.5) / 16.0);
}

// Anti-chrome tone limiter (docs/RAINFX_TRAIL_FLOW.md). CSP drops show the
// refracted scene with reduced contrast against what lies behind the drop.
// bg = blurred, sky-corrected view at the drop's own pixel. The refracted
// colour is compressed toward bg; the final colour is held inside a
// luminance ratio window of bg, so no drop turns into a mirror.
float3 rainWaterToneBg(float2 sceneUV)
{
    float3 bg = txDynamicSnapshot.SampleLevel(samLinearClamp,
        saturate(sceneUV), gDynamicDropWaterToneBgMip).rgb;
    if (gDynamicDropBirthSkyCorrection > 0.5)
        bg = rainDynamicWeatherSkyTone(bg, sceneUV);
    return bg;
}

float3 rainWaterToneCompress(float3 color, float3 bg)
{
    return gDynamicDropWaterToneEnabled > 0.5
        ? bg + (color - bg) * gDynamicDropWaterToneContrast : color;
}

float3 rainWaterToneClamp(float3 color, float3 bg)
{
    float3 w = float3(0.2126, 0.7152, 0.0722);
    float l = max(dot(color, w), 1e-5);
    float lb = max(dot(bg, w), 1e-5);
    // Upper bound has a floor (x fog luminance): over a black background
    // the window used to collapse and remove every drop there.
    float lbUp = max(lb, dot(gDynamicDropWeatherFogColor, w)
        * gDynamicDropWaterToneFloor);
    float target = clamp(l, lb * gDynamicDropWaterToneRatioMin,
        lbUp * gDynamicDropWaterToneRatioMax);
    return gDynamicDropWaterToneEnabled > 0.5 ? color * (target / l) : color;
}

// Water-field lens rule (identical to the head branch): look past the
// centre along the dimensionless slope, blur with slope, lose energy at the
// steep rim, lower rim picks up broad sky light. Used by the micro disks too,
// so both drop families share one optics.
float3 rainWaterLensColor(float2 sceneUV, float2 slope, float energy,
    float refraction)
{
    float slopeLen = length(slope);
    float aspect = gDynamicDropInvScreenSize.x
        / max(gDynamicDropInvScreenSize.y, 1e-9);
    float2 sampleUV = saturate(sceneUV + slope * refraction
        * float2(aspect, 1.0));
    float lensMip = gDynamicDropWFSceneMip
        + gDynamicDropWFSlopeMip * saturate(slopeLen / 1.5);
    float3 color = txDynamicSnapshot.SampleLevel(samLinearClamp,
        sampleUV, lensMip).rgb;
    if (gDynamicDropBirthSkyCorrection > 0.5)
        color = rainDynamicWeatherSkyTone(color, sampleUV);
    // Micro disks: the tone limiter has its own switch (default off: the
    // user preferred micro drops without it). Same v1 rule as the heads.
    bool microTone = gDynamicDropWaterToneMicro > 0.5;
    float3 toneBg = microTone ? rainWaterToneBg(sceneUV) : color;
    if (microTone)
        color = rainWaterToneCompress(color, toneBg);
    color *= 1.0 - gDynamicDropWFEdgeLoss * smoothstep(
        gDynamicDropWFLossStart, gDynamicDropWFLossEnd, slopeLen);
    float2 screenUp = float2(gDynamicDropCameraSide.y,
        -gDynamicDropCameraUp.y);
    screenUp = dot(screenUp, screenUp) > 1e-6
        ? normalize(screenUp) : float2(0.0, -1.0);
    float facing = slopeLen > 1e-4
        ? saturate(dot(slope / slopeLen, screenUp)) : 0.0;
    float glint = facing * facing * facing * facing
        * smoothstep(0.5, 1.1, slopeLen)
        * gDynamicDropWFGlint * (1.0 + energy);
    color += gDynamicDropWeatherFogColor * glint;
    return microTone ? rainWaterToneClamp(color, toneBg) : color;
}

// ---------------------------------------------------------------------------
// Smear class facets v7 (docs/RAINFX_SMEAR_MASK.md v7). Inferred CSP model:
// G' is quantised into N classes; every class is one "facet" with its own
// refraction image (scene offset), tone and blur. Far away the classes read
// as noise, close up as patches of differently bent / toned scene with soft
// boundaries. Classes are erased one by one (fixed random order) as the
// state weakens (reveal level falls, or wiping clears the spot).
//   k = min(floor(G' N), N-1),  f = frac(G' N)
//   colour = lerp(C(k), C(k+1), smoothstep(1-soft, 1, f))
//   C(k)   = scene(uv + o_k, mip + m_k) * (1 + t_k), veiled to fog
//   presence_k = smoothstep(e - w, e + w, order_k),
//   e = max(1 - reveal / ERASE_SPAN, wipe * CLASS_WIPE),
//   order_k = frac((k + 0.5) * 0.618034 + seed)
// ---------------------------------------------------------------------------
float4 rainSmearClassHash(float k)
{
    return frac(sin(float4(k * 12.9898 + 1.7, k * 78.233 + 4.1,
        k * 37.719 + 2.3, k * 93.989 + 7.9)) * 43758.5453);
}

float rainSmearClassOrder(float k)
{
    return frac((k + 0.5) * 0.6180339887 + gDynamicDropSmearClassSeed * 0.37);
}

float3 rainSmearClassColor(float k, float2 sceneUV)
{
    float4 h = rainSmearClassHash(k + gDynamicDropSmearClassSeed * 7.0);
    float2 off = (h.xy * 2.0 - 1.0) * gDynamicDropSmearFacetPixels
        * gDynamicDropInvRenderTargetSize;
    float mip = max(gDynamicDropSmearMip
        + (h.z * 2.0 - 1.0) * gDynamicDropSmearClassMipRange, 0.0);
    float2 uv = saturate(sceneUV + off);
    float3 c = txDynamicSnapshot.SampleLevel(samLinearClamp, uv, mip).rgb;
    if (gDynamicDropBirthSkyCorrection > 0.5)
        c = rainDynamicWeatherSkyTone(c, uv);
    return c * (1.0 + (h.w * 2.0 - 1.0) * gDynamicDropSmearToneRange);
}

// Micro pop-in (docs/RAINFX_MICRO_PATTERN.md §pop-in). A picked share of the
// baked disks cycles: absent for OFF of its own period, then appears at once
// (a drop "lands"), lives, fades. Period and phase are per disk, so only a
// few disks change in any frame and no synchronised blink reveals the bake.
uint rainHashU(uint v)
{
    v = v * 747796405u + 2891336453u;
    uint w = ((v >> ((v >> 28u) + 4u)) ^ v) * 277803737u;
    return (w >> 22u) ^ w;
}

float rainMicroPop(float2 centerUV, out float flash)
{
    flash = 0.0;
    if (gDynamicDropMicroPopEnabled < 0.5)
        return 1.0;
    float2 cell = floor(saturate(centerUV)
        * max(gDynamicDropMicroPatternGrid, 1.0)
        * max(gDynamicDropMicroPopIdScale, 0.05));
    uint h0 = rainHashU(uint(cell.x) * 73856093u ^ uint(cell.y) * 19349663u);
    uint h1 = rainHashU(h0);
    uint h2 = rainHashU(h1);
    float pick = float(h0 & 65535u) / 65535.0;
    if (pick >= gDynamicDropMicroPopPick)
        return 1.0;
    float period = max(gDynamicDropMicroPopPeriod, 0.05)
        * (0.5 + float(h1 & 65535u) / 65535.0);
    float t = frac(gDynamicDropMicroPopTime / period
        + float(h2 & 65535u) / 65535.0);
    float off = saturate(gDynamicDropMicroPopOff);
    if (t < off)
        return 0.0;
    float life = (t - off) / max(1.0 - off, 1e-3);
    flash = gDynamicDropMicroPopFlash * (1.0 - saturate(life / 0.08));
    return 1.0 - smoothstep(1.0 - max(gDynamicDropMicroPopFade, 1e-3), 1.0,
        life);
}

// Trail refraction T3 (docs/RAINFX_TRAIL_REFRACTION.md): thickness ripple
// stretched along the mean drop flow and advected with it (phase from Lua),
// so the refracted image waves and travels with the water.
float rainTrailRipple(float2 uv)
{
    float2 d = gDynamicDropTrailFlowDir;
    float2 n = float2(-d.y, d.x);
    float a = dot(uv, d) * gDynamicDropTrailRippleAlong
        - gDynamicDropTrailRipplePhase;
    float c = dot(uv, n) * gDynamicDropTrailRippleAcross;
    return rainHazeNoise(float2(a, c)) * 0.67
        + rainHazeNoise(float2(a * 2.07 + 7.3, c * 1.93 + 3.1)) * 0.33;
}

// Gradient of the ripple per visor UV (central differences, step s).
float2 rainTrailRippleGrad(float2 uv, float s)
{
    return float2(rainTrailRipple(uv + float2(s, 0.0))
            - rainTrailRipple(uv - float2(s, 0.0)),
        rainTrailRipple(uv + float2(0.0, s))
            - rainTrailRipple(uv - float2(0.0, s))) / (2.0 * s);
}

float4 rainDropMain(PS_IN pin)
{
    // Visor surface layer only. The legacy per-drop quad heads and the
    // legacy micro-layer quads (and their screen/scene-source diagnostics)
    // were removed 2026-10-02 (docs/RAINFX_WATER_FIELD.md §10).
    bool surfaceMicroPattern = pin.Tex.x < -2.5;
    clip(surfaceMicroPattern ? 1.0 : -1.0);
    if (surfaceMicroPattern)
    {
        clip(gDynamicDropMicroPatternEnabled - 0.5);
        float2 patternUV = saturate(float2(
            pin.Tex.x + 4.0, pin.Tex.y + 1.0));
        if (gDynamicDropDepthOnly > 0.5 && gDynamicDropDepthExact < 0.5)
        {
            float depthWater = gDynamicDropWaterField > 0.5
                ? rainWaterFieldTap(patternUV).g : 0.0;
            float4 depthMicro = rainMicroPoint(patternUV);
            float depthWipe = gDynamicDropTrailMaskWipeEnabled > 0.5
                ? txDynamicTrailMask.SampleLevel(samLinearClamp,
                    patternUV, 0.0).g * gDynamicDropTrailMaskWipeStrength
                : 0.0;
            bool depthMicroOn = depthMicro.a > 0.75
                && gDynamicDropMicroRain > 0.001
                && gDynamicDropMicroRain >= rainMicroGate(depthMicro.b)
                && depthWipe < 0.08;
            clip(depthWater > gDynamicDropWFThreshold || depthMicroOn
                ? 1.0 : -1.0);
            return float4(0.0, 0.0, 0.0, 0.0);
        }
        // Hoisted before any per-pixel return (haze exits early).
        float2 hoistPatternDx = ddx(patternUV);
        float2 hoistPatternDy = ddy(patternUV);
        // Water-field silhouette width, hoisted before any per-pixel exit.
        float hoistWFFwidth = fwidth(gDynamicDropWaterField > 0.5
            ? rainWaterFieldTap(patternUV).g : 0.0);
        if (gDynamicDropSmear > 0.5)
        {
            // v8: R (region blobs) and G (class patches) tile separately;
            // the G pattern is denser than one copy over the whole visor.
            // Wrap is done in code (frac): a custom SamplerState block is an
            // effect-syntax state block that the compiler ignores, so the
            // bound sampler clamped and the tiles ran off the visor.
            float2 smearUVR = patternUV * max(gDynamicDropSmearRTiling, 0.01);
            float2 smearUVG = patternUV * max(gDynamicDropSmearGTiling, 0.01);
            float2 smearRG = gDynamicDropSmearTexture > 0.5
                ? float2(txDynamicSmearMask.SampleLevel(samLinearClamp,
                        frac(smearUVR), 0.0).r,
                    txDynamicSmearMask.SampleLevel(samLinearClamp,
                        frac(smearUVG), 0.0).g)
                : float2(rainSmearProcedural(smearUVR).x,
                    rainSmearProcedural(smearUVG).y);
            gSmearR = smearRG.x;
            // G contrast (docs/RAINFX_SMEAR_MASK.md v6): steeper G cuts the
            // pattern away more raggedly.
            gSmearG = pow(saturate((smearRG.y - gDynamicDropSmearGPivot)
                * gDynamicDropSmearGContrast + gDynamicDropSmearGPivot),
                max(gDynamicDropSmearGGamma, 0.05));
            // Region where R <= reveal. The band keeps reveal 0 empty and
            // reveal 1 complete: front = reveal * (1 + 2 soft) - soft.
            float smearSoft = max(gDynamicDropSmearEdgeSoft, 0.001);
            float smearFront = gDynamicDropSmearIntensity
                * (1.0 + 2.0 * smearSoft) - smearSoft;
            gSmearMask = gDynamicDropSmearIntensity > 0.0005
                ? 1.0 - smoothstep(smearFront - smearSoft,
                    smearFront + smearSoft, gSmearR) : 0.0;
            float2 smearRatio = gDynamicDropInvRenderTargetSize
                / gDynamicDropInvScreenSize;
            float2 smearSceneUV = saturate(pin.PosH.xy
                * gDynamicDropInvScreenSize
                * lerp(float2(1.0, 1.0), smearRatio, 0.98));
            // v7 class facets (see rainSmearClassColor).
            float smearN = clamp(floor(gDynamicDropSmearClasses + 0.5),
                1.0, 8.0);
            float smearCls = gSmearG * smearN;
            float smearK0 = min(floor(smearCls), smearN - 1.0);
            float smearK1 = min(smearK0 + 1.0, smearN - 1.0);
            float smearBlend = smoothstep(
                1.0 - max(gDynamicDropSmearClassSoft, 0.001), 1.0,
                smearCls - smearK0);
            float smearWipe = gDynamicDropTrailMaskWipeEnabled > 0.5
                ? txDynamicTrailMask.SampleLevel(samLinearClamp,
                    patternUV, 0.0).g * gDynamicDropSmearClassWipe : 0.0;
            float smearErase = max(1.0 - gDynamicDropSmearIntensity
                / max(gDynamicDropSmearEraseSpan, 0.01), smearWipe);
            float smearP0 = smoothstep(smearErase - 0.08, smearErase + 0.08,
                rainSmearClassOrder(smearK0));
            float smearP1 = smoothstep(smearErase - 0.08, smearErase + 0.08,
                rainSmearClassOrder(smearK1));
            float smearPresence = lerp(smearP0, smearP1, smearBlend);
            gSmearMask *= smearPresence;
            gSmearK = gSmearMask * gSmearG;
            float3 smearScene = float3(0.0, 0.0, 0.0);
            if (gSmearMask > 0.002)
                smearScene = lerp(rainSmearClassColor(smearK0, smearSceneUV),
                    rainSmearClassColor(smearK1, smearSceneUV), smearBlend);
            // Faint, soft lines on the internal class boundaries only.
            float smearLineD = abs(smearCls - clamp(floor(smearCls + 0.5),
                1.0, max(smearN - 1.0, 1.0)));
            smearScene *= 1.0 - gDynamicDropSmearLineStrength
                * (smearN > 1.5 ? 1.0 - smoothstep(0.0,
                    max(gDynamicDropSmearLineWidth, 0.001), smearLineD) : 0.0);
            gSmearColor = lerp(smearScene, gDynamicDropWeatherFogColor,
                gDynamicDropSmearVeil);
            if (gDynamicDropSmearDebug > 3.5)
                return float4(frac(smearK0 * 0.618034 + 0.2),
                    smearPresence, smearBlend, 0.9);
            if (gDynamicDropSmearDebug > 2.5)
                return float4(gSmearG.xxx, 0.9);
            if (gDynamicDropSmearDebug > 1.5)
                return float4(gSmearR.xxx, 0.9);
            if (gDynamicDropSmearDebug > 0.5)
                return float4(gSmearMask * 0.85, gSmearK, 0.15, 0.85);
        }
        if (gDynamicDropWaterField > 0.5)
        {
            // Water field (docs/RAINFX_WATER_FIELD.md). G = union height of
            // soft kernels, R/G = radius code (texels / 32), B/G = impact
            // energy. Heads and the decaying trail canvas share one rule.
            // Centre: head and trail separately, so each source gets its
            // own slope step (docs/RAINFX_TRAIL_FLOW.md §2). A one-trail-texel
            // step on a small head smeared its dome flat (single-colour dots).
            float4 wHead = txDynamicBirthMask.SampleLevel(samLinearClamp,
                patternUV, 0.0);
            float4 wTrail = gDynamicDropWFTrail > 0.5
                ? txDynamicWaterTrail.SampleLevel(samLinearClamp,
                    patternUV, 0.0) : float4(0.0, 0.0, 0.0, 0.0);
            bool trailWins = wTrail.g > wHead.g;
            float4 w0 = trailWins ? wTrail : wHead;
            float wfStep = trailWins ? gDynamicDropWFTrailStep
                : gDynamicDropWFHeadStep;
            float2 stepU = float2(wfStep, 0.0);
            float2 stepV = float2(0.0, wfStep);
            float hU1 = rainWaterFieldTap(patternUV + stepU).g;
            float hU0 = rainWaterFieldTap(patternUV - stepU).g;
            float hV1 = rainWaterFieldTap(patternUV + stepV).g;
            float hV0 = rainWaterFieldTap(patternUV - stepV).g;
            float h0 = w0.g;
            // Derivatives before any per-pixel branch (hoisted).
            float2 wfDx = hoistPatternDx;
            float2 wfDy = hoistPatternDy;
            // Projected radius first: it drives the size-dependent tone,
            // the large-drop blur and the large-drop soft edge.
            float radiusUV = w0.r / max(w0.g, 0.02) * 32.0
                * gDynamicDropWFInvMaskSize;
            float wfDet = wfDx.x * wfDy.y - wfDx.y * wfDy.x;
            float radiusPx = radiusUV / sqrt(max(abs(wfDet), 1e-14));
            float largeW = smoothstep(gDynamicDropLargeStartPx,
                max(gDynamicDropLargeFullPx, gDynamicDropLargeStartPx + 0.5),
                radiusPx);
            // Fast-flow sheet water (B/G) has no crisp silhouette: its edge
            // band widens so the film fades out instead of being outlined.
            // Large drops get a soft, size-proportional boundary (a constant
            // height band is a constant fraction of the radius).
            float sheetEarly = saturate(w0.b / max(w0.g, 0.02));
            float hWidth = max(hoistWFFwidth * 0.75, 0.004)
                + gDynamicDropWFSheetEdgeSoft * sheetEarly
                + gDynamicDropLargeEdgeSoft * largeW;
            float inside = smoothstep(gDynamicDropWFThreshold - hWidth,
                gDynamicDropWFThreshold + hWidth, h0);
            if (gDynamicDropWFDebug > 0.5 && gDynamicDropWFDebug < 1.5
                && h0 > 0.01)
                return float4(h0, inside, 0.0, 0.85);
            if (inside > 0.003)
            {
                float2 gradUV = float2(hU1 - hU0, hV1 - hV0)
                    / (2.0 * max(wfStep, 1e-6));
                // Dimensionless screen slope; points toward the drop centre
                // (height increases inward). Shape independent.
                float2 slope = float2(dot(gradUV, wfDx), dot(gradUV, wfDy))
                    * radiusPx;
                // Trail refraction v2 (docs/RAINFX_TRAIL_REFRACTION.md T1):
                // a trail is a cylindrical lens, not a head dome. Its canvas
                // is flat-topped, so the 1-texel gradient is ~0 inside and
                // the head radius code means nothing for it. Thickness above
                // the silhouette threshold is differentiated at two scales:
                // the narrow step keeps the steep contact edge, the wide
                // step (~ half a trail width) gives the whole interior a
                // cross-flow slope. Normalised by the wide step in pixels,
                // the slope is ~1 at the edge of a trail of that half-width.
                bool trailV2 = trailWins && gDynamicDropTrailRefractV2 > 0.5;
                float2 trailOffsetPx = float2(0.0, 0.0);
                if (trailV2)
                {
                    float thr = gDynamicDropWFThreshold;
                    float invRange = 1.0 / max(gDynamicDropTrailProfileRange,
                        0.02);
                    float s2 = max(gDynamicDropTrailGradStep2, wfStep);
                    float2 u2 = float2(s2, 0.0);
                    float2 v2 = float2(0.0, s2);
                    float tU1 = saturate((rainWaterFieldTap(patternUV + u2).g
                        - thr) * invRange);
                    float tU0 = saturate((rainWaterFieldTap(patternUV - u2).g
                        - thr) * invRange);
                    float tV1 = saturate((rainWaterFieldTap(patternUV + v2).g
                        - thr) * invRange);
                    float tV0 = saturate((rainWaterFieldTap(patternUV - v2).g
                        - thr) * invRange);
                    float2 gWide = float2(tU1 - tU0, tV1 - tV0) / (2.0 * s2);
                    float2 gNarrow = float2(saturate((hU1 - thr) * invRange)
                        - saturate((hU0 - thr) * invRange),
                        saturate((hV1 - thr) * invRange)
                        - saturate((hV0 - thr) * invRange))
                        / (2.0 * max(wfStep, 1e-6));
                    float2 gT = lerp(gNarrow, gWide,
                        saturate(gDynamicDropTrailGradMix));
                    // T3: flowing thickness ripple, only inside the trail.
                    if (gDynamicDropTrailRippleAmp > 0.0005)
                    {
                        float t0 = saturate((h0 - thr) * invRange);
                        gT += rainTrailRippleGrad(patternUV, s2)
                            * gDynamicDropTrailRippleAmp
                            * smoothstep(0.0, 0.35, t0);
                    }
                    // UV gradient -> per-pixel gradient (UV Jacobian), times
                    // the wide step in pixels -> dimensionless slope.
                    float s2Px = s2 / sqrt(max(abs(wfDet), 1e-14));
                    slope = float2(dot(gT, wfDx), dot(gT, wfDy)) * s2Px;
                    float sl = length(slope);
                    float slMax = max(gDynamicDropTrailSlopeMax, 0.1);
                    if (sl > slMax)
                        slope *= slMax / sl;
                    // T4: steep contact edges refract dramatically (the
                    // view leaves through the side of the lens). Edge loss
                    // and the sky glint below use the same slope.
                    float edgeRim = smoothstep(gDynamicDropTrailEdgeStart,
                        max(gDynamicDropTrailEdgeEnd,
                            gDynamicDropTrailEdgeStart + 0.01),
                        length(slope));
                    trailOffsetPx = slope * gDynamicDropTrailRefractPx
                        * (1.0 + gDynamicDropTrailEdgeBoost * edgeRim);
                }
                float slopeLen = length(slope);
                if (gDynamicDropWFDebug > 2.5)
                    return float4(largeW, 1.0 - largeW, 0.2, inside);
                if (gDynamicDropWFDebug > 1.5)
                    return float4(slope * 0.5 + 0.5, 0.0, inside);
                float2 resolutionRatio = gDynamicDropInvRenderTargetSize
                    / gDynamicDropInvScreenSize;
                float2 sceneUV = pin.PosH.xy * gDynamicDropInvScreenSize
                    * lerp(float2(1.0, 1.0), resolutionRatio, 0.98);
                // One rule for every drop: look toward (and past) the
                // centre. The rim at the top sees below, the bottom rim sees
                // above, so each image is inverted and neighbours agree.
                float aspect = gDynamicDropInvScreenSize.x
                    / max(gDynamicDropInvScreenSize.y, 1e-9);
                // Large drops: the inner image is "low-res" and imperfect,
                // not a sharp copy: an irregular warp in drop-sized cells.
                float2 warpCell = patternUV
                    / max(radiusUV * gDynamicDropLargeWarpCells, 1e-5);
                float2 warp = float2(rainHazeNoise(warpCell),
                    rainHazeNoise(warpCell + 17.31)) - 0.5;
                float2 sampleUV = saturate(sceneUV + slope
                    * gDynamicDropWFRefraction * float2(aspect, 1.0)
                    + warp * (2.0 * gDynamicDropLargeWarpPx * largeW)
                        * gDynamicDropInvRenderTargetSize);
                // T1: trails shift the image toward the thick side by a
                // pixel amount (sharp, no large-drop warp).
                if (trailV2)
                    sampleUV = saturate(sceneUV + trailOffsetPx
                        * gDynamicDropInvRenderTargetSize);
                // B/G: sheet factor (fast-flow film / splash) or impact
                // energy. Sheets read blurrier and milkier.
                float sheetFactor = saturate(w0.b / max(w0.g, 0.02));
                float wfMip = gDynamicDropWFSceneMip
                    + gDynamicDropWFSlopeMip * saturate(slopeLen / 1.5)
                    + gDynamicDropWFSheetBlur * sheetFactor
                    + gDynamicDropLargeBlurMip * largeW
                    + (trailWins ? gDynamicDropSmearTrailBlur * gSmearMask
                        : 0.0);
                // T2: water does not blur; only curvature defocuses. Trails
                // drop the head base mip, the sheet blur and the large-drop
                // blur (smear-region turbidity blur is kept).
                if (trailV2)
                    wfMip = gDynamicDropTrailMipBase
                        + gDynamicDropTrailMipSlope * saturate(slopeLen
                            / max(gDynamicDropTrailSlopeMax, 0.1))
                        + gDynamicDropTrailSheetBlur * sheetFactor
                        + gDynamicDropSmearTrailBlur * gSmearMask;
                float3 color = txDynamicSnapshot.SampleLevel(samLinearClamp,
                    sampleUV, wfMip).rgb;
                if (gDynamicDropBirthSkyCorrection > 0.5)
                    color = rainDynamicWeatherSkyTone(color, sampleUV);
                // Anti-chrome tone (trail flow v1 rule, restored): compress
                // toward the background here, clamp the luminance window at
                // the end (after rim loss and glint).
                float3 toneBg = rainWaterToneBg(sceneUV);
                color = rainWaterToneCompress(color, toneBg);
                // Steep rim: refraction/total internal reflection sends the
                // view out of the scene, so energy is lost there.
                // Sheets: no dark rim (a film has no steep contact line).
                color *= 1.0 - gDynamicDropWFEdgeLoss * (1.0 - sheetFactor)
                    * smoothstep(gDynamicDropWFLossStart,
                        gDynamicDropWFLossEnd, slopeLen);
                // Lower inner rim picks up the broad sky (world up).
                float2 screenUp = float2(gDynamicDropCameraSide.y,
                    -gDynamicDropCameraUp.y);
                screenUp = dot(screenUp, screenUp) > 1e-6
                    ? normalize(screenUp) : float2(0.0, -1.0);
                float facing = slopeLen > 1e-4
                    ? saturate(dot(slope / slopeLen, screenUp)) : 0.0;
                float energy = w0.b / max(w0.g, 0.02);
                float glint = facing * facing * facing * facing
                    * smoothstep(0.5, 1.1, slopeLen)
                    * gDynamicDropWFGlint * (1.0 + energy)
                    * (1.0 - 0.7 * sheetFactor);
                color += gDynamicDropWeatherFogColor * glint;
                color = lerp(color, gDynamicDropWeatherFogColor,
                    gDynamicDropWFSheetVeil * sheetFactor);
                color = rainWaterToneClamp(color, toneBg);
                // Smear: heads turn turbid by region x G; trails by a fixed
                // amount anywhere inside the region (v4, no G).
                color = lerp(color, gSmearColor, saturate(trailWins
                    ? gDynamicDropSmearTrailTurbid * gSmearMask
                    : gDynamicDropSmearDropTurbid * gSmearK));
                // Fast-flow sheets are mostly transparent: the scene shows
                // through a blurred, milky, slightly distorted layer.
                float wfAlpha = lerp(gDynamicDropWFOpacity,
                    gDynamicDropWFSheetAlpha, sheetFactor)
                    * rainSmearVis(trailWins ? gDynamicDropSmearTrailHide
                        : gDynamicDropSmearHeadHide);
                // v9 (user): inside the smear the WF trails are weak and
                // transparent; only the moving drops stay turbid, which reads
                // as foam carried by the drops.
                if (trailWins)
                    wfAlpha *= 1.0 - saturate(gDynamicDropSmearTrailClear)
                        * gSmearMask;
                // Inside the region the water keeps full presence (shape,
                // rim, glint: the flow stays visible) and its colour mixes
                // with the micro / haze beneath (no early return).
                float waterMix = saturate(gSmearMask * (trailWins
                    ? gDynamicDropSmearTrailMix : gDynamicDropSmearHeadMix));
                gSolidA = inside * wfAlpha;
                if (waterMix < 0.002)
                    return float4(color, inside * wfAlpha);
                gOver = float4(color, inside * wfAlpha);
                gOverMix = waterMix;
            }
        }
        // Diagnostic displays UV-space water and wiping coverage over
        // the complete visor, including gaps between static circles.
        if (gDynamicDropTrailMaskDebug > 0.5)
        {
            float2 coverage = txDynamicTrailMask.SampleLevel(
                samLinearClamp, patternUV, 0.0).rg;
            float strength = max(coverage.r, coverage.g);
            clip(strength - 0.01);
            return float4(coverage.r, coverage.g, 0.12,
                saturate(strength * 0.85));
        }
        // G holds a broad wiped film; R holds a narrow, short-lived
        // liquid core. Both share one canvas and one scene source.
        if (gDynamicDropTrailFilmEnabled > 0.5
            || gDynamicDropTrailRidgeEnabled > 0.5)
        {
            float2 coverage = txDynamicTrailMask.SampleLevel(
                samLinearClamp, patternUV, 0.0).rg;
            float filmCoverage = gDynamicDropTrailFilmEnabled > 0.5
                ? rainSmearWipe(coverage.g) : 0.0;
            float ridgeCoverage = gDynamicDropTrailRidgeEnabled > 0.5
                ? rainSmearWipe(coverage.r) : 0.0;
            float2 filmGradient = float2(
                ddx(filmCoverage), ddy(filmCoverage));
            float2 ridgeGradient = float2(
                ddx(ridgeCoverage), ddy(ridgeCoverage));
            if (max(filmCoverage, ridgeCoverage) > 0.04)
            {
                float4 filmPattern = txDynamicMicroPattern.SampleLevel(
                    samLinearClamp, patternUV, 0.0);
                float4 filmPoint = rainMicroPoint(patternUV);
                bool filmHasDisk = filmPoint.a > 0.25
                    && gDynamicDropMicroRain > 0.001;
                if (filmHasDisk && gDynamicDropMicroRain < 0.999)
                    filmHasDisk = gDynamicDropMicroRain
                        >= rainMicroGate(filmPoint.b);
                if (filmHasDisk
                    && gDynamicDropTrailMaskWipeEnabled > 0.5)
                {
                    float2 filmLocal = filmPattern.xy * 2.0 - 1.0;
                    float2 diskCenterUV = patternUV - filmLocal
                        * (rainMicroRadiusCells(filmPoint.b)
                            / max(gDynamicDropMicroPatternGrid, 1.0));
                    float diskClearance = txDynamicTrailMask.SampleLevel(
                        samLinearClamp, saturate(diskCenterUV), 0.0).g;
                    float visibleDisk = 1.0 - smoothstep(0.08, 0.70,
                        saturate(rainSmearWipe(diskClearance)
                            * gDynamicDropTrailMaskWipeStrength));
                    filmHasDisk = visibleDisk > 0.015;
                }
                if (filmHasDisk)
                {
                    float filmPopFlash;
                    filmHasDisk = rainMicroPop(patternUV
                        - (filmPoint.xy * 2.0 - 1.0)
                        * (rainMicroRadiusCells(filmPoint.b)
                            / max(gDynamicDropMicroPatternGrid, 1.0)),
                        filmPopFlash) > 0.015;
                }
                // A fresh liquid ridge sits above even a surviving disk.
                if (ridgeCoverage > 0.20)
                    filmHasDisk = false;
                if (!filmHasDisk)
                {
                    float2 resolutionRatio = gDynamicDropInvRenderTargetSize
                        / gDynamicDropInvScreenSize;
                    float2 shotScale = lerp(float2(1.0, 1.0),
                        resolutionRatio, 0.98);
                    float2 filmUV = pin.PosH.xy
                        * gDynamicDropInvScreenSize * shotScale;
                    float2 filmNormal = filmGradient
                        / max(length(filmGradient), 0.0001);
                    float filmEdge = saturate(
                        length(filmGradient) * 20.0);
                    float2 ridgeNormal = ridgeGradient
                        / max(length(ridgeGradient), 0.0001);
                    float ridgeEdge = saturate(
                        length(ridgeGradient) * 22.0);
                    float2 offsetPx = filmNormal * filmEdge
                            * gDynamicDropTrailFilmPixels
                        + ridgeNormal * ridgeEdge
                            * gDynamicDropTrailRidgePixels
                            * ridgeCoverage;
                    float filmMip = lerp(2.0, 1.0, ridgeCoverage);
                    // T6 (docs/RAINFX_TRAIL_REFRACTION.md): the wiped film is
                    // thin water too: stronger edge bend, flowing ripple,
                    // sharp sampling.
                    if (gDynamicDropTrailRefractV2 > 0.5)
                    {
                        offsetPx *= gDynamicDropTrailFilmBoost;
                        float fs2 = max(gDynamicDropTrailGradStep2, 1e-5);
                        float fDet = hoistPatternDx.x * hoistPatternDy.y
                            - hoistPatternDx.y * hoistPatternDy.x;
                        float fs2Px = fs2 / sqrt(max(abs(fDet), 1e-14));
                        float2 fg = rainTrailRippleGrad(patternUV, fs2);
                        float2 fSlope = float2(dot(fg, hoistPatternDx),
                            dot(fg, hoistPatternDy)) * fs2Px
                            * gDynamicDropTrailRippleAmp
                            * saturate(max(filmCoverage, ridgeCoverage));
                        offsetPx += fSlope * gDynamicDropTrailRefractPx;
                        filmMip = gDynamicDropTrailMipBase
                            + 0.5 * (1.0 - ridgeCoverage);
                    }
                    float2 offset = offsetPx * gDynamicDropInvRenderTargetSize;
                    float2 filmSampleUV = saturate(filmUV + offset);
                    float3 filmScene = txDynamicSnapshot.SampleLevel(
                        samLinearClamp, filmSampleUV, filmMip).rgb;
                    if (gDynamicDropTrailSkyCorrection > 0.5)
                        filmScene = rainDynamicWeatherSkyTone(
                            filmScene, filmSampleUV);
                    float3 ridgeAccent = float3(0.30, 0.35, 0.38)
                        * ridgeEdge * ridgeCoverage * 0.12;
                    float opacity = filmCoverage
                        * gDynamicDropTrailFilmOpacity
                        + ridgeCoverage
                            * gDynamicDropTrailRidgeOpacity;
                    // The wiped film lies over the (recovering) haze.
                    float filmAlpha = saturate(opacity);
                    gSolidA = filmAlpha;
                    float4 filmHaze = rainHazeEval(pin.PosH.xy, patternUV);
                    float filmOut = filmAlpha
                        + (1.0 - filmAlpha) * filmHaze.a;
                    return rainOver(float4((filmAlpha
                        * (filmScene + ridgeAccent)
                        + (1.0 - filmAlpha) * filmHaze.a * filmHaze.rgb)
                        / max(filmOut, 1e-4), filmOut));
                }
            }
        }
        // At zero rain, skip the entire static pattern (a pending weak
        // trail is still drawn).
        if (gDynamicDropMicroRain < 0.001)
            return rainHazeOrClip(pin.PosH.xy, patternUV);
        // Haze debug shows the film over the whole visor, disks hidden.
        if (gDynamicDropHazeDebug > 0.5)
            return rainHazeOrClip(pin.PosH.xy, patternUV);
        float4 pattern = txDynamicMicroPattern.SampleLevel(
            samLinearClamp, patternUV, 0.0);
        // Class, gate and radius are point-sampled: A = 1 interior,
        // 0.5 outline ring, 0 empty. Crisp texel steps are intended (the
        // low-resolution look reads as natural glitter from a distance).
        float4 patternPoint = rainMicroPoint(patternUV);
        if (patternPoint.a < 0.25)
            return rainHazeOrClip(pin.PosH.xy, patternUV);
        if (gDynamicDropMicroRain < 0.999
            && gDynamicDropMicroRain < rainMicroGate(patternPoint.b))
            return rainHazeOrClip(pin.PosH.xy, patternUV);
        bool microOutline = patternPoint.a < 0.75;
        // Invisible cut line (default): the winner's thin outer ring shows
        // the unrefracted scene / haze, so every fragment reads as its own
        // lens instead of merging into one chrome sheet.
        if (microOutline && gDynamicDropMicroOutlineDark <= 0.001)
            return rainHazeOrClip(pin.PosH.xy, patternUV);
        float microRadiusCells = rainMicroRadiusCells(patternPoint.b);
        float2 lensLocal = pattern.xy * 2.0 - 1.0;
        // Pop-in: the disk id uses the point-sampled local offset so every
        // pixel of one disk agrees on its centre cell.
        float microPopFlash = 0.0;
        float microPop = rainMicroPop(patternUV - (patternPoint.xy * 2.0 - 1.0)
            * (microRadiusCells / max(gDynamicDropMicroPatternGrid, 1.0)),
            microPopFlash);
        if (microPop < 0.01)
            return rainHazeOrClip(pin.PosH.xy, patternUV);
        // Smear v3: inside the region the micro drop shows only by G
        // (low G = hidden), so the region's noise appears as a trace.
        float microVisibility = lerp(1.0, gSmearG,
            gSmearMask * gDynamicDropSmearMicroHide) * microPop;
        if (gDynamicDropTrailMaskWipeEnabled > 0.5)
        {
            // All pixels of a winning disk share one clearance sample.
            // Keep its existing baked, pixelated silhouette intact.
            float2 diskCenterUV = patternUV - lensLocal
                * (microRadiusCells / max(gDynamicDropMicroPatternGrid, 1.0));
            float clearance = txDynamicTrailMask.SampleLevel(
                samLinearClamp, saturate(diskCenterUV), 0.0).g;
            microVisibility *= 1.0 - smoothstep(0.08, 0.70,
                saturate(rainSmearWipe(clearance)
                    * gDynamicDropTrailMaskWipeStrength));
            if (microVisibility < 0.01)
                return rainHazeOrClip(pin.PosH.xy, patternUV);
        }
        float lensRadius = saturate(length(lensLocal));
        // The baked alpha owns the silhouette, including its pixelated rim.
        // The winning disk owns the pixel; its outer ring also marks
        // boundaries where a newer disk hides an older one.
        float rim = smoothstep(0.70, 0.95, lensRadius);
        if (gDynamicDropMicroDebug > 0.5)
        {
            float3 diagnostic = lerp(float3(0.13, 0.22, 0.28),
                float3(0.83, 0.95, 1.0), microOutline ? 1.0 : rim * 0.4);
            return float4(diagnostic, 0.83);
        }
        float2 resolutionRatio = gDynamicDropInvRenderTargetSize
            / gDynamicDropInvScreenSize;
        float2 shotScale = lerp(float2(1.0, 1.0),
            resolutionRatio, 0.98);
        float2 sceneUV = pin.PosH.xy * gDynamicDropInvScreenSize
            * shotScale;
        float2 uvDx = hoistPatternDx;
        float2 uvDy = hoistPatternDy;
        float determinant = uvDx.x * uvDy.y - uvDx.y * uvDy.x;
        {
            // Micro disks use the head lens rule (docs/RAINFX_MICRO_PATTERN.md).
            // The legacy "scene optics" mode (image scale / rotation / visor
            // normal / concave profile / cap normals) was removed 2026-10-02.
            // the same dome h = 1 - (r / kernelScale)^2 in visor UV, its
            // gradient mapped to screen through the UV Jacobian, times the
            // projected radius. No rotation parameter: inversion comes from
            // looking past the centre, exactly as for the heads.
            float microRadiusUVs = microRadiusCells
                / max(gDynamicDropMicroPatternGrid, 1.0);
            float kernelScale = max(gDynamicDropWFKernelScale, 1.0);
            float2 lensGradUV = -2.0 * lensLocal
                / (kernelScale * kernelScale * max(microRadiusUVs, 1e-7));
            float microRadiusPx = microRadiusUVs
                / sqrt(max(abs(determinant), 1e-14));
            float2 lensSlope = float2(dot(lensGradUV, uvDx),
                dot(lensGradUV, uvDy)) * microRadiusPx
                * gDynamicDropMicroWaterLensSlope;
            float3 lensColor = rainWaterLensColor(sceneUV, lensSlope, 0.0,
                gDynamicDropWFRefraction * gDynamicDropMicroWaterLensRefraction);
            if (microOutline)
                lensColor *= 1.0 - gDynamicDropMicroOutlineDark;
            lensColor = lerp(lensColor, gSmearColor,
                saturate(gDynamicDropSmearMicroTurbid * gSmearK));
            float lensAlpha = saturate(gDynamicDropMicroOpacity
                * microVisibility);
            gSolidA = lensAlpha;
            lensColor += gDynamicDropWeatherFogColor * microPopFlash;
            float4 lensHaze = rainHazeEval(pin.PosH.xy, patternUV);
            float lensOut = lensAlpha + (1.0 - lensAlpha) * lensHaze.a;
            return rainOver(float4((lensAlpha * lensColor
                + (1.0 - lensAlpha) * lensHaze.a * lensHaze.rgb)
                / max(lensOut, 1e-4), lensOut));
        }
    }

    return float4(0.0, 0.0, 0.0, 0.0);
}

// Entry point. The depth occlusion pass (realvisor.lua, exact mode) shades
// every visor pixel exactly as the colour pass and writes depth only where
// the SOLID element (water, film, micro drop; not haze, not the smear facet
// film) is opaque enough, so wiped / recovering micro drops and trail films
// occlude later car glass, while haze-only pixels let it draw.
float4 main(PS_IN pin)
{
    float4 c = rainDropMain(pin);
    if (gDynamicDropDepthOnly > 0.5 && gDynamicDropDepthExact > 0.5)
    {
        clip(max(gSolidA, gOver.a) - gDynamicDropDepthAlphaMin);
        return float4(0.0, 0.0, 0.0, 0.0);
    }
    return c;
}
