// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask3
// OSGN | SV_TARGET0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb10[5]
dcl_sampler s5
dcl_resource_texture2d (float) t0
dcl_resource_texture2d (float) t1
dcl_input_ps linear noperspective v1.xy
dcl_output o0
dcl_temps 2
sample_l r0.x, v1.xyxx, t1, s5, l(0)
eq r0.y, r0.x, l(1)
if_nz r0.y
mov o0, l(0, 0, 0, 0)
ret 
endif 
sample_l r0.yzw, v1.xyxx, t0.wxyz, s5, l(0)
mad r0.yzw, r0.yyzw, l(0, 2, 2, 2), l(0, -1, -1, -1)
dp3 r1.x, r0.yzwy, r0.yzwy
rsq r1.x, r1.x
mul r0.yzw, r0.yyzw, r1.xxxx
dp3 r1.x, r0.yzwy, cb10[0].xyzx
dp3 r1.y, r0.yzwy, cb10[1].xyzx
dp3 r1.z, r0.yzwy, cb10[2].xyzx
lt r0.y, l(0), r1.y
movc r0.yzw, r0.yyyy, -r1.xxyz, r1.xxyz
dp3 r1.x, r0.yzwy, cb10[4].xyzx
add r1.x, -r1.x, l(1)
mul r1.x, r1.x, r1.x
mul r1.x, r1.x, r1.x
mad r0.yzw, cb10[4].xxyz, r1.xxxx, r0.yyzw
dp3 r1.x, r0.yzwy, r0.yzwy
rsq r1.x, r1.x
mul o0.xyz, r0.yzwy, r1.xxxx
mov o0.w, r0.x
ret 
// instr=26 tex/ld=2
