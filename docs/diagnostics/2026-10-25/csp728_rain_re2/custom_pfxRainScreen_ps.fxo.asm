// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD1 r1 sv0 mask3; TEXCOORD2 r1 sv0 mask4; TEXCOORD3 r1 sv0 mask8
// OSGN | SV_Target0 r0 sv0 mask1
ps_5_0
dcl_globalFlags 0x1
dcl_input_ps linear v1.xy
dcl_input_ps linear v1.w
dcl_output o0.x
dcl_temps 1
dp2 r0.x, v1.xyxx, v1.xyxx
sqrt r0.x, r0.x
add r0.y, -r0.x, l(1)
add r0.x, r0.x, l(-1)
mul_sat r0.x, r0.x, l(-1.25)
lt r0.y, r0.y, l(0)
discard_nz r0.y
mad r0.y, r0.x, l(-2), l(3)
mul r0.x, r0.x, r0.x
mul r0.x, r0.x, r0.y
min r0.x, r0.x, l(1)
mul o0.x, r0.x, v1.w
ret 
// instr=13 tex/ld=0
