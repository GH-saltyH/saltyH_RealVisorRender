// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | POSITION0 r0 sv0 maskf; NORMAL0 r1 sv0 mask7; TEXCOORD0 r2 sv0 mask3; TANGENT0 r3 sv0 mask7; TEXCOORD1 r4 sv0 maskf; TEXCOORD2 r5 sv0 maskf
// OSGN | SV_POSITION0 r0 sv1 maskf
vs_5_0
dcl_globalFlags 0x1
dcl_immediateConstantBuffer { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
dcl_constantbuffer cb0[8]
dcl_constantbuffer cb11[5]
dcl_constantbuffer cb13[220] dynamicIndexed
dcl_input v0
dcl_input v4
dcl_input v5
dcl_output_siv o0 sv1
dcl_temps 3
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
dp4 r0.x, r1, cb0[0]
dp4 r0.y, r1, cb0[1]
dp4 r0.z, r1, cb0[2]
dp4 r0.w, r1, cb0[3]
dp4 o0.x, r0, cb0[4]
dp4 o0.y, r0, cb0[5]
dp4 o0.z, r0, cb0[6]
dp4 o0.w, r0, cb0[7]
ret 
// instr=33 tex/ld=0
