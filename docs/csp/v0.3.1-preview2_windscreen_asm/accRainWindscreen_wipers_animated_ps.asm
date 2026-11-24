// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask7; TEXCOORD2 r1 sv0 mask8; TEXCOORD1 r2 sv0 mask7; TEXCOORD3 r2 sv0 mask8; TEXCOORD4 r3 sv0 mask1
// OSGN | SV_TARGET0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_input_ps linear noperspective v1.w
dcl_input_ps linear noperspective v2.xy
dcl_input_ps linear noperspective v2.w
dcl_input_ps linear noperspective v3.x
dcl_output o0
dcl_temps 1
add r0.x, -v1.w, l(1)
min r0.x, r0.x, v1.w
min r0.x, r0.x, v2.w
lt r0.x, r0.x, l(0)
discard_nz r0.x
mad o0.xy, v2.xyxx, l(0.5, 0.5, 0, 0), l(0.5, 0.5, 0, 0)
mov o0.z, v3.x
mov o0.w, l(1)
ret 
// instr=9 tex/ld=0
