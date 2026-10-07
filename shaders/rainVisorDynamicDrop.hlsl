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
    float4 result = float4(0.0, 0.0, 0.0, 0.0);
    if (gDynamicDropMicroPointLoad < 0.5)
        result = txDynamicMicroPattern.SampleLevel(samLinearClamp, uv, 0.0);
    else
    {
        uint w = 1u, h = 1u;
        txDynamicMicroPattern.GetDimensions(w, h);
        int2 dimensions = max(int2(w, h), int2(1, 1));
        int2 p = clamp(int2(saturate(uv) * dimensions), int2(0, 0), dimensions - 1);
        result = txDynamicMicroPattern.Load(int3(p, 0));
    }
    return result;
}

// (Declared before its first use, s39 fix.)
// Fog / ambient tone used by veil, glint and sky tone. In-scene (HDR) it is
// the WeatherFX fog colour; in the post overlay (LDR, docs/
// RAINFX_POST_OVERLAY.md P1) it is estimated from the final frame itself.
static float2 gFlowSceneOffset = float2(0.0, 0.0);
static float gFlowCoverage = 0.0;
static float gImpactCover = 0.0;
static float gSmearVisibilityG = 0.0;
static float3 gFogTone = float3(0.0, 0.0, 0.0);

// Every refraction-source read goes through here. gDynamicDropMipBias =
// log2(overlay size / main render size) keeps blur widths in screen terms
// when the post overlay renders at a higher resolution (s41); 0 in-scene.
float4 rainSnap(SamplerState s, float2 uv, float mip)
{
    return txDynamicSnapshot.SampleLevel(s, saturate(uv + gFlowSceneOffset), mip + gDynamicDropMipBias);
}

// Match far shot pixels to the current WeatherFX fog tone. Transfer only
// bounded cloud luminance from the shot; never copy its mismatched sky hue.
float3 rainDynamicWeatherSkyTone(float3 scene, float2 uv)
{
    float depth = txDynamicShotDepth.SampleLevel(
        samLinearClamp, saturate(uv), 0.0).r;
    if (depth <= 0.99999)
        return scene;
    float3 broad = rainSnap(
        samLinearClamp, saturate(uv), 9.0).rgb;
    float3 weights = float3(0.2126, 0.7152, 0.0722);
    float contrast = clamp(
        1.0 + (dot(scene, weights)
            / max(dot(broad, weights), 0.02) - 1.0) * 0.25,
        0.95, 1.12);
    return gFogTone * contrast;
}

// Water field tap: the higher of head canvas and trail canvas wins, so a
// head moving over its own trail keeps its own radius code.
// Composite RGB contains the film underlay; A preserves the pure trail.
// Remove the underlay before WF winner selection and lens derivatives.
float4 rainPureTrail(float4 t)
{
    if (gDynamicDropImpactFilm > 0.5)
    {
        float film = max(t.g - t.a, 0.0);
        t.rgb = max(t.rgb - float3(film * 0.75, film, film), 0.0);
        t.g = t.a;
    }
    return t;
}

float4 rainWaterFieldTap(float2 uv)
{
    float4 result = float4(0.0, 0.0, 0.0, 0.0);
    result = txDynamicBirthMask.SampleLevel(samLinearClamp, uv, 0.0);
    if (gDynamicDropWFTrail > 0.5)
    {
        float4 trail = rainPureTrail(txDynamicWaterTrail.SampleLevel(samLinearClamp,
            uv, 0.0));
        if (trail.g > result.g)
            result = trail;
    }
    return result;
}

