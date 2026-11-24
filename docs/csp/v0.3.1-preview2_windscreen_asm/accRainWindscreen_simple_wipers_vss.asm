// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | POSITION0 r0 sv0 maskf; NORMAL0 r1 sv0 mask7; TEXCOORD0 r2 sv0 mask3; TANGENT0 r3 sv0 mask7; SV_InstanceID0 r4 sv8 mask1
// OSGN | SV_POSITION0 r0 sv1 maskf; SV_ClipDistance0 r1 sv2 mask1
vs_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb0[8]
dcl_constantbuffer cb11[4]
dcl_constantbuffer cb8[8]
dcl_input v0
dcl_input_sgv v4.x sv8
dcl_output_siv o0 sv1
dcl_output_siv o1.x sv2
dcl_temps 4
movc r0, v4.xxxx, cb8[4], cb0[4]
movc r1, v4.xxxx, cb8[0], cb0[0]
dp4 r2.x, v0, cb11[0]
dp4 r2.y, v0, cb11[1]
dp4 r2.z, v0, cb11[2]
dp4 r2.w, v0, cb11[3]
dp4 r1.x, r2, r1
movc r3, v4.xxxx, cb8[1], cb0[1]
dp4 r1.y, r2, r3
movc r3, v4.xxxx, cb8[2], cb0[2]
dp4 r1.z, r2, r3
movc r3, v4.xxxx, cb8[3], cb0[3]
dp4 r1.w, r2, r3
dp4 r0.x, r1, r0
movc r2, v4.xxxx, cb8[7], cb0[7]
dp4 r0.y, r1, r2
add r0.z, r0.y, r0.x
add r0.x, -r0.y, r0.x
mov o0.w, r0.y
mul r0.xz, r0.xxzx, l(0.5, 0, 0.5, 0)
mov r0.y, -r0.x
movc r0.xy, v4.xxxx, r0.xyxx, r0.zzzz
mov o0.x, r0.x
mov o1.x, r0.y
movc r0, v4.xxxx, cb8[5], cb0[5]
dp4 o0.y, r1, r0
movc r0, v4.xxxx, cb8[6], cb0[6]
dp4 o0.z, r1, r0
ret 
// instr=29 tex/ld=0
