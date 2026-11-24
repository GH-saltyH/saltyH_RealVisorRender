// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | POSITION0 r0 sv0 maskf; NORMAL0 r1 sv0 mask7; TEXCOORD0 r2 sv0 mask3; TANGENT0 r3 sv0 mask7; SV_InstanceID0 r4 sv8 mask1
// OSGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask7; TEXCOORD2 r1 sv0 mask8; TEXCOORD1 r2 sv0 mask7; TEXCOORD3 r2 sv0 mask8; TEXCOORD4 r3 sv0 mask1
vs_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb11[5]
dcl_constantbuffer cb5[224] dynamicIndexed
dcl_constantbuffer cb0[8]
dcl_constantbuffer cb8[1]
dcl_sampler s1
dcl_resource_texture2darray (float) t12
dcl_input v0.xyz
dcl_input v3.y
dcl_input_sgv v4.x sv8
dcl_output_siv o0 sv1
dcl_output o1.xyz
dcl_output o1.w
dcl_output o2.xyz
dcl_output o2.w
dcl_output o3.x
dcl_temps 13
and r0.x, v3.y, l(255)
ine r0.y, r0.x, l(255)
mov r1.w, l(1)
mov r2.w, l(1)
mov r3.w, l(1)
mov r4.w, l(1)
mov r5.w, l(1)
mov r1.xyz, v0.xyzx
mov r0.zw, l(0, 0, -1, 0)
loop 
ige r6.x, r0.w, l(4)
breakc_nz r6.x
imul null, r6.x, r0.w, l(56)
itof r7.z, r0.w
ftou r6.y, r7.z
ishl r6.z, r6.y, l(5)
ult r6.w, r6.z, r0.x
iadd r6.z, r6.z, l(32)
ult r6.z, r0.x, r6.z
and r6.z, r6.z, r6.w
not r6.z, r6.z
eq r6.w, l(0), cb5[r6.x].w
or r6.z, r6.w, r6.z
if_z r6.z
if_nz r0.y
add r8.xyz, r1.xyzx, -cb5[r6.x].xyzx
dp3 r6.z, r8.xyzx, cb5[r6.x + 1].xyzx
mul r7.x, r6.z, cb5[r6.x].w
mov r7.y, cb5[r6.x + 2].w
sample_l r6.w, r7.xyzx, t12.yzwx, s1, l(0)
mul r8.xyz, r6.wwww, cb5[r6.x + 2].xyzx
bfi r9.xyz, l(27, 27, 27, 0), l(5, 5, 5, 0), r6.yyyy, l(3, 4, 5, 0)
ieq r9.xyz, r0.xxxx, r9.xyzx
if_nz r9.x
div_sat r6.w, r7.x, cb5[r6.x + 1].w
mul r8.xyz, r6.wwww, r8.xyzx
endif 
dp4 r10.x, r1, cb5[r6.x + 44]
dp4 r10.y, r1, cb5[r6.x + 45]
dp4 r10.z, r1, cb5[r6.x + 46]
mad r6.w, r6.z, cb5[r6.x].w, -cb5[r6.x + 3].z
add r7.y, -cb5[r6.x + 3].z, cb5[r6.x + 3].w
div_sat r6.w, r6.w, r7.y
add r10.xyz, -r1.xyzx, r10.xyzx
mad r2.xyz, r6.wwww, r10.xyzx, r1.xyzx
or r6.w, r9.z, r9.y
if_nz r6.w
mad r6.w, r7.x, cb5[r6.x + 52].z, cb5[r6.x + 52].y
mul r6.w, r6.w, r6.w
mul r6.w, r6.w, cb5[r6.x + 52].x
and r6.w, r6.w, r9.z
dp4 r9.x, r2, cb5[r6.x + 12]
dp4 r9.y, r2, cb5[r6.x + 13]
dp4 r9.z, r2, cb5[r6.x + 14]
dp4 r10.x, r2, cb5[r6.x + 32]
dp4 r10.y, r2, cb5[r6.x + 33]
dp4 r10.z, r2, cb5[r6.x + 34]
add r7.xyw, -r9.xyxz, r10.xyxz
mad r7.xyw, r6.wwww, r7.xyxw, r9.xyxz
add r1.xyz, r8.xyzx, r7.xywx
else 
bfi r6.w, l(27), l(5), r6.y, l(6)
ieq r6.w, r0.x, r6.w
if_nz r6.w
mov r3.xyz, r2.xyzx
dp4 r9.x, r3, cb5[r6.x + 16]
dp4 r9.y, r3, cb5[r6.x + 17]
dp4 r9.z, r3, cb5[r6.x + 18]
add r1.xyz, r8.xyzx, r9.xyzx
else 
bfi r3.x, l(27), l(5), r6.y, l(7)
ieq r3.x, r0.x, r3.x
if_nz r3.x
mov r4.xyz, r2.xyzx
dp4 r3.x, r4, cb5[r6.x + 20]
dp4 r3.y, r4, cb5[r6.x + 21]
dp4 r3.z, r4, cb5[r6.x + 22]
add r1.xyz, r8.xyzx, r3.xyzx
else 
bfi r3.x, l(27), l(5), r6.y, l(2)
ieq r3.x, r0.x, r3.x
mad r3.y, r6.z, cb5[r6.x].w, -cb5[r6.x + 3].x
add r3.z, -cb5[r6.x + 3].x, cb5[r6.x + 3].y
div_sat r3.y, r3.y, r3.z
movc r3.x, r3.x, l(0), r3.y
mov r5.xyz, r2.xyzx
dp4 r2.x, r5, cb5[r6.x + 8]
dp4 r2.y, r5, cb5[r6.x + 9]
dp4 r2.z, r5, cb5[r6.x + 10]
dp4 r4.x, r5, cb5[r6.x + 4]
dp4 r4.y, r5, cb5[r6.x + 5]
dp4 r4.z, r5, cb5[r6.x + 6]
add r4.xyz, r8.xyzx, r4.xyzx
add r4.xyz, -r2.xyzx, r4.xyzx
mad r1.xyz, r3.xxxx, r4.xyzx, r2.xyzx
endif 
endif 
endif 
endif 
mov r2.xyz, r1.xyzx
bfi r3.xyz, l(27, 27, 27, 0), l(5, 5, 5, 0), r0.wwww, l(1, 3, 6, 0)
ieq r3.x, r0.x, r3.x
ult r3.y, r3.y, r0.x
ult r3.z, r0.x, r3.z
and r3.y, r3.z, r3.y
or r3.x, r3.y, r3.x
if_nz r3.x
mov r0.z, r7.z
endif 
break 
endif 
iadd r0.w, r0.w, l(1)
mov r0.z, l(-1)
endloop 
eq r0.w, r0.z, l(-1)
if_nz r0.w
mov o0, l(-10, -10, -10, -10)
mov o1, l(0, 0, 0, 0)
mov o2, l(0, 0, 0, 0)
mov o3.x, l(0)
ret 
endif 
utof r0.w, v4.x
mad r0.w, r0.w, cb8[0].x, l(-0.5)
mov r2.w, l(1)
mov r3.w, l(1)
mov r4.w, l(1)
mov r5.w, l(1)
mov r6.w, l(1)
mov r2.xyz, v0.xyzx
mov r8.x, l(0)
mov r8.y, r0.z
mov r7.xyz, l(0, 0, 0, 0)
loop 
ige r7.w, r7.z, l(4)
breakc_nz r7.w
imul null, r7.w, r7.z, l(56)
itof r9.y, r7.z
ftou r8.z, r9.y
ishl r8.w, r8.z, l(5)
ult r10.x, r8.w, r0.x
iadd r8.w, r8.w, l(32)
ult r8.w, r0.x, r8.w
and r8.w, r8.w, r10.x
not r8.w, r8.w
eq r10.x, l(0), cb5[r7.w].w
or r8.w, r8.w, r10.x
if_z r8.w
add r10.xyz, r2.xyzx, -cb5[r7.w].xyzx
dp3 r8.w, r10.xyzx, cb5[r7.w + 1].xyzx
mul r9.z, r8.w, cb5[r7.w].w
if_nz r0.y
mov r9.w, cb5[r7.w + 52].w
sample_l r9.w, r9.zwyz, t12.yzwx, s1, l(0)
mul r10.xyz, r9.wwww, cb5[r7.w + 2].xyzx
bfi r11.xyz, l(27, 27, 27, 0), l(5, 5, 5, 0), r8.zzzz, l(3, 4, 5, 0)
ieq r11.xyz, r0.xxxx, r11.xyzx
if_nz r11.x
div_sat r9.w, r9.z, cb5[r7.w + 1].w
mul r10.xyz, r9.wwww, r10.xyzx
endif 
dp4 r12.x, r2, cb5[r7.w + 48]
dp4 r12.y, r2, cb5[r7.w + 49]
dp4 r12.z, r2, cb5[r7.w + 50]
mad r9.w, r8.w, cb5[r7.w].w, -cb5[r7.w + 3].z
add r10.w, -cb5[r7.w + 3].z, cb5[r7.w + 3].w
div_sat r9.w, r9.w, r10.w
add r12.xyz, -r2.xyzx, r12.xyzx
mad r3.xyz, r9.wwww, r12.xyzx, r2.xyzx
or r9.w, r11.z, r11.y
if_nz r9.w
mad r9.z, r9.z, cb5[r7.w + 52].z, cb5[r7.w + 52].y
mul r9.z, r9.z, r9.z
mul r9.z, r9.z, cb5[r7.w + 52].x
and r9.z, r9.z, r11.z
dp4 r11.x, r3, cb5[r7.w + 12]
dp4 r11.y, r3, cb5[r7.w + 13]
dp4 r11.z, r3, cb5[r7.w + 14]
dp4 r12.x, r3, cb5[r7.w + 32]
dp4 r12.y, r3, cb5[r7.w + 33]
dp4 r12.z, r3, cb5[r7.w + 34]
add r9.z, r9.z, l(2)
add r12.xyz, -r11.xyzx, r12.xyzx
mad r11.xyz, r9.zzzz, r12.xyzx, r11.xyzx
add r2.xyz, r10.xyzx, r11.xyzx
else 
bfi r9.z, l(27), l(5), r8.z, l(6)
ieq r9.z, r0.x, r9.z
if_nz r9.z
mov r4.xyz, r3.xyzx
dp4 r11.x, r4, cb5[r7.w + 16]
dp4 r11.y, r4, cb5[r7.w + 17]
dp4 r11.z, r4, cb5[r7.w + 18]
dp4 r12.x, r4, cb5[r7.w + 36]
dp4 r12.y, r4, cb5[r7.w + 37]
dp4 r12.z, r4, cb5[r7.w + 38]
add r4.xyz, -r11.xyzx, r12.xyzx
mad r4.xyz, r4.xyzx, l(2, 2, 2, 0), r11.xyzx
add r2.xyz, r10.xyzx, r4.xyzx
else 
bfi r4.x, l(27), l(5), r8.z, l(7)
ieq r4.x, r0.x, r4.x
if_nz r4.x
mov r5.xyz, r3.xyzx
dp4 r4.x, r5, cb5[r7.w + 20]
dp4 r4.y, r5, cb5[r7.w + 21]
dp4 r4.z, r5, cb5[r7.w + 22]
dp4 r11.x, r5, cb5[r7.w + 40]
dp4 r11.y, r5, cb5[r7.w + 41]
dp4 r11.z, r5, cb5[r7.w + 42]
add r5.xyz, -r4.xyzx, r11.xyzx
mad r4.xyz, r5.xyzx, l(2, 2, 2, 0), r4.xyzx
add r2.xyz, r10.xyzx, r4.xyzx
else 
bfi r4.x, l(27), l(5), r8.z, l(2)
ieq r4.x, r0.x, r4.x
mad r4.y, r8.w, cb5[r7.w].w, -cb5[r7.w + 3].x
add r4.z, -cb5[r7.w + 3].x, cb5[r7.w + 3].y
div_sat r4.y, r4.y, r4.z
movc r4.x, r4.x, l(0), r4.y
mov r6.xyz, r3.xyzx
dp4 r3.x, r6, cb5[r7.w + 8]
dp4 r3.y, r6, cb5[r7.w + 9]
dp4 r3.z, r6, cb5[r7.w + 10]
dp4 r5.x, r6, cb5[r7.w + 28]
dp4 r5.y, r6, cb5[r7.w + 29]
dp4 r5.z, r6, cb5[r7.w + 30]
add r5.xyz, -r3.xyzx, r5.xyzx
mad r3.xyz, r5.xyzx, l(2, 2, 2, 0), r3.xyzx
dp4 r5.x, r6, cb5[r7.w + 4]
dp4 r5.y, r6, cb5[r7.w + 5]
dp4 r5.z, r6, cb5[r7.w + 6]
dp4 r11.x, r6, cb5[r7.w + 24]
dp4 r11.y, r6, cb5[r7.w + 25]
dp4 r11.z, r6, cb5[r7.w + 26]
add r6.xyz, -r5.xyzx, r11.xyzx
mad r5.xyz, r6.xyzx, l(2, 2, 2, 0), r5.xyzx
add r5.xyz, r10.xyzx, r5.xyzx
add r5.xyz, -r3.xyzx, r5.xyzx
mad r2.xyz, r4.xxxx, r5.xyzx, r3.xyzx
endif 
endif 
endif 
endif 
mov r3.xyz, r2.xyzx
bfi r4.xyz, l(27, 27, 27, 0), l(5, 5, 5, 0), r7.zzzz, l(1, 3, 6, 0)
ieq r4.x, r0.x, r4.x
ult r4.y, r4.y, r0.x
ult r4.z, r0.x, r4.z
and r4.y, r4.z, r4.y
or r4.x, r4.y, r4.x
if_nz r4.x
mad r4.x, r8.w, cb5[r7.w].w, -cb5[r7.w + 53].w
add r10, -cb5[r7.w + 53].wxyz, cb5[r7.w + 54].wxyz
div r7.x, r4.x, r10.x
lt r4.x, cb5[r7.w + 55].x, r7.x
add r4.y, r7.x, l(-1)
add r4.z, l(-1), cb5[r7.w + 55].x
div r4.y, r4.y, r4.z
div r4.z, r7.x, cb5[r7.w + 55].x
movc r4.x, r4.x, r4.y, r4.z
mad r5.xyz, r7.xxxx, r10.yzwy, cb5[r7.w + 53].xyzx
add_sat r4.x, -r4.x, l(1)
log r4.x, r4.x
mul r4.x, r4.x, cb5[r7.w + 55].z
exp r4.x, r4.x
add r4.x, -r4.x, l(1)
mul r4.x, r4.x, cb5[r7.w + 55].y
mad r4.xyz, cb5[r7.w + 2].xyzx, r4.xxxx, r5.xyzx
add r4.xyz, -r4.xyzx, v0.xyzx
dp3 r4.x, r4.xyzx, cb5[r7.w + 2].xyzx
mov r7.y, |r4.x|
mov r9.x, cb5[r7.w + 55].w
else 
mov r9.xy, r8.xyxx
endif 
mov r8.xy, r9.xyxx
break 
endif 
iadd r7.z, r7.z, l(1)
mov r7.xy, l(0, 0, 0, 0)
endloop 
mov r1.w, l(1)
dp4 r0.x, r1, cb11[0]
dp4 r0.y, r1, cb11[1]
dp4 r0.z, r1, cb11[2]
mov r2.w, l(1)
dp4 r1.x, r2, cb11[0]
dp4 r1.y, r2, cb11[1]
dp4 r1.z, r2, cb11[2]
add r2.xyz, -r0.xyzx, r1.xyzx
mad r2.xyz, r0.wwww, r2.xyzx, r0.xyzx
add r0.xyz, r0.xyzx, -r1.xyzx
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
add o2.w, -r7.y, r8.x
add r0.x, r7.x, r8.y
mad o3.x, r0.x, cb11[4].x, cb11[4].y
mov o1.xyz, v0.xyzx
mov o1.w, r7.x
ret 
// instr=315 tex/ld=2