// Film and trail have independent thickness profiles. Differentiating a
// saturated combined height would erase a flowing trail on a broad film.
float rainWaterProfileTap(float2 uv, float threshold, float invRange)
{
    return saturate((rainWaterFieldTap(uv).g - threshold) * invRange);
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
    return lerp(1.0, gSmearVisibilityG, saturate(gSmearMask * hide));
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
            float4 trailTap = txDynamicWaterTrail.SampleLevel(samLinearClamp,
                patternUV, 0.0);
            float water = gDynamicDropImpactFilm > 0.5 ? trailTap.a : trailTap.g;
            amount *= 1.0 - gDynamicDropHazeTrailClear
                * (1.0 - gSmearMask)
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
    float3 color = rainSnap(samLinearClamp, uv,
        gDynamicDropHazeMip).rgb;
    if (gDynamicDropHazeSkyCorrection > 0.5)
        color = rainDynamicWeatherSkyTone(color, uv);
    // Forward scattering lifts the film toward the ambient fog tone.
    color = lerp(color, gFogTone, gDynamicDropHazeVeil);
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
    float facetOut = fa + (1.0 - fa) * haze.a;
    float4 material = float4((fa * gSmearColor + (1.0 - fa) * haze.a * haze.rgb)
        / max(facetOut, 1e-4), facetOut);
    float2 ratio = gDynamicDropInvRenderTargetSize / gDynamicDropInvScreenSize;
    float2 sceneUV = posH * gDynamicDropInvScreenSize
        * lerp(float2(1.0, 1.0), ratio, 0.98);
    float cover = gImpactCover * (1.0 - gSmearMask);
    float coveredAlpha = cover + (1.0 - cover) * material.a;
    float3 filmScene = rainSnap(samLinearClamp, sceneUV, 0.0).rgb;
    float4 covered = float4((cover * filmScene + (1.0 - cover) * material.a * material.rgb)
        / max(coveredAlpha, 1e-4), coveredAlpha);
    float fill = gFlowCoverage * (1.0 - covered.a);
    float outA = covered.a + fill;
    return float4((covered.rgb * covered.a + filmScene * fill) / max(outA, 1e-4), outA);
}

