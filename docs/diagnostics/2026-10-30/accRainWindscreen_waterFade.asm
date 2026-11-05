// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask3
// OSGN | SV_TARGET0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb12[2]
dcl_sampler s5
dcl_resource_texture2d (float) t0
dcl_resource_texture2d (float) t2
dcl_resource_texture2d (float) t20
dcl_input_ps_siv v0.xy sv1
dcl_input_ps linear noperspective v1.xy
dcl_output o0
dcl_temps 2
mul r0.xy, v1.xyxx, l(2.2, 2.2, 0, 0)
sample_l r0.x, r0.xyxx, t20, s5, l(0)
mad_sat r0.x, r0.x, l(30), l(-10)
add r0.y, -cb12[0].y, cb12[0].x
mad r0.x, r0.x, r0.y, cb12[0].y
ftoi r1.xy, v0.xyxx
mov r1.zw, l(0, 0, 0, 0)
ld r0.y, r1, t0.xzyw
add r0.x, -r0.x, r0.y
max r0.x, r0.x, l(0)
sample_l r0.y, v1.xyxx, t2.xwyz, s5, l(0)
add r0.y, -r0.y, l(1)
mul r0.x, r0.y, r0.x
min o0.z, r0.x, cb12[1].x
mov o0.xyw, l(0, 0, 0, 0)
ret 
// instr=16 tex/ld=3
