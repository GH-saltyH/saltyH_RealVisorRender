// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask3
// OSGN | SV_TARGET0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb10[3]
dcl_sampler s8
dcl_sampler s9
dcl_resource_texture2d (float) t0
dcl_resource_texture2d (float) t1
dcl_resource_texture2d (float) t2
dcl_input_ps linear noperspective v1.xy
dcl_output o0
dcl_temps 5
mad r0.xy, v1.xyxx, l(2, 2, 0, 0), l(-1, -1, 0, 0)
mad r0.zw, r0.xxxy, l(0, 0, 0.475, 0.475), l(0, 0, 0.5, 0.5)
mad r0.zw, r0.zzzw, cb10[0].zzzw, cb10[0].xxxy
sample_l r1, r0.zwzz, t0.wxyz, s9, l(0)
mov_sat r1.x, r1.x
log r0.z, r1.x
mul r0.z, r0.z, cb10[2].z
exp r0.z, r0.z
mul r0.z, r0.z, l(1.05)
min r0.z, r0.z, l(1)
mul r1.xyz, r1.yzwy, l(0.5, 0.5, 0.5, 0)
max r1.w, r0.z, cb10[2].w
ne r0.z, l(0, 0, 0, 0), cb10[1].w
if_nz r0.z
sincos r2.x, r3.x, cb10[1].z
sincos r4.x, null, -cb10[1].z
mov r4.y, r3.x
dp2 r3.x, r4.yxyy, r0.xyxx
mov r4.z, r2.x
dp2 r3.y, r4.zyzz, r0.xyxx
add r0, r3.xyxy, cb10[1].xyxy
mul r0, r0, cb10[1].wwww
mul r0.xy, r0.xyxx, l(0.8, 0.8, 0, 0)
max r0.x, |r0.y|, |r0.x|
add r0.x, r0.x, l(-1)
mul_sat r0.x, r0.x, l(-10)
mad r0.yz, r0.zzwz, l(0, 0.4, 0.4, 0), l(0, 0.5, 0.5, 0)
mad r0.yz, r0.yyzy, cb10[0].zzwz, cb10[0].xxyx
sample_l r2, r0.yzyy, t1, s8, l(0)
max r0.y, r2.w, l(0.0001)
div r0.yzw, r2.xxyz, r0.yyyy
mad r2.xy, v1.xyxx, cb10[0].zwzz, cb10[0].xyxx
add r0.yz, r0.yyzy, r2.xxyx
sample_l r0.yzw, r0.yzyy, t2.wxyz, s8, r0.w
mul_sat r2.x, r2.w, l(1.4)
mul r0.x, r0.x, r2.x
add r2.x, -r1.w, l(1)
mul r2.y, r0.x, r2.x
mul r3.xyz, r1.wwww, r1.xyzx
mad r0.yzw, r0.yyzw, r2.yyyy, r3.xxyz
mad r2.y, r0.x, r2.x, r1.w
div r1.xyz, r0.yzwy, r2.yyyy
mad r0.x, -r0.x, r2.x, l(1)
mad r1.w, -r2.x, r0.x, l(1)
endif 
lt r0.x, r1.w, l(0.001)
discard_nz r0.x
mov o0, r1
ret 
// instr=49 tex/ld=3
