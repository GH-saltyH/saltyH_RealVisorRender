// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask7; TEXCOORD1 r2 sv0 mask3; TEXCOORD2 r2 sv0 maskc
// OSGN | SV_TARGET0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb11[7]
dcl_sampler s10
dcl_resource_texture2d (float) t0
dcl_resource_texture2d (float) t1
dcl_input_ps_siv v0.xy sv1
dcl_input_ps linear v1.xyz
dcl_input_ps linear v2.zw
dcl_output o0
dcl_temps 4
deriv_rtx_coarse r0.xyz, v1.xyzx
dp3 r0.w, r0.xyzx, r0.xyzx
rsq r0.w, r0.w
mul r0.xyz, r0.wwww, r0.xyzx
add r1.xy, v2.zwzz, l(-0.5, -0.5, 0, 0)
lt r1.xy, l(0.499, 0.499, 0, 0), |r1.xyxx|
or r0.w, r1.y, r1.x
sample_l r1, v2.zwzz, t0, s10, l(0)
movc r1, r0.wwww, l(0, 0, 0, 0), r1
mad r1.xy, r1.xyxx, l(2, 2, 0, 0), l(-1, -1, 0, 0)
dp2 r2.x, r1.xyxx, cb11[4].xyxx
dp2 r2.y, r1.xyxx, cb11[5].xyxx
dp2 r2.z, r1.xyxx, cb11[6].xyxx
dp3 r0.x, r2.xyzx, r0.xyzx
deriv_rty_coarse r3.xyz, v1.xyzx
dp3 r0.z, r3.xyzx, r3.xyzx
rsq r0.z, r0.z
mul r3.xyz, r0.zzzz, r3.xyzx
dp3 r0.y, r2.xyzx, r3.xyzx
dp3 r0.z, r2.xyzx, l(1, 1, 1, 0)
lt r0.z, l(0.001), |r0.z|
mad r0.xy, r0.xyxx, l(0.5, 0.5, 0, 0), l(0.5, 0.5, 0, 0)
movc r0.xy, r0.zzzz, r0.xyxx, l(0.5, 0.5, 0, 0)
ftoi r2.xy, v0.xyxx
mov r2.zw, l(0, 0, 0, 0)
ld r2.xyz, r2, t1
add r0.xy, r0.xyxx, -r2.xyxx
mul_sat r0.z, r1.w, l(10)
mad o0.xy, r0.zzzz, r0.xyxx, r2.xyxx
ne r0.x, l(0, 0, 0, 0), r1.z
movc o0.z, r0.x, r1.z, r2.z
mov o0.w, r1.w
ret 
// instr=33 tex/ld=2
