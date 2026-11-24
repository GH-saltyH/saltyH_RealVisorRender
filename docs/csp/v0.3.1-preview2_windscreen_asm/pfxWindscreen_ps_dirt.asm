// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD1 r1 sv0 mask3; TEXCOORD2 r1 sv0 mask4
// OSGN | SV_TARGET0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_input_ps linear v1.xy
dcl_input_ps linear v1.z
dcl_output o0
dcl_temps 1
dp2 r0.x, v1.xyxx, v1.xyxx
add r0.x, -r0.x, l(1)
lt r0.x, r0.x, l(0)
discard_nz r0.x
mov o0, v1.zzzz
ret 
// instr=6 tex/ld=0
