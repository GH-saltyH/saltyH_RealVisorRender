// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | POSITION0 r0 sv0 maskf; NORMAL0 r1 sv0 mask7; TEXCOORD0 r2 sv0 mask3; TANGENT0 r3 sv0 mask7
// OSGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask7; TEXCOORD1 r2 sv0 mask7; TEXCOORD2 r3 sv0 mask3; TEXCOORD3 r3 sv0 maskc
vs_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb10[3]
dcl_constantbuffer cb11[7]
dcl_input v0
dcl_input v3.xy
dcl_output_siv o0 sv1
dcl_output o1.xyz
dcl_output o2.xyz
dcl_output o3.xy
dcl_output o3.zw
dcl_temps 2
frc r0.xy, v3.xyxx
add r0.z, -r0.y, l(1)
mad o0.xy, r0.xzxx, l(2, 2, 0, 0), l(-1, -1, 0, 0)
mov o0.zw, l(0, 0, 0, 1)
mov r0.w, l(1)
dp4 r0.x, v0, cb10[0]
dp4 r0.y, v0, cb10[1]
dp4 r0.z, v0, cb10[2]
dp4 r1.x, r0, cb11[4]
dp4 r1.y, r0, cb11[5]
dp4 r1.z, r0, cb11[6]
add o1.xyz, r1.xyzx, l(-2147483648, -2147483648, -0.002, 0)
mov o2.xyz, r0.xyzx
dp4 o3.x, r0, cb11[0]
dp4 o3.y, r0, cb11[1]
mov o3.zw, v3.xxxy
ret 
// instr=17 tex/ld=0
