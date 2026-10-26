// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | 
// OSGN | 
cs_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb8[6]
dcl_sampler s0
dcl_resource_texture2d (float) t5
dcl_resource_texture2d (float) t6
dcl_resource_texture2d (float) t9
dcl_resource_texture2d (float) t10
dcl_resource_texture2d (float) t11
dcl_resource_structured t19 stride=32
dcl_uav_structured u0 stride=48
dcl_uav_structured u1 stride=4
dcl_uav_structured u3 stride=4
dcl_uav_raw u4
dcl_input vThreadID.xyz
dcl_temps 13
dcl_thread_group 256, 1, 1
ld_raw r0.x, l(8), u4.xxxx
ld_structured r1, vThreadID.y, l(0), t19
umin r0.x, r0.x, r1.x
ult r0.x, vThreadID.x, r0.x
if_nz r0.x
ld_structured r0, vThreadID.y, l(16), t19
utof r2, vThreadID.xxyz
mul r3.y, r2.x, l(0.00390625)
dp3 r1.x, r2.yzwy, l(0.01, 0.01, 0.01, 0)
add r3.x, r1.x, cb8[0].w
dp2 r1.x, r3.xyxx, l(12.9898, 78.233, 0, 0)
mul r2, r1.xxxx, l(0.12345, 1.12345, 2.12345, 3.12345)
sincos r2, null, r2
mul r2, r2, l(43758.5, 43758.5, 43758.5, 43758.5)
frc r2, r2
add r2.zw, r2.zzzw, l(0, 0, -0.5, -0.5)
mad r2.xy, r2.zwzz, l(0.01, 0.01, 0, 0), r2.xyxx
sample_l r3, r2.xyxx, t5, s0, l(0)
sample_l r4, r2.xyxx, t6, s0, l(0)
mul r5.xyz, r3.zxyz, r4.yzxy
mad r5.xyz, r3.yzxy, r4.zxyz, -r5.xyzx
dp3 r5.w, r5.xyzx, r5.xyzx
rsq r5.w, r5.w
mul r5.xyz, r5.wwww, r5.xyzx
mul r6, r1.xxxx, l(4.12345, 5.12345, 6.12345, 7.12345)
sincos r6, null, r6
mul r6, r6, l(43758.5, 43758.5, 43758.5, 43758.5)
frc r6, r6
mad r5.w, r0.w, l(0.3), l(0.9)
mul r7.y, r5.w, r6.x
mad r5.w, r6.y, l(0.9798), l(0.0101)
mad r5.w, r6.z, l(0.02), r5.w
add r5.w, r5.w, l(-0.01)
mad r5.w, r6.w, l(0.0002), r5.w
add r6.z, r5.w, l(-0.0001)
mul r8.xyz, r1.xxxx, l(8.12345, 9.12345, 10.1235, 0)
sincos r8.xyz, null, r8.xyzx
mul r8.xyz, r8.xyzx, l(43758.5, 43758.5, 43758.5, 0)
frc r8.xyz, r8.xyzx
lt r1.w, r8.x, r1.w
mul r5.w, r8.y, r8.y
mad r5.w, r5.w, l(-0.8), l(1)
and r9.y, r1.w, r5.w
mad r1.w, r8.z, l(2), l(2)
mad r7.z, r0.w, r0.w, r1.w
lt r0.w, r1.y, l(0)
if_nz r0.w
sample_l r8, r2.xyxx, t9, s0, l(0)
mad r8.xyz, r8.xyzx, l(2, 2, 2, 0), l(-1, -1, -1, 0)
mul r8.xyz, r8.xyzx, l(20, 20, 20, 0)
dp3 r1.w, r8.xyzx, r8.xyzx
rsq r5.w, r1.w
mul r10.xyz, r5.wwww, r8.xyzx
mad r5.w, r8.w, l(2.2), l(-1.2)
mul r11, r1.xxxx, l(11.1235, 12.1235, 13.1235, 14.1235)
sincos r11, null, r11
mul r11, r11, l(43758.5, 43758.5, 43758.5, 43758.5)
frc r11, r11
mul r11.xy, r11.xyxx, r11.xyxx
lt r5.w, r11.x, r5.w
dp3 r10.x, r5.xyzx, r10.xyzx
mul r10.y, r10.x, l(1.2)
lt r10.y, r11.y, r10.y
and r5.w, r5.w, r10.y
mad r12.y, r8.w, l(0.5), r7.y
lt r8.w, l(0.8), r11.z
mad r10.y, r11.w, l(0.5), l(0.5)
lt r10.x, r10.x, r10.y
and r8.w, r8.w, r10.x
dp3 r3.x, r8.xyzx, r3.xyzx
dp3 r3.y, r8.xyzx, r4.xyzx
mul r3.z, r1.x, l(15.1235)
sincos r3.z, null, r3.z
mul r3.z, r3.z, l(43758.5)
frc r3.z, r3.z
mul r3.z, r3.z, r3.z
mad r3.z, r3.z, l(4), l(4)
sqrt r1.w, r1.w
mul r1.w, r1.w, l(0.05)
min r1.w, r1.w, l(1)
mad r10.z, r3.z, r1.w, r7.z
mov r7.xw, l(7.5, 0, 0, 15.1235)
mov r10.xw, l(7, 0, 0, 16.1235)
movc r12.xzw, r8.wwww, r7.xxzw, r10.xxzw
and r3.xy, r3.xyxx, r8.wwww
and r2.zw, r3.xxxy, r5.wwww
mov r7.xw, l(0, 0, 0, 13.1235)
movc r8, r5.wwww, r12.yxwz, r7.yxwz
mov r6.xy, r8.yxyy
mov r8.xz, r8.wwzw
mov r1.w, l(0)
else 
dp3 r3.x, r5.xyzx, cb8[5].xyzx
add_sat r3.x, r3.x, r3.x
mul r3.y, r3.x, r7.z
mul r4.xyz, r1.xxxx, l(11.1235, 12.1235, 13.1235, 0)
sincos r4.xyz, null, r4.xyzx
mul r4.xyz, r4.xyzx, l(43758.5, 43758.5, 43758.5, 0)
frc r4.xyz, r4.xyzx
lt r4.x, r4.x, r1.z
dp3 r0.x, r5.xyzx, r0.xyzx
mul r0.y, r0.x, l(1.2)
lt r0.y, r4.y, r0.y
not r0.z, r0.y
mul r4.y, r4.z, r4.z
mad r4.y, r4.y, l(8), l(8)
add_sat r1.z, r1.z, r1.z
mul r1.z, r1.z, r4.y
add_sat r0.x, r0.x, r0.x
mad r10.y, r1.z, r0.x, r3.y
mov r10.xz, l(7, 0, 14.1235, 0)
mov r3.xz, l(0, 0, 13.1235, 0)
movc r7.xzw, r0.yyyy, r10.xxyz, r3.xxyz
mov r3.xz, l(7, 0, 12.1235, 0)
movc r8.xyz, r4.xxxx, r7.zxwz, r3.yxzy
and r1.w, r0.z, r4.x
mov r2.zw, l(0, 0, 0, 0)
mov r6.x, r8.y
mov r6.y, r7.y
endif 
if_z r1.w
sample_l r0.x, r2.xyxx, t10, s0, l(2)
mad_sat r0.x, r0.x, l(2), l(-1)
mad r0.y, |r1.y|, l(-0.8), l(1)
mul r0.y, r0.y, r6.x
sample_l r1.yz, r2.xyxx, t11.xzwy, s0, l(0)
sample_l r0.z, r2.xyxx, t5.xywz, s0, l(2)
add r1.w, -r1.z, l(1)
mul r8.x, r1.w, r8.x
lt r1.w, l(0.1), r1.y
lt r1.yz, r1.yyzy, l(0, 0.8, 0.9, 0)
and r1.y, r1.y, r1.w
and r1.y, r1.z, r1.y
add r0.x, -r0.x, l(1)
mul r0.x, r0.x, l(4)
min r0.x, r0.x, l(1)
mul r1.z, r1.x, r8.z
sincos r1.z, null, r1.z
mul r1.z, r1.z, l(43758.5)
frc r1.z, r1.z
add r1.w, r8.z, l(1)
mad r1.z, r1.z, l(0.5), l(0.05)
lt r0.x, r1.z, r0.x
not r0.w, r0.w
dp3 r1.z, r5.xyzx, cb8[5].xyzx
mul r1.x, r1.x, r1.w
sincos r1.x, null, r1.x
mul r1.x, r1.x, l(43758.5)
frc r1.x, r1.x
mul r1.x, r1.x, r1.x
mad r1.x, r1.x, l(-0.7), l(0.5)
lt r1.x, r1.z, r1.x
and r0.w, r0.w, r1.x
or r0.x, r0.w, r0.x
lt r0.w, r3.w, l(0.5)
lt r1.x, r4.w, l(0.5)
lt r0.z, r0.z, l(0.8)
and r0.z, r0.z, r1.x
or r0.z, r0.z, r0.w
or r0.x, r0.z, r0.x
movc r0.x, r0.x, l(0), r0.y
movc r6.x, r1.y, r0.y, r0.x
endif 
imm_atomic_iadd r0.x, u4, l(4), l(-1)
iadd r0.x, r0.x, l(-1)
ld_structured r0.x, r0.x, l(0), u3.xxxx
f32tof16 r9.w, r8.x
store_structured u0, r0.x, l(0), r2
mov r6.w, l(0)
store_structured u0, r0.x, l(16), r6
mov r9.xz, l(0, 0, 0, 0)
store_structured u0, r0.x, l(32), r9
imm_atomic_iadd r1.x, u4, l(0), l(1)
store_structured u1.x, r1.x, l(0), r0.x
endif 
ret 
// instr=176 tex/ld=10
