// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | POSITION0 r0 sv0 maskf; NORMAL0 r1 sv0 mask7; TEXCOORD0 r2 sv0 mask3; TANGENT0 r3 sv0 mask7
// OSGN | SV_POSITION0 r0 sv1 maskf
vs_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb5[223] dynamicIndexed
dcl_constantbuffer cb0[8]
dcl_constantbuffer cb11[4]
dcl_sampler s1
dcl_resource_texture2darray (float) t12
dcl_input v0
dcl_input v3.y
dcl_output_siv o0 sv1
dcl_temps 10
and r0.x, v3.y, l(255)
ine r0.y, r0.x, l(255)
mov r1.w, l(1)
mov r2.w, l(1)
mov r3.w, l(1)
mov r4.w, l(1)
mov r5.w, l(1)
mov r1.xyz, v0.xyzx
mov r0.z, l(0)
loop 
ige r0.w, r0.z, l(4)
breakc_nz r0.w
imul null, r0.w, r0.z, l(56)
itof r6.z, r0.z
ftou r6.w, r6.z
ishl r7.x, r6.w, l(5)
ult r7.y, r7.x, r0.x
iadd r7.x, r7.x, l(32)
ult r7.x, r0.x, r7.x
and r7.x, r7.x, r7.y
not r7.x, r7.x
eq r7.y, l(0), cb5[r0.w].w
or r7.x, r7.y, r7.x
if_z r7.x
if_nz r0.y
add r7.xyz, r1.xyzx, -cb5[r0.w].xyzx
dp3 r7.x, r7.xyzx, cb5[r0.w + 1].xyzx
mul r6.x, r7.x, cb5[r0.w].w
mov r6.y, cb5[r0.w + 2].w
sample_l r6.y, r6.xyzx, t12.yxzw, s1, l(0)
mul r7.yzw, r6.yyyy, cb5[r0.w + 2].xxyz
bfi r8.xyz, l(27, 27, 27, 0), l(5, 5, 5, 0), r6.wwww, l(3, 4, 5, 0)
ieq r8.xyz, r0.xxxx, r8.xyzx
if_nz r8.x
div_sat r6.y, r6.x, cb5[r0.w + 1].w
mul r7.yzw, r6.yyyy, r7.yyzw
endif 
dp4 r9.x, r1, cb5[r0.w + 44]
dp4 r9.y, r1, cb5[r0.w + 45]
dp4 r9.z, r1, cb5[r0.w + 46]
mad r6.y, r7.x, cb5[r0.w].w, -cb5[r0.w + 3].z
add r6.z, -cb5[r0.w + 3].z, cb5[r0.w + 3].w
div_sat r6.y, r6.y, r6.z
add r9.xyz, -r1.xyzx, r9.xyzx
mad r2.xyz, r6.yyyy, r9.xyzx, r1.xyzx
or r6.y, r8.z, r8.y
if_nz r6.y
mad r6.x, r6.x, cb5[r0.w + 52].z, cb5[r0.w + 52].y
mul r6.x, r6.x, r6.x
mul r6.x, r6.x, cb5[r0.w + 52].x
and r6.x, r6.x, r8.z
dp4 r8.x, r2, cb5[r0.w + 12]
dp4 r8.y, r2, cb5[r0.w + 13]
dp4 r8.z, r2, cb5[r0.w + 14]
dp4 r9.x, r2, cb5[r0.w + 32]
dp4 r9.y, r2, cb5[r0.w + 33]
dp4 r9.z, r2, cb5[r0.w + 34]
add r9.xyz, -r8.xyzx, r9.xyzx
mad r6.xyz, r6.xxxx, r9.xyzx, r8.xyzx
add r1.xyz, r7.yzwy, r6.xyzx
else 
bfi r6.x, l(27), l(5), r6.w, l(6)
ieq r6.x, r0.x, r6.x
if_nz r6.x
mov r3.xyz, r2.xyzx
dp4 r6.x, r3, cb5[r0.w + 16]
dp4 r6.y, r3, cb5[r0.w + 17]
dp4 r6.z, r3, cb5[r0.w + 18]
add r1.xyz, r7.yzwy, r6.xyzx
else 
bfi r3.x, l(27), l(5), r6.w, l(7)
ieq r3.x, r0.x, r3.x
if_nz r3.x
mov r4.xyz, r2.xyzx
dp4 r3.x, r4, cb5[r0.w + 20]
dp4 r3.y, r4, cb5[r0.w + 21]
dp4 r3.z, r4, cb5[r0.w + 22]
add r1.xyz, r7.yzwy, r3.xyzx
else 
bfi r3.x, l(27), l(5), r6.w, l(2)
ieq r3.x, r0.x, r3.x
mad r3.y, r7.x, cb5[r0.w].w, -cb5[r0.w + 3].x
add r3.z, -cb5[r0.w + 3].x, cb5[r0.w + 3].y
div_sat r3.y, r3.y, r3.z
movc r3.x, r3.x, l(0), r3.y
mov r5.xyz, r2.xyzx
dp4 r2.x, r5, cb5[r0.w + 8]
dp4 r2.y, r5, cb5[r0.w + 9]
dp4 r2.z, r5, cb5[r0.w + 10]
dp4 r4.x, r5, cb5[r0.w + 4]
dp4 r4.y, r5, cb5[r0.w + 5]
dp4 r4.z, r5, cb5[r0.w + 6]
add r4.xyz, r7.yzwy, r4.xyzx
add r4.xyz, -r2.xyzx, r4.xyzx
mad r1.xyz, r3.xxxx, r4.xyzx, r2.xyzx
endif 
endif 
endif 
endif 
mov r2.xyz, r1.xyzx
break 
endif 
iadd r0.z, r0.z, l(1)
endloop 
mov r1.w, v0.w
dp4 r0.x, r1, cb11[0]
dp4 r0.y, r1, cb11[1]
dp4 r0.z, r1, cb11[2]
dp4 r0.w, r1, cb11[3]
dp4 r1.x, r0, cb0[0]
dp4 r1.y, r0, cb0[1]
dp4 r1.z, r0, cb0[2]
dp4 r1.w, r0, cb0[3]
dp4 o0.x, r1, cb0[4]
dp4 o0.y, r1, cb0[5]
dp4 o0.z, r1, cb0[6]
dp4 o0.w, r1, cb0[7]
ret 
// instr=118 tex/ld=1
