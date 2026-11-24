// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_VertexID0 r0 sv6 mask1
// OSGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask7; TEXCOORD2 r1 sv0 mask8; TEXCOORD1 r2 sv0 mask7; TEXCOORD3 r2 sv0 mask8; TEXCOORD4 r3 sv0 mask1
vs_5_0
dcl_globalFlags 0x1
dcl_immediateConstantBuffer { 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0 }
dcl_constantbuffer cb11[5]
dcl_constantbuffer cb5[224] dynamicIndexed
dcl_constantbuffer cb0[8]
dcl_constantbuffer cb8[1]
dcl_sampler s1
dcl_resource_texture2darray (float) t12
dcl_input_sgv v0.x sv6
dcl_output_siv o0 sv1
dcl_output o1.xyz
dcl_output o1.w
dcl_output o2.xyz
dcl_output o2.w
dcl_output o3.x
dcl_temps 7
udiv r0.x, r1.x, v0.x, l(6)
udiv r0.x, r2.x, r0.x, l(10)
utof r0.y, r2.x
add r0.y, r0.y, icb[r1.x].x
mad r0.z, r0.y, l(0.1), l(-1)
ushr r0.w, r0.x, l(1)
and r0.x, r0.x, l(1)
utof r0.x, r0.x
add r0.x, r0.x, icb[r1.x].y
imul null, r1.x, r0.w, l(56)
utof r2.y, r0.w
add r0.w, l(-1), cb5[r1.x + 55].x
div r0.z, r0.z, r0.w
mul r0.xw, r0.xxxy, l(0.5, 0, 0, 0.1)
mad r0.y, r0.y, l(0.1), r2.y
mad o3.x, r0.y, cb11[4].x, cb11[4].y
lt r0.y, cb5[r1.x + 55].x, r0.w
div r1.y, r0.w, cb5[r1.x + 55].x
movc r0.y, r0.y, r0.z, r1.y
add_sat r0.y, -r0.y, l(1)
log r0.y, r0.y
mul r0.y, r0.y, cb5[r1.x + 55].z
exp r0.y, r0.y
add r0.y, -r0.y, l(1)
mul r0.y, r0.y, cb5[r1.x + 55].y
add r1.yzw, -cb5[r1.x + 53].xxyz, cb5[r1.x + 54].xxyz
mad r1.yzw, r0.wwww, r1.yyzw, cb5[r1.x + 53].xxyz
mov o1.w, r0.w
mad r3.xyz, cb5[r1.x + 2].xyzx, r0.yyyy, r1.yzwy
mov r3.w, l(1)
dp4 r4.x, r3, cb5[r1.x + 48]
dp4 r4.y, r3, cb5[r1.x + 49]
dp4 r4.z, r3, cb5[r1.x + 50]
add r0.yzw, -r3.xxyz, r4.xxyz
add r1.yzw, r3.xxyz, -cb5[r1.x].xxyz
dp3 r1.y, r1.yzwy, cb5[r1.x + 1].xyzx
mad r1.z, r1.y, cb5[r1.x].w, -cb5[r1.x + 3].z
mul r2.x, r1.y, cb5[r1.x].w
add r1.y, -cb5[r1.x + 3].z, cb5[r1.x + 3].w
div_sat r1.y, r1.z, r1.y
mad r4.xyz, r1.yyyy, r0.yzwy, r3.xyzx
mov r4.w, l(1)
dp4 r5.x, r4, cb5[r1.x + 32]
dp4 r5.y, r4, cb5[r1.x + 33]
dp4 r5.z, r4, cb5[r1.x + 34]
dp4 r6.x, r4, cb5[r1.x + 12]
dp4 r6.y, r4, cb5[r1.x + 13]
dp4 r6.z, r4, cb5[r1.x + 14]
add r0.yzw, r5.xxyz, -r6.xxyz
mad r1.z, r2.x, cb5[r1.x + 52].z, cb5[r1.x + 52].y
mul r1.z, r1.z, r1.z
mad r1.w, r1.z, cb5[r1.x + 52].x, cb11[4].z
mul r1.z, r1.z, cb5[r1.x + 52].x
mad r0.yzw, r1.wwww, r0.yyzw, r6.xxyz
mov r2.w, cb5[r1.x + 52].w
sample_l r1.w, r2.xwyx, t12.yzwx, s1, l(0)
mad r4.xyz, cb5[r1.x + 2].xyzx, r1.wwww, r0.yzwy
mov r4.w, l(1)
dp4 r5.x, r4, cb11[0]
dp4 r5.y, r4, cb11[1]
dp4 r5.z, r4, cb11[2]
dp4 r4.x, r3, cb5[r1.x + 44]
dp4 r4.y, r3, cb5[r1.x + 45]
dp4 r4.z, r3, cb5[r1.x + 46]
add r0.yzw, -r3.xxyz, r4.xxyz
mad r3.xyz, r1.yyyy, r0.yzwy, r3.xyzx
mov r3.w, l(1)
dp4 r4.x, r3, cb5[r1.x + 32]
dp4 r4.y, r3, cb5[r1.x + 33]
dp4 r4.z, r3, cb5[r1.x + 34]
dp4 r6.x, r3, cb5[r1.x + 12]
dp4 r6.y, r3, cb5[r1.x + 13]
dp4 r6.z, r3, cb5[r1.x + 14]
add r0.yzw, r4.xxyz, -r6.xxyz
mad r0.yzw, r1.zzzz, r0.yyzw, r6.xxyz
mov r2.z, cb5[r1.x + 2].w
sample_l r1.y, r2.xzyx, t12.yxzw, s1, l(0)
mad r1.xyz, cb5[r1.x + 2].xyzx, r1.yyyy, r0.yzwy
mov r1.w, l(1)
dp4 r2.x, r1, cb11[0]
dp4 r2.y, r1, cb11[1]
dp4 r2.z, r1, cb11[2]
add r0.yzw, -r2.xxyz, r5.xxyz
add r1.xyz, -r5.xyzx, r2.xyzx
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
mov o1.xyz, l(0, 0, 0, 0)
dp3 r0.x, r1.xyzx, cb0[0].xyzx
dp3 r0.y, r1.xyzx, cb0[1].xyzx
dp3 r0.z, r1.xyzx, cb0[2].xyzx
dp3 r1.x, r0.xyzx, cb0[4].xyzx
dp3 r1.y, r0.xyzx, cb0[5].xyzx
dp3 r1.z, r0.xyzx, cb0[6].xyzx
mul o2.xyz, r1.xyzx, cb8[0].wwww
mov o2.w, l(1)
ret 
// instr=104 tex/ld=2
