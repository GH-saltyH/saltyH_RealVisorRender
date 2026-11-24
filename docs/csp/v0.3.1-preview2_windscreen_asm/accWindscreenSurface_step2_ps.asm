// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask3
// OSGN | SV_TARGET0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb10[1]
dcl_sampler s5
dcl_sampler s8
dcl_resource_texture2d (float) t0
dcl_input_ps linear noperspective v1.xy
dcl_output o0
dcl_temps 4
sample_l r0, v1.xyxx, t0, s5, l(0)
ne r1.x, l(0, 0, 0, 0), r0.w
if_z r1.x
mov o0, l(0, 0, 0, 0)
ret 
endif 
mov r1, r0
mov r2.x, l(-16)
loop 
ilt r2.y, l(16), r2.x
breakc_nz r2.y
if_z r2.x
mov r2.x, l(1)
continue 
endif 
imax r2.y, -r2.x, r2.x
itof r2.y, r2.y
mad r2.y, r2.y, l(0.1), l(1)
div r2.y, l(1, 1, 1, 1), r2.y
itof r2.z, r2.x
mad r2.zw, cb10[0].xxxy, r2.zzzz, v1.xxxy
sample_l r3, r2.zwzz, t0, s8, l(0)
mad r1, r3, r2.yyyy, r1
iadd r2.x, r2.x, l(1)
endloop 
mul r0, r1, l(0.0512583, 0.0512583, 0.0512583, 0.0512583)
ne r1.x, l(0, 0, 0, 0), cb10[0].x
dp3 r1.y, r0.xyzx, r0.xyzx
rsq r1.y, r1.y
mul r1.yzw, r0.xxyz, r1.yyyy
movc o0.xyz, r1.xxxx, r1.yzwy, r0.xyzx
mov o0.w, r0.w
ret 
// instr=33 tex/ld=2
