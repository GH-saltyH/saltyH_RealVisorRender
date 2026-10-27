// chunks: ['RDEF', 'ISGN', 'OSGN', 'SHEX', 'STAT']
// res samLinear type=3 dim=0 bind=0 count=1
// res samShadow type=3 dim=0 bind=1 count=1
// res samPoint type=3 dim=0 bind=2 count=1
// res samLinearSimple type=3 dim=0 bind=5 count=1
// res samLinearBorder0 type=3 dim=0 bind=6 count=1
// res samLinearClamp type=3 dim=0 bind=8 count=1
// res txDiffuse type=2 dim=4 bind=0 count=1
// res _txRainWater type=2 dim=4 bind=1 count=1
// res _txRainDetail type=2 dim=4 bind=2 count=1
// res _txRainWiper type=2 dim=4 bind=3 count=1
// res _txOcclusion type=2 dim=4 bind=4 count=1
// res _txRainWaterBlurred type=2 dim=4 bind=5 count=1
// res _txTracingColor type=2 dim=4 bind=6 count=1
// res txCube type=2 dim=9 bind=13 count=1
// res txShadowArray type=2 dim=5 bind=14 count=1
// res txCloudShadow type=2 dim=4 bind=15 count=1
// res txDepth type=2 dim=4 bind=18 count=1
// res txPrevFrame type=2 dim=4 bind=19 count=1
// res txNoise type=2 dim=4 bind=20 count=1
// res cbCamera type=0 dim=0 bind=0 count=1
// res cbPerObject type=0 dim=0 bind=1 count=1
// res cbLighting type=0 dim=0 bind=2 count=1
// res cbShadowMaps type=0 dim=0 bind=3 count=1
// res cbMaterial type=0 dim=0 bind=4 count=1
// res _cbExtWindscreen type=0 dim=0 bind=6 count=1
// res _cbExtLighting type=0 dim=0 bind=7 count=1
// res _cbData type=0 dim=0 bind=12 count=1
// cbuffer _cbData size=160
//    +0 gCarTransform (64)
//    +64 gCarTransformInv (64) unused
//    +128 gCameraSide (12) unused
//    +140 gWindscreenFXFlags (4)
//    +144 gCameraUp (12)
//    +156 gFadingInv (4)
// cbuffer cbMaterial size=112
//    +0 ksAmbient (4)
//    +4 ksDiffuse (4)
//    +8 ksSpecular (4) unused
//    +12 ksSpecularEXP (4) unused
//    +16 ksEmissive (12)
//    +28 ksAlphaRef (4) unused
//    +32 extFlags (4)
//    +36 extExtraSharpLocalReflections (4) unused
//    +40 seasonAutumn (4) unused
//    +44 seasonWinter (4) unused
//    +48 bannerMode (4)
//    +52 solidBrightnessAdjustment (4)
//    +64 extEdgePosL (12)
//    +76 extEdgeRefractionBias (4)
//    +80 extEdgeThreshold (4)
//    +84 reflectionsIntensity (4)
//    +88 alphaGamma (4)
//    +92 extDetailScale (4)
//    +96 extOcclusionDebug (4)
// cbuffer cbCamera size=320
//    +0 ksView_base (64) unused
//    +64 ksProjection_base (64) unused
//    +128 ksMVPInverse (64) unused
//    +192 ksCameraPosition (12)
//    +204 extCameraTangent (4) unused
//    +208 ksNearPlane (4)
//    +212 ksFarPlane (4)
//    +216 ksFOV (4) unused
//    +220 ksDofFactor (4) unused
//    +224 extScreenSize (16)
//    +240 ksViewProjPrev (64) unused
//    +304 extAltCameraPosition (12)
//    +316 extAltCameraThreshold (4)
// cbuffer cbPerObject size=80
//    +0 ksWorld (64) unused
//    +64 vaoSecondaryMix (4) unused
//    +68 perObjAmbientMultiplier (4)
//    +72 extMotionStencil (4)
//    +76 _cbPerObject_pad0 (4) unused
// cbuffer cbLighting size=528
//    +0 ksLightDirection (16)
//    +16 ksAmbientColor_sky0 (16)
//    +32 ksLightColor (16)
//    +48 ksHorizonColor (16) unused
//    +64 ksZenithColor (16) unused
//    +80 ksExposure (4) unused
//    +84 ksScreenWidth (4) unused
//    +88 ksScreenHeight (4) unused
//    +92 ksFogLinear (4) unused
//    +96 ksFogBlend (4) unused
//    +100 ksFogColor (12)
//    +112 ksCloudCover (4) unused
//    +116 ksCloudCutoff (4) unused
//    +120 ksCloudColor (4) unused
//    +124 ksCloudOffset (4) unused
//    +128 ksMinExposure (4) unused
//    +132 ksMaxExposure (4) unused
//    +136 ksDofFocus (4) unused
//    +140 ksDofRange (4) unused
//    +144 ksSaturation (4) unused
//    +148 ksGameTime (4) unused
//    +152 extSceneRain (4)
//    +156 extSceneWetness (4) unused
//    +160 extSceneWater (4) unused
//    +164 extFrameTime (4) unused
//    +168 extVaoMode (4)
//    +172 extMSAA (4) unused
//    +176 extFogConstantPiece (4) unused
//    +180 extFogBacklitMult (4)
//    +184 extFogBacklitExp (4)
//    +188 extFogExp (4) unused
//    +192 extAdditionalAmbientColor (12)
//    +204 extPhotoElBoost_mirageMult (4) unused
//    +208 extAdditionalAmbientDir (12)
//    +220 extAdditionalAmbient_mix (4)
//    +224 extBaseAmbient (12)
//    +236 extLODDistanceMult (4) unused
//    +240 extSpecularColor (12)
//    +252 extSunSpecularMult (4) unused
//    +256 extWindVel (8) unused
//    +264 extWindSpeed (4) unused
//    +268 extWindWave (4) unused
//    +272 extWindSpeedPrev (4) unused
//    +276 extWindWavePrev (4) unused
//    +280 extGlowBrightness_extForceEmissive (4) unused
//    +284 extLambertGamma_inner (4)
//    +288 extEmissiveMults (16)
//    +304 extIBLAmbient (4)
//    +308 extIBLAmbientBaseThreshold (4)
//    +312 extIBLAmbientBrightness (4)
//    +316 extIBLAmbientSaturation (4)
//    +320 extVAOMult (4) unused
//    +324 extVAOAdd (4) unused
//    +328 extVAOExp (4) unused
//    +332 extCloudShadowOpacity (4)
//    +336 extCloudShadowMatrix (64)
//    +400 p_extCPLDir (12)
//    +412 p_extCPLFactor (4)
//    +416 extDirLook (12) unused
//    +428 extFogAtmosphere (4)
//    +432 extDirUp (12) unused
//    +444 extPad_screenMode_frameNum_A2COffset (4) unused
//    +448 extSceneOffset (12) unused
//    +460 extTiltBias_extGrassFx12RangeInv (4) unused
//    +464 extWindWater (8) unused
//    +472 extFresnelGamma (4)
//    +476 _extPad (4) unused
//    +480 ksAmbientColor_sky1 (12)
//    +492 ksAmbientColor_sky1_mix (4)
//    +496 extExtraAoAmbientColor (12)
//    +508 extExtraAoAmbientColor_exp (4)
//    +512 extWindVelPrev (8) unused
//    +520 _extPad_actuallyEmpty (8) unused
// cbuffer cbShadowMaps size=240
//    +0 ksShadowMatrix0 (64)
//    +64 bias (12) unused
//    +76 pixelSize (4)
//    +80 shadowR1 (4) unused
//    +84 shadowPos (12) unused
//    +96 shadowR2 (4) unused
//    +100 shadowsTransitionWeight (12) unused
//    +112 shadowsMatrixModifier1A (12) unused
//    +124 reflectionsTweak (4)
//    +128 shadowsMatrixModifier1M (12) unused
//    +140 shadowReflectionOcclusion (4) unused
//    +144 shadowsMatrixModifier2A (12) unused
//    +156 extShadowsOpacityMult (4) unused
//    +160 shadowsMatrixModifier2M (12) unused
//    +172 realTextureSize (4) unused
//    +176 shadowsMatrixModifier3A (12) unused
//    +188 realTextureSizeSqr2 (4) unused
//    +192 shadowsMatrixModifier3M (12) unused
//    +204 sceneShadowOpacity (4) unused
//    +208 shadowsBias (16)
//    +224 shadowsDistanceSqrInv (16) unused
// cbuffer _cbExtLighting size=15408
//    +0 gNoLightAt (32)
//    +32 gNoLightEdgeA (8)
//    +40 gNoLightEdgeB (8)
//    +48 gLightBVHNodeData (5120)
//    +5168 gLightsData (10240)
// cbuffer _cbExtWindscreen size=16
//    +0 carVelocity (12)
//    +12 noiseMult_disableTexture (4)
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask7; TEXCOORD6 r1 sv0 mask8; TEXCOORD1 r2 sv0 mask7; TEXCOORD2 r3 sv0 mask3; TEXCOORD24 r3 sv0 maskc; TEXCOORD20 r4 sv0 mask7; TEXCOORD21 r5 sv0 mask7; TEXCOORD25 r6 sv0 mask7; TEXCOORD3 r7 sv0 maskf; COLOR1 r8 sv0 mask1
// OSGN | SV_Target0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_immediateConstantBuffer { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
dcl_constantbuffer cb12[10]
dcl_constantbuffer cb4[7]
dcl_constantbuffer cb0[20]
dcl_constantbuffer cb1[5]
dcl_constantbuffer cb2[32]
dcl_constantbuffer cb3[14]
dcl_constantbuffer cb7[963] dynamicIndexed
dcl_constantbuffer cb6[1]
dcl_sampler s0
dcl_sampler s1 comparison
dcl_sampler s2
dcl_sampler s5
dcl_sampler s6
dcl_sampler s8
dcl_resource_texture2d (float) t0
dcl_resource_texture2d (float) t1
dcl_resource_texture2d (float) t2
dcl_resource_texture2d (float) t3
dcl_resource_texture2d (float) t4
dcl_resource_texture2d (float) t5
dcl_resource_texture2d (float) t6
dcl_resource_texturecube (float) t13
dcl_resource_texture2darray (float) t14
dcl_resource_texture2d (float) t15
dcl_resource_texture2d (float) t18
dcl_resource_texture2d (float) t19
dcl_resource_texture2d (float) t20
dcl_input_ps_siv v0.xyz sv1
dcl_input_ps linear v1.xyz
dcl_input_ps linear v1.w
dcl_input_ps linear v2.xyz
dcl_input_ps linear v3.xy
dcl_input_ps linear v3.zw
dcl_input_ps linear v4.xyz
dcl_input_ps linear v5.xyz
dcl_input_ps linear v6.xyz
dcl_input_ps linear v7.xyz
dcl_output o0
dcl_temps 24
dp3 r0.x, v2.xyzx, v2.xyzx
rsq r0.y, r0.x
mul r1.xyz, r0.yyyy, v2.xyzx
dp3 r0.z, v1.xyzx, v1.xyzx
rsq r0.z, r0.z
mul r2.xyz, r0.zzzz, v1.xyzx
sample r3, v3.zwzz, t1, s0
sample_l r0.zw, v3.zwzz, t1, s5, l(2.5)
sample_l r4.x, v3.zwzz, t5, s5, l(0)
mul r4.y, r4.x, l(2)
mov_sat r4.y, r4.y
mad_sat r4.z, r4.x, l(2), l(-1)
sample r5, v3.zwzz, t3, s0
add r4.w, -cb4[6].x, l(1)
sample_l r6, v3.zwzz, t4, s0, r4.w
mad r4.w, cb2[9].z, l(0.2), r3.w
add r4.w, r4.w, l(-0.45)
mul_sat r4.w, r4.w, l(3.33333)
max r7.x, r3.z, r4.w
mul r7.yz, v3.zzwz, cb4[5].wwww
sample r7.yzw, r7.yzyy, t2.zxyw, s5
mul r0.z, r0.z, l(0.9)
max r0.z, r0.w, r0.z
mad_sat r0.z, -r0.z, l(10), l(4)
mul r0.z, r0.z, cb12[9].w
add r5.y, -r5.y, l(1)
mov_sat r8.x, r5.y
mul r0.z, r0.z, r8.x
add_sat r8.x, -r3.z, l(1)
mul r0.z, r0.z, r8.x
mul r8.x, r6.w, l(10)
mad_sat r8.y, r6.w, l(2), l(-1)
mul r0.z, r0.z, r8.y
mul r0.z, r0.z, r7.w
mad r8.y, r4.y, l(2), l(-1)
max r8.y, r8.y, l(0)
add r8.y, -r8.y, l(1)
mad r8.y, r0.z, l(2), -r8.y
mad r4.y, -r4.y, l(2.33333), l(0.3)
max r4.y, r4.y, l(0)
add r4.y, -r4.y, r8.y
mul_sat r4.y, r4.y, l(3)
mul r0.z, r0.z, r4.y
mul_sat r0.z, r0.z, l(2)
mul r4.y, r4.z, r7.w
mul r4.y, r4.y, l(1.15)
max r0.z, r0.z, r4.y
add r4.y, -r7.x, l(1)
mul r4.z, r0.z, r4.y
mad r0.z, r0.z, r4.y, r7.x
mov_sat r8.x, r8.x
mul r0.z, r0.z, r8.x
mul r4.y, r0.z, l(2)
mad_sat r7.x, r0.z, l(2), l(-1)
mad r7.w, -r7.x, l(0.7), l(1)
sample r8, v3.xyxx, t0, s0
ne r9.xy, l(0, 0, 0, 0), cb4[3].yxyy
add_sat r10.xyz, r8.xyzx, cb4[3].yyyy
mad_sat r9.z, r8.w, l(10), l(-5)
add r10.xyz, -r8.xyzx, r10.xyzx
mad r10.xyz, r9.zzzz, r10.xyzx, r8.xyzx
movc r8.xyz, r9.xxxx, r10.xyzx, r8.xyzx
ne r9.xz, l(0, 0, 0, 0), cb4[5].zzyz
mov_sat r9.w, r8.w
log r9.w, r9.w
mul r9.w, r9.w, cb4[5].z
exp r9.w, r9.w
movc r8.w, r9.x, r9.w, r8.w
not r9.x, r9.y
lt r9.y, r8.w, l(0.5)
and r9.x, r9.y, r9.x
mul r9.yw, v0.xxxy, cb0[14].zzzw
sample_l r10, r9.ywyy, t6, s6, l(0)
and r10, r9.zzzz, r10
add r11.xyz, -cb0[12].xyzx, cb0[19].xyzx
lt r9.z, v0.x, cb0[19].w
and r9.z, r9.z, l(1)
mad r11.xyz, r11.xyzx, r9.zzzz, v2.xyzx
mov r11.w, l(1)
dp4 r12.x, r11, cb2[21]
dp4 r12.y, r11, cb2[22]
sample_l r9.z, r12.xyxx, t15.yzxw, s8, l(1.5)
mad_sat r9.z, -r9.z, cb2[20].w, l(1)
f16tof32 r11.w, cb6[0].w
eq r12.x, r11.w, l(-1)
if_nz r12.x
mul r12.x, r9.z, cb1[4].y
else 
add r12.yzw, r11.xxyz, cb0[12].xxyz
add r13.xyz, r12.yzwy, cb6[0].xyzx
mov r13.w, l(1)
dp4 r14.x, r13, cb3[0]
dp4 r14.y, r13, cb3[1]
dp4 r14.z, r13, cb3[2]
dp3 r12.y, r2.xyzx, cb2[0].xyzx
add r12.y, -|r12.y|, l(1)
max r12.y, r12.y, l(0.1)
mul r12.y, r12.y, cb3[13].x
mul r12.zw, v7.xxxy, l(0, 0, 1000, 1000)
sample_l r12.z, r12.zwzz, t20.yzxw, s2, l(0)
add r12.z, r12.z, l(-0.5)
mad r13, r11.wwww, r12.zzzz, l(0.5, 1.5, 2.5, 3.5)
add r14.xyz, r14.xyzx, -v7.xyzx
mul r14.xyz, r14.xyzx, l(0.111111, 0.111111, 0.111111, 0)
mad r15.xyz, r14.xyzx, r13.xxxx, v7.xyzx
mad r12.w, -r12.y, l(2), r15.z
mad r15.xy, r15.xyxx, l(0.5, -0.5, 0, 0), -cb3[4].wwww
add r15.xy, r15.xyxx, l(0.5, 0.5, 0, 0)
mov r15.z, l(0)
sample_c_lz r12.w, r15.xyzx, t14.xxxx, s1, r12.w
mad r15.xyz, r14.xyzx, r13.yyyy, v7.xyzx
mul r16, cb3[4].wwww, l(-1, 0, -1, 1)
mad r13.x, -r12.y, l(2), r15.z
mad r15.xy, r15.xyxx, l(0.5, -0.5, 0, 0), r16.xyxx
add r15.xy, r15.xyxx, l(0.5, 0.5, 0, 0)
mov r15.z, l(0)
sample_c_lz r13.x, r15.xyzx, t14.xxxx, s1, r13.x
add r12.w, r12.w, r13.x
mad r13.xyz, r14.xyzx, r13.zzzz, v7.xyzx
mad r13.z, -r12.y, l(2), r13.z
mad r13.xy, r13.xyxx, l(0.5, -0.5, 0, 0), r16.zwzz
add r15.xy, r13.xyxx, l(0.5, 0.5, 0, 0)
mov r15.z, l(0)
sample_c_lz r13.x, r15.xyzx, t14.xxxx, s1, r13.z
add r12.w, r12.w, r13.x
mad r13.xyz, r14.xyzx, r13.wwww, v7.xyzx
mad r13.z, -r12.y, l(2), r13.z
mad r13.xy, r13.xyxx, l(0.5, -0.5, 0, 0), r16.yxyy
add r15.xy, r13.xyxx, l(0.5, 0.5, 0, 0)
mov r15.z, l(0)
sample_c_lz r13.x, r15.xyzx, t14.xxxx, s1, r13.z
add r12.w, r12.w, r13.x
mad r13, r11.wwww, r12.zzzz, l(4.5, 5.5, 6.5, 7.5)
mad r15.xyz, r14.xyzx, r13.xxxx, v7.xyzx
mad r13.x, -r12.y, l(2), r15.z
mad r15.xy, r15.xyxx, l(0.5, -0.5, 0, 0), l(0.5, 0.5, 0, 0)
mov r15.z, l(0)
sample_c_lz r13.x, r15.xyzx, t14.xxxx, s1, r13.x
add r12.w, r12.w, r13.x
mad r15.xyz, r14.xyzx, r13.yyyy, v7.xyzx
mul r13.xy, cb3[4].wwww, l(1, 0, 0, 0)
mad r14.w, -r12.y, l(2), r15.z
mad r15.xy, r15.xyxx, l(0.5, -0.5, 0, 0), r13.yxyy
add r15.xy, r15.xyxx, l(0.5, 0.5, 0, 0)
mov r15.z, l(0)
sample_c_lz r14.w, r15.xyzx, t14.xxxx, s1, r14.w
add r12.w, r12.w, r14.w
mad r15.xyz, r14.xyzx, r13.zzzz, v7.xyzx
mad r13.z, -r12.y, l(2), r15.z
mad r15.xy, r15.xyxx, l(0.5, -0.5, 0, 0), r16.wzww
add r15.xy, r15.xyxx, l(0.5, 0.5, 0, 0)
mov r15.z, l(0)
sample_c_lz r13.z, r15.xyzx, t14.xxxx, s1, r13.z
add r12.w, r12.w, r13.z
mad r15.xyz, r14.xyzx, r13.wwww, v7.xyzx
mad r13.z, -r12.y, l(2), r15.z
mad r13.xy, r15.xyxx, l(0.5, -0.5, 0, 0), r13.xyxx
add r15.xy, r13.xyxx, l(0.5, 0.5, 0, 0)
mov r15.z, l(0)
sample_c_lz r13.x, r15.xyzx, t14.xxxx, s1, r13.z
add r12.w, r12.w, r13.x
mad r11.w, r11.w, r12.z, l(8.5)
mad r13.xyz, r14.xyzx, r11.wwww, v7.xyzx
mad r11.w, -r12.y, l(2), r13.z
mad r12.yz, r13.xxyx, l(0, 0.5, -0.5, 0), cb3[4].wwww
add r13.xy, r12.yzyy, l(0.5, 0.5, 0, 0)
mov r13.z, l(0)
sample_c_lz r11.w, r13.xyzx, t14.xxxx, s1, r11.w
add r11.w, r11.w, r12.w
mul r9.z, r9.z, r11.w
mul r12.x, r9.z, l(0.111111)
endif 
mul r7.w, r7.w, r12.x
ne r9.z, l(0, 0, 0, 0), r10.w
if_nz r9.z
eq r9.z, cb4[5].y, l(1)
dp3 r10.w, r2.xyzx, r1.xyzx
add_sat r10.w, r10.w, l(1)
mul r10.w, r10.w, r10.w
mul r11.w, r10.w, r10.w
mul r10.w, r10.w, r11.w
lt r11.w, cb4[5].y, l(0)
add r12.x, cb4[5].y, l(50)
mad r12.x, r10.w, r12.x, -cb4[5].y
mul r12.xyz, r10.xyzx, r12.xxxx
add r13.x, -cb4[5].y, l(1000)
mad r10.w, r10.w, r13.x, cb4[5].y
mul r13.xyz, r10.wwww, r10.xyzx
mov r12.w, l(0.02)
mov r13.w, l(0.001)
movc r12, r11.wwww, r12, r13
movc r10.w, r9.z, l(1), r12.w
movc r12.xyz, r9.zzzz, r10.xyzx, r12.xyzx
and r12.xyz, r9.xxxx, r12.xyzx
and r9.z, r9.x, r10.w
mov r10.w, r9.x
else 
mov r12.xyz, l(0, 0, 0, 0)
mov r9.z, l(0)
mov r10.w, l(0)
endif 
if_z r10.w
mad_sat r10.w, -r4.x, l(5), l(1)
mad r10.w, r10.w, r5.z, l(-1)
mad r10.w, cb12[9].w, r10.w, l(1)
dp3_sat r11.w, cb2[2].xyzx, l(0.2125, 0.7154, 0.0721, 0)
mul r11.w, r8.w, r11.w
dp3 r12.w, r1.xyzx, -cb2[0].xyzx
mul_sat r12.w, r7.w, r12.w
mul r10.w, r10.w, r12.w
mul r13.xyz, cb4[0].yyyy, cb2[2].xyzx
ushr r12.w, cb6[0].w, l(16)
mul r11.w, r11.w, r10.w
movc r11.w, r12.w, l(0), r11.w
movc r9.z, r9.x, r11.w, r8.w
mad_sat r8.w, r2.y, l(0.25), l(0.75)
dp3_sat r11.w, r2.xyzx, cb2[13].xyzx
mul r12.w, r0.x, cb2[13].w
mad r13.w, r0.x, cb2[13].w, l(1)
div r12.w, r12.w, r13.w
add r12.w, -r12.w, l(1)
mul r11.w, r11.w, r12.w
min r8.w, r8.w, cb1[4].y
mul r12.w, r0.x, cb2[30].w
mad r0.x, r0.x, cb2[30].w, l(1)
div r0.x, r12.w, r0.x
mad r14.xyz, cb2[30].xyzx, r0.xxxx, cb2[1].xyzx
mad r14.xyz, cb2[12].xyzx, r11.wwww, r14.xyzx
add r0.x, -r0.x, l(1)
mul r15.xyz, r0.xxxx, cb2[31].xyzx
mov_sat r0.x, cb1[4].y
log r0.x, r0.x
mul r0.x, r0.x, cb2[31].w
exp r0.x, r0.x
mul r15.xyz, r0.xxxx, r15.xyzx
mad r14.xyz, r14.xyzx, r8.wwww, r15.xyzx
ge r0.x, cb2[10].z, l(-100)
max r15.xyz, r14.xyzx, l(0, 0, 0, 0)
movc r14.xyz, r0.xxxx, r15.xyzx, r14.xyzx
add r14.xyz, r14.xyzx, cb2[14].xyzx
and r15.xyz, cb4[2].xxxx, l(16, 4, 3, 0)
if_z r15.x
eq r0.x, cb2[10].z, l(-101)
movc r16.xyz, r0.xxxx, l(1, 1, 1, 0), r14.xyzx
mov r2.w, -r2.x
sample_l r2.xyz, r2.wyzw, t13, s5, l(15)
mul r17.xyz, r16.xyzx, cb2[19].yyyy
dp3 r0.x, r2.xyzx, l(0.333, 0.333, 0.333, 0)
add r2.xyz, -r0.xxxx, r2.xyzx
mad r2.xyz, cb2[19].wwww, r2.xyzx, r0.xxxx
mul r2.xyz, r2.xyzx, cb2[19].zzzz
max r2.xyz, r2.xyzx, r17.xyzx
mad r2.xyz, r2.xyzx, cb1[4].yyyy, -r16.xyzx
mad r14.xyz, cb2[19].xxxx, r2.xyzx, r16.xyzx
endif 
mul r2.xyz, r14.xyzx, cb4[0].xxxx
mad r2.xyz, r13.xyzx, r10.wwww, r2.xyzx
mul r10.xyz, r10.xyzx, l(0.2, 0.2, 0.2, 0)
mad r2.xyz, r2.xyzx, r8.xyzx, r10.xyzx
mul r10.xyz, r8.xyzx, cb4[1].xyzx
dp4 r0.x, cb2[18], icb[r15.z]
movc r0.x, r15.y, l(1), r0.x
mad r12.xyz, r10.xyzx, r0.xxxx, r2.xyzx
endif 
eq r0.x, cb1[4].z, l(17)
add r2.x, cb4[3].x, l(-1)
max r2.x, r2.x, l(0)
if_nz r0.x
add r10, v0.xyxy, l(1, -1, 1, 1)
ftoi r10, r10.zwxy
mov r13.xy, r10.zwzz
mov r13.zw, l(0, 0, 0, 0)
ld r0.x, r13, t18
ne r2.y, l(0, 0, 0, 0), r0.x
mul r2.z, cb0[13].y, cb0[13].x
add r2.w, -cb0[13].x, cb0[13].y
mad r0.x, -r0.x, r2.w, cb0[13].y
div r0.x, r2.z, r0.x
movc r0.x, r2.y, r0.x, cb0[13].y
min r0.x, r0.x, l(10)
mov r10.zw, l(0, 0, 0, 0)
ld r2.y, r10, t18.yxzw
ne r8.w, l(0, 0, 0, 0), r2.y
mad r2.y, -r2.y, r2.w, cb0[13].y
div r2.y, r2.z, r2.y
movc r2.y, r8.w, r2.y, cb0[13].y
min r0.x, r0.x, r2.y
add r10, v0.xyxy, l(-1, 1, -1, -1)
ftoi r10, r10.zwxy
mov r13.xy, r10.zwzz
mov r13.zw, l(0, 0, 0, 0)
ld r2.y, r13, t18.yxzw
ne r8.w, l(0, 0, 0, 0), r2.y
mad r2.y, -r2.y, r2.w, cb0[13].y
div r2.y, r2.z, r2.y
movc r2.y, r8.w, r2.y, cb0[13].y
min r0.x, r0.x, r2.y
mov r10.zw, l(0, 0, 0, 0)
ld r2.y, r10, t18.yxzw
ne r8.w, l(0, 0, 0, 0), r2.y
mad r2.y, -r2.y, r2.w, cb0[13].y
div r2.y, r2.z, r2.y
movc r2.y, r8.w, r2.y, cb0[13].y
min r0.x, r0.x, r2.y
mad r2.y, -v0.z, r2.w, cb0[13].y
div r2.y, r2.z, r2.y
add r0.x, -r0.x, r2.y
lt r0.x, r0.x, l(0)
discard_nz r0.x
ne r0.x, l(0, 0, 0, 0), r2.x
movc o0.w, r0.x, l(1), r9.z
max r2.yzw, r12.xxyz, l(0, 0, 0, 0)
mov_sat r10.z, v1.w
mul r0.x, r10.z, r10.z
mad r0.x, r10.z, r0.x, -r10.z
mad r10.x, cb2[26].w, r0.x, r10.z
mad r0.x, r10.z, r10.z, -r10.z
mad r10.y, cb2[26].w, r0.x, r10.z
dp3_sat r0.x, -r1.xyzx, cb2[0].xyzx
log r0.x, r0.x
mul r0.x, r0.x, cb2[11].z
exp r0.x, r0.x
mul r13.xyz, r0.xxxx, cb2[2].xyzx
mad r13.xyz, r13.xyzx, cb2[11].yyyy, cb2[6].yzwy
add r13.xyz, -r2.yzwy, r13.xyzx
mad o0.xyz, r10.xyzx, r13.xyzx, r2.yzwy
ret 
endif 
mul r0.x, r3.w, l(4)
mad r2.yz, r3.xxyx, l(0, 2, 2, 0), l(0, -1, -1, 0)
mad r2.w, r4.w, l(0.9), l(0.1)
mul r3.xy, r2.wwww, r2.yzyy
mad r2.yz, -r2.yyzy, r2.wwww, r7.yyzy
mad r2.yz, r4.zzzz, r2.yyzy, r3.xxyx
dp2 r2.w, r2.yzyy, r2.yzyy
add r2.w, -r2.w, l(1)
max r2.w, r2.w, l(0)
sqrt r2.w, r2.w
mad r10.xyz, r6.xyzx, l(2, 2, 2, 0), l(-1, -1, -1, 0)
mul r13.xyz, r10.yzxy, v6.zxyz
mad r13.xyz, v6.yzxy, r10.zxyz, -r13.xyzx
dp3 r3.x, r13.xyzx, r13.xyzx
rsq r3.x, r3.x
mul r13.xyz, r3.xxxx, r13.xyzx
mul r13.xyz, r2.zzzz, r13.xyzx
mad r10.xyz, r2.yyyy, r10.xyzx, r13.xyzx
mad r10.xyz, r2.wwww, v6.xyzx, r10.xyzx
dp3 r2.y, r10.xyzx, r10.xyzx
rsq r2.y, r2.y
mul r10.xyz, r2.yyyy, r10.xyzx
dp3 r13.x, r10.xyzx, cb12[0].xyzx
dp3 r13.y, r10.xyzx, cb12[1].xyzx
dp3 r13.z, r10.xyzx, cb12[2].xyzx
mad r0.z, r0.z, l(-0.2), l(0.6)
mad_sat r2.y, r4.x, l(8), l(-0.8)
mul r0.z, r0.z, r2.y
mul r0.z, r5.y, r0.z
add r2.y, -r5.x, l(1)
mad r0.z, r0.z, r2.y, r5.x
mad_sat r0.w, -r0.w, l(10), l(2.5)
mad_sat r2.y, -r3.z, l(5), l(1)
mul r0.w, r0.w, r2.y
mad r0.w, r0.w, l(-0.2), l(0.2)
add_sat r0.z, -r0.w, r0.z
mad_sat r0.w, -r3.z, l(4), l(1)
mad_sat r0.x, -r0.x, r0.w, l(1)
mad r2.yz, r5.wwww, l(0, 2.5, 0.5, 0), l(0, -0.5, 0.5, 0)
mov_sat r2.y, r2.y
mul r0.w, r2.y, r2.z
mad r0.w, r0.w, l(0.5), l(0.5)
mul r0.w, r6.w, r0.w
mul r2.y, r2.z, r6.w
mul r2.y, r2.y, l(0.95)
ne r2.z, l(0, 0, 0, 0), cb4[6].x
ne r3.x, l(0, 0, 0, 0), cb4[4].w
if_nz r3.x
add r3.xyz, -v4.xyzx, cb4[4].xyzx
dp3 r4.z, r3.xyzx, r3.xyzx
rsq r4.z, r4.z
mul r3.xyz, r3.xyzx, r4.zzzz
dp3 r4.z, v5.xyzx, v5.xyzx
rsq r4.z, r4.z
mul r5.xyw, r4.zzzz, v5.xyxz
dp3 r3.x, r3.xyzx, r5.xywx
add r3.y, cb4[5].x, l(-0.01)
add r3.x, -r3.y, r3.x
add r3.y, -r3.y, cb4[5].x
div_sat r3.x, r3.x, r3.y
else 
mov r3.x, l(0)
endif 
add r3.y, -r2.w, l(1)
mul r3.z, r3.y, r3.y
mul r3.z, r3.z, r3.y
mul r3.y, r3.y, l(0.5)
mad r5.xyw, -v2.xyxz, r0.yyyy, -r13.xyxz
mad r5.xyw, r3.yyyy, r5.xyxw, r1.xyxz
dp3 r3.y, r5.xywx, r5.xywx
rsq r3.y, r3.y
mul r10.xyz, r3.yyyy, r5.xywx
dp3 r3.y, r1.xyzx, r13.xyzx
add r3.y, r3.y, r3.y
mad r5.xyw, r13.xyxz, -r3.yyyy, r1.xyxz
add r14.xyz, -r5.xywx, r13.xyzx
mad r14.xyz, r14.xyzx, l(0.7, 0.7, 0.7, 0), r5.xywx
mov r14.w, -r14.x
sample_l r5.xyw, r14.wyzw, t13.xywz, s5, l(2)
mov r10.w, -r10.x
sample_l r10.xyz, r10.wyzw, t13, s5, l(0)
mul r14.xyz, r10.xyzx, l(0.7, 0.7, 0.7, 0)
and r3.y, cb12[8].w, l(1)
if_nz r3.y
mul r15.xyz, v1.yzxy, cb12[9].zxyz
mad r15.xyz, cb12[9].yzxy, v1.zxyz, -r15.xyzx
dp3 r4.z, r15.xyzx, r15.xyzx
rsq r4.z, r4.z
mul r15.xyz, r4.zzzz, r15.xyzx
mul r16.xyz, r15.yzxy, v1.zxyz
mad r16.xyz, v1.yzxy, r15.zxyz, -r16.xyzx
dp3 r4.z, r16.xyzx, r16.xyzx
rsq r4.z, r4.z
mul r16.xyz, r4.zzzz, r16.xyzx
dp3 r15.x, r15.xyzx, r13.xyzx
dp3 r15.y, r16.xyzx, r13.xyzx
mul r4.zw, r15.xxxy, l(0, 0, -1, 1)
mul r4.x, r4.x, r4.x
mad r3.w, r3.w, l(2), l(3)
mul r7.y, cb1[4].y, cb2[9].z
mad r7.y, r7.y, l(0.25), l(0.25)
mad r4.zw, r4.zzzw, r7.yyyy, r9.yyyw
mad r3.w, r4.x, r3.w, r2.x
add r3.w, r3.w, l(-2)
sample_b r4.xzw, r4.zwzz, t19.xwyz, s8, r3.w
add r3.w, r2.w, l(-0.3)
mul_sat r3.w, r3.w, l(10)
mad r4.xzw, -r10.xxyz, l(0.7, 0, 0.7, 0.7), r4.xxzw
mad r14.xyz, r3.wwww, r4.xzwx, r14.xyzx
resinfo r4.xz, l(4), t19.xzyw
utof r10, r4.xxzz
mad r15, r9.yyww, r10.yyww, l(-0.5, -0.5, -0.5, -0.5)
frc r16, r15.ywyw
add r4.xzw, -r16.xxxx, l(1, 0, 2, 3)
mul r17.xyz, r4.xzwx, r4.xzwx
mul r18.xy, r4.xzxx, r17.xyxx
mul r7.yz, r18.xxyx, l(0, 4, 4, 0)
mad r19.xy, r17.yzyy, r4.zwzz, -r7.yzyy
mad r18.w, r18.x, l(6), r19.y
mad r3.w, -r17.x, r4.x, l(6)
add r3.w, -r19.x, r3.w
add r19.z, -r18.w, r3.w
add r4.xzw, -r16.yyyy, l(1, 0, 2, 3)
mul r17.xyz, r4.xzwx, r4.xzwx
mul r20.xy, r4.xzxx, r17.xyxx
mul r7.yz, r20.xxyx, l(0, 4, 4, 0)
mad r21.xz, r17.zzyz, r4.wwzw, -r7.zzyz
mad r20.w, r20.x, l(6), r21.x
mad r3.w, -r17.x, r4.x, l(6)
add r3.w, -r21.z, r3.w
add r21.w, -r20.w, r3.w
add r15, r15, -r16.zzww
add r15, r15, l(-0.5, 1.5, -0.5, 1.5)
add r16.xy, r18.xwxx, r19.xzxx
add r16.zw, r20.xxxw, r21.zzzw
mov r21.xy, r19.xzxx
div r17, r21, r16
add r15, r15, r17
div r10, r15, r10
sample_l r4.xzw, r10.xzxx, t19.xwyz, s8, l(4)
sample_l r15.xyz, r10.yzyy, t19, s8, l(4)
sample_l r17.xyz, r10.xwxx, t19, s8, l(4)
sample_l r10.xyz, r10.ywyy, t19, s8, l(4)
add r7.yz, r16.yywy, r16.xxzx
div r7.yz, r16.xxzx, r7.yyzy
add r16.xyz, -r10.xyzx, r17.xyzx
mad r10.xyz, r7.yyyy, r16.xyzx, r10.xyzx
add r4.xzw, r4.xxzw, -r15.xxyz
mad r4.xzw, r7.yyyy, r4.xxzw, r15.xxyz
add r4.xzw, -r10.xxyz, r4.xxzw
mad r4.xzw, r7.zzzz, r4.xxzw, r10.xxyz
else 
mov r1.w, -r1.x
sample_l r4.xzw, r1.wyzw, t13.xwyz, s5, l(1)
endif 
mul r10.xyz, r2.yyyy, r14.xyzx
mul r5.xyw, r0.wwww, r5.xyxw
mul r1.w, r0.x, l(-0.2)
mad r1.w, r3.z, l(0.5), r1.w
add r1.w, r1.w, l(0.2)
mad r2.y, r0.x, l(0.5), l(0.5)
max r0.x, r0.x, r1.w
add r2.w, r2.w, l(-0.8)
mad r2.w, r2.w, l(-5), l(1)
min r2.w, r2.w, l(1)
mul r2.w, r0.x, r2.w
movc r0.x, r3.y, r0.x, r2.w
mad r3.yzw, r5.xxyw, r2.yyyy, -r10.xxyz
mad r3.yzw, r1.wwww, r3.yyzw, r10.xxyz
mul r1.w, r0.x, r7.x
mov_sat r4.y, r4.y
mad r5.xyw, -v2.xyxz, r0.yyyy, -cb2[0].xyxz
dp3 r2.y, r5.xywx, r5.xywx
rsq r2.y, r2.y
mul r5.xyw, r2.yyyy, r5.xyxw
dp3_sat r2.y, r5.xywx, -r13.xyzx
log r2.y, r2.y
mul r2.y, r2.y, l(40)
exp r2.y, r2.y
dp3 r2.w, -r13.xyzx, -cb2[0].xyzx
mov_sat r5.x, r2.w
log r5.x, r5.x
mul r5.x, r5.x, cb2[17].w
exp r5.x, r5.x
mul_sat r2.w, r2.w, l(10)
mul r2.w, r2.w, r5.x
mul r2.y, r2.w, r2.y
mul r2.y, r7.w, r2.y
mul r2.y, r2.y, l(80)
mul r5.xyw, r2.yyyy, cb2[15].xyxz
mul r5.xyw, r4.yyyy, r5.xyxw
dp3 r2.y, r1.xyzx, -r13.xyzx
add r2.y, r2.y, r2.y
mad r7.yzw, r13.xxyz, r2.yyyy, r1.xxyz
dp3 r2.y, r7.yzwy, r7.yzwy
rsq r2.y, r2.y
mul r10.xyz, r2.yyyy, r7.yzwy
dp3 r2.y, r10.xyzx, cb2[25].xyzx
add r2.w, -cb2[25].w, l(1)
mul r2.y, r2.y, r2.y
add r8.w, -r2.w, l(1)
mad r2.y, r2.y, r8.w, r2.w
mul r4.y, r4.y, l(10)
add r10.xyz, r11.xyzx, -cb7[1].xyzx
dp3 r10.x, r10.xyzx, r10.xyzx
mad_sat r10.x, r10.x, cb7[2].w, -cb7[2].z
add r10.yzw, r11.xxyz, -cb7[0].xxyz
dp3 r10.y, r10.yzwy, r10.yzwy
mad_sat r10.y, r10.y, cb7[2].y, -cb7[2].x
add_sat r10.y, r10.y, cb7[0].w
mov r14.w, l(1)
mov r15.xyz, l(0, 0, 0, 0)
mov r10.zw, l(0, 0, 0.001, 0.001)
mov r11.w, l(0)
loop 
add r16.xy, -r11.xzxx, cb7[r11.w + 3].xyxx
f16tof32 r17.x, cb7[r11.w + 3].z
ushr r12.w, cb7[r11.w + 3].z, l(16)
f16tof32 r17.y, r12.w
lt r16.xy, |r16.xyxx|, r17.xyxx
and r12.w, r16.y, r16.x
if_nz r12.w
ubfe r12.w, l(3), l(27), cb7[r11.w + 3].w
switch r12.w
case l(1)
call label[0]
break 
case l(2)
call label[1]
break 
case l(3)
call label[2]
break 
default 
call label[3]
break 
endswitch 
iadd r11.w, r11.w, l(1)
else 
and r11.w, l(1023), cb7[r11.w + 3].w
mov r16.xyz, r15.xyzx
mov r17.xy, r10.zwzz
endif 
if_z r11.w
mov r15.xyz, r16.xyzx
mov r10.zw, r17.xxxy
break 
endif 
mov r15.xyz, r16.xyzx
mov r10.zw, r17.xxxy
endloop 
mul r7.yzw, r2.yyyy, r15.xxyz
dp3 r0.y, r7.yzwy, r4.yyyy
dp3 r10.x, r7.yzwy, l(1, 1, 1, 0)
dp3 r10.y, r4.yyyy, l(1, 1, 1, 0)
mad r10.x, r10.x, r10.y, l(0.0001)
div r0.y, r0.y, r10.x
dp3 r10.x, r4.yyyy, l(0.2125, 0.7154, 0.0721, 0)
div_sat r10.y, r10.z, r10.w
mad r0.y, r0.y, r10.x, -r4.y
mad r0.y, r10.y, r0.y, r4.y
mul r7.yzw, r0.yyyy, r7.yyzw
mad r5.xyw, r5.xyxw, r2.yyyy, r7.yzyw
mad r3.yzw, r5.xxyw, r0.wwww, r3.yyzw
mad r0.x, -r7.x, r0.x, l(1)
mad r0.x, r0.z, r0.x, r1.w
mul r3.yzw, r1.wwww, r3.yyzw
mad r5.xyw, r4.xzxw, r0.wwww, -r3.yzyw
mad r3.yzw, r0.zzzz, r5.xxyw, r3.yyzw
max r0.y, r0.x, l(897988541)
div r3.yzw, r3.yyzw, r0.yyyy
add r0.y, -r0.x, l(1)
mad r0.y, r9.z, r0.y, r0.x
mul r5.xyw, r0.xxxx, r3.yzyw
mad r3.yzw, -r3.yyzw, r0.xxxx, r12.xxyz
mad r3.yzw, r9.zzzz, r3.yyzw, r5.xxyw
max r0.x, r0.y, l(897988541)
div r3.yzw, r3.yyzw, r0.xxxx
max r5.xyw, r8.xyxz, l(0.4, 0.4, 0, 0.4)
max r0.x, r5.w, r5.y
max r0.x, r0.x, r5.x
div r5.xyw, r5.xyxw, r0.xxxx
movc r0.x, r9.x, l(1), r3.x
add r7.xyz, -r5.xywx, l(1, 1, 1, 0)
mad r5.xyw, r0.xxxx, r7.xyxz, r5.xyxw
mul r3.yzw, r3.yyzw, r5.xxyw
add r0.x, -r0.y, l(1)
mad r7.w, r5.z, r0.x, r0.y
mul r0.xyz, r0.yyyy, r3.yzwy
mad r3.yzw, r4.xxzw, r0.wwww, -r0.xxyz
mad r0.xyz, r5.zzzz, r3.yzwy, r0.xyzx
max r0.w, r7.w, l(897988541)
div r7.xyz, r0.xyzx, r0.wwww
mov r6.w, l(0.8)
movc r0, r2.zzzz, r6, r7
lt r1.w, l(0), r3.x
lt r2.y, l(1), cb4[3].x
or r1.w, r1.w, r2.y
if_nz r1.w
add r1.w, r2.x, cb4[4].w
sample_l r4, r9.ywyy, t19, s8, r1.w
mul r1.w, r3.x, r4.w
mad r2.x, -r3.x, r4.w, l(1)
mad r5.w, r0.w, r2.x, r1.w
mul r3.yzw, r1.wwww, r4.xxyz
mad r6.xyz, -r4.xyzx, r1.wwww, r0.xyzx
mad r3.yzw, r0.wwww, r6.xxyz, r3.yyzw
max r1.w, r5.w, l(897988541)
div r5.xyz, r3.yzwy, r1.wwww
add r3.yzw, -r4.xxyz, r5.xxyz
mad r4.xyz, r5.wwww, r3.yzwy, r4.xyzx
mov r4.w, l(1)
movc r4, r2.yyyy, r4, r5
lt r1.w, cb4[4].w, l(0)
add r2.x, -r3.x, l(1)
mul r5.x, r2.x, l(3)
mul r5.y, r3.x, l(3)
mov r5.zw, l(0, 0, 0, 1)
movc r0, r1.wwww, r5, r4
endif 
and r1.w, cb4[2].x, l(1048576)
if_nz r1.w
dp3 r1.w, v1.xyzx, r1.xyzx
lt r1.w, l(0), r1.w
movc r2.xyz, r1.wwww, -v1.xyzx, v1.xyzx
dp3 r1.w, r2.xyzx, -r1.xyzx
add_sat r1.w, -r1.w, l(1)
mul r3.x, r1.w, r1.w
mul r3.x, r3.x, r3.x
mad r1.w, r1.w, r3.x, l(0.1)
min r1.w, r1.w, l(1)
dp3 r3.x, r1.xyzx, r2.xyzx
add r3.x, r3.x, r3.x
mad r2.xyz, r2.xyzx, -r3.xxxx, r1.xyzx
dp3 r3.x, r2.xyzx, r2.xyzx
rsq r3.x, r3.x
mul r2.xyz, r2.xyzx, r3.xxxx
dp3 r3.x, r2.xyzx, r1.xyzx
mad_sat r3.x, r3.x, l(2), l(1)
mul r3.x, r3.x, cb3[7].w
mad r3.xyz, v2.xyzx, r3.xxxx, r2.xyzx
dp3 r3.w, r3.xyzx, r3.xyzx
rsq r3.w, r3.w
mul r3.xyz, r3.wwww, r3.xyzx
and r4.x, cb4[2].x, l(8388608)
lod r4.y, r3.xyzx, t13.x, s5
mul r4.y, r4.y, l(0.4)
mov r3.w, -r3.x
sample_l r3.xyz, r3.wyzw, t13, s5, r4.y
movc r3.xyz, r4.xxxx, l(0, 0, 0, 0), r3.xyzx
dp3 r2.x, r2.xyzx, cb2[25].xyzx
mul r2.x, r2.x, r2.x
mad r2.x, r2.x, r8.w, r2.w
mul r2.xyz, r2.xxxx, r3.xyzx
log r2.w, r1.w
mul r2.w, r2.w, cb2[29].z
exp r2.w, r2.w
min r3.x, r2.w, l(1)
add r3.x, -r3.x, l(1)
mul r2.xyz, r2.wwww, r2.xyzx
mad r0.xyz, r0.xyzx, r3.xxxx, r2.xyzx
add r2.x, -r0.w, l(1)
mad o0.w, r1.w, r2.x, r0.w
else 
mov o0.w, r0.w
endif 
max r0.xyz, r0.xyzx, l(0, 0, 0, 0)
mov_sat r2.z, v1.w
mul r0.w, r2.z, r2.z
mad r0.w, r2.z, r0.w, -r2.z
mad r2.x, cb2[26].w, r0.w, r2.z
mad r0.w, r2.z, r2.z, -r2.z
mad r2.y, cb2[26].w, r0.w, r2.z
dp3_sat r0.w, -r1.xyzx, cb2[0].xyzx
log r0.w, r0.w
mul r0.w, r0.w, cb2[11].z
exp r0.w, r0.w
mul r1.xyz, r0.wwww, cb2[2].xyzx
mad r1.xyz, r1.xyzx, cb2[11].yyyy, cb2[6].yzwy
add r1.xyz, -r0.xyzx, r1.xyzx
mad o0.xyz, r2.xyzx, r1.xyzx, r0.xyzx
ret 
label label[0]
ubfe r12.w, l(10), l(10), cb7[r11.w + 3].w
add r18.xyz, -r11.xyzx, cb7[r12.w + 323].xyzx
dp3 r13.w, r18.xyzx, r18.xyzx
sqrt r13.w, r13.w
div r19.xyz, r18.xyzx, r13.wwww
dp3 r15.w, cb7[r12.w + 324].xyzx, -r19.xyzx
add_sat r15.w, -r15.w, cb7[r12.w + 324].w
ushr r16.w, cb7[r12.w + 325].w, l(16)
f16tof32 r16.w, r16.w
eq r17.z, r15.w, l(0)
dp3 r17.w, r18.xyzx, cb7[r12.w + 324].xyzx
lt r16.w, r16.w, r17.w
or r16.w, r16.w, r17.z
if_z r16.w
ushr r18.xyz, cb7[r12.w + 325].zxyz, l(16, 16, 16, 0)
f16tof32 r16.w, cb7[r12.w + 323].w
ushr r17.z, cb7[r12.w + 323].w, l(16)
f16tof32 r17.z, r17.z
f16tof32 r20, cb7[r12.w + 325].xzyw
f16tof32 r14.xyz, r18.xyzx
add r12.w, r10.x, r20.w
add_sat r12.w, r12.w, cb7[0].w
mad_sat r13.w, -r13.w, r17.z, r16.w
mul r13.w, r13.w, r13.w
dp3 r16.w, -r13.xyzx, r19.xyzx
add r16.w, r16.w, l(-1)
mad_sat r16.w, r20.y, r16.w, l(1)
mul r13.w, r15.w, r13.w
mul r12.w, r12.w, r13.w
mov r20.y, r14.y
mul r18.xyz, r12.wwww, r20.xyzx
mul r18.xyz, r16.wwww, r18.xyzx
mul r18.xyz, r14.zzzz, r18.xyzx
mad r19.xyz, v2.xyzx, r0.yyyy, -r19.xyzx
dp3 r12.w, r19.xyzx, r19.xyzx
rsq r12.w, r12.w
mul r19.xyz, r12.wwww, r19.xyzx
dp3_sat r12.w, -r19.xyzx, -r13.xyzx
mul r12.w, r12.w, r12.w
mul r12.w, r12.w, r12.w
mul r12.w, r12.w, r12.w
mul r19.xyz, r12.wwww, r18.xyzx
mad r16.xyz, r18.xyzx, r12.wwww, r15.xyzx
dp3 r12.w, r19.xyzx, l(1, 1, 1, 0)
mad r17.xy, r14.xwxx, r12.wwww, r10.zwzz
else 
mov r16.xyz, r15.xyzx
mov r17.xy, r10.zwzz
endif 
ret 
label label[1]
ubfe r12.w, l(10), l(10), cb7[r11.w + 3].w
f16tof32 r13.w, cb7[r12.w + 326].x
ushr r14.x, cb7[r12.w + 326].x, l(16)
f16tof32 r14.x, r14.x
add r18.xyz, -r11.xyzx, cb7[r12.w + 323].xyzx
dp3 r14.y, r18.xyzx, r18.xyzx
sqrt r14.y, r14.y
div r18.xyz, r18.xyzx, r14.yyyy
dp3 r14.z, cb7[r12.w + 324].xyzx, -r18.xyzx
add_sat r15.w, -r14.z, cb7[r12.w + 324].w
mad_sat r13.w, -r14.z, r14.x, r13.w
eq r14.x, r15.w, l(0)
eq r14.z, r13.w, l(0)
and r14.x, r14.z, r14.x
if_z r14.x
ushr r19.xyz, cb7[r12.w + 326].yzwy, l(16, 16, 16, 0)
f16tof32 r14.x, cb7[r12.w + 323].w
ushr r14.z, cb7[r12.w + 323].w, l(16)
f16tof32 r14.z, r14.z
ushr r20, cb7[r12.w + 325], l(16, 16, 16, 16)
f16tof32 r21.xyz, cb7[r12.w + 326].yzwy
f16tof32 r19.xyz, r19.xyzx
f16tof32 r22, cb7[r12.w + 325].xzyw
f16tof32 r20, r20
mad_sat r12.w, -r14.y, r14.z, r14.x
mul r12.w, r12.w, r12.w
mul r14.x, r14.y, r19.z
mad_sat r14.y, r14.y, r19.x, -r21.x
mov_sat r14.x, r14.x
add r14.x, -r14.x, r14.y
max r14.x, r14.x, l(0)
mul r14.x, r14.x, r14.x
dp3 r14.y, -r13.xyzx, r18.xyzx
mad_sat r14.y, r14.y, l(0.88), l(0.12)
mul r12.w, r12.w, r15.w
mov r21.w, r19.y
dp3 r14.z, r21.ywzy, -r18.xyzx
mov r19.xz, r22.yywy
mov r19.y, r20.z
add_sat r19.xyz, -r14.zzzz, r19.xyzx
mul r13.w, r13.w, r14.x
mul r13.w, r20.w, r13.w
mad r19.xyz, r12.wwww, r19.xyzx, r13.wwww
mul r19.xyz, r10.yyyy, r19.xyzx
mov r22.y, r20.x
mul r19.xyz, r19.xyzx, r22.xyzx
mul r14.xyz, r14.yyyy, r19.xyzx
mul r14.xyz, r20.yyyy, r14.xyzx
mad r18.xyz, v2.xyzx, r0.yyyy, -r18.xyzx
dp3 r12.w, r18.xyzx, r18.xyzx
rsq r12.w, r12.w
mul r18.xyz, r12.wwww, r18.xyzx
dp3_sat r12.w, -r18.xyzx, -r13.xyzx
mul r12.w, r12.w, r12.w
mul r12.w, r12.w, r12.w
mul r12.w, r12.w, r12.w
mul r18.xyz, r12.wwww, r14.xyzx
mad r16.xyz, r14.xyzx, r12.wwww, r15.xyzx
dp3 r12.w, r18.xyzx, l(1, 1, 1, 0)
add r17.xy, r10.zwzz, r12.wwww
else 
mov r16.xyz, r15.xyzx
mov r17.xy, r10.zwzz
endif 
ret 
label label[2]
ubfe r12.w, l(10), l(10), cb7[r11.w + 3].w
ushr r14.xy, cb7[r12.w + 324].zwzz, l(16, 16, 0, 0)
f16tof32 r18.xy, cb7[r12.w + 324].zwzz
f16tof32 r18.zw, r14.xxxy
f16tof32 r13.w, cb7[r12.w + 323].w
ushr r14.x, cb7[r12.w + 323].w, l(16)
f16tof32 r14.x, r14.x
add r19.xyz, r11.xyzx, -cb7[r12.w + 323].xyzx
dp3 r14.y, r19.xzyx, r18.xyzx
mul_sat r14.y, r18.w, r14.y
mad r19.xyz, r14.yyyy, r18.xzyx, cb7[r12.w + 323].xyzx
add r19.xyz, -r11.xyzx, r19.xyzx
dp3 r14.z, r19.xyzx, r19.xyzx
sqrt r14.z, r14.z
mad_sat r13.w, -r14.z, r14.x, r13.w
mul r13.w, r13.w, r13.w
ne r14.x, r13.w, l(0)
if_nz r14.x
ushr r14.x, cb7[r12.w + 324].y, l(16)
f16tof32 r14.x, r14.x
ne r15.w, r14.x, l(0)
if_nz r15.w
ushr r15.w, cb7[r12.w + 324].x, l(16)
f16tof32 r20.y, r15.w
f16tof32 r20.xz, cb7[r12.w + 324].xxyx
ushr r21, cb7[r12.w + 325].zwxy, l(16, 16, 16, 16)
f16tof32 r22, cb7[r12.w + 325].zxwy
f16tof32 r21, r21
div r19.xyz, r19.xyzx, r14.zzzz
mov r23.xz, r22.yywy
mov r23.y, r21.z
dp3 r14.z, r23.xyzx, -r19.xyzx
add_sat r14.z, -r14.z, r21.w
dp3 r15.w, -r13.xyzx, r19.xyzx
add r15.w, r15.w, l(-1)
mad_sat r15.w, r21.y, r15.w, l(1)
mul r13.w, r13.w, r14.z
mov r22.y, r21.x
mad r19.xyz, r22.xyzx, r14.yyyy, r20.xyzx
mul r19.xyz, r13.wwww, r19.xyzx
add r20.xyz, -r11.xyzx, cb7[r12.w + 323].xyzx
dp3 r12.w, r7.yzwy, r20.xyzx
dp3 r13.w, r7.ywzy, r18.xyzx
dp3 r14.y, r20.xzyx, r18.xyzx
mad r12.w, r12.w, r13.w, -r14.y
dp3 r14.y, r18.xyzx, r18.xyzx
mad r13.w, -r13.w, r13.w, r14.y
div_sat r12.w, r12.w, r13.w
mad r18.xyz, r12.wwww, r18.xzyx, r20.xyzx
dp3 r12.w, r18.xyzx, r7.yzwy
mad r20.xyz, r12.wwww, r7.yzwy, -r18.xyzx
add r12.w, -r21.y, l(1.2)
mul r12.w, r12.w, l(0.25)
dp3 r13.w, r20.xyzx, r20.xyzx
sqrt r13.w, r13.w
div_sat r12.w, r12.w, r13.w
mad r18.xyz, r20.xyzx, r12.wwww, r18.xyzx
dp3 r12.w, r18.xyzx, r18.xyzx
rsq r12.w, r12.w
mad r18.xyz, -r18.xyzx, r12.wwww, r1.xyzx
dp3 r12.w, r18.xyzx, r18.xyzx
rsq r12.w, r12.w
mul r18.xyz, r12.wwww, r18.xyzx
dp3_sat r12.w, -r18.xyzx, -r13.xyzx
mul r18.xyz, r15.wwww, r19.xyzx
mul r12.w, r12.w, r12.w
mul r12.w, r12.w, r12.w
mul r12.w, r12.w, r12.w
mul r18.xyz, r12.wwww, r18.xyzx
mul r19.xyz, r14.xxxx, r18.xyzx
mad r16.xyz, r18.xyzx, r14.xxxx, r15.xyzx
dp3 r12.w, r19.xyzx, l(1, 1, 1, 0)
add r17.xy, r10.zwzz, r12.wwww
else 
mov r16.xyz, r15.xyzx
mov r17.xy, r10.zwzz
endif 
else 
mov r16.xyz, r15.xyzx
mov r17.xy, r10.zwzz
endif 
ret 
label label[3]
mov r16.xyz, r15.xyzx
mov r17.xy, r10.zwzz
ret 
// instr=914 tex/ld=34
