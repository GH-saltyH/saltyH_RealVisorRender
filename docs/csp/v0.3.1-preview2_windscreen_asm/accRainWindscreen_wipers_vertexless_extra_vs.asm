// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_VertexID0 r0 sv6 mask1
// OSGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask7; TEXCOORD2 r1 sv0 mask8; TEXCOORD1 r2 sv0 mask7; TEXCOORD3 r2 sv0 mask8; TEXCOORD4 r3 sv0 mask1
vs_5_0
dcl_globalFlags 0x1
dcl_immediateConstantBuffer { 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0 }
dcl_constantbuffer cb11[5]
dcl_constantbuffer cb12[13] dynamicIndexed
dcl_constantbuffer cb5[223] dynamicIndexed
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
dcl_temps 11
udiv r0.x, r1.x, v0.x, l(6)
udiv r0.x, r2.x, r0.x, l(10)
and r0.y, r0.x, l(1)
utof r0.z, r2.x
add r0.z, r0.z, icb[r1.x].x
mul r0.w, r0.z, l(0.1)
ushr r0.x, r0.x, l(1)
imul null, r0.x, r0.x, l(3)
imul null, r1.y, cb12[12].x, l(56)
lt r1.z, cb12[r0.x].w, r0.w
mad r1.w, r0.z, l(0.1), l(-1)
add r2.x, l(-1), cb12[r0.x].w
div r1.w, r1.w, r2.x
div r2.x, r0.w, cb12[r0.x].w
movc_sat r1.z, r1.z, r1.w, r2.x
add r2.xyz, -cb12[r0.x].xyzx, cb12[r0.x + 1].xyzx
mad r2.xyz, r0.wwww, r2.xyzx, cb12[r0.x].xyzx
log r1.z, r1.z
mul r1.z, r1.z, cb12[r0.x + 2].x
exp r1.z, r1.z
mul r1.z, r1.z, cb12[r0.x + 1].w
mad r2.xyz, cb5[r1.y + 2].xyzx, r1.zzzz, r2.xyzx
utof r3.y, cb12[12].x
add r4.xyz, r2.xyzx, -cb5[r1.y].xyzx
dp3 r1.z, r4.xyzx, cb5[r1.y + 1].xyzx
mul r3.x, r1.z, cb5[r1.y].w
mov r3.z, cb5[r1.y + 2].w
sample_l r1.w, r3.xzyx, t12.yzwx, s1, l(0)
mov r2.w, l(1)
dp4 r4.x, r2, cb5[r1.y + 44]
dp4 r4.y, r2, cb5[r1.y + 45]
dp4 r4.z, r2, cb5[r1.y + 46]
mad r1.z, r1.z, cb5[r1.y].w, -cb5[r1.y + 3].z
add r3.z, -cb5[r1.y + 3].z, cb5[r1.y + 3].w
div_sat r1.z, r1.z, r3.z
add r4.xyz, -r2.xyzx, r4.xyzx
mad r4.xyz, r1.zzzz, r4.xyzx, r2.xyzx
ieq r3.z, l(1), cb12[r0.x + 2].y
if_nz r3.z
mov r5, cb5[r1.y + 8]
mov r6, cb5[r1.y + 9]
mov r7, cb5[r1.y + 10]
else 
ieq r8.x, l(2), cb12[r0.x + 2].y
if_nz r8.x
mov r5, cb5[r1.y + 12]
mov r6, cb5[r1.y + 13]
mov r7, cb5[r1.y + 14]
else 
ieq r8.x, l(3), cb12[r0.x + 2].y
if_nz r8.x
mov r5, cb5[r1.y + 16]
mov r6, cb5[r1.y + 17]
mov r7, cb5[r1.y + 18]
else 
ieq r8.x, l(4), cb12[r0.x + 2].y
if_nz r8.x
mov r5, cb5[r1.y + 20]
mov r6, cb5[r1.y + 21]
mov r7, cb5[r1.y + 22]
else 
mov r5, cb5[r1.y + 4]
mov r6, cb5[r1.y + 5]
mov r7, cb5[r1.y + 6]
endif 
endif 
endif 
endif 
mov r4.w, l(1)
dp4 r5.x, r4, r5
dp4 r5.y, r4, r6
dp4 r5.z, r4, r7
mad r4.xyz, cb5[r1.y + 2].xyzx, r1.wwww, r5.xyzx
mov r3.w, cb5[r1.y + 52].w
sample_l r1.w, r3.xwyx, t12.yzwx, s1, l(0)
dp4 r5.x, r2, cb5[r1.y + 48]
dp4 r5.y, r2, cb5[r1.y + 49]
dp4 r5.z, r2, cb5[r1.y + 50]
add r5.xyz, -r2.xyzx, r5.xyzx
mad r2.xyz, r1.zzzz, r5.xyzx, r2.xyzx
if_nz r3.z
mov r5, cb5[r1.y + 8]
mov r6, cb5[r1.y + 9]
mov r7, cb5[r1.y + 10]
mov r8, cb5[r1.y + 28]
mov r9, cb5[r1.y + 29]
mov r10, cb5[r1.y + 30]
else 
ieq r1.z, l(2), cb12[r0.x + 2].y
if_nz r1.z
mov r5, cb5[r1.y + 12]
mov r6, cb5[r1.y + 13]
mov r7, cb5[r1.y + 14]
mov r8, cb5[r1.y + 32]
mov r9, cb5[r1.y + 33]
mov r10, cb5[r1.y + 34]
else 
ieq r1.z, l(3), cb12[r0.x + 2].y
if_nz r1.z
mov r5, cb5[r1.y + 16]
mov r6, cb5[r1.y + 17]
mov r7, cb5[r1.y + 18]
mov r8, cb5[r1.y + 36]
mov r9, cb5[r1.y + 37]
mov r10, cb5[r1.y + 38]
else 
ieq r0.x, l(4), cb12[r0.x + 2].y
if_nz r0.x
mov r5, cb5[r1.y + 20]
mov r6, cb5[r1.y + 21]
mov r7, cb5[r1.y + 22]
mov r8, cb5[r1.y + 40]
mov r9, cb5[r1.y + 41]
mov r10, cb5[r1.y + 42]
else 
mov r5, cb5[r1.y + 4]
mov r6, cb5[r1.y + 5]
mov r7, cb5[r1.y + 6]
mov r8, cb5[r1.y + 24]
mov r9, cb5[r1.y + 25]
mov r10, cb5[r1.y + 26]
endif 
endif 
endif 
endif 
mov r2.w, l(1)
dp4 r5.x, r2, r5
dp4 r5.y, r2, r6
dp4 r5.z, r2, r7
dp4 r6.x, r2, r8
dp4 r6.y, r2, r9
dp4 r6.z, r2, r10
add r2.xyz, -r5.xyzx, r6.xyzx
mad r2.xyz, cb11[4].zzzz, r2.xyzx, r5.xyzx
mad r2.xyz, cb5[r1.y + 2].xyzx, r1.wwww, r2.xyzx
mov r4.w, l(1)
dp4 r5.x, r4, cb11[0]
dp4 r5.y, r4, cb11[1]
dp4 r5.z, r4, cb11[2]
mov r2.w, l(1)
dp4 r4.x, r2, cb11[0]
dp4 r4.y, r2, cb11[1]
dp4 r4.z, r2, cb11[2]
add r1.yzw, -r4.xxyz, r5.xxyz
utof r0.x, r0.y
add r0.x, r0.x, icb[r1.x].y
mul r0.x, r0.x, l(0.5)
add r2.xyz, -r5.xyzx, r4.xyzx
mad r2.xyz, r0.xxxx, r2.xyzx, r5.xyzx
mov r2.w, l(1)
dp4 r4.x, r2, cb0[0]
dp4 r4.y, r2, cb0[1]
dp4 r4.z, r2, cb0[2]
dp4 r4.w, r2, cb0[3]
dp3 r2.x, r1.yzwy, cb0[0].xyzx
dp3 r2.y, r1.yzwy, cb0[1].xyzx
dp3 r2.z, r1.yzwy, cb0[2].xyzx
dp3 r1.x, r2.xyzx, cb0[4].xyzx
dp3 r1.y, r2.xyzx, cb0[5].xyzx
dp3 r1.z, r2.xyzx, cb0[6].xyzx
mul o2.xyz, r1.xyzx, cb8[0].wwww
dp4 o0.x, r4, cb0[4]
dp4 o0.y, r4, cb0[5]
dp4 o0.z, r4, cb0[6]
dp4 o0.w, r4, cb0[7]
mad r0.x, r0.z, l(0.1), r3.y
mad o3.x, r0.x, cb11[4].x, cb11[4].y
mov o1.xyz, l(0, 0, 0, 0)
mov o1.w, r0.w
mov o2.w, l(1)
ret 
// instr=171 tex/ld=2
