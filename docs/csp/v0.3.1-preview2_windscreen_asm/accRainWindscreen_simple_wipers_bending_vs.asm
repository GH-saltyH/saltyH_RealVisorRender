// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | POSITION0 r0 sv0 maskf; NORMAL0 r1 sv0 mask7; TEXCOORD0 r2 sv0 mask3; TANGENT0 r3 sv0 mask7
// OSGN | SV_POSITION0 r0 sv1 maskf
vs_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb13[24] dynamicIndexed
dcl_constantbuffer cb12[8] dynamicIndexed
dcl_constantbuffer cb0[8]
dcl_constantbuffer cb11[4]
dcl_input v0
dcl_output_siv o0 sv1
dcl_temps 4
dp4 r0.x, v0, cb11[0]
dp4 r0.y, v0, cb11[1]
dp4 r0.z, v0, cb11[2]
dp4 r1.w, v0, cb11[3]
mov r2.xyz, r0.xyzx
mov r0.w, l(1)
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
mad r2.xyz, cb12[r2.w].xyzx, r3.xxxx, r2.xyzx
add r3.y, l(-1), cb12[r2.w].w
mad r3.x, r3.x, r3.y, l(1)
mul r0.w, r0.w, r3.x
iadd r2.w, r2.w, l(1)
endloop 
add r0.w, r0.w, r0.w
add r2.xyz, -r0.xyzx, r2.xyzx
mad r1.xyz, r0.wwww, r2.xyzx, r0.xyzx
dp4 r0.x, r1, cb0[0]
dp4 r0.y, r1, cb0[1]
dp4 r0.z, r1, cb0[2]
dp4 r0.w, r1, cb0[3]
dp4 o0.x, r0, cb0[4]
dp4 o0.y, r0, cb0[5]
dp4 o0.z, r0, cb0[6]
dp4 o0.w, r0, cb0[7]
ret 
// instr=42 tex/ld=0
