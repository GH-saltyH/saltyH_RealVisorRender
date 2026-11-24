// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | POSITION0 r0 sv0 maskf; NORMAL0 r1 sv0 mask7; TEXCOORD0 r2 sv0 mask3; TANGENT0 r3 sv0 mask7
// OSGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 maskf; TEXCOORD2 r2 sv0 mask3
vs_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb10[4]
dcl_input v0
dcl_input v3.xy
dcl_output_siv o0 sv1
dcl_output o1
dcl_output o2.xy
dcl_temps 1
frc r0.xy, v3.xyxx
add r0.z, -r0.y, l(1)
mad o0.xy, r0.xzxx, l(2, 2, 0, 0), l(-1, -1, 0, 0)
mov o0.zw, l(0, 0, 0, 1)
dp4 o1.x, v0, cb10[0]
dp4 o1.y, v0, cb10[1]
dp4 o1.z, v0, cb10[2]
dp4 o1.w, v0, cb10[3]
mov o2.xy, v3.xyxx
ret 
// instr=10 tex/ld=0
