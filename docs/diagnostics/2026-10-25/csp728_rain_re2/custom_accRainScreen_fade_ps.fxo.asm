// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask3
// OSGN | SV_TARGET0 r0 sv0 mask1
ps_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb10[1]
dcl_resource_texture2d (float) t0
dcl_input_ps_siv v0.xy sv1
dcl_output o0.x
dcl_temps 1
ftoi r0.xy, v0.xyxx
mov r0.zw, l(0, 0, 0, 0)
ld r0.x, r0, t0
min r0.x, r0.x, l(0.8)
mad o0.x, -cb10[0].y, l(2), r0.x
ret 
// instr=6 tex/ld=1
