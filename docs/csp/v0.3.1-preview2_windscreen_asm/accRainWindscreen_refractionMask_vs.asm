// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | POSITION0 r0 sv0 maskf; NORMAL0 r1 sv0 mask7; TEXCOORD0 r2 sv0 mask3; TANGENT0 r3 sv0 mask7
// OSGN | SV_POSITION0 r0 sv1 maskf
vs_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb10[4]
dcl_constantbuffer cb0[8]
dcl_input v0
dcl_output_siv o0 sv1
dcl_temps 2
dp4 r0.x, v0, cb10[0]
dp4 r0.y, v0, cb10[1]
dp4 r0.z, v0, cb10[2]
dp4 r0.w, v0, cb10[3]
dp4 r1.x, r0, cb0[0]
dp4 r1.y, r0, cb0[1]
dp4 r1.z, r0, cb0[2]
dp4 r1.w, r0, cb0[3]
dp4 o0.x, r1, cb0[4]
dp4 o0.y, r1, cb0[5]
dp4 o0.z, r1, cb0[6]
dp4 o0.w, r1, cb0[7]
ret 
// instr=13 tex/ld=0
