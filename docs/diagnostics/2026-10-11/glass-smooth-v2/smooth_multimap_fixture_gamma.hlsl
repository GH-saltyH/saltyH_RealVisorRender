#define GAMMA_FIX 1
#define TARGET_PS 1
#define MODE_MAIN_NOFX 1
#define OBJECT_SHADER 1
#define NO_FOG 1
#define main nativeMaterialMain
#include "ksPerPixelMultiMap_emissive_ps.fx"
#undef main
cbuffer Fixture : register(b12) {float2 fixtureSize; float fixtureAngle; float fixtureProbe; float2 fixtureUV;};
float4 main(float4 position:SV_POSITION):SV_TARGET {
 PS_IN_NmExtra4 pin=(PS_IN_NmExtra4)0;
 pin.PosH=position;
 float2 uv=fixtureProbe>0 ? fixtureUV : position.xy/fixtureSize;
 pin.Tex=uv; pin.Extra=float4(1,0,0,0); pin.Ao=1;
 pin.ShadowTex0=float4(0,0,0,1);
 float angle=fixtureProbe>0 ? fixtureAngle : (uv.x-.5)*1.9+fixtureAngle;
 pin.NormalW=float3(sin(angle),0,cos(angle));
 pin.TangentW=float3(cos(angle),0,-sin(angle)); pin.BitangentW=float3(0,1,0);
 pin.PosC=float3(0,0,-1);
 PS_OUT result=nativeMaterialMain(pin); return result.result;
}
