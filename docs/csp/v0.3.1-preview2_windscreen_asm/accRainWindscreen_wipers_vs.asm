// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | POSITION0 r0 sv0 maskf; NORMAL0 r1 sv0 mask7; TEXCOORD0 r2 sv0 mask3; TANGENT0 r3 sv0 mask7; SV_InstanceID0 r4 sv8 mask1
// OSGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask7; TEXCOORD1 r2 sv0 mask7
vs_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb11[7]
dcl_constantbuffer cb0[8]
dcl_constantbuffer cb8[1]
dcl_input v0
dcl_input_sgv v4.x sv8
dcl_output_siv o0 sv1
dcl_output o1.xyz
dcl_output o2.xyz
dcl_temps 3
utof r0.x, v4.x
mad r0.x, r0.x, cb8[0].x, l(-0.5)
dp4 r1.x, v0, cb11[4]
dp4 r1.y, v0, cb11[5]
dp4 r1.z, v0, cb11[6]
dp4 r2.x, v0, cb11[0]
dp4 r2.y, v0, cb11[1]
dp4 r2.z, v0, cb11[2]
add r0.yzw, r1.xxyz, -r2.xxyz
add r1.xyz, -r1.xyzx, r2.xyzx
mad r0.xyz, r0.xxxx, r0.yzwy, r2.xyzx
mov r0.w, l(1)
dp4 r2.x, r0, cb0[0]
dp4 r2.y, r0, cb0[1]
dp4 r2.z, r0, cb0[2]
dp4 r2.w, r0, cb0[3]
dp4 o0.x, r2, cb0[4]
dp4 o0.y, r2, cb0[5]
dp4 o0.z, r2, cb0[6]
dp4 o0.w, r2, cb0[7]
mov o1.xyz, v0.xyzx
dp3 r0.x, r1.xyzx, cb0[0].xyzx
dp3 r0.y, r1.xyzx, cb0[1].xyzx
dp3 r0.z, r1.xyzx, cb0[2].xyzx
dp3 r1.x, r0.xyzx, cb0[4].xyzx
dp3 r1.y, r0.xyzx, cb0[5].xyzx
dp3 r1.z, r0.xyzx, cb0[6].xyzx
mul o2.xyz, r1.xyzx, cb8[0].wwww
ret 
// instr=29 tex/ld=0
