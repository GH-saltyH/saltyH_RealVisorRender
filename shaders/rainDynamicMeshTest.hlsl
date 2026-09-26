/*
    RealVisor Dynamic Mesh Renderer - Stage 1

    Static 256-quad test shader.
    This deliberately does NOT consume Persistent GPU state.
    It exists only to measure:
      createMesh() -> render.mesh() -> rasterized droplet footprints.

    Each quad receives local UVs in the normal mesh shader pipeline.
*/

float4 main(PS_IN pin)
{
    float2 uv = pin.Tex;

    // Keep the fragment work intentionally tiny.
    float edge = smoothstep(0.0, 0.08, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
    float alpha = 0.30 + edge * 0.20;

    return float4(0.35, 0.85, 1.0, alpha);
}
