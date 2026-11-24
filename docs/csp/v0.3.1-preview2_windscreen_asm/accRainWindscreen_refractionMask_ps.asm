// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf
// OSGN | SV_TARGET0 r0 sv0 mask3
ps_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb10[1]
dcl_output o0.xy
mov o0.xy, cb10[0].xyxx
ret 
// instr=2 tex/ld=0