// Gap pixels (no micro disk): haze alone, or nothing.
float4 rainHazeOrClip(float2 posH, float2 patternUV)
{
    float4 haze = rainOver(rainHazeEval(posH, patternUV));
    clip(max(haze.a, gFlowCoverage) - 0.003);
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
    float3 bg = rainSnap(samLinearClamp,
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
    float lbUp = max(lb, dot(gFogTone, w)
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
    float3 color = rainSnap(samLinearClamp,
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
    color += gFogTone * glint;
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
    float3 c = rainSnap(samLinearClamp, uv, mip).rgb;
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

// Broad film ripples use physical flow direction/phase, with two scales.
// Unlike trail silhouettes, their interior remains optically non-flat.
float rainImpactHeight(float2 uv)
{
    float4 t = txDynamicWaterTrail.SampleLevel(samLinearClamp, saturate(uv), 0.0);
    return max(t.g - t.a, 0.0);
}

float rainImpactRipple(float2 uv)
{
    float2 d = gDynamicDropTrailFlowDir;
    d = dot(d, d) > 1e-6 ? normalize(d) : float2(0.0, 1.0);
    float2 n = float2(-d.y, d.x);
    float along = dot(uv, d) * 14.0 - gDynamicDropTrailRipplePhase * 0.3;
    float across = dot(uv, n) * 26.0;
    float t = gDynamicDropMicroPopTime * 0.28;
    return rainHazeNoise(float2(along, across)) * 0.65
        + rainHazeNoise(float2(along * 2.13 + across * 0.23 + t,
            across * 1.71 - t)) * 0.35;
}

float3 rainSmearColorAt(float2 smearSceneUV)
{
    float smearN = clamp(floor(gDynamicDropSmearClasses + 0.5), 1.0, 8.0);
    float smearCls = gSmearG * smearN;
    float smearK0 = min(floor(smearCls), smearN - 1.0);
    float smearK1 = min(smearK0 + 1.0, smearN - 1.0);
    float smearBlend = smoothstep(1.0 - max(gDynamicDropSmearClassSoft, 0.001), 1.0, smearCls - smearK0);
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
            return lerp(smearScene, gFogTone,
                gDynamicDropSmearVeil);
}

float4 rainDropMain(PS_IN pin)
{
    // Initialize writable helper state inside this function as well as its
    // normal shading path, including the early depth-pass return.
    gSmearMask = 0.0;
    gSmearG = 0.0;
    gSmearK = 0.0;
    gSmearR = 0.0;
    gSmearColor = float3(0.0, 0.0, 0.0);
    gOver = float4(0.0, 0.0, 0.0, 0.0);
    gOverMix = 0.0;
    gSolidA = 0.0;
    // Visor surface layer only. The legacy per-drop quad heads and the
    // legacy micro-layer quads (and their screen/scene-source diagnostics)
    // were removed 2026-10-02 (docs/RAINFX_WATER_FIELD.md §10).
    bool surfaceMicroPattern = pin.Tex.x < -2.5;
    clip(surfaceMicroPattern ? 1.0 : -1.0);
    {
        clip(gDynamicDropMicroPatternEnabled - 0.5);
        float2 patternUV = saturate(float2(
            pin.Tex.x + 4.0, pin.Tex.y + 1.0));
        // Compute derivatives before depth/debug exits so FXC never needs
        // values from a neighbouring invocation that already returned.
        float2 hoistPatternDx = ddx(patternUV);
        float2 hoistPatternDy = ddy(patternUV);
        float hoistWFFwidth = fwidth(gDynamicDropWaterField > 0.5
            ? rainWaterFieldTap(patternUV).g : 0.0);
        float4 smearDebugColor = float4(0.0, 0.0, 0.0, 0.0);
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
            float2 visibilityRG = smearRG;
            if (gDynamicDropSmearTexture > 0.5)
            {
                float2 dR = float2(0.003 * max(gDynamicDropSmearRTiling, 0.01), 0.0);
                float2 dG = float2(0.003 * max(gDynamicDropSmearGTiling, 0.01), 0.0);
                visibilityRG = smearRG * 0.2;
                visibilityRG.x += 0.2 * (txDynamicSmearMask.SampleLevel(samLinearClamp, frac(smearUVR + dR), 0).r
                    + txDynamicSmearMask.SampleLevel(samLinearClamp, frac(smearUVR - dR), 0).r
                    + txDynamicSmearMask.SampleLevel(samLinearClamp, frac(smearUVR + dR.yx), 0).r
                    + txDynamicSmearMask.SampleLevel(samLinearClamp, frac(smearUVR - dR.yx), 0).r);
                visibilityRG.y += 0.2 * (txDynamicSmearMask.SampleLevel(samLinearClamp, frac(smearUVG + dG), 0).g
                    + txDynamicSmearMask.SampleLevel(samLinearClamp, frac(smearUVG - dG), 0).g
                    + txDynamicSmearMask.SampleLevel(samLinearClamp, frac(smearUVG + dG.yx), 0).g
                    + txDynamicSmearMask.SampleLevel(samLinearClamp, frac(smearUVG - dG.yx), 0).g);
            }
            gSmearVisibilityG = pow(saturate((visibilityRG.y - gDynamicDropSmearGPivot)
                * gDynamicDropSmearGContrast + gDynamicDropSmearGPivot), max(gDynamicDropSmearGGamma, 0.05));
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
                    smearFront + smearSoft, visibilityRG.x) : 0.0;
            // Alpha is a non-tiled whole-visor eligibility mask. The current
            // R/G template is opaque, so it permits the complete visor.
            float smearEligible = gDynamicDropSmearTexture > 0.5
                ? txDynamicSmearMask.SampleLevel(samLinearClamp, patternUV, 0.0).a : 1.0;
            if (gDynamicDropSmearNoseEnabled > 0.5)
            {
                float2 q = patternUV - gDynamicDropSmearNose.xy;
                float height = max(gDynamicDropSmearNose.w, 0.001);
                float spread = max(gDynamicDropSmearNose.z, 0.001) / height;
                float sideDistance = (q.y * spread - abs(q.x))
                    / sqrt(1.0 + spread * spread);
                float distanceInside = min(min(q.y, height - q.y), sideDistance);
                float soft = max(gDynamicDropSmearNoseSoft, 0.001);
                smearEligible *= 1.0 - smoothstep(-soft, soft, distanceInside);
            }
            gSmearMask *= saturate(smearEligible);
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
            float visCls = gSmearVisibilityG * smearN;
            float visK0 = min(floor(visCls), smearN - 1.0);
            float visK1 = min(visK0 + 1.0, smearN - 1.0);
            float visBlend = smoothstep(1.0 - max(gDynamicDropSmearClassSoft, 0.15), 1.0, visCls - visK0);
            gSmearMask *= lerp(smoothstep(smearErase - 0.15, smearErase + 0.15, rainSmearClassOrder(visK0)),
                smoothstep(smearErase - 0.15, smearErase + 0.15, rainSmearClassOrder(visK1)), visBlend);
            gSmearK = gSmearMask * gSmearG;
            gSmearColor = rainSmearColorAt(smearSceneUV);
            if (gDynamicDropSmearDebug > 3.5)
                smearDebugColor = float4(frac(smearK0 * 0.618034 + 0.2),
                    smearPresence, smearBlend, 0.9);
            else if (gDynamicDropSmearDebug > 2.5)
                smearDebugColor = float4(gSmearG.xxx, 0.9);
            else if (gDynamicDropSmearDebug > 1.5)
                smearDebugColor = float4(gSmearR.xxx, 0.9);
            else if (gDynamicDropSmearDebug > 0.5)
                smearDebugColor = float4(gSmearMask * 0.85, gSmearK, 0.15, 0.85);
        }
        // Film/ridge derivatives also precede every colour/debug return.
        // FXC otherwise sees undefined neighbour values on early-exit paths.
        float2 coverageForGradient = txDynamicTrailMask.SampleLevel(
            samLinearClamp, patternUV, 0.0).rg;
        float filmG = 0.95 * pow(saturate(coverageForGradient.g / 0.95),
            max(gDynamicDropTrailFilmAgeExp, 0.05));
        float filmCoverage = gDynamicDropTrailFilmEnabled > 0.5
            ? rainSmearWipe(filmG) : 0.0;
        float ridgeCoverage = gDynamicDropTrailRidgeEnabled > 0.5
            ? rainSmearWipe(coverageForGradient.r) : 0.0;
        float2 filmGradient = float2(ddx(filmCoverage), ddy(filmCoverage));
        float2 ridgeGradient = float2(ddx(ridgeCoverage), ddy(ridgeCoverage));
        if (gDynamicDropSmear > 0.5 && gDynamicDropSmearDebug > 0.5)
            return smearDebugColor;
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
            float impactHeight = gDynamicDropImpactFilm > 0.5
                ? max(wTrail.g - wTrail.a, 0.0) : 0.0;
            // Coverage is a thin surface boundary, not the film intensity.
            // Growing thickness changes the lens, rather than crossfading two views.
            gImpactCover = smoothstep(0.0005, 0.004, impactHeight)
                * saturate(gDynamicDropImpactOpacity);
            float2 impactOffset = float2(0.0, 0.0);
            if (gImpactCover > 0.0)
            {
                float st = max(gDynamicDropWFTrailStep, 0.002);
                float2 u = float2(st, 0.0), v = float2(0.0, st);
                float2 thicknessGrad = float2(rainImpactHeight(patternUV + u) - rainImpactHeight(patternUV - u),
                    rainImpactHeight(patternUV + v) - rainImpactHeight(patternUV - v)) / (2.0 * st);
                float2 waveGrad = float2(rainImpactRipple(patternUV + u) - rainImpactRipple(patternUV - u),
                    rainImpactRipple(patternUV + v) - rainImpactRipple(patternUV - v)) / (2.0 * st);
                float intensity = impactHeight / (impactHeight + 0.08);
                float2 lensGrad = thicknessGrad * 0.12 + waveGrad * (0.08 + 0.24 * intensity);
                float stepPixels = st / sqrt(max(abs(hoistPatternDx.x * hoistPatternDy.y
                    - hoistPatternDx.y * hoistPatternDy.x), 1e-14));
                float2 lensSlope = float2(dot(lensGrad, hoistPatternDx), dot(lensGrad, hoistPatternDy)) * stepPixels;
                lensSlope *= 0.04 / st;
                lensSlope /= max(1.0, length(lensSlope) / 1.5);
                impactOffset = lensSlope * gDynamicDropImpactWavePx
                    * gDynamicDropInvRenderTargetSize * intensity;
                gFlowCoverage = gImpactCover;
                gFlowSceneOffset = impactOffset * lerp(1.0,
                    saturate(gDynamicDropSmearFilmMix), gSmearMask);
                float2 ratio = gDynamicDropInvRenderTargetSize / gDynamicDropInvScreenSize;
                gSmearColor = rainSmearColorAt(pin.PosH.xy * gDynamicDropInvScreenSize
                    * lerp(float2(1.0, 1.0), ratio, 0.98));
            }
            wTrail = rainPureTrail(wTrail);
            bool trailWins = wTrail.g > wHead.g;
            float4 w0 = trailWins ? wTrail : wHead;
            float impactShare = trailWins && gDynamicDropImpactFilm > 0.5
                ? saturate((wTrail.g - wTrail.a) / max(wTrail.g, 0.02)) : 0.0;
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
                    float tU1 = rainWaterProfileTap(patternUV + u2, thr, invRange);
                    float tU0 = rainWaterProfileTap(patternUV - u2, thr, invRange);
                    float tV1 = rainWaterProfileTap(patternUV + v2, thr, invRange);
                    float tV0 = rainWaterProfileTap(patternUV - v2, thr, invRange);
                    float2 gWide = float2(tU1 - tU0, tV1 - tV0) / (2.0 * s2);
                    float2 gNarrow = float2(saturate((hU1 - thr) * invRange)
                        - saturate((hU0 - thr) * invRange),
                        saturate((hV1 - thr) * invRange)
                        - saturate((hV0 - thr) * invRange));
                    if (gDynamicDropImpactFilm > 0.5)
                        gNarrow = float2(
                            rainWaterProfileTap(patternUV + stepU, thr, invRange)
                            - rainWaterProfileTap(patternUV - stepU, thr, invRange),
                            rainWaterProfileTap(patternUV + stepV, thr, invRange)
                            - rainWaterProfileTap(patternUV - stepV, thr, invRange));
                    gNarrow /= 2.0 * max(wfStep, 1e-6);
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
                float3 color = rainSnap(samLinearClamp,
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
                color += gFogTone * glint;
                color = lerp(color, gFogTone,
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
                float solidAlpha = inside * wfAlpha;
                if (trailWins)
                {
                    float pureInside = inside;
                    if (gDynamicDropImpactFilm > 0.5)
                        pureInside = smoothstep(gDynamicDropWFThreshold - hWidth,
                            gDynamicDropWFThreshold + hWidth, wTrail.a);
                    float trailCover = pureInside * gSmearMask;
                    gFlowCoverage = 1.0 - (1.0 - gImpactCover) * (1.0 - trailCover);
                    float2 trailOffset = (sampleUV - sceneUV) * trailCover
                        * saturate(gDynamicDropSmearTrailMix);
                    gFlowSceneOffset += trailOffset;
                    gSmearColor = rainSmearColorAt(sceneUV);
                    solidAlpha = pureInside * wfAlpha * (1.0 - gSmearMask);
                }
                gSolidA = solidAlpha;
                if (waterMix < 0.002 && gFlowCoverage < 0.002)
                    return float4(color, solidAlpha);
                gOver = float4(color, solidAlpha);
                gOverMix = waterMix;
            }
        }
        // Diagnostic displays UV-space water and wiping coverage over
        // the complete visor, including gaps between static circles.
        if (gDynamicDropTrailMaskDebug > 0.5)
        {
            float2 coverage = coverageForGradient;
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
            // s34 (docs/RAINFX_NEAR_OBJECTS.md §6): the thin film has its
            // own lifetime. G decays as 0.95 exp(-3 t / T_wipe), so
            // (G / 0.95) ^ (T_wipe / T_film) = exp(-3 t / T_film): same
            // channel, film fades with T_film, micro clearing keeps T_wipe.
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
                    float filmPopFlash = 0.0;
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
                    float3 filmScene = rainSnap(
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
        float microVisibility = lerp(1.0, gSmearVisibilityG,
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
                * microVisibility) * (1.0 - gImpactCover * (1.0 - gSmearMask));
            gSolidA = lensAlpha;
            lensColor += gFogTone * microPopFlash;
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
    float4 c = float4(0.0, 0.0, 0.0, 0.0);
    gFlowSceneOffset = float2(0.0, 0.0);
    gFlowCoverage = 0.0;
    gImpactCover = 0.0;
    gSmearVisibilityG = 0.0;
    gSmearMask = 0.0;
    gSmearG = 0.0;
    gSmearK = 0.0;
    gSmearR = 0.0;
    gSmearColor = float3(0.0, 0.0, 0.0);
    gOver = float4(0.0, 0.0, 0.0, 0.0);
    gOverMix = 0.0;
    gSolidA = 0.0;
    gFogTone = gDynamicDropWeatherFogColor;
    // Keep the coarse depth-only exit outside the colour function. FXC
    // otherwise propagates undefined colour-path temporaries to its exit.
    if (gDynamicDropDepthOnly > 0.5 && gDynamicDropDepthExact < 0.5)
    {
        clip(pin.Tex.x < -2.5 ? 1.0 : -1.0);
        clip(gDynamicDropMicroPatternEnabled - 0.5);
        float2 patternUV = saturate(float2(pin.Tex.x + 4.0, pin.Tex.y + 1.0));
        float depthWater = gDynamicDropWaterField > 0.5
            ? rainWaterFieldTap(patternUV).g : 0.0;
        float4 depthMicro = rainMicroPoint(patternUV);
        float depthWipe = gDynamicDropTrailMaskWipeEnabled > 0.5
            ? txDynamicTrailMask.SampleLevel(samLinearClamp, patternUV, 0.0).g
                * gDynamicDropTrailMaskWipeStrength : 0.0;
        bool depthMicroOn = depthMicro.a > 0.75 && gDynamicDropMicroRain > 0.001
            && gDynamicDropMicroRain >= rainMicroGate(depthMicro.b) && depthWipe < 0.08;
        clip(depthWater > gDynamicDropWFThreshold || depthMicroOn ? 1.0 : -1.0);
    }
    else
    {
    gFogTone = gDynamicDropWeatherFogColor;
    if (gDynamicDropLDR > 0.5)
    {
        float3 m = rainSnap(samLinearClamp,
            float2(0.5, 0.4), gDynamicDropLdrFogMip).rgb;
        float l = dot(m, float3(0.2126, 0.7152, 0.0722));
        gFogTone = lerp(float3(l, l, l), m, saturate(gDynamicDropLdrFogSat));
    }
    c = rainDropMain(pin);
    if (gFlowCoverage > 0.0 && gDynamicDropWFDebug < 0.5 && gDynamicDropSmearDebug < 0.5)
    {
        float2 ratio = gDynamicDropInvRenderTargetSize / gDynamicDropInvScreenSize;
        float2 sceneUV = pin.PosH.xy * gDynamicDropInvScreenSize
            * lerp(float2(1.0, 1.0), ratio, 0.98);
        float3 refractedScene = rainSnap(samLinearClamp, sceneUV, 0.0).rgb;
        float fillAlpha = saturate(gFlowCoverage) * (1.0 - c.a);
        float outAlpha = c.a + fillAlpha;
        c = float4((c.rgb * c.a + refractedScene * fillAlpha)
            / max(outAlpha, 1e-4), outAlpha);
    }
    if (gDynamicDropLDR > 0.5)
        c.rgb = saturate(c.rgb);
    // Visor layer (docs/RAINFX_VISOR_LAYER.md): premultiplied output so the
    // rain layer stacks with the KN5 glass layers (BlendPremultiplied).
    if (gDynamicDropPremulOut > 0.5)
        c.rgb *= saturate(c.a);
    if (gDynamicDropDepthOnly > 0.5 && gDynamicDropDepthExact > 0.5)
    {
        // v4 (docs/RAINFX_NEAR_OBJECTS.md): optionally dense haze / film
        // also writes depth, so car glass (drawn after every hookable stage,
        // e.g. the windscreen wiper zone) cannot draw over it. Trade-off:
        // under that haze the glass tint is gone (2026-10-02 note above).
        float solid = max(gSolidA, gOver.a) - gDynamicDropDepthAlphaMin;
        float hazeD = gDynamicDropHazeDepthMin > 0.0
            ? c.a - gDynamicDropHazeDepthMin : -1.0;
        clip(max(solid, hazeD));
        c = float4(0.0, 0.0, 0.0, 0.0);
    }
    }
    return c;
}
