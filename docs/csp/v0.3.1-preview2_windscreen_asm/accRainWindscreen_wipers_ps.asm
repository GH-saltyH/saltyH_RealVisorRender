// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask7; TEXCOORD1 r2 sv0 mask7
// OSGN | SV_TARGET0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb11[2]
dcl_input_ps linear noperspective v1.xyz
dcl_input_ps linear noperspective v2.xy
dcl_output o0
dcl_temps 1
add r0.xyz, v1.xyzx, -cb11[0].xyzx
dp3 r0.x, r0.xyzx, r0.xyzx
sqrt r0.x, r0.x
mad o0.z, r0.x, cb11[0].w, cb11[1].x
mad o0.xy, v2.xyxx, l(0.5, 0.5, 0, 0), l(0.5, 0.5, 0, 0)
mov o0.w, l(1)
ret 
// instr=7 tex/ld=0
