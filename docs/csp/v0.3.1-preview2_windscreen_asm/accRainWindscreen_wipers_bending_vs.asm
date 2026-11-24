// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | POSITION0 r0 sv0 maskf; NORMAL0 r1 sv0 mask7; TEXCOORD0 r2 sv0 mask3; TANGENT0 r3 sv0 mask7; SV_InstanceID0 r4 sv8 mask1
// OSGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask7; TEXCOORD1 r2 sv0 mask7
vs_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb11[7]
dcl_constantbuffer cb13[24] dynamicIndexed
dcl_constantbuffer cb12[16] dynamicIndexed
dcl_constantbuffer cb0[8]
dcl_constantbuffer cb8[1]
dcl_input v0
dcl_input_sgv v4.x sv8
dcl_output_siv o0 sv1
dcl_output o1.xyz
dcl_output o2.xyz
dcl_temps 4
utof r0.x, v4.x
mad r0.x, r0.x, cb8[0].x, l(-0.5)
dp4 r1.x, v0, cb11[0]
dp4 r1.y, v0, cb11[1]
dp4 r1.z, v0, cb11[2]
mov r2.xyz, r1.xyzx
mov r0.yz, l(0, 1, 0, 0)
loop 
ige r0.w, r0.z, l(8)
breakc_nz r0.w
imul null, r0.w, r0.z, l(3)
mad r3.xyz, v0.xyzx, cb13[r0.w + 1].xyzx, cb13[r0.w].xyzx
dp3 r1.w, r3.xyzx, r3.xyzx
sqrt r1.w, r1.w
add r1.w, -r1.w, l(1)
max r1.w, r1.w, l(0)
mad_sat r1.w, r1.w, cb13[r0.w].w, cb13[r0.w + 1].w
log r1.w, r1.w
mul r1.w, r1.w, cb13[r0.w + 2].x
exp r1.w, r1.w
mul r2.w, r1.w, r1.w
mad r3.x, -r1.w, l(2), l(3)
mad r2.w, r2.w, r3.x, -r1.w
mad r0.w, cb13[r0.w + 2].y, r2.w, r1.w
mad r2.xyz, cb12[r0.z].xyzx, r0.wwww, r2.xyzx
add r1.w, l(-1), cb12[r0.z].w
mad r0.w, r0.w, r1.w, l(1)
mul r0.y, r0.w, r0.y
iadd r0.z, r0.z, l(1)
endloop 
add r0.y, r0.y, r0.y
add r2.xyz, -r1.xyzx, r2.xyzx
mad r0.yzw, r0.yyyy, r2.xxyz, r1.xxyz
dp4 r1.x, v0, cb11[4]
dp4 r1.y, v0, cb11[5]
dp4 r1.z, v0, cb11[6]
mov r2.xyz, r0.yzwy
mov r1.w, l(1)
mov r2.w, l(0)
loop 
ige r3.x, r2.w, l(8)
breakc_nz r3.x
imul null, r3.x, r2.w, l(3)
mad r3.yzw, v0.xxyz, cb13[r3.x + 1].xxyz, cb13[r3.x].xxyz
dp3 r3.y, r3.yzwy, r3.yzwy
sqrt r3.y, r3.y
add r3.y, -r3.y, l(1)
max r3.y, r3.y, l(0)
mad_sat r3.y, r3.y, cb13[r3.x].w, cb13[r3.x + 1].w
log r3.y, r3.y
mul r3.y, r3.y, cb13[r3.x + 2].x
exp r3.y, r3.y
mul r3.z, r3.y, r3.y
mad r3.w, -r3.y, l(2), l(3)
mad r3.z, r3.z, r3.w, -r3.y
mad r3.x, cb13[r3.x + 2].y, r3.z, r3.y
mad r2.xyz, cb12[r2.w + 8].xyzx, r3.xxxx, r2.xyzx
add r3.y, l(-1), cb12[r2.w + 8].w
mad r3.x, r3.x, r3.y, l(1)
mul r1.w, r1.w, r3.x
iadd r2.w, r2.w, l(1)
endloop 
add r1.w, r1.w, r1.w
add r2.xyz, -r0.yzwy, r2.xyzx
mad r0.yzw, r1.wwww, r2.xxyz, r0.yyzw
add r2.xyz, -r0.yzwy, r1.xyzx
mad r2.xyz, r0.xxxx, r2.xyzx, r0.yzwy
add r0.xyz, -r1.xyzx, r0.yzwy
mov r2.w, l(1)
dp4 r1.x, r2, cb0[0]
dp4 r1.y, r2, cb0[1]
dp4 r1.z, r2, cb0[2]
dp4 r1.w, r2, cb0[3]
dp3 r2.x, r0.xyzx, cb0[0].xyzx
dp3 r2.y, r0.xyzx, cb0[1].xyzx
dp3 r2.z, r0.xyzx, cb0[2].xyzx
dp3 r0.x, r2.xyzx, cb0[4].xyzx
dp3 r0.y, r2.xyzx, cb0[5].xyzx
dp3 r0.z, r2.xyzx, cb0[6].xyzx
mul o2.xyz, r0.xyzx, cb8[0].wwww
dp4 o0.x, r1, cb0[4]
dp4 o0.y, r1, cb0[5]
dp4 o0.z, r1, cb0[6]
dp4 o0.w, r1, cb0[7]
mov o1.xyz, v0.xyzx
ret 
// instr=86 tex/ld=0
