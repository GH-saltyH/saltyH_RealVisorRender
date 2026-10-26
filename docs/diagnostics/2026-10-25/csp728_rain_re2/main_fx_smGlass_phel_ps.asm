// chunks: ['RDEF', 'ISGN', 'OSGN', 'SHEX', 'STAT']
// res samLinear type=3 dim=0 bind=0 count=1
// res samShadow type=3 dim=0 bind=1 count=1
// res samLinearSimple type=3 dim=0 bind=5 count=1
// res samLinearBorder0 type=3 dim=0 bind=6 count=1
// res samLinearBorder1 type=3 dim=0 bind=7 count=1
// res samLinearClamp type=3 dim=0 bind=8 count=1
// res txDiffuse type=2 dim=4 bind=0 count=1
// res txNormal type=2 dim=4 bind=1 count=1
// res txEmissive type=2 dim=4 bind=4 count=1
// res txCube type=2 dim=9 bind=13 count=1
// res txShadowArray type=2 dim=5 bind=14 count=1
// res txCloudShadow type=2 dim=4 bind=15 count=1
// res txAO type=2 dim=4 bind=17 count=1
// res txPrevFrame type=2 dim=4 bind=19 count=1
// res txNoise type=2 dim=4 bind=20 count=1
// res txBDRFMap type=2 dim=4 bind=21 count=1
// res txColorShadow type=2 dim=4 bind=22 count=1
// res cbCamera type=0 dim=0 bind=0 count=1
// res cbPerObject type=0 dim=0 bind=1 count=1
// res cbLighting type=0 dim=0 bind=2 count=1
// res cbShadowMaps type=0 dim=0 bind=3 count=1
// res cbMaterial type=0 dim=0 bind=4 count=1
// res cbGlassParams type=0 dim=0 bind=6 count=1
// res _cbExtLighting type=0 dim=0 bind=7 count=1
// res cbStaticStuff type=0 dim=0 bind=11 count=1
// res _cbColorAmbientOcclusion type=0 dim=0 bind=13 count=1
// cbuffer cbGlassParams size=112
//    +0 extMaskPass (4)
//    +4 extMaskPassColor (12)
//    +16 extIOR (4)
//    +20 extThicknessMult (4)
//    +24 extThicknessProfileFix (4)
//    +28 _blendingMode (4)
//    +32 stAmbientSpec (4)
//    +36 stAmbientEXP (4)
//    +40 extUseNormalMap (4)
//    +44 extRefraction (4)
//    +48 extRefractionRainbow (4)
//    +52 extSaturation (4)
//    +56 extRefractionNormalFactor (4)
//    +60 extRefractionBias (4)
//    +64 extEdgeRefractionBias (4)
//    +68 extEdgePosL (12)
//    +80 extEdgeThreshold (4)
//    +84 extNormalMult (4)
//    +88 extPhelMult (4)
//    +92 extPhelBaseScale (4)
//    +96 extPhelNoiseScale (4)
//    +100 extPhelSpotsScale (4)
//    +104 extPhelSpotsOffset (4)
//    +108 extPhelStripesScale (4)
// cbuffer cbStaticStuff size=704
//    +0 emMirrorDir (12) unused
//    +12 emMirrorOffset (4) unused
//    +16 emEmissiveArea0 (16)
//    +32 emEmissiveArea1 (16)
//    +48 emEmissiveArea2 (16)
//    +64 emEmissiveArea3 (16)
//    +80 emAlphaFromDiffuse (4) unused
//    +84 emMaskColorInputBlur (4)
//    +88 emMaskResultDiffuseBlur (4) unused
//    +92 emMaskResultNormalAlphaBlur (4) unused
//    +96 emGeoChannel0S (16)
//    +112 emGeoChannel0P (16)
//    +128 emGeoChannel1S (16)
//    +144 emGeoChannel1P (16)
//    +160 emGeoChannel2S (16)
//    +176 emGeoChannel2P (16)
//    +192 emGeoChannel3S (16)
//    +208 emGeoChannel3P (16)
//    +224 emMaskColor0C (16)
//    +240 emMaskColor0P (16)
//    +256 emMaskColor1C (16)
//    +272 emMaskColor1P (16)
//    +288 emMaskColor2C (16)
//    +304 emMaskColor2P (16)
//    +320 emMaskColor3C (16)
//    +336 emMaskColor3P (16)
//    +352 emMaskColor0A (4)
//    +356 emMaskColor1A (4)
//    +360 emMaskColor2A (4)
//    +364 emMaskColor3A (4)
//    +368 emPoly00 (16)
//    +384 emPoly01 (16)
//    +400 emPoly10 (16)
//    +416 emPoly11 (16)
//    +432 emPoly20 (16)
//    +448 emPoly21 (16)
//    +464 emPoly30 (16)
//    +480 emPoly31 (16)
//    +496 emPoly02 (16)
//    +512 emPoly12 (16)
//    +528 emPoly22 (16)
//    +544 emPoly32 (16)
//    +560 emDiffuseAvgColorAsMultiplier0 (16)
//    +576 emDiffuseAvgColorAsMultiplier1 (16)
//    +592 emDiffuseAvgColorAsMultiplier2 (16)
//    +608 emDiffuseAvgColorAsMultiplier3 (16)
//    +624 emDiffuseAlphaAsMultiplier0 (16)
//    +640 emDiffuseAlphaAsMultiplier1 (16)
//    +656 emDiffuseAlphaAsMultiplier2 (16)
//    +672 emDiffuseAlphaAsMultiplier3 (16)
//    +688 emMirrorUV (8)
//    +696 emMirrorUVOffset (4)
// cbuffer cbMaterial size=176
//    +0 ksAmbient (4)
//    +4 ksDiffuse (4)
//    +8 ksSpecular (4) unused
//    +12 ksSpecularEXP (4) unused
//    +16 ksEmissive (12)
//    +28 ksAlphaRef (4) unused
//    +32 extFlags (4)
//    +36 extExtraSharpLocalReflections (4) unused
//    +40 fresnelC (4)
//    +44 fresnelEXP (4) unused
//    +48 fresnelMaxLevel (4) unused
//    +52 extColoredReflection (4)
//    +56 extColoredReflectionNorm (4)
//    +60 isAdditive (4) unused
//    +64 seasonAutumn (4) unused
//    +68 seasonWinter (4) unused
//    +72 emChannelsMode (4)
//    +80 ksEmissive1 (12)
//    +92 emMirrorChannel3As4 (4)
//    +96 ksEmissive2 (12)
//    +108 emMirrorChannel2As5 (4)
//    +112 ksEmissive3 (12)
//    +124 emMirrorChannel1As6 (4)
//    +128 ksEmissive4 (12)
//    +140 emSkipDiffuseMap (4)
//    +144 ksEmissive5 (12)
//    +156 emProceduralMode_uint (4)
//    +160 ksEmissive6 (12)
// cbuffer cbCamera size=320
//    +0 ksView_base (64) unused
//    +64 ksProjection_base (64) unused
//    +128 ksMVPInverse (64) unused
//    +192 ksCameraPosition (12)
//    +204 extCameraTangent (4)
//    +208 ksNearPlane (4) unused
//    +212 ksFarPlane (4) unused
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
//    +72 extMotionStencil (4) unused
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
//    +152 extSceneRain (4) unused
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
//    +204 extPhotoElBoost_mirageMult (4)
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
//    +284 extLambertGamma_inner (4) unused
//    +288 extEmissiveMults (16)
//    +304 extIBLAmbient (4) unused
//    +308 extIBLAmbientBaseThreshold (4) unused
//    +312 extIBLAmbientBrightness (4) unused
//    +316 extIBLAmbientSaturation (4) unused
//    +320 extVAOMult (4) unused
//    +324 extVAOAdd (4) unused
//    +328 extVAOExp (4) unused
//    +332 extCloudShadowOpacity (4)
//    +336 extCloudShadowMatrix (64)
//    +400 p_extCPLDir (12)
//    +412 p_extCPLFactor (4)
//    +416 extDirLook (12) unused
//    +428 extFogAtmosphere (4)
//    +432 extDirUp (12)
//    +444 extPad_screenMode_frameNum_A2COffset (4) unused
//    +448 extSceneOffset (12) unused
//    +460 extTiltBias_extGrassFx12RangeInv (4) unused
//    +464 extWindWater (8) unused
//    +472 extFresnelGamma (4) unused
//    +476 _extPad (4) unused
//    +480 ksAmbientColor_sky1 (12)
//    +492 ksAmbientColor_sky1_mix (4)
//    +496 extExtraAoAmbientColor (12)
//    +508 extExtraAoAmbientColor_exp (4)
//    +512 extWindVelPrev (8) unused
//    +520 _extPad_actuallyEmpty (8) unused
// cbuffer cbShadowMaps size=240
//    +0 ksShadowMatrix0 (64) unused
//    +64 bias (12) unused
//    +76 pixelSize (4)
//    +80 shadowR1 (4)
//    +84 shadowPos (12)
//    +96 shadowR2 (4)
//    +100 shadowsTransitionWeight (12)
//    +112 shadowsMatrixModifier1A (12)
//    +124 reflectionsTweak (4)
//    +128 shadowsMatrixModifier1M (12)
//    +140 shadowReflectionOcclusion (4) unused
//    +144 shadowsMatrixModifier2A (12)
//    +156 extShadowsOpacityMult (4)
//    +160 shadowsMatrixModifier2M (12)
//    +172 realTextureSize (4)
//    +176 shadowsMatrixModifier3A (12)
//    +188 realTextureSizeSqr2 (4) unused
//    +192 shadowsMatrixModifier3M (12)
//    +204 sceneShadowOpacity (4)
//    +208 shadowsBias (16)
//    +224 shadowsDistanceSqrInv (16)
// cbuffer _cbColorAmbientOcclusion size=80
//    +0 extCaoBias (4)
//    +4 _extCaoPad (12) unused
//    +16 extCaoUV (64)
// cbuffer _cbExtLighting size=15408
//    +0 gNoLightAt (32)
//    +32 gNoLightEdgeA (8)
//    +40 gNoLightEdgeB (8)
//    +48 gLightBVHNodeData (5120)
//    +5168 gLightsData (10240)
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask7; TEXCOORD1 r2 sv0 mask7; TEXCOORD2 r3 sv0 mask3; TEXCOORD8 r3 sv0 mask4; TEXCOORD20 r4 sv0 mask7; TEXCOORD21 r5 sv0 mask7; TEXCOORD22 r6 sv0 maskf; TEXCOORD3 r7 sv0 maskf; TEXCOORD6 r8 sv0 mask7; TEXCOORD7 r9 sv0 mask7; COLOR0 r10 sv0 mask1
// OSGN | SV_Target0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_immediateConstantBuffer { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
dcl_constantbuffer cb6[7]
dcl_constantbuffer cb11[44]
dcl_constantbuffer cb4[11]
dcl_constantbuffer cb0[20]
dcl_constantbuffer cb1[5]
dcl_constantbuffer cb2[32]
dcl_constantbuffer cb3[15]
dcl_constantbuffer cb13[4]
dcl_constantbuffer cb7[963] dynamicIndexed
dcl_sampler s0
dcl_sampler s1 comparison
dcl_sampler s5
dcl_sampler s6
dcl_sampler s7
dcl_sampler s8
dcl_resource_texture2d (float) t0
dcl_resource_texture2d (float) t1
dcl_resource_texture2d (float) t4
dcl_resource_texturecube (float) t13
dcl_resource_texture2darray (float) t14
dcl_resource_texture2d (float) t15
dcl_resource_texture2d (float) t17
dcl_resource_texture2d (float) t19
dcl_resource_texture2d (float) t20
dcl_resource_texture2d (float) t21
dcl_resource_texture2d (float) t22
dcl_input_ps_siv v0.xy sv1
dcl_input_ps linear v1.xyz
dcl_input_ps linear v2.xyz
dcl_input_ps linear v3.xy
dcl_input_ps linear v3.z
dcl_input_ps linear v4.xyz
dcl_input_ps linear v5.xyz
dcl_input_ps linear v6
dcl_input_ps linear v7.xyz
dcl_input_ps linear v8.xyz
dcl_input_ps linear v9.xyz
dcl_input_ps linear centroid v10.x
dcl_output o0
dcl_temps 28
dcl_indexableTemp x0[4], 4
dp3 r0.x, v2.xyzx, v2.xyzx
rsq r0.y, r0.x
mul r1.xyz, r0.yyyy, v2.yzxy
dp3 r0.z, v1.xyzx, v1.xyzx
rsq r0.z, r0.z
mul r2.xyz, r0.zzzz, v1.xyzx
eq r3.xyz, cb2[10].zzzz, l(3, 4, 5, 0)
movc r0.z, r3.x, l(1), v10.x
mul r3.xw, v0.xxxy, cb0[14].zzzw
sample_l r4, r3.xwxx, t17, s0, l(0)
add r0.w, -r4.x, l(1)
min r1.w, r0.w, r0.z
mad_sat r1.w, r1.w, l(3), l(-1)
mov r5.xyz, v2.xyzx
mov r5.w, l(1)
dp4 r6.x, r5, cb2[21]
dp4 r6.y, r5, cb2[22]
sample_l r2.w, r6.xyxx, t15.yzwx, s8, l(0)
mad_sat r2.w, -r2.w, cb2[20].w, l(1)
dp3 r4.x, r2.xyzx, -cb2[0].xyzx
mul r4.x, r4.x, l(50)
max r4.x, r4.x, l(0)
mad r5.xyz, v7.xyzx, cb3[8].xyzx, cb3[7].xyzx
mad r6.xyz, v7.xyzx, cb3[10].xyzx, cb3[9].xyzx
mad r7.xyz, v7.xyzx, cb3[12].xyzx, cb3[11].xyzx
lt r8.xy, |v7.xyxx|, l(1, 1, 0, 0)
and r5.w, r8.y, r8.x
lt r8.xy, |r5.xyxx|, l(1, 1, 0, 0)
and r6.w, r8.y, r8.x
lt r8.xy, |r6.xyxx|, l(1, 1, 0, 0)
and r7.w, r8.y, r8.x
lt r8.xy, |r7.xyxx|, l(1, 1, 0, 0)
and r8.x, r8.y, r8.x
movc r8.x, r8.x, l(3), l(-1)
movc r7.w, r7.w, l(2), r8.x
movc r6.w, r6.w, l(1), r7.w
movc r8.z, r5.w, l(0), r6.w
eq r5.w, r8.z, l(-1)
if_nz r5.w
min r5.w, r1.w, r4.x
mul r5.w, r2.w, r5.w
else 
dp3 r6.w, r2.xyzx, cb2[0].xyzx
add r6.w, -|r6.w|, l(1)
mul r6.w, r6.w, r6.w
max r6.w, r6.w, l(0.1)
mov x0[0].xyz, v7.xyzx
mov x0[1].xyz, r5.xyzx
mov x0[2].xyz, r6.xyzx
mov x0[3].xyz, r7.xyzx
ftou r5.x, r8.z
mov r6.xyz, x0[r5.x].xyzx
ftoi r5.y, r8.z
dp4 r5.y, cb3[13], icb[r5.y]
mad r5.y, -r6.w, r5.y, r6.z
mad r7.xy, r6.xyxx, l(0.5, -0.5, 0, 0), l(0.5, 0.5, 0, 0)
mad r7.xy, r7.xyxx, cb3[10].wwww, l(0.5, 0.5, 0, 0)
round_ni r7.zw, r7.xxxy
add r7.xy, -r7.zwzz, r7.xyxx
add r7.zw, r7.zzzw, l(0, 0, -0.5, -0.5)
mul r9.xy, r7.zwzz, cb3[4].wwww
mul_sat r5.z, r5.y, l(40)
add r6.z, -r5.y, l(1)
mul_sat r6.z, r6.z, l(40)
mul r5.z, r5.z, r6.z
mul r5.z, r5.z, cb3[9].w
mad r9.zw, -r7.yyyx, l(0, 0, 3, 3), l(0, 0, 4, 4)
mad r10.xy, r7.xyxx, l(3, 3, 0, 0), l(1, 1, 0, 0)
mad r10.zw, -r7.xxxy, l(0, 0, 2, 2), l(0, 0, 3, 3)
div r10.zw, r10.zzzw, r9.wwwz
add r11.xy, r7.xyxx, l(3, 3, 0, 0)
div r7.xy, r7.xyxx, r10.xyxx
add r12.xw, r10.zzzw, l(-2, 0, 0, -2)
mul r12.yz, r11.yyxy, l(0, 0.142857, 0.142857, 0)
add r11.xy, r7.xyxx, l(2, 2, 0, 0)
mul r6.z, r9.z, r9.w
mul r13, r12.xwzw, cb3[4].wwww
mad r8.xy, r7.zwzz, cb3[4].wwww, r13.xyxx
sample_c_lz r7.x, r8.xyzx, t14.xxxx, s1, r5.y
mul r8.xy, r9.zwzz, l(7, 7, 0, 0)
mad r13.xy, r7.zwzz, cb3[4].wwww, r13.zwzz
mov r13.z, r8.z
sample_c_lz r7.y, r13.xyzx, t14.xxxx, s1, r5.y
mul r7.y, r7.y, r8.x
mad r6.z, r6.z, r7.x, r7.y
mul r7.xy, r9.zwzz, r10.xyxx
mov r11.zw, r12.wwwy
mul r14, r11.xzxw, cb3[4].wwww
mad r13.xy, r7.zwzz, cb3[4].wwww, r14.xyxx
sample_c_lz r8.x, r13.xyzx, t14.xxxx, s1, r5.y
mad r6.z, r7.x, r8.x, r6.z
mul r15, r12.xyzy, cb3[4].wwww
mad r13.xy, r7.zwzz, cb3[4].wwww, r15.xyxx
sample_c_lz r7.x, r13.xyzx, t14.xxxx, s1, r5.y
mad r6.z, r8.y, r7.x, r6.z
mad r13.xy, r7.zwzz, cb3[4].wwww, r15.zwzz
sample_c_lz r7.x, r13.xyzx, t14.xxxx, s1, r5.y
mad r6.z, r7.x, l(49), r6.z
mul r8.xy, r10.xyxx, l(7, 7, 0, 0)
mad r13.xy, r7.zwzz, cb3[4].wwww, r14.zwzz
sample_c_lz r7.x, r13.xyzx, t14.xxxx, s1, r5.y
mad r6.z, r8.x, r7.x, r6.z
mov r12.y, r11.y
mul r12, r12.xyzy, cb3[4].wwww
mad r13.xy, r7.zwzz, cb3[4].wwww, r12.xyxx
sample_c_lz r7.x, r13.xyzx, t14.xxxx, s1, r5.y
mad r6.z, r7.y, r7.x, r6.z
mad r13.xy, r7.zwzz, cb3[4].wwww, r12.zwzz
sample_c_lz r7.x, r13.xyzx, t14.xxxx, s1, r5.y
mad r6.z, r8.y, r7.x, r6.z
mul r7.x, r10.y, r10.x
mad r13.xy, r11.xyxx, cb3[4].wwww, r9.xyxx
sample_c_lz r5.y, r13.xyzx, t14.xxxx, s1, r5.y
mad r5.y, r7.x, r5.y, r6.z
mad r5.y, r5.y, l(0.00694444), l(-1)
mad r5.y, r5.z, r5.y, l(1)
max r5.z, |r6.y|, |r6.x|
dp4 r6.x, cb3[14], icb[r5.x]
mad_sat r6.x, r0.x, r6.x, l(-1)
mad_sat r5.z, r5.z, l(5), l(-4)
ne r6.y, r8.z, l(3)
ne r6.z, l(0, 0, 0, 0), r6.x
and r6.y, r6.z, r6.y
if_nz r6.y
add r7.z, r8.z, l(1)
ftou r6.y, r7.z
mov r8.xyz, x0[r6.y].xyzx
add r6.y, -r5.z, l(1)
dp3 r5.x, cb3[6].yzwy, icb[r5.x].xyzx
max r6.z, |r8.y|, |r8.x|
add r6.z, -r6.z, l(1)
max r6.z, r6.z, l(0)
mul r6.z, r5.z, r6.z
mul r7.w, r6.z, r6.x
mad r5.x, r6.y, r5.x, r6.z
div r5.x, r7.w, r5.x
ne r6.y, l(0, 0, 0, 0), r5.x
if_nz r6.y
ftoi r6.y, r7.z
dp4 r6.y, cb3[13], icb[r6.y]
mad r6.y, -r6.w, r6.y, r8.z
mad r6.zw, r8.xxxy, l(0, 0, 0.5, -0.5), l(0, 0, 0.5, 0.5)
mad r6.zw, r6.zzzw, cb3[10].wwww, l(0, 0, 0.5, 0.5)
round_ni r8.xy, r6.zwzz
add r6.zw, r6.zzzw, -r8.xxxy
add r8.xy, r8.xyxx, l(-0.5, -0.5, 0, 0)
mul r8.zw, r8.xxxy, cb3[4].wwww
mul_sat r7.w, r6.y, l(40)
add r9.x, -r6.y, l(1)
mul_sat r9.x, r9.x, l(40)
mul r7.w, r7.w, r9.x
mul r7.w, r7.w, cb3[9].w
mad r9.xy, -r6.wzww, l(3, 3, 0, 0), l(4, 4, 0, 0)
mad r9.zw, r6.zzzw, l(0, 0, 3, 3), l(0, 0, 1, 1)
mad r10.xy, -r6.zwzz, l(2, 2, 0, 0), l(3, 3, 0, 0)
div r10.xy, r10.xyxx, r9.yxyy
add r10.zw, r6.zzzw, l(0, 0, 3, 3)
div r6.zw, r6.zzzw, r9.zzzw
add r11.xw, r10.xxxy, l(-2, 0, 0, -2)
mul r11.yz, r10.wwzw, l(0, 0.142857, 0.142857, 0)
add r10.xy, r6.zwzz, l(2, 2, 0, 0)
mul r6.z, r9.x, r9.y
mul r12, r11.xwzw, cb3[4].wwww
mad r7.xy, r8.xyxx, cb3[4].wwww, r12.xyxx
sample_c_lz r6.w, r7.xyzx, t14.xxxx, s1, r6.y
mul r12.xy, r9.xyxx, l(7, 7, 0, 0)
mad r7.xy, r8.xyxx, cb3[4].wwww, r12.zwzz
sample_c_lz r12.z, r7.xyzx, t14.xxxx, s1, r6.y
mul r12.x, r12.z, r12.x
mad r6.z, r6.z, r6.w, r12.x
mul r9.xy, r9.xyxx, r9.zwzz
mov r10.zw, r11.wwwy
mul r13, r10.xzxw, cb3[4].wwww
mad r7.xy, r8.xyxx, cb3[4].wwww, r13.xyxx
sample_c_lz r6.w, r7.xyzx, t14.xxxx, s1, r6.y
mad r6.z, r9.x, r6.w, r6.z
mul r14, r11.xyzy, cb3[4].wwww
mad r7.xy, r8.xyxx, cb3[4].wwww, r14.xyxx
sample_c_lz r6.w, r7.xyzx, t14.xxxx, s1, r6.y
mad r6.z, r12.y, r6.w, r6.z
mad r7.xy, r8.xyxx, cb3[4].wwww, r14.zwzz
sample_c_lz r6.w, r7.xyzx, t14.xxxx, s1, r6.y
mad r6.z, r6.w, l(49), r6.z
mul r10.zw, r9.zzzw, l(0, 0, 7, 7)
mad r7.xy, r8.xyxx, cb3[4].wwww, r13.zwzz
sample_c_lz r6.w, r7.xyzx, t14.xxxx, s1, r6.y
mad r6.z, r10.z, r6.w, r6.z
mov r11.y, r10.y
mul r11, r11.xyzy, cb3[4].wwww
mad r7.xy, r8.xyxx, cb3[4].wwww, r11.xyxx
sample_c_lz r6.w, r7.xyzx, t14.xxxx, s1, r6.y
mad r6.z, r9.y, r6.w, r6.z
mad r7.xy, r8.xyxx, cb3[4].wwww, r11.zwzz
sample_c_lz r6.w, r7.xyzx, t14.xxxx, s1, r6.y
mad r6.z, r10.w, r6.w, r6.z
mul r6.w, r9.w, r9.z
mad r7.xy, r10.xyxx, cb3[4].wwww, r8.zwzz
sample_c_lz r6.y, r7.xyzx, t14.xxxx, s1, r6.y
mad r6.y, r6.w, r6.y, r6.z
mad r6.y, r6.y, l(0.00694444), l(-1)
mad r6.y, r7.w, r6.y, l(1)
add r6.y, -r5.y, r6.y
mad r5.y, r5.x, r6.y, r5.y
endif 
else 
mad r5.x, r6.x, r5.z, l(-0.9)
mul r5.x, r5.x, l(10)
max r5.x, r5.x, l(0)
add r1.w, r1.w, -r5.y
mad r5.y, r5.x, r1.w, r5.y
endif 
min r1.w, r4.x, r5.y
mul r5.w, r1.w, r2.w
endif 
add r5.xyz, -cb0[12].xyzx, cb0[19].xyzx
lt r1.w, v0.x, cb0[19].w
and r2.w, r1.w, l(1)
mad r5.xyz, r5.xyzx, r2.wwww, v2.xyzx
add r6.xyz, r5.xyzx, -cb3[5].yzwy
dp3 r2.w, r6.xyzx, r6.xyzx
mad_sat r2.w, r2.w, cb3[5].x, cb3[6].x
add r4.x, r2.w, l(-1)
mad r6.xyz, cb3[12].wwww, r4.xxxx, l(1, 1, 1, 0)
sample r7, v3.xyxx, t0, s0
ne r8.xy, l(0, 0, 0, 0), cb6[2].zwzz
if_nz r8.x
dp3 r4.x, v8.xyzx, v8.xyzx
rsq r4.x, r4.x
mul r8.xzw, r4.xxxx, v8.xxyz
dp3 r4.x, v9.xyzx, v9.xyzx
rsq r4.x, r4.x
mul r9.xyz, r4.xxxx, v9.xyzx
mul r10.xy, v3.xyxx, cb6[5].yyyy
sample r10, r10.xyxx, t1, s0
mad r10.xyz, r10.xyzx, l(2, 2, 2, 0), l(-1, -1, -1, 0)
mul r11.xyz, r2.xyzx, r10.zzzz
mad r8.xzw, r8.xxzw, r10.xxxx, r11.xxyz
mad r8.xzw, r9.xxyz, r10.yyyy, r8.xxzw
dp3 r4.x, r8.xzwx, r8.xzwx
rsq r4.x, r4.x
mul r8.xzw, r4.xxxx, r8.xxzw
eq r4.x, cb6[2].z, l(2)
movc r4.x, r4.x, r10.w, r7.w
else 
mov r8.xzw, r2.xxyz
mov r4.x, r7.w
endif 
dp3 r6.w, r7.xyzx, l(0.2125, 0.7154, 0.0721, 0)
add r9.xyz, -r6.wwww, r7.xyzx
mad_sat r9.xyz, cb6[3].yyyy, r9.xyzx, r6.wwww
mul r10.xyz, r9.xyzx, |cb4[0].yyyy|
and r11, cb4[2].xxxx, l(8192, 4, 3, 16)
if_nz r11.x
movc r12.xyz, r1.wwww, cb0[19].xyzx, cb0[12].xyzx
add r12.xyz, r12.xyzx, v2.xyzx
mad r13.xy, v7.xyxx, l(0.5, -0.5, 0, 0), l(0.5, 0.5, 0, 0)
sample_l r13.xyz, r13.xyxx, t22, s7, l(0)
mul r13.xyz, r5.wwww, r13.xyzx
mov r12.w, l(1)
dp4 r14.x, r12, cb13[1]
dp4 r14.y, r12, cb13[2]
dp4 r1.w, r12, cb13[3]
sample_l r6.w, r14.xyxx, t22, s6, l(2)
add_sat r1.w, r1.w, -r6.w
mad r1.w, r1.w, l(8), cb13[0].x
mov_sat r6.w, -r8.z
mad r1.w, r6.w, r1.w, r1.w
sample_l r12.xyz, r14.xyxx, t22, s7, r1.w
mul r6.xyz, r6.zzzz, r12.xyzx
else 
mov r13.xyz, r5.wwww
endif 
dp3 r1.w, r1.zxyz, r8.xzwx
add r5.w, r1.w, r1.w
mad r12.xyz, r8.xzwx, -r5.wwww, r1.zxyz
dp3 r5.w, r12.xyzx, r12.xyzx
rsq r5.w, r5.w
mul r14.xyz, r5.wwww, r12.xyzx
dp3 r5.w, r14.yzxy, r1.xyzx
mad_sat r5.w, r5.w, l(2), l(1)
mul r5.w, r5.w, cb3[7].w
mad r15.xyz, v2.xyzx, r5.wwww, r14.xyzx
dp3 r5.w, r15.xyzx, r15.xyzx
rsq r5.w, r5.w
mul r15.xyz, r5.wwww, r15.xyzx
mad r16.xyz, -v2.xyzx, r0.yyyy, -cb2[0].xyzx
dp3 r5.w, r16.xyzx, r16.xyzx
rsq r5.w, r5.w
mul r16.xyz, r5.wwww, r16.xyzx
dp3 r5.w, r8.zwxz, -r1.xyzx
add r6.w, |r5.w|, l(507307272)
min r17.x, r6.w, l(1)
dp3_sat r6.w, -cb2[0].xyzx, r8.xzwx
dp3_sat r9.w, -cb2[0].xyzx, r16.xyzx
dp3_sat r10.w, r16.yzxy, -r1.xyzx
dp3_sat r11.x, r16.xyzx, r8.xzwx
mov_sat r6.xyz, r6.xyzx
mad r16.xyz, cb4[2].zzzz, -r10.xyzx, r10.xyzx
mul r18.xyz, r6.wwww, cb2[2].xyzx
mul r18.xyz, r13.xyzx, r18.xyzx
mul r18.xyz, r18.xyzx, l(0.4, 0.4, 0.4, 0)
mul r19.xyz, r6.wwww, cb2[15].xyzx
mul r13.xyz, r13.xyzx, r19.xyzx
mul r13.xyz, r13.xyzx, l(0.4, 0.4, 0.4, 0)
mul r9.w, r9.w, r9.w
mad r9.w, r9.w, l(0.00012), l(-0.5)
add r13.w, -r17.x, l(1)
mul r14.w, r13.w, r13.w
mul r14.w, r14.w, r14.w
mul r13.w, r13.w, r14.w
mad r13.w, r9.w, r13.w, l(1)
add r14.w, -r6.w, l(1)
mul r16.w, r14.w, r14.w
mul r16.w, r16.w, r16.w
mul r14.w, r14.w, r16.w
mad r9.w, r9.w, r14.w, l(1)
mul r9.w, r9.w, r13.w
mul r18.xyz, r18.xyzx, r9.wwww
mad_sat r9.w, r8.z, l(0.25), l(0.75)
dp3_sat r13.w, r8.xzwx, cb2[13].xyzx
mul r14.w, r0.x, cb2[13].w
mad r16.w, r0.x, cb2[13].w, l(1)
div r14.w, r14.w, r16.w
add r14.w, -r14.w, l(1)
mul r13.w, r13.w, r14.w
min r9.w, r9.w, cb1[4].y
mul r14.w, r0.x, cb2[30].w
mad r16.w, r0.x, cb2[30].w, l(1)
div r14.w, r14.w, r16.w
mad r19.xyz, cb2[30].xyzx, r14.wwww, cb2[1].xyzx
mad r19.xyz, cb2[12].xyzx, r13.wwww, r19.xyzx
add r13.w, -r14.w, l(1)
mul r20.xyz, r13.wwww, cb2[31].xyzx
mov_sat r13.w, cb1[4].y
log r13.w, r13.w
mul r13.w, r13.w, cb2[31].w
exp r13.w, r13.w
mul r20.xyz, r13.wwww, r20.xyzx
mad r19.xyz, r19.xyzx, r9.wwww, r20.xyzx
ge r9.w, cb2[10].z, l(-100)
max r20.xyz, r19.xyzx, l(0, 0, 0, 0)
movc r19.xyz, r9.wwww, r20.xyzx, r19.xyzx
add r19.xyz, r19.xyzx, cb2[14].xyzx
mul r19.xyz, r16.xyzx, r19.xyzx
mul r6.xyz, r6.xyzx, r19.xyzx
mul r6.xyz, r6.xyzx, l(0.4, 0.4, 0.4, 0)
mov r17.y, l(0.99)
sample_l r17.yz, r17.xyxx, t21.zxyw, s8, l(0)
mad r6.xyz, r18.xyzx, r16.xyzx, r6.xyzx
add r9.w, -cb4[2].z, l(1)
add r10.w, -r10.w, l(1)
mul r13.w, r10.w, r10.w
mul r13.w, r13.w, r13.w
mul r10.w, r10.w, r13.w
mad r9.w, r9.w, r10.w, cb4[2].z
dp2 r10.w, r17.xxxx, r6.wwww
add r6.w, r17.x, r6.w
add r6.w, -r10.w, r6.w
mad r6.w, r6.w, l(0.0001), r10.w
div r6.w, l(0.5), r6.w
mad r10.w, -r11.x, r11.x, l(1)
mul r11.x, r11.x, l(0.0001)
mad r10.w, r11.x, r11.x, r10.w
div r10.w, l(0.0001), r10.w
mul r10.w, r10.w, r10.w
mul r6.w, r6.w, r10.w
mul r6.w, r9.w, r6.w
mul r6.w, r6.w, l(0.31831)
div r9.w, l(1, 1, 1, 1), r17.z
add r9.w, r9.w, l(-1)
mad r9.w, cb4[2].z, r9.w, l(1)
mul r6.w, r6.w, r9.w
mul r13.xyz, r13.xyzx, r6.wwww
max r13.xyz, r13.xyzx, l(0, 0, 0, 0)
add r6.w, -r17.y, r17.z
mad r6.w, cb4[2].z, r6.w, r17.y
mul r6.w, r9.w, r6.w
lt r9.w, v6.x, l(0)
sample r16, v3.xyxx, t4, s0
if_nz cb4[9].w
and r17, cb4[9].wwww, l(1, 2, 4, 8)
and r18, cb4[9].wwww, l(16, 32, 64, 128)
and r19, cb4[9].wwww, l(256, 512, 1024, 2048)
and r20, cb4[9].wwww, l(4096, 8192, 16384, 32768)
and r21.xy, cb4[9].wwww, l(65536, 131072, 0, 0)
frc r22, v3.xyxy
movc r22, r21.yyyy, v3.xyxy, r22
dp2 r10.w, cb11[43].xyxx, r22.zwzz
add r10.w, r10.w, -cb11[43].z
lt r10.w, r10.w, l(0)
mad r23, -cb11[43].xyxy, cb11[43].zzzz, r22.zwzw
dp4 r11.x, r23.zzww, cb11[43].xxyy
mad r23, cb11[43].xyxy, -r11.xxxx, r23
mad r23, cb11[43].xyxy, cb11[43].zzzz, r23
movc r22, r10.wwww, r23, r22
movc r16, r17.xxxx, r16, l(1, 1, 1, 1)
if_nz r17.y
mad r17.xy, r22.zwzz, cb11[6].xyxx, cb11[6].zwzz
add r17.xy, -|r17.xyxx|, l(1, 1, 0, 0)
mul_sat r17.xy, r17.xyxx, cb11[7].xyxx
add r17.xy, -r17.xyxx, l(1, 1, 0, 0)
dp2 r10.w, r17.xyxx, r17.xyxx
sqrt r10.w, r10.w
add r10.w, -r10.w, l(1)
max r10.w, r10.w, l(0)
max r11.x, cb11[7].z, l(0.0001)
log r10.w, r10.w
mul r10.w, r10.w, r11.x
exp r23.x, r10.w
mad r17.xy, r22.zwzz, cb11[8].xyxx, cb11[8].zwzz
add r17.xy, -|r17.xyxx|, l(1, 1, 0, 0)
mul_sat r17.xy, r17.xyxx, cb11[9].xyxx
add r17.xy, -r17.xyxx, l(1, 1, 0, 0)
dp2 r10.w, r17.xyxx, r17.xyxx
sqrt r10.w, r10.w
add r10.w, -r10.w, l(1)
max r10.w, r10.w, l(0)
max r11.x, cb11[9].z, l(0.0001)
log r10.w, r10.w
mul r10.w, r10.w, r11.x
exp r23.y, r10.w
mad r17.xy, r22.zwzz, cb11[10].xyxx, cb11[10].zwzz
add r17.xy, -|r17.xyxx|, l(1, 1, 0, 0)
mul_sat r17.xy, r17.xyxx, cb11[11].xyxx
add r17.xy, -r17.xyxx, l(1, 1, 0, 0)
dp2 r10.w, r17.xyxx, r17.xyxx
sqrt r10.w, r10.w
add r10.w, -r10.w, l(1)
max r10.w, r10.w, l(0)
max r11.x, cb11[11].z, l(0.0001)
log r10.w, r10.w
mul r10.w, r10.w, r11.x
exp r23.z, r10.w
mad r17.xy, r22.zwzz, cb11[12].xyxx, cb11[12].zwzz
add r17.xy, -|r17.xyxx|, l(1, 1, 0, 0)
mul_sat r17.xy, r17.xyxx, cb11[13].xyxx
add r17.xy, -r17.xyxx, l(1, 1, 0, 0)
dp2 r10.w, r17.xyxx, r17.xyxx
sqrt r10.w, r10.w
add r10.w, -r10.w, l(1)
max r10.w, r10.w, l(0)
max r11.x, cb11[13].z, l(0.0001)
log r10.w, r10.w
mul r10.w, r10.w, r11.x
exp r23.w, r10.w
dp3 r10.w, r23.yzwy, l(2, 2, 2, 0)
add r24.x, -r10.w, r23.x
dp2 r10.w, r23.zwzz, l(2, 2, 0, 0)
add r24.y, -r10.w, r23.y
mad r24.z, -r23.w, l(2), r23.z
mov r24.w, r23.w
max r24, r24, l(0, 0, 0, 0)
movc r23, r19.zzzz, r24, r23
mov r24.x, cb11[7].w
mov r24.y, cb11[9].w
mov r24.z, cb11[11].w
mov r24.w, cb11[13].w
mul r25, r23, r24
max r10.w, r25.w, r25.z
max r10.w, r10.w, r25.y
max r10.w, r10.w, r25.x
add r11.x, -r10.w, l(1)
movc r10.w, r17.w, r11.x, r10.w
mul r25, r10.wwww, r16
mad r26, r23, r24, r16
mad r27, -r23, r24, r16
add r23, r23, l(-1, -1, -1, -1)
mad r23, r24, r23, l(1, 1, 1, 1)
mul r23, r16, r23
movc r23, r17.wwww, r27, r23
movc r17, r17.zzzz, r26, r23
movc_sat r16, r21.xxxx, r25, r17
endif 
if_nz r18.x
sample_b r17, v3.xyxx, t0, s0, cb11[5].y
add r21.xyz, -r17.xyzx, cb11[14].xyzx
dp3 r10.w, r21.xyzx, r21.xyzx
sqrt r10.w, r10.w
add r10.w, -r10.w, l(1)
dp3 r11.x, cb11[14].xyzx, cb11[14].xyzx
rsq r11.x, r11.x
mul r21.xyz, r11.xxxx, cb11[14].xyzx
dp3 r11.x, r17.xyzx, r17.xyzx
rsq r11.x, r11.x
mul r23.xyz, r11.xxxx, r17.xyzx
dp3 r11.x, r21.xyzx, r23.xyzx
add r11.x, -r10.w, r11.x
mad r10.w, cb11[14].w, r11.x, r10.w
mad_sat r10.w, r10.w, cb11[15].x, -cb11[15].y
add r11.x, cb11[15].z, l(-1249495107)
add r13.w, -r11.x, cb11[15].w
add r11.x, -r11.x, r17.w
div r13.w, l(1, 1, 1, 1), r13.w
mul_sat r11.x, r11.x, r13.w
mad r13.w, r11.x, l(-2), l(3)
mul r11.x, r11.x, r11.x
mul r11.x, r11.x, r13.w
min r11.x, r11.x, l(1)
mul r21.x, r10.w, r11.x
add r24.xyz, -r17.xyzx, cb11[16].xyzx
dp3 r13.w, r24.xyzx, r24.xyzx
sqrt r13.w, r13.w
add r13.w, -r13.w, l(1)
dp3 r14.w, cb11[16].xyzx, cb11[16].xyzx
rsq r14.w, r14.w
mul r24.xyz, r14.wwww, cb11[16].xyzx
dp3 r14.w, r24.xyzx, r23.xyzx
add r14.w, -r13.w, r14.w
mad r13.w, cb11[16].w, r14.w, r13.w
mad_sat r13.w, r13.w, cb11[17].x, -cb11[17].y
add r14.w, cb11[17].z, l(-1249495107)
add r18.x, -r14.w, cb11[17].w
add r14.w, -r14.w, r17.w
div r18.x, l(1, 1, 1, 1), r18.x
mul_sat r14.w, r14.w, r18.x
mad r18.x, r14.w, l(-2), l(3)
mul r14.w, r14.w, r14.w
mul r14.w, r14.w, r18.x
min r14.w, r14.w, l(1)
mul r21.y, r13.w, r14.w
add r24.xyz, -r17.xyzx, cb11[18].xyzx
dp3 r18.x, r24.xyzx, r24.xyzx
sqrt r18.x, r18.x
add r18.x, -r18.x, l(1)
dp3 r19.z, cb11[18].xyzx, cb11[18].xyzx
rsq r19.z, r19.z
mul r24.xyz, r19.zzzz, cb11[18].xyzx
dp3 r19.z, r24.xyzx, r23.xyzx
add r19.z, -r18.x, r19.z
mad r18.x, cb11[18].w, r19.z, r18.x
mad_sat r18.x, r18.x, cb11[19].x, -cb11[19].y
add r19.z, cb11[19].z, l(-1249495107)
add r23.w, -r19.z, cb11[19].w
add r19.z, r17.w, -r19.z
div r23.w, l(1, 1, 1, 1), r23.w
mul_sat r19.z, r19.z, r23.w
mad r23.w, r19.z, l(-2), l(3)
mul r19.z, r19.z, r19.z
mul r19.z, r19.z, r23.w
min r19.z, r19.z, l(1)
mul r21.z, r18.x, r19.z
add r17.xyz, -r17.xyzx, cb11[20].xyzx
dp3 r17.x, r17.xyzx, r17.xyzx
sqrt r17.x, r17.x
add r17.x, -r17.x, l(1)
dp3 r17.y, cb11[20].xyzx, cb11[20].xyzx
rsq r17.y, r17.y
mul r24.xyz, r17.yyyy, cb11[20].xyzx
dp3 r17.y, r24.xyzx, r23.xyzx
add r17.y, -r17.x, r17.y
mad r17.x, cb11[20].w, r17.y, r17.x
mad_sat r17.x, r17.x, cb11[21].x, -cb11[21].y
add r17.y, cb11[21].z, l(-1249495107)
add r17.z, -r17.y, cb11[21].w
add r17.y, -r17.y, r17.w
div r17.z, l(1, 1, 1, 1), r17.z
mul_sat r17.y, r17.z, r17.y
mad r17.z, r17.y, l(-2), l(3)
mul r17.y, r17.y, r17.y
mul r17.y, r17.y, r17.z
min r17.y, r17.y, l(1)
mul r21.w, r17.y, r17.x
dp3 r17.x, r21.yzwy, l(2, 2, 2, 0)
mad r17.x, r10.w, r11.x, -r17.x
dp2 r10.w, r21.zwzz, l(2, 2, 0, 0)
mad r17.y, r13.w, r14.w, -r10.w
mad r17.z, -r21.w, l(2), r21.z
mov r17.w, r21.w
max r17, r17, l(0, 0, 0, 0)
movc r17, r19.wwww, r17, r21
mad r21, r17, cb11[22], r16
mad r23, -r17, cb11[22], r16
add r17, r17, l(-1, -1, -1, -1)
mad r17, cb11[22], r17, l(1, 1, 1, 1)
mul r17, r16, r17
movc r17, r18.zzzz, r23, r17
movc_sat r16, r18.yyyy, r21, r17
endif 
if_nz r18.w
add r17, r22.zwzw, -cb11[23]
dp2 r10.w, r17.xyxx, r17.xyxx
add r18.xy, -cb11[23].xyxx, cb11[24].zwzz
dp2 r11.x, r17.xyxx, r18.xyxx
dp2 r13.w, r18.xyxx, r18.xyxx
div_sat r11.x, r11.x, r13.w
mad r18.zw, -r18.xxxy, r11.xxxx, r17.xxxy
dp2 r11.x, r18.zwzz, r18.zwzz
min r10.w, r10.w, r11.x
ge r18.zw, r22.wwww, cb11[23].yyyw
lt r19.zw, r22.wwww, cb11[24].wwwy
mul r17.xy, r17.yxyy, r18.xyxx
lt r11.x, r17.y, r17.x
and r13.w, r18.z, r19.z
and r13.w, r11.x, r13.w
not r17.xy, r18.zwzz
not r18.xy, r19.zwzz
not r11.x, r11.x
and r14.w, r17.x, r18.x
and r11.x, r11.x, r14.w
or r11.x, r11.x, r13.w
add r18.xz, -cb11[23].zzwz, cb11[23].xxyx
dp2 r13.w, r17.zwzz, r18.xzxx
dp2 r14.w, r18.xzxx, r18.xzxx
div_sat r13.w, r13.w, r14.w
mad r21.xy, -r18.xzxx, r13.wwww, r17.zwzz
dp2 r13.w, r21.xyxx, r21.xyxx
min r10.w, r10.w, r13.w
lt r21.xy, r22.wwww, cb11[23].ywyy
mul r17.xz, r17.wwzw, r18.xxzx
lt r13.w, r17.z, r17.x
and r14.w, r18.w, r21.x
and r14.w, r13.w, r14.w
not r17.xz, r21.xxyx
not r13.w, r13.w
and r17.x, r17.x, r17.y
and r13.w, r13.w, r17.x
or r13.w, r13.w, r14.w
movc r17.xy, r11.xxxx, l(-1, 1, 0, 0), l(1, -1, 0, 0)
movc r11.x, r13.w, r17.y, r17.x
add r17.xy, cb11[23].zwzz, -cb11[24].xyxx
add r23, r22.zwzw, -cb11[24]
dp2 r13.w, r23.xyxx, r17.xyxx
dp2 r14.w, r17.xyxx, r17.xyxx
div_sat r13.w, r13.w, r14.w
mad r18.xz, -r17.xxyx, r13.wwww, r23.xxyx
dp2 r13.w, r18.xzxx, r18.xzxx
min r10.w, r10.w, r13.w
ge r18.xz, r22.wwww, cb11[24].yywy
mul r17.xy, r17.xyxx, r23.yxyy
lt r13.w, r17.y, r17.x
and r14.w, r21.y, r18.x
and r14.w, r13.w, r14.w
not r17.xy, r18.xzxx
not r13.w, r13.w
and r17.x, r17.z, r17.x
and r13.w, r13.w, r17.x
or r13.w, r13.w, r14.w
movc r11.x, r13.w, -r11.x, r11.x
add r17.xz, -cb11[24].zzwz, cb11[24].xxyx
dp2 r13.w, r23.zwzz, r17.xzxx
dp2 r14.w, r17.xzxx, r17.xzxx
div_sat r13.w, r13.w, r14.w
mad r18.xw, -r17.xxxz, r13.wwww, r23.zzzw
dp2 r13.w, r18.xwxx, r18.xwxx
min r10.w, r10.w, r13.w
mul r17.xz, r23.wwzw, r17.xxzx
lt r13.w, r17.z, r17.x
and r14.w, r19.w, r18.z
and r14.w, r13.w, r14.w
not r13.w, r13.w
and r17.x, r18.y, r17.y
and r13.w, r13.w, r17.x
or r13.w, r13.w, r14.w
movc r11.x, r13.w, -r11.x, r11.x
sqrt r10.w, r10.w
mul r10.w, r10.w, r11.x
lt r11.x, cb11[31].z, l(0)
movc r10.w, r11.x, |r10.w|, r10.w
mad_sat r10.w, r10.w, cb11[31].x, -cb11[31].y
max r11.x, |cb11[31].z|, l(0.0001)
log r10.w, r10.w
mul r10.w, r10.w, r11.x
exp r17.x, r10.w
add r18, r22.zwzw, -cb11[25]
dp2 r10.w, r18.xyxx, r18.xyxx
add r19.zw, -cb11[25].xxxy, cb11[26].zzzw
dp2 r11.x, r18.xyxx, r19.zwzz
dp2 r13.w, r19.zwzz, r19.zwzz
div_sat r11.x, r11.x, r13.w
mad r21.xy, -r19.zwzz, r11.xxxx, r18.xyxx
dp2 r11.x, r21.xyxx, r21.xyxx
min r10.w, r10.w, r11.x
ge r21.xy, r22.wwww, cb11[25].ywyy
lt r21.zw, r22.wwww, cb11[26].wwwy
mul r18.xy, r18.yxyy, r19.zwzz
lt r11.x, r18.y, r18.x
and r13.w, r21.z, r21.x
and r13.w, r11.x, r13.w
not r18.xy, r21.xyxx
not r19.zw, r21.zzzw
not r11.x, r11.x
and r14.w, r18.x, r19.z
and r11.x, r11.x, r14.w
or r11.x, r11.x, r13.w
add r21.xz, -cb11[25].zzwz, cb11[25].xxyx
dp2 r13.w, r18.zwzz, r21.xzxx
dp2 r14.w, r21.xzxx, r21.xzxx
div_sat r13.w, r13.w, r14.w
mad r23.xy, -r21.xzxx, r13.wwww, r18.zwzz
dp2 r13.w, r23.xyxx, r23.xyxx
min r10.w, r10.w, r13.w
lt r23.xy, r22.wwww, cb11[25].ywyy
mul r18.xz, r18.wwzw, r21.xxzx
lt r13.w, r18.z, r18.x
and r14.w, r21.y, r23.x
and r14.w, r13.w, r14.w
not r18.xz, r23.xxyx
not r13.w, r13.w
and r18.x, r18.x, r18.y
and r13.w, r13.w, r18.x
or r13.w, r13.w, r14.w
movc r18.xy, r11.xxxx, l(-1, 1, 0, 0), l(1, -1, 0, 0)
movc r11.x, r13.w, r18.y, r18.x
add r18.xy, cb11[25].zwzz, -cb11[26].xyxx
add r24, r22.zwzw, -cb11[26]
dp2 r13.w, r24.xyxx, r18.xyxx
dp2 r14.w, r18.xyxx, r18.xyxx
div_sat r13.w, r13.w, r14.w
mad r21.xy, -r18.xyxx, r13.wwww, r24.xyxx
dp2 r13.w, r21.xyxx, r21.xyxx
min r10.w, r10.w, r13.w
ge r21.xy, r22.wwww, cb11[26].ywyy
mul r18.xy, r18.xyxx, r24.yxyy
lt r13.w, r18.y, r18.x
and r14.w, r23.y, r21.x
and r14.w, r13.w, r14.w
not r18.xy, r21.xyxx
not r13.w, r13.w
and r18.x, r18.z, r18.x
and r13.w, r13.w, r18.x
or r13.w, r13.w, r14.w
movc r11.x, r13.w, -r11.x, r11.x
add r18.xz, -cb11[26].zzwz, cb11[26].xxyx
dp2 r13.w, r24.zwzz, r18.xzxx
dp2 r14.w, r18.xzxx, r18.xzxx
div_sat r13.w, r13.w, r14.w
mad r21.xz, -r18.xxzx, r13.wwww, r24.zzwz
dp2 r13.w, r21.xzxx, r21.xzxx
min r10.w, r10.w, r13.w
mul r18.xz, r24.wwzw, r18.xxzx
lt r13.w, r18.z, r18.x
and r14.w, r21.w, r21.y
and r14.w, r13.w, r14.w
not r13.w, r13.w
and r18.x, r19.w, r18.y
and r13.w, r13.w, r18.x
or r13.w, r13.w, r14.w
movc r11.x, r13.w, -r11.x, r11.x
sqrt r10.w, r10.w
mul r10.w, r10.w, r11.x
lt r11.x, cb11[32].z, l(0)
movc r10.w, r11.x, |r10.w|, r10.w
mad_sat r10.w, r10.w, cb11[32].x, -cb11[32].y
max r11.x, |cb11[32].z|, l(0.0001)
log r10.w, r10.w
mul r10.w, r10.w, r11.x
exp r17.y, r10.w
add r18, r22.zwzw, -cb11[27]
dp2 r10.w, r18.xyxx, r18.xyxx
add r19.zw, -cb11[27].xxxy, cb11[28].zzzw
dp2 r11.x, r18.xyxx, r19.zwzz
dp2 r13.w, r19.zwzz, r19.zwzz
div_sat r11.x, r11.x, r13.w
mad r21.xy, -r19.zwzz, r11.xxxx, r18.xyxx
dp2 r11.x, r21.xyxx, r21.xyxx
min r10.w, r10.w, r11.x
ge r21.xy, r22.wwww, cb11[27].ywyy
lt r21.zw, r22.wwww, cb11[28].wwwy
mul r18.xy, r18.yxyy, r19.zwzz
lt r11.x, r18.y, r18.x
and r13.w, r21.z, r21.x
and r13.w, r11.x, r13.w
not r18.xy, r21.xyxx
not r19.zw, r21.zzzw
not r11.x, r11.x
and r14.w, r18.x, r19.z
and r11.x, r11.x, r14.w
or r11.x, r11.x, r13.w
add r21.xz, -cb11[27].zzwz, cb11[27].xxyx
dp2 r13.w, r18.zwzz, r21.xzxx
dp2 r14.w, r21.xzxx, r21.xzxx
div_sat r13.w, r13.w, r14.w
mad r23.xy, -r21.xzxx, r13.wwww, r18.zwzz
dp2 r13.w, r23.xyxx, r23.xyxx
min r10.w, r10.w, r13.w
lt r23.xy, r22.wwww, cb11[27].ywyy
mul r18.xz, r18.wwzw, r21.xxzx
lt r13.w, r18.z, r18.x
and r14.w, r21.y, r23.x
and r14.w, r13.w, r14.w
not r18.xz, r23.xxyx
not r13.w, r13.w
and r18.x, r18.x, r18.y
and r13.w, r13.w, r18.x
or r13.w, r13.w, r14.w
movc r18.xy, r11.xxxx, l(-1, 1, 0, 0), l(1, -1, 0, 0)
movc r11.x, r13.w, r18.y, r18.x
add r18.xy, cb11[27].zwzz, -cb11[28].xyxx
add r24, r22.zwzw, -cb11[28]
dp2 r13.w, r24.xyxx, r18.xyxx
dp2 r14.w, r18.xyxx, r18.xyxx
div_sat r13.w, r13.w, r14.w
mad r21.xy, -r18.xyxx, r13.wwww, r24.xyxx
dp2 r13.w, r21.xyxx, r21.xyxx
min r10.w, r10.w, r13.w
ge r21.xy, r22.wwww, cb11[28].ywyy
mul r18.xy, r18.xyxx, r24.yxyy
lt r13.w, r18.y, r18.x
and r14.w, r23.y, r21.x
and r14.w, r13.w, r14.w
not r18.xy, r21.xyxx
not r13.w, r13.w
and r18.x, r18.z, r18.x
and r13.w, r13.w, r18.x
or r13.w, r13.w, r14.w
movc r11.x, r13.w, -r11.x, r11.x
add r18.xz, -cb11[28].zzwz, cb11[28].xxyx
dp2 r13.w, r24.zwzz, r18.xzxx
dp2 r14.w, r18.xzxx, r18.xzxx
div_sat r13.w, r13.w, r14.w
mad r21.xz, -r18.xxzx, r13.wwww, r24.zzwz
dp2 r13.w, r21.xzxx, r21.xzxx
min r10.w, r10.w, r13.w
mul r18.xz, r24.wwzw, r18.xxzx
lt r13.w, r18.z, r18.x
and r14.w, r21.w, r21.y
and r14.w, r13.w, r14.w
not r13.w, r13.w
and r18.x, r19.w, r18.y
and r13.w, r13.w, r18.x
or r13.w, r13.w, r14.w
movc r11.x, r13.w, -r11.x, r11.x
sqrt r10.w, r10.w
mul r10.w, r10.w, r11.x
lt r11.x, cb11[33].z, l(0)
movc r10.w, r11.x, |r10.w|, r10.w
mad_sat r10.w, r10.w, cb11[33].x, -cb11[33].y
max r11.x, |cb11[33].z|, l(0.0001)
log r10.w, r10.w
mul r10.w, r10.w, r11.x
exp r17.z, r10.w
add r18, r22.zwzw, -cb11[29]
dp2 r10.w, r18.xyxx, r18.xyxx
add r19.zw, -cb11[29].xxxy, cb11[30].zzzw
dp2 r11.x, r18.xyxx, r19.zwzz
dp2 r13.w, r19.zwzz, r19.zwzz
div_sat r11.x, r11.x, r13.w
mad r21.xy, -r19.zwzz, r11.xxxx, r18.xyxx
dp2 r11.x, r21.xyxx, r21.xyxx
min r10.w, r10.w, r11.x
ge r21.xy, r22.wwww, cb11[29].ywyy
lt r21.zw, r22.wwww, cb11[30].wwwy
mul r18.xy, r18.yxyy, r19.zwzz
lt r11.x, r18.y, r18.x
and r13.w, r21.z, r21.x
and r13.w, r11.x, r13.w
not r18.xy, r21.xyxx
not r19.zw, r21.zzzw
not r11.x, r11.x
and r14.w, r18.x, r19.z
and r11.x, r11.x, r14.w
or r11.x, r11.x, r13.w
add r21.xz, -cb11[29].zzwz, cb11[29].xxyx
dp2 r13.w, r18.zwzz, r21.xzxx
dp2 r14.w, r21.xzxx, r21.xzxx
div_sat r13.w, r13.w, r14.w
mad r23.xy, -r21.xzxx, r13.wwww, r18.zwzz
dp2 r13.w, r23.xyxx, r23.xyxx
min r10.w, r10.w, r13.w
lt r23.xy, r22.wwww, cb11[29].ywyy
mul r18.xz, r18.wwzw, r21.xxzx
lt r13.w, r18.z, r18.x
and r14.w, r21.y, r23.x
and r14.w, r13.w, r14.w
not r18.xz, r23.xxyx
not r13.w, r13.w
and r18.x, r18.x, r18.y
and r13.w, r13.w, r18.x
or r13.w, r13.w, r14.w
movc r18.xy, r11.xxxx, l(-1, 1, 0, 0), l(1, -1, 0, 0)
movc r11.x, r13.w, r18.y, r18.x
add r18.xy, cb11[29].zwzz, -cb11[30].xyxx
add r24, r22, -cb11[30]
dp2 r13.w, r24.xyxx, r18.xyxx
dp2 r14.w, r18.xyxx, r18.xyxx
div_sat r13.w, r13.w, r14.w
mad r21.xy, -r18.xyxx, r13.wwww, r24.xyxx
dp2 r13.w, r21.xyxx, r21.xyxx
min r10.w, r10.w, r13.w
ge r21.xy, r22.wwww, cb11[30].ywyy
mul r18.xy, r18.xyxx, r24.yxyy
lt r13.w, r18.y, r18.x
and r14.w, r23.y, r21.x
and r14.w, r13.w, r14.w
not r18.xy, r21.xyxx
not r13.w, r13.w
and r18.x, r18.z, r18.x
and r13.w, r13.w, r18.x
or r13.w, r13.w, r14.w
movc r11.x, r13.w, -r11.x, r11.x
add r18.xz, -cb11[30].zzwz, cb11[30].xxyx
dp2 r13.w, r24.zwzz, r18.xzxx
dp2 r14.w, r18.xzxx, r18.xzxx
div_sat r13.w, r13.w, r14.w
mad r21.xz, -r18.xxzx, r13.wwww, r24.zzwz
dp2 r13.w, r21.xzxx, r21.xzxx
min r10.w, r10.w, r13.w
mul r18.xz, r24.wwzw, r18.xxzx
lt r13.w, r18.z, r18.x
and r14.w, r21.w, r21.y
and r14.w, r13.w, r14.w
not r13.w, r13.w
and r18.x, r19.w, r18.y
and r13.w, r13.w, r18.x
or r13.w, r13.w, r14.w
movc r11.x, r13.w, -r11.x, r11.x
sqrt r10.w, r10.w
mul r10.w, r10.w, r11.x
lt r11.x, cb11[34].z, l(0)
movc r10.w, r11.x, |r10.w|, r10.w
mad_sat r10.w, r10.w, cb11[34].x, -cb11[34].y
max r11.x, |cb11[34].z|, l(0.0001)
log r10.w, r10.w
mul r10.w, r10.w, r11.x
exp r17.w, r10.w
dp3 r10.w, r17.yzwy, l(2, 2, 2, 0)
add r18.x, -r10.w, r17.x
dp2 r10.w, r17.zwzz, l(2, 2, 0, 0)
add r18.y, -r10.w, r17.y
mad r18.z, -r17.w, l(2), r17.z
mov r18.w, r17.w
max r18, r18, l(0, 0, 0, 0)
movc r17, r20.xxxx, r18, r17
mov r18.x, cb11[31].w
mov r18.y, cb11[32].w
mov r18.z, cb11[33].w
mov r18.w, cb11[34].w
mad r21, r17, r18, r16
mad r22, -r17, r18, r16
add r17, r17, l(-1, -1, -1, -1)
mad r17, r18, r17, l(1, 1, 1, 1)
mul r17, r16, r17
movc r17, r19.yyyy, r22, r17
movc_sat r16, r19.xxxx, r21, r17
endif 
if_nz r20.y
add r17.xyz, v6.yzwy, -cb11[1].xyzx
dp3 r10.w, r17.xyzx, r17.xyzx
max r11.x, cb11[1].w, l(1e-05)
div r10.w, r10.w, r11.x
add r17.xyz, v6.yzwy, -cb11[2].xyzx
dp3 r11.x, r17.xyzx, r17.xyzx
max r13.w, cb11[2].w, l(1e-05)
div r11.x, r11.x, r13.w
add r17.xyz, v6.yzwy, -cb11[3].xyzx
dp3 r13.w, r17.xyzx, r17.xyzx
max r14.w, cb11[3].w, l(1e-05)
div r13.w, r13.w, r14.w
add r17.xyz, v6.yzwy, -cb11[4].xyzx
dp3 r14.w, r17.xyzx, r17.xyzx
max r17.x, cb11[4].w, l(1e-05)
div r14.w, r14.w, r17.x
min r17.x, r13.w, r14.w
min r17.x, r11.x, r17.x
min r17.x, r10.w, r17.x
eq r10.w, r10.w, r17.x
eq r17.y, cb11[1].w, l(0)
or r18.x, r10.w, r17.y
eq r10.w, r11.x, r17.x
eq r11.x, cb11[2].w, l(0)
or r18.y, r10.w, r11.x
eq r10.w, r13.w, r17.x
eq r11.x, cb11[3].w, l(0)
or r18.z, r10.w, r11.x
eq r10.w, r14.w, r17.x
eq r11.x, cb11[4].w, l(0)
or r18.w, r10.w, r11.x
and r17, r18, l(1, 1, 1, 1)
add r19, r16, r17
movc r18, r18, l(-1, -1, -1, -1), l(-2147483648, -2147483648, -2147483648, -2147483648)
add r18, r16, r18
mul r17, r16, r17
movc r17, r20.wwww, r18, r17
movc_sat r16, r20.zzzz, r19, r17
endif 
endif 
dp4 r10.w, cb11[38], l(1, 1, 1, 1)
ne r10.w, l(0, 0, 0, 0), r10.w
dp3 r11.x, r10.xyzx, l(0.333, 0.333, 0.333, 0)
mad_sat r17, r11.xxxx, cb11[35], cb11[36]
log r17, r17
mul r17, r17, cb11[37]
exp r17, r17
add r17, r17, l(-1, -1, -1, -1)
mad_sat r17, cb11[38], r17, l(1, 1, 1, 1)
mul r17, r16, r17
movc r16, r10.wwww, r17, r16
dp4 r10.w, cb11[42], l(1, 1, 1, 1)
ne r10.w, l(0, 0, 0, 0), r10.w
mad_sat r17, r7.wwww, cb11[39], cb11[40]
log r17, r17
mul r17, r17, cb11[41]
exp r17, r17
add r17, r17, l(-1, -1, -1, -1)
mad_sat r17, |cb11[42]|, r17, l(1, 1, 1, 1)
mul r17, r16, r17
movc r16, r10.wwww, r17, r16
ne r7.w, l(0, 0, 0, 0), cb4[4].z
ne r10.w, l(0, 0, 0, 0), cb4[7].w
and r10.w, r9.w, r10.w
movc r17.xyz, r10.wwww, cb4[10].xyzx, cb4[5].xyzx
mul r17.xyz, r16.yyyy, r17.xyzx
mad r17.xyz, r16.xxxx, cb4[1].xyzx, r17.xyzx
ne r10.w, l(0, 0, 0, 0), cb4[6].w
and r10.w, r9.w, r10.w
movc r18.xyz, r10.wwww, cb4[9].xyzx, cb4[6].xyzx
mad r17.xyz, r16.zzzz, r18.xyzx, r17.xyzx
ne r10.w, l(0, 0, 0, 0), cb4[5].w
and r9.w, r9.w, r10.w
movc r18.xyz, r9.wwww, cb4[8].xyzx, cb4[7].xyzx
mad r17.xyz, r16.wwww, r18.xyzx, r17.xyzx
mul r16.xyz, r16.xyzx, cb4[1].xyzx
movc r16.xyz, r7.wwww, r17.xyzx, r16.xyzx
mov_sat r7.w, cb4[8].w
mad r17.xyz, -r9.xyzx, |cb4[0].yyyy|, l(1, 1, 1, 0)
mad r17.xyz, r7.wwww, r17.xyzx, r10.xyzx
mul r16.xyz, r16.xyzx, r17.xyzx
dp4 r7.w, cb2[18], icb[r11.z]
movc r7.w, r11.y, l(1), r7.w
mad r6.xyz, r16.xyzx, r7.wwww, r6.xyzx
mad_sat r7.w, r14.y, l(0.5), l(0.5)
log r7.w, r7.w
mul r7.w, r7.w, cb6[2].y
exp r7.w, r7.w
mul r7.w, r7.w, cb6[2].x
mov r12.w, -r12.x
sample_l r11.xyz, r12.wyzw, t13, s5, l(5.5)
mad r11.xyz, r7.wwww, r11.xyzx, r13.xyzx
mad r13.xyz, -v2.xyzx, r0.yyyy, l(0, 1, 0, 0)
dp3 r9.w, r13.xyzx, r13.xyzx
rsq r9.w, r9.w
mul r13.xyz, r9.wwww, r13.xyzx
mov_sat r5.w, r5.w
dp3_sat r9.w, r13.xyzx, r8.xzwx
mul r13.x, r5.w, l(0.2)
mul r13.y, r9.w, l(0.5)
add r13.xy, r13.xyxx, v4.xzxx
mul r13.xy, r13.xyxx, cb6[5].wwww
round_ni r13.zw, r13.xxxy
frc r13.xy, r13.xyxx
mul r16.xy, r13.xyxx, r13.xyxx
mad r13.xy, -r13.xyxx, l(2, 2, 0, 0), l(3, 3, 0, 0)
mul r13.xy, r13.xyxx, r16.xyxx
mul r16.xy, r13.zwzz, cb6[6].xxxx
sample_l r9.w, r16.xyxx, t20.yzwx, s5, l(0)
add r16, r13.zwzw, l(1, 0, 0, 1)
mul r16, r16, cb6[6].xxxx
sample_l r10.w, r16.xyxx, t20.yzwx, s5, l(0)
sample_l r12.w, r16.zwzz, t20.yzwx, s5, l(0)
add r13.zw, r13.zzzw, l(0, 0, 1, 1)
mul r13.zw, r13.zzzw, cb6[6].xxxx
sample_l r13.z, r13.zwzz, t20.yzxw, s5, l(0)
add r10.w, -r9.w, r10.w
mad r9.w, r13.x, r10.w, r9.w
add r10.w, -r12.w, r13.z
mad r10.w, r13.x, r10.w, r12.w
add r10.w, -r9.w, r10.w
mad r9.w, r13.y, r10.w, r9.w
mul r9.w, |r9.w|, cb6[6].w
frc r10.w, r9.w
round_ni r9.w, r9.w
add r13.xyz, r10.wwww, l(-0.75, -0.5, -0.25, 0)
mul r13.xyz, r13.xyzx, l(4, 4, 4, 0)
mad r13.xyz, -r13.xyzx, r13.xyzx, l(1, 1, 1, 0)
max r13.xyz, r13.xyzx, l(0, 0, 0, 0)
mul r13.xyz, r13.xyzx, cb6[5].zzzz
f16tof32 r10.w, cb2[12].w
mad_sat r13.xyz, -r13.xyzx, r10.wwww, l(1, 1, 1, 0)
mul r10.w, r9.w, l(4)
ge r10.w, r10.w, -r10.w
movc r16.xy, r10.wwww, l(4, 0.25, 0, 0), l(-4, -0.25, 0, 0)
mul r9.w, r9.w, r16.y
frc r9.w, r9.w
mul r9.w, r9.w, r16.x
ne r9.w, r9.w, l(3)
and r9.w, r9.w, l(1)
mad r16.xy, v4.xyxx, cb6[6].yyyy, cb6[6].zzzz
sample_l r10.w, r16.xyxx, t20.yzwx, s5, l(0)
mad_sat r10.w, r10.w, l(2), l(-0.2)
mul r12.w, r10.w, r10.w
mul r10.w, r10.w, r12.w
mul r9.w, r9.w, r10.w
add r13.xyz, r13.xyzx, l(-1, -1, -1, 0)
mad r13.xyz, r9.wwww, r13.xyzx, l(1, 1, 1, 0)
dp3 r9.w, r14.xyzx, cb2[25].xyzx
add r10.w, -cb2[25].w, l(1)
mul r9.w, r9.w, r9.w
add r12.w, -r10.w, l(1)
mad r9.w, r9.w, r12.w, r10.w
mul r11.xyz, r9.wwww, r11.xyzx
mul r11.xyz, r13.xyzx, r11.xyzx
add r10.w, cb4[3].z, l(0.001)
max r10.w, r10.w, r10.z
max r10.w, r10.w, r10.y
max r10.w, r10.w, r10.x
div r10.xyz, r10.xyzx, r10.wwww
add r10.xyz, r10.xyzx, l(-1, -1, -1, 0)
mad r10.xyz, cb4[3].yyyy, r10.xyzx, l(1, 1, 1, 0)
max r10.xyz, r10.xyzx, l(0, 0, 0, 0)
mad r6.xyz, r11.xyzx, r10.xyzx, r6.xyzx
mul r9.xyz, r9.xyzx, cb4[0].xxxx
movc r10.w, r11.w, l(1), l(0)
mad_sat r11.x, r0.z, l(2), r10.w
min r0.w, r0.w, r11.x
mul r2.w, r0.w, r2.w
add r11.xyz, r5.xyzx, -cb7[1].xyzx
dp3 r11.x, r11.xyzx, r11.xyzx
mad_sat r11.x, r11.x, cb7[2].w, -cb7[2].z
dp3 r11.y, r9.xyzx, l(1, 1, 1, 0)
dp3 r11.z, r9.xyzx, l(0.2125, 0.7154, 0.0721, 0)
add r14.xyz, r5.xyzx, -cb7[0].xyzx
dp3 r11.w, r14.xyzx, r14.xyzx
mad_sat r11.w, r11.w, cb7[2].y, -cb7[2].x
add_sat r11.w, r11.w, cb7[0].w
mov r14.w, l(1)
mov r16.xyz, l(0, 0, 0, 0)
mov r17.xyz, l(0, 0, 0, 0)
mov r18.xy, l(0.001, 0.001, 0, 0)
mov r12.w, l(0)
loop 
add r18.zw, -r5.xxxz, cb7[r12.w + 3].xxxy
f16tof32 r19.x, cb7[r12.w + 3].z
ushr r13.w, cb7[r12.w + 3].z, l(16)
f16tof32 r19.y, r13.w
lt r18.zw, |r18.zzzw|, r19.xxxy
and r13.w, r18.w, r18.z
if_nz r13.w
ubfe r13.w, l(3), l(27), cb7[r12.w + 3].w
switch r13.w
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
iadd r12.w, r12.w, l(1)
else 
and r12.w, l(1023), cb7[r12.w + 3].w
mov r19.xyz, r16.xyzx
mov r20.xyz, r17.xyzx
mov r18.zw, r18.xxxy
endif 
if_z r12.w
mov r16.xyz, r19.xyzx
mov r17.xyz, r20.xyzx
mov r18.xy, r18.zwzz
break 
endif 
mov r16.xyz, r19.xyzx
mov r17.xyz, r20.xyzx
mov r18.xy, r18.zwzz
endloop 
mul r5.xyz, r9.wwww, r17.xyzx
dp3 r0.y, r5.xyzx, l(4, 4, 4, 0)
dp3 r11.x, r5.xyzx, l(1, 1, 1, 0)
mad r11.x, r11.x, l(12), l(0.0001)
div r0.y, r0.y, r11.x
div_sat r11.x, r18.x, r18.y
mad r0.y, r0.y, l(4), l(-4)
mad r0.y, r11.x, r0.y, l(4)
mad r5.xyz, r5.xyzx, r0.yyyy, r16.xyzx
mad r5.xyz, r2.wwww, r5.xyzx, r6.xyzx
mul r4.yzw, r0.wwww, r4.yyzw
add_sat r0.y, r0.z, r10.w
mul r0.yzw, r0.yyyy, r4.yyzw
mad r0.yzw, r0.yyzw, r9.xxyz, r5.xxyz
movc r0.yzw, r3.zzzz, r8.xxzw, r0.yyzw
movc r0.yzw, r3.yyyy, v10.xxxx, r0.yyzw
lod r2.w, r15.xyzx, t13.x, s5
mul r2.w, r2.w, l(0.4)
mov r15.w, -r15.x
sample_l r4.yzw, r15.wyzw, t13.wxyz, s5, r2.w
mul r4.yzw, r10.xxyz, r4.yyzw
mul r4.yzw, r13.xxyz, r4.yyzw
mul r4.yzw, r9.wwww, r4.yyzw
mul r2.w, r4.x, l(0.99)
mul r3.y, r2.w, r2.w
mad_sat r2.w, -r3.y, r3.y, r2.w
log r2.w, r2.w
mul r2.w, r2.w, l(0.84)
exp r2.w, r2.w
mul r2.w, r2.w, cb6[1].y
mul r2.w, r2.w, l(0.61)
add_sat r3.y, -r4.x, l(1)
max r3.y, r3.y, l(869711765)
div r2.w, r2.w, r3.y
max r3.y, r5.w, l(897988541)
div r3.y, cb6[1].z, r3.y
lt r3.y, l(0.5), r3.y
and r3.y, r3.y, l(1)
mad_sat r3.z, r3.y, r6.w, r6.w
div r4.x, l(1, 1, 1, 1), cb6[1].x
mul r5.x, r4.x, r4.x
mad r5.y, -r1.w, r1.w, l(1)
mad r5.x, -r5.x, r5.y, l(1)
sqrt r5.y, r5.x
mad r5.y, r4.x, r1.w, r5.y
ge r5.x, r5.x, l(0)
mul r5.yzw, r8.xxzw, r5.yyyy
mad r5.yzw, r4.xxxx, r1.zzxy, -r5.yyzw
and r5.xyz, r5.yzwy, r5.xxxx
dp3_sat r4.x, r8.xzwx, -r5.xyzx
max r4.x, r4.x, l(0.001)
div r4.x, l(1, 1, 1, 1), r4.x
mul r2.w, -r2.w, r4.x
mul r2.w, r2.w, l(1.4427)
exp r2.w, r2.w
add r2.w, -r2.w, l(1)
add r4.x, -r2.w, l(1)
mad r2.w, r3.z, r4.x, r2.w
add r4.x, -r2.w, l(1)
mad r2.w, r7.w, r4.x, r2.w
add_sat r2.w, r3.y, r2.w
ne r3.y, l(0, 0, 0, 0), cb6[1].w
max r4.x, r2.w, l(0.001)
div r4.x, r3.z, r4.x
movc r3.y, r3.y, r4.x, r3.z
mad r4.xyz, r3.yyyy, r4.yzwy, r0.yzwy
ne r0.y, l(0, 0, 0, 0), cb6[4].x
or r0.z, r0.y, r8.y
if_nz r0.z
dp3 r0.z, r8.xzwx, r2.xyzx
add r0.w, cb6[3].z, l(-1)
mad_sat r0.z, |r0.z|, cb6[3].z, -r0.w
mad r2.xy, |r1.wwww|, l(2, 2, 0, 0), l(-0.5, -0.2, 0, 0)
mul_sat r0.w, r2.x, l(6)
add_sat r2.x, r2.y, r2.y
mul r2.x, r0.z, r2.x
mad r2.x, r2.x, -cb6[2].w, cb6[2].w
mul r2.x, r2.x, l(0.3)
mul r5.xyz, r1.xyzx, cb2[27].zxyz
mad r5.xyz, cb2[27].yzxy, r1.yzxy, -r5.xyzx
dp3 r2.y, r5.xyzx, r5.xyzx
rsq r2.y, r2.y
mul r5.xyz, r2.yyyy, r5.xyzx
dp3 r5.x, r8.xzwx, r5.xyzx
dp3 r5.y, r8.xzwx, cb2[27].xyzx
mul r2.xy, r2.xxxx, r5.xyxx
min r1.w, |r1.w|, l(1)
mad r1.w, r1.w, l(-0.5), l(1)
mul r2.xy, r1.wwww, r2.xyxx
div r5.x, cb0[14].y, cb0[14].x
mov r5.y, l(1)
mul r2.xy, r2.xyxx, r5.xyxx
mul r2.xy, r2.xyxx, cb0[12].wwww
sqrt r0.x, r0.x
div r2.xy, r2.xyxx, r0.xxxx
if_nz r0.y
add r5.xyz, -v4.xyzx, cb6[4].yzwy
dp3 r0.y, r5.xyzx, r5.xyzx
rsq r0.y, r0.y
mul r5.xyz, r0.yyyy, r5.xyzx
dp3 r0.y, v5.xyzx, v5.xyzx
rsq r0.y, r0.y
mul r6.xyz, r0.yyyy, v5.xyzx
dp3 r0.y, r5.xyzx, r6.xyzx
add r1.w, cb6[5].x, l(-0.01)
add r0.y, r0.y, -r1.w
add r1.w, -r1.w, cb6[5].x
div_sat r0.y, r0.y, r1.w
else 
mov r0.y, l(0)
endif 
add r1.w, -cb6[3].w, cb6[4].x
mad r1.w, r0.y, r1.w, cb6[3].w
mad r3.yz, v0.xxyx, cb0[14].zzwz, r2.xxyx
lod r2.z, r3.yzyy, t19.x, s8
div r0.x, r0.x, cb0[12].w
add r0.x, r0.x, l(2)
log r0.x, r0.x
div r0.x, r1.w, r0.x
max r0.x, r0.x, r2.z
sample_l r5, r3.yzyy, t19, s8, r0.x
ne r1.w, l(0, 0, 0, 0), cb6[3].x
if_nz r1.w
mad r3.xy, r2.xyxx, cb6[3].xxxx, r3.xwxx
sample_l r5.x, r3.xyxx, t19.xwyz, s8, r0.x
div r2.xy, r2.xyxx, cb6[3].xxxx
mad r2.xy, v0.xyxx, cb0[14].zwzz, r2.xyxx
sample_l r5.z, r2.xyxx, t19.xwzy, s8, r0.x
endif 
and r0.x, cb4[2].x, l(2048)
mad r0.z, -r0.z, r0.w, l(1)
mul r0.z, r0.z, cb6[2].w
mul_sat r0.z, r0.z, l(25)
max r0.z, r0.z, r0.y
movc r0.x, r0.x, l(1), r0.z
mul r0.x, r0.x, r5.w
ne r0.z, l(0, 0, 0, 0), cb6[0].x
if_nz r0.z
max r0.z, r7.z, l(0.01)
max r0.z, r0.z, r7.y
max r0.z, r0.z, r7.x
div r2.xyz, r7.xyzx, r0.zzzz
add r2.xyz, r2.xyzx, cb6[0].yzwy
max r2.xyz, r2.xyzx, l(1e-05, 1e-05, 1e-05, 0)
max r0.z, r2.z, r2.y
max r0.z, r0.z, r2.x
div r2.xyz, r2.xyzx, r0.zzzz
mul_sat r0.z, r2.w, cb6[0].x
add r2.xyz, r2.xyzx, l(-1, -1, -1, 0)
mad r2.xyz, r0.zzzz, r2.xyzx, l(1, 1, 1, 0)
mov r5.w, r5.y
mul r5.xyz, r2.xyzx, r5.xwzx
endif 
add r0.z, r2.w, l(-1)
mad r0.z, r0.x, r0.z, l(1)
add r2.xyz, r4.xyzx, -r5.xyzx
mad r3.yzw, r0.zzzz, r2.xxyz, r5.xxyz
add r0.z, -r2.w, l(1)
mad r3.x, r0.x, r0.z, r2.w
lt r0.x, cb6[4].x, l(0)
add r0.z, -r0.y, l(1)
mul r5.yz, r0.zzyz, l(0, 3, 3, 0)
mov r5.xw, l(1, 0, 0, 0)
movc r4, r0.xxxx, r5.yzwx, r3.yzwx
mov o0.w, r4.w
else 
mov o0.w, r2.w
endif 
max r0.xyz, r4.xyzx, l(0, 0, 0, 0)
mov_sat r2.z, v3.z
mul r0.w, r2.z, r2.z
mad r0.w, r2.z, r0.w, -r2.z
mad r2.x, cb2[26].w, r0.w, r2.z
mad r0.w, r2.z, r2.z, -r2.z
mad r2.y, cb2[26].w, r0.w, r2.z
dp3_sat r0.w, -r1.zxyz, cb2[0].xyzx
log r0.w, r0.w
mul r0.w, r0.w, cb2[11].z
exp r0.w, r0.w
mul r1.xyz, r0.wwww, cb2[2].xyzx
mad r1.xyz, r1.xyzx, cb2[11].yyyy, cb2[6].yzwy
add r1.xyz, -r0.xyzx, r1.xyzx
mad o0.xyz, r2.xyzx, r1.xyzx, r0.xyzx
ret 
label label[0]
ubfe r13.w, l(10), l(10), cb7[r12.w + 3].w
add r21.xyz, -r5.xyzx, cb7[r13.w + 323].xyzx
dp3 r16.w, r21.xyzx, r21.xyzx
sqrt r16.w, r16.w
div r22.xyz, r21.xyzx, r16.wwww
dp3 r17.w, cb7[r13.w + 324].xyzx, -r22.xyzx
add_sat r17.w, -r17.w, cb7[r13.w + 324].w
ushr r19.w, cb7[r13.w + 325].w, l(16)
f16tof32 r19.w, r19.w
eq r20.w, r17.w, l(0)
dp3 r21.x, r21.xyzx, cb7[r13.w + 324].xyzx
lt r19.w, r19.w, r21.x
or r19.w, r19.w, r20.w
if_z r19.w
ushr r21.xyz, cb7[r13.w + 325].zxyz, l(16, 16, 16, 0)
f16tof32 r19.w, cb7[r13.w + 323].w
ushr r20.w, cb7[r13.w + 323].w, l(16)
f16tof32 r20.w, r20.w
f16tof32 r23.xyz, cb7[r13.w + 325].wxyw
f16tof32 r14.xyz, r21.xyzx
add r13.w, r11.x, r23.x
add_sat r13.w, r13.w, cb7[0].w
mad_sat r16.w, -r16.w, r20.w, r19.w
mul r16.w, r16.w, r16.w
dp3 r19.w, r8.xzwx, r22.xyzx
mul r16.w, r17.w, r16.w
mul r13.w, r13.w, r16.w
mov r23.w, r14.y
mul r21.xyz, r13.wwww, r23.ywzy
dp3 r14.y, r23.ywzy, r9.xyzx
dp3 r16.w, r23.ywzy, l(1, 1, 1, 0)
mad r16.w, r16.w, r11.y, l(0.0001)
div r14.y, r14.y, r16.w
mad r23.xyz, r14.yyyy, r11.zzzz, -r9.xyzx
mad r23.xyz, r14.xxxx, r23.xyzx, r9.xyzx
mul r24.xyz, r21.xyzx, r23.xyzx
lt r14.y, r19.w, l(0)
dp3 r16.w, r24.xyzx, l(0.33, 0.33, 0.33, 0)
mad r23.xyz, r21.xyzx, r23.xyzx, -r16.wwww
mad r23.xyz, r23.xyzx, l(1.6, 1.6, 1.6, 0), r16.wwww
max r23.xyz, r23.xyzx, l(0, 0, 0, 0)
mul r23.xyz, r13.wwww, r23.xyzx
movc r23.xyz, r14.yyyy, r23.xyzx, r24.xyzx
mad r19.xyz, |r19.wwww|, r23.xyzx, r16.xyzx
mul r21.xyz, |r19.wwww|, r21.xyzx
mul r21.xyz, r14.zzzz, r21.xyzx
mad r22.xyz, v2.xyzx, r0.yyyy, -r22.xyzx
dp3 r13.w, r22.xyzx, r22.xyzx
rsq r13.w, r13.w
mul r22.xyz, r13.wwww, r22.xyzx
dp3_sat r13.w, -r22.xyzx, r8.xzwx
log r13.w, r13.w
mul r13.w, r13.w, l(1000)
exp r13.w, r13.w
mul r22.xyz, r13.wwww, r21.xyzx
mad r20.xyz, r21.xyzx, r13.wwww, r17.xyzx
dp3 r13.w, r22.xyzx, l(1, 1, 1, 0)
mad r18.zw, r14.xxxw, r13.wwww, r18.xxxy
else 
mov r19.xyz, r16.xyzx
mov r20.xyz, r17.xyzx
mov r18.zw, r18.xxxy
endif 
ret 
label label[1]
ubfe r13.w, l(10), l(10), cb7[r12.w + 3].w
f16tof32 r14.x, cb7[r13.w + 326].x
ushr r14.y, cb7[r13.w + 326].x, l(16)
f16tof32 r14.y, r14.y
add r21.xyz, -r5.xyzx, cb7[r13.w + 323].xyzx
dp3 r14.z, r21.xyzx, r21.xyzx
sqrt r14.z, r14.z
div r21.xyz, r21.xyzx, r14.zzzz
dp3 r16.w, cb7[r13.w + 324].xyzx, -r21.xyzx
add_sat r17.w, -r16.w, cb7[r13.w + 324].w
mad_sat r14.x, -r16.w, r14.y, r14.x
eq r14.y, r17.w, l(0)
eq r16.w, r14.x, l(0)
and r14.y, r14.y, r16.w
if_z r14.y
ushr r22.xyz, cb7[r13.w + 326].yzwy, l(16, 16, 16, 0)
f16tof32 r14.y, cb7[r13.w + 323].w
ushr r16.w, cb7[r13.w + 323].w, l(16)
f16tof32 r16.w, r16.w
ushr r23, cb7[r13.w + 325], l(16, 16, 16, 16)
f16tof32 r24.xyz, cb7[r13.w + 326].yzwy
f16tof32 r22.xyz, r22.xyzx
f16tof32 r25, cb7[r13.w + 325].xzyw
f16tof32 r23, r23
mad_sat r13.w, -r14.z, r16.w, r14.y
mul r13.w, r13.w, r13.w
mul r26.x, r14.z, r22.z
mad_sat r14.y, r14.z, r22.x, -r24.x
mov_sat r26.x, r26.x
add r14.y, r14.y, -r26.x
max r14.y, r14.y, l(0)
mul r14.y, r14.y, r14.y
dp3 r14.z, r8.xzwx, r21.xyzx
mad_sat r14.z, r14.z, l(0.88), l(0.12)
mul r13.w, r13.w, r17.w
mov r24.w, r22.y
dp3 r16.w, r24.ywzy, -r21.xyzx
mov r22.xz, r25.yywy
mov r22.y, r23.z
add_sat r22.xyz, -r16.wwww, r22.xyzx
mul r14.x, r14.y, r14.x
mul r14.x, r23.w, r14.x
mad r22.xyz, r13.wwww, r22.xyzx, r14.xxxx
mul r22.xyz, r11.wwww, r22.xyzx
mov r25.y, r23.x
mul r22.xyz, r22.xyzx, r25.xyzx
mul r23.xzw, r9.xxyz, r22.xxyz
mad r19.xyz, r14.zzzz, r23.xzwx, r16.xyzx
mul r14.xyz, r14.zzzz, r22.xyzx
mul r14.xyz, r23.yyyy, r14.xyzx
mad r21.xyz, v2.xyzx, r0.yyyy, -r21.xyzx
dp3 r13.w, r21.xyzx, r21.xyzx
rsq r13.w, r13.w
mul r21.xyz, r13.wwww, r21.xyzx
dp3_sat r13.w, -r21.xyzx, r8.xzwx
log r13.w, r13.w
mul r13.w, r13.w, l(1000)
exp r13.w, r13.w
mul r21.xyz, r13.wwww, r14.xyzx
mad r20.xyz, r14.xyzx, r13.wwww, r17.xyzx
dp3 r13.w, r21.xyzx, l(1, 1, 1, 0)
add r18.zw, r13.wwww, r18.xxxy
else 
mov r19.xyz, r16.xyzx
mov r20.xyz, r17.xyzx
mov r18.zw, r18.xxxy
endif 
ret 
label label[2]
ubfe r13.w, l(10), l(10), cb7[r12.w + 3].w
ushr r14.xy, cb7[r13.w + 324].zwzz, l(16, 16, 0, 0)
f16tof32 r21.xy, cb7[r13.w + 324].zwzz
f16tof32 r21.zw, r14.xxxy
f16tof32 r14.x, cb7[r13.w + 323].w
ushr r14.y, cb7[r13.w + 323].w, l(16)
f16tof32 r14.y, r14.y
add r22.xyz, r5.xyzx, -cb7[r13.w + 323].xyzx
dp3 r14.z, r22.xzyx, r21.xyzx
mul_sat r14.z, r21.w, r14.z
mad r22.xyz, r14.zzzz, r21.xzyx, cb7[r13.w + 323].xyzx
add r22.xyz, -r5.xyzx, r22.xyzx
dp3 r16.w, r22.xyzx, r22.xyzx
sqrt r16.w, r16.w
mad_sat r14.x, -r16.w, r14.y, r14.x
mul r14.x, r14.x, r14.x
ne r14.y, r14.x, l(0)
if_nz r14.y
ushr r23.xy, cb7[r13.w + 324].xyxx, l(16, 16, 0, 0)
f16tof32 r24.xy, cb7[r13.w + 324].xyxx
f16tof32 r24.zw, r23.xxxy
ushr r23.xyz, cb7[r13.w + 325].zxyz, l(16, 16, 16, 0)
f16tof32 r25, cb7[r13.w + 325].zwxy
f16tof32 r23.xyz, r23.yxzy
div r22.xyz, r22.xyzx, r16.wwww
mov r26.xz, r25.zzwz
mov r26.y, r23.x
dp3 r14.y, r26.xyzx, -r22.xyzx
add_sat r14.y, -r14.y, r23.z
dp3 r16.w, r8.xzwx, r22.xyzx
mul r14.x, r14.y, r14.x
mov r23.xz, r25.xxyx
mad r22.xyz, r23.xyzx, r14.zzzz, r24.xzyx
mul r14.xyz, r14.xxxx, r22.xyzx
mul r22.xyz, r9.xyzx, r14.xyzx
mad r19.xyz, |r16.wwww|, r22.xyzx, r16.xyzx
ne r17.w, r24.w, l(0)
if_nz r17.w
ushr r17.w, cb7[r13.w + 325].w, l(16)
f16tof32 r17.w, r17.w
add r22.xyz, -r5.xyzx, cb7[r13.w + 323].xyzx
dp3 r13.w, r12.xyzx, r22.xyzx
dp3 r19.w, r12.xzyx, r21.xyzx
dp3 r20.w, r22.xzyx, r21.xyzx
mad r13.w, r13.w, r19.w, -r20.w
dp3 r20.w, r21.xyzx, r21.xyzx
mad r19.w, -r19.w, r19.w, r20.w
div_sat r13.w, r13.w, r19.w
mad r21.xyz, r13.wwww, r21.xzyx, r22.xyzx
dp3 r13.w, r21.xyzx, r12.xyzx
mad r22.xyz, r13.wwww, r12.xyzx, -r21.xyzx
add r13.w, -r17.w, l(1.2)
mul r13.w, r13.w, l(0.25)
dp3 r17.w, r22.xyzx, r22.xyzx
sqrt r17.w, r17.w
div_sat r13.w, r13.w, r17.w
mad r21.xyz, r22.xyzx, r13.wwww, r21.xyzx
dp3 r13.w, r21.xyzx, r21.xyzx
rsq r13.w, r13.w
mad r21.xyz, -r21.xyzx, r13.wwww, r1.zxyz
dp3 r13.w, r21.xyzx, r21.xyzx
rsq r13.w, r13.w
mul r21.xyz, r13.wwww, r21.xyzx
dp3_sat r13.w, -r21.xyzx, r8.xzwx
mul r14.xyz, |r16.wwww|, r14.xyzx
log r13.w, r13.w
mul r13.w, r13.w, l(1000)
exp r13.w, r13.w
mul r14.xyz, r13.wwww, r14.xyzx
mul r21.xyz, r24.wwww, r14.xyzx
mad r20.xyz, r14.xyzx, r24.wwww, r17.xyzx
dp3 r13.w, r21.xyzx, l(1, 1, 1, 0)
add r18.zw, r13.wwww, r18.xxxy
else 
mov r20.xyz, r17.xyzx
mov r18.zw, r18.xxxy
endif 
else 
mov r19.xyz, r16.xyzx
mov r20.xyz, r17.xyzx
mov r18.zw, r18.xxxy
endif 
ret 
label label[3]
mov r19.xyz, r16.xyzx
mov r20.xyz, r17.xyzx
mov r18.zw, r18.xxxy
ret 
// instr=1566 tex/ld=38
