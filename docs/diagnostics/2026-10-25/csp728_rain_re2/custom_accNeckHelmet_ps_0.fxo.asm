// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask3
// OSGN | SV_TARGET0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb10[3]
dcl_sampler s8
dcl_resource_texture2d (float) t0
dcl_resource_texture2d (float) t1
dcl_resource_texture2d (float) t2
dcl_input_ps linear noperspective v1.xy
dcl_output o0
dcl_temps 5
mad r0.xy, v1.xyxx, l(2, 2, 0, 0), l(-1, -1, 0, 0)
mad r1, r0.xyxy, l(0.475, 0.475, 0.475, 0.475), l(0.5, 0.5, 0.5, 0.5)
mad r1, r1, cb10[0].zwzw, cb10[0].xyxy
add r2, r1.zwzw, l(0.0179095, -0.00315129, 0.00870452, -0.00996964)
sample_l r3, r2.xyxx, t0, s8, l(0)
sample_l r2, r2.zwzz, t0, s8, l(0)
add r2, r2.wxyz, r3.wxyz
add r3, r1.zwzw, l(0.0153916, 0.00723346, 0.0026477, 0.000995146)
sample_l r4, r3.xyxx, t0, s8, l(0)
add r2, r2, r4.wxyz
sample_l r3, r3.zwzz, t0, s8, l(0)
add r2, r2, r3.wxyz
add r3, r1.zwzw, l(0.00421124, 0.0182194, 0.00455547, 0.00988957)
sample_l r4, r3.xyxx, t0, s8, l(0)
add r2, r2, r4.wxyz
sample_l r3, r3.zwzz, t0, s8, l(0)
add r2, r2, r3.wxyz
add r3, r1.zwzw, l(-0.00760546, 0.00229428, -0.00222379, -0.00567186)
sample_l r4, r3.xyxx, t0, s8, l(0)
add r2, r2, r4.wxyz
sample_l r3, r3.zwzz, t0, s8, l(0)
add r2, r2, r3.wxyz
add r3, r1.zwzw, l(-0.00456506, 0.0114266, -0.0106928, -0.00533445)
sample_l r4, r3.xyxx, t0, s8, l(0)
add r2, r2, r4.wxyz
sample_l r3, r3.zwzz, t0, s8, l(0)
add r2, r2, r3.wxyz
add r3, r1.zwzw, l(-0.0117884, -0.0152529, -0.00421111, -0.0192816)
sample_l r4, r3.xyxx, t0, s8, l(0)
add r2, r2, r4.wxyz
sample_l r3, r3.zwzz, t0, s8, l(0)
add r2, r2, r3.wxyz
add r3, r1.zwzw, l(-0.0127672, 0.00951173, -0.0185707, 0.00300369)
sample_l r4, r3.xyxx, t0, s8, l(0)
add r2, r2, r4.wxyz
sample_l r3, r3.zwzz, t0, s8, l(0)
add r2, r2, r3.wxyz
add r1, r1, l(0.0078766, -0.0182893, -0.018723, -0.00642824)
sample_l r3, r1.xyxx, t0, s8, l(0)
add r2, r2, r3.wxyz
sample_l r1, r1.zwzz, t0, s8, l(0)
add r1, r1.wxyz, r2
mul r1, r1, l(0.0625, 0.03125, 0.03125, 0.03125)
mov_sat r1.x, r1.x
log r0.z, r1.x
mul r0.z, r0.z, cb10[2].z
exp r0.z, r0.z
mul r0.z, r0.z, l(1.05)
min r0.z, r0.z, l(1)
max r1.x, r0.z, cb10[2].w
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
add r2.x, -r1.x, l(1)
mul r2.y, r0.x, r2.x
mul r3.xyz, r1.xxxx, r1.yzwy
mad r0.yzw, r0.yyzw, r2.yyyy, r3.xxyz
mad r2.y, r0.x, r2.x, r1.x
div r1.yzw, r0.yyzw, r2.yyyy
mad r0.x, -r0.x, r2.x, l(1)
mad r1.x, -r2.x, r0.x, l(1)
endif 
lt r0.x, r1.x, l(0.001)
discard_nz r0.x
mov o0, r1.yzwx
ret 
// instr=87 tex/ld=18
