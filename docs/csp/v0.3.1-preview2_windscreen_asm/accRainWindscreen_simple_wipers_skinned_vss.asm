// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | POSITION0 r0 sv0 maskf; NORMAL0 r1 sv0 mask7; TEXCOORD0 r2 sv0 mask3; TANGENT0 r3 sv0 mask7; TEXCOORD1 r4 sv0 maskf; TEXCOORD2 r5 sv0 maskf; SV_InstanceID0 r6 sv8 mask1
// OSGN | SV_POSITION0 r0 sv1 maskf; SV_ClipDistance0 r1 sv2 mask1
vs_5_0
dcl_globalFlags 0x1
dcl_immediateConstantBuffer { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
dcl_constantbuffer cb0[8]
dcl_constantbuffer cb11[5]
dcl_constantbuffer cb13[220] dynamicIndexed
dcl_constantbuffer cb8[8]
dcl_input v0
dcl_input v4
dcl_input v5
dcl_input_sgv v6.x sv8
dcl_output_siv o0 sv1
dcl_output_siv o1.x sv2
dcl_temps 5
mov r0, l(0, 0, 0, 0)
loop 
ige r1.x, r0.w, l(4)
breakc_nz r1.x
dp4 r1.x, v4, icb[r0.w]
ne r1.y, r1.x, l(0)
if_nz r1.y
dp4 r1.y, v5, icb[r0.w]
ftou r1.y, r1.y
ishl r1.y, r1.y, l(2)
mul r2.xyz, v0.yyyy, cb13[r1.y + 1].xyzx
mad r2.xyz, cb13[r1.y].xyzx, v0.xxxx, r2.xyzx
mad r2.xyz, cb13[r1.y + 2].xyzx, v0.zzzz, r2.xyzx
mad r1.yzw, cb13[r1.y + 3].xxyz, v0.wwww, r2.xxyz
add r1.yzw, r1.yyzw, cb11[4].xxyz
mad r0.xyz, r1.yzwy, r1.xxxx, r0.xyzx
endif 
iadd r0.w, r0.w, l(1)
endloop 
mov r0.w, l(1)
dp4 r1.x, r0, cb11[0]
dp4 r1.y, r0, cb11[1]
dp4 r1.z, r0, cb11[2]
dp4 r1.w, r0, cb11[3]
movc r0, v6.xxxx, cb8[0], cb0[0]
movc r2, v6.xxxx, cb8[1], cb0[1]
movc r3, v6.xxxx, cb8[2], cb0[2]
movc r4, v6.xxxx, cb8[3], cb0[3]
dp4 r0.x, r1, r0
dp4 r0.y, r1, r2
dp4 r0.z, r1, r3
dp4 r0.w, r1, r4
movc r1, v6.xxxx, cb8[4], cb0[4]
movc r2, v6.xxxx, cb8[5], cb0[5]
movc r3, v6.xxxx, cb8[6], cb0[6]
movc r4, v6.xxxx, cb8[7], cb0[7]
dp4 r1.x, r0, r1
dp4 o0.y, r0, r2
dp4 o0.z, r0, r3
dp4 r0.x, r0, r4
add r0.y, -r0.x, r1.x
mul r2.x, r0.y, l(0.5)
add r0.y, r0.x, r1.x
mul r0.y, r0.y, l(0.5)
mov r2.y, -r2.x
movc r0.yz, v6.xxxx, r2.xxyx, r0.yyyy
mov o0.xw, r0.yyyx
mov o1.x, r0.z
ret 
// instr=49 tex/ld=0
