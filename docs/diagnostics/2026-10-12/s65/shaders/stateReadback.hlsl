struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;float3 ApplyFog(float3 c){return c;}};
Texture2D txRainState;
Texture2D txRainStateMeta;

float gRainReadbackHeight;
float gRainReadbackWidth;
float gRainStateCount;
float gRainStateVelocityEncodeRange;

SamplerState samPointRain {
    Filter = MIN_MAG_MIP_POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
    AddressW = CLAMP;
};

float4 main(PS_IN pin):SV_TARGET
{
    float count = max(gRainStateCount, 1.0);
    float total = count * 6.0;
    float slot = min(floor(pin.Tex.y * gRainReadbackHeight)
        * gRainReadbackWidth
        + floor(pin.Tex.x * gRainReadbackWidth), total - 1.0);
    float channel = floor(slot / count);
    float index = slot - channel * count;
    float2 suv = float2((index + 0.5) / count, 0.5);

    float4 state = txRainState.SampleLevel(samPointRain, suv, 0.0);
    float4 meta = txRainStateMeta.SampleLevel(samPointRain, suv, 0.0);

    float velocityRange = max(gRainStateVelocityEncodeRange, 0.000001);
    float value = 0.0;

    if (channel < 0.5) {
        value = saturate(state.r);
    } else if (channel < 1.5) {
        // Encode signed visor V (-1..0) into documented 0..1 CPU scalar range.
        value = saturate(state.g + 1.0);
    } else if (channel < 2.5) {
        value = 0.5 + 0.5 * state.b / (abs(state.b) + velocityRange);
    } else if (channel < 3.5) {
        value = 0.5 + 0.5 * state.a / (abs(state.a) + velocityRange);
    } else if (channel < 4.5) {
        value = max(meta.r, 0.0);
    } else {
        value = meta.a;
    }

    return float4(value, value, value, value);
}
