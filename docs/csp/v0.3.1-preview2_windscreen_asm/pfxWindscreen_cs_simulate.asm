// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | 
// OSGN | 
cs_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb8[9]
dcl_sampler s0
dcl_sampler s1
dcl_sampler s4
dcl_resource_texture2d (float) t5
dcl_resource_texture2d (float) t6
dcl_resource_texture2d (float) t7
dcl_resource_texture2d (float) t8
dcl_resource_texture2d (float) t10
dcl_resource_texture2d (float) t11
dcl_uav_structured u0 stride=48
dcl_uav_structured u1 stride=4
dcl_uav_structured u2 stride=4
dcl_uav_structured u3 stride=4
dcl_uav_raw u4
dcl_uav_structured u5 stride=32
dcl_uav_raw u6
dcl_uav_typed_texture2d u7
dcl_input vThreadID.x
dcl_temps 16
dcl_thread_group 256, 1, 1
ld_raw r0.x, l(0), u4.xxxx
ult r0.x, vThreadID.x, r0.x
if_nz r0.x
ld_structured r0.x, vThreadID.x, l(0), u1.xxxx
ld_structured r1, r0.x, l(0), u0.zwxy
ld_structured r2, r0.x, l(16), u0.wxyz
ld_structured r3, r0.x, l(32), u0
lt r0.y, l(0), r2.y
if_nz r0.y
f16tof32 r4.x, r3.w
ushr r0.y, r3.w, l(16)
f16tof32 r4.y, r0.y
ne r0.y, cb8[1].x, l(0)
if_nz r0.y
mul r0.yz, r2.wwww, l(0, 274.31, 165168, 0)
frc r0.yz, r0.yyzy
mul r0.y, r0.y, l(0.98)
lt r0.y, r0.y, cb8[2].w
mul r0.w, cb8[1].x, cb8[2].w
mad r3.w, cb8[2].w, l(950), l(50)
mad r0.w, -r0.w, r3.w, r2.y
movc r0.y, r0.y, r0.w, r2.y
sample_l r4.zw, r1.zwzz, t8.zwxy, s0, l(2)
sample_l r0.w, r1.zwzz, t8, s0, l(3)
mul r4.zw, r4.zzzw, l(0, 0, 0.1, 0.1)
mad_sat r3.w, r0.w, l(2.5), l(-1.5)
eq r5.x, r2.x, l(0)
mad r5.yz, r2.zzwz, l(0, 1.7, 77.2527, 0), l(0, 0.1, 0.69199, 0)
mad r5.w, cb8[1].x, l(-0.02), r3.y
dp2 r6.x, r4.zwzz, r4.zwzz
sqrt r6.y, r6.x
mul r6.y, r5.y, r6.y
mad_sat r6.y, r6.y, l(3), l(-0.1)
add r5.w, r5.w, -r6.y
mul r5.y, r3.w, r5.y
mad r5.y, -r5.y, l(0.02), r5.w
max r5.y, r5.y, l(-0.2)
min r5.y, r5.y, l(1)
movc r5.x, r5.x, r5.y, r3.y
mad r6.yz, cb8[1].xxxx, l(0, 10, 40, 0), l(0, 1, 1, 0)
div r6.yz, l(1, 1, 1, 1), r6.yyzy
dp2 r5.w, r1.xyxx, l(1, 1, 0, 0)
ne r5.w, l(0, 0, 0, 0), r5.w
dp2 r6.w, r1.xyxx, r1.xyxx
rsq r6.w, r6.w
mul r7.xy, r1.xyxx, r6.wwww
mul r7.xy, r4.yyyy, r7.xyxx
mul r7.xy, r7.xyxx, cb8[7].yyyy
mul r7.xy, r7.xyxx, l(0.008, 0.008, 0, 0)
and r7.xy, r5.wwww, r7.xyxx
add r7.xy, r1.zwzz, r7.xyxx
ne r5.w, l(0, 0, 0, 0), r3.z
and r6.w, r5.w, l(1)
movc r5.w, r5.w, l(-1), l(-2147483648)
add r5.w, r4.y, r5.w
mad r4.y, r6.z, r5.w, r6.w
sample_l r8.xyz, r7.xyxx, t7.xywz, s4, l(0)
mad r7.zw, r8.xxxy, l(0, 0, 2, 2), l(0, 0, -1, -1)
mul r7.zw, r7.zzzw, cb8[7].yyyy
mul r8.xy, r7.zwzz, l(4.10278, 4.10278, 0, 0)
sample_l r7.xy, r7.xyxx, t7.zwxy, s1, l(0)
frc r5.z, r5.z
lt r5.w, l(0.1), r7.y
lt r5.z, r5.z, cb8[7].w
and r5.z, r5.z, r5.w
if_nz r5.z
mul r5.z, r7.x, l(255)
ftou r9.x, r5.z
dp2 r5.z, r8.xyxx, r8.xyxx
add r5.z, r5.z, l(-0.1)
max r5.z, r5.z, l(0)
min r5.z, r5.z, l(0.25)
mov r9.yzw, l(0, 0, 0, 0)
ld_uav_typed r5.w, r9.xwww, u7.yzwx
add r5.z, r5.z, r5.w
store_uav_typed u7, r9, r5.zzzz
endif 
lt r5.z, r3.z, l(0)
if_nz r5.z
mad r5.z, cb8[1].x, l(10), r3.z
min r5.y, r5.z, l(0)
mov r9.xy, r1.zwzz
mov r2.y, r3.x
else 
lt r5.z, l(0.5), r8.z
if_nz r5.z
lt r5.z, l(0), r2.x
mad r5.w, r2.w, l(72.2685), l(0.17249)
frc r5.w, r5.w
lt r5.w, r5.w, cb8[7].w
dp2 r6.w, r8.xyxx, r8.xyxx
lt r7.x, l(0.001), r6.w
and r5.w, r5.w, r7.x
or r5.z, r5.w, r5.z
if_nz r5.z
ne r5.z, l(0, 0, 0, 0), r2.x
mov r5.y, r3.x
movc r5.xy, r5.zzzz, r5.xyxx, r1.wzww
mad r2.x, cb8[1].x, l(5), r2.x
lt r5.z, r6.w, l(0.001)
dp2 r5.w, r8.xyxx, r1.xyxx
lt r5.w, r5.w, l(0)
or r5.z, r5.w, r5.z
movc r0.y, r5.z, l(0), l(1)
mad r5.zw, -r7.zzzw, l(0, 0, 4.10278, 4.10278), r1.xxxy
mad r1.xy, r6.yyyy, r5.zwzz, r8.xyxx
mul r5.zw, r7.zzzw, cb8[1].xxxx
mul r5.zw, r5.zzzw, l(0, 0, 3.28223, 3.28223)
div r5.zw, r5.zzzw, cb8[3].wwww
add r9.xy, r1.zwzz, r5.zwzz
mov r2.y, r5.y
mov r5.y, r3.z
else 
lt r5.z, l(0), r3.z
dp2 r5.w, r1.xyxx, r8.xyxx
lt r5.w, r5.w, l(0)
and r5.z, r5.w, r5.z
not r5.z, r5.z
and r5.z, r5.z, r7.x
if_nz r5.z
sample_l r5.z, r1.zwzz, t8.xywz, s0, l(5)
mul r7.xy, r2.wwww, l(3773.8, 4374.42, 0, 0)
frc r7.xy, r7.xyxx
mul r5.w, r7.y, l(40)
mad r6.w, r7.x, l(0.2), l(0.05)
mul r7.xy, r6.wwww, r8.xyxx
mad r8.xy, -r8.xyxx, r6.wwww, r1.xyxx
mad r1.xy, r6.zzzz, r8.xyxx, r7.xyxx
add r5.z, r5.z, l(-0.1)
lt r5.z, r5.z, r5.w
mul r6.zw, r7.zzzw, cb8[1].xxxx
mul r6.zw, r6.zzzw, l(0, 0, 6.15418, 6.15418)
div r6.zw, r6.zzzw, cb8[3].wwww
add r6.zw, r1.zzzw, r6.zzzw
movc r9.xy, r5.zzzz, r6.zwzz, r1.zwzz
mad r5.zw, r1.xxxy, l(0, 0, 0.06, 0.06), r9.xxxy
sample_l r5.z, r5.zwzz, t5.xywz, s0, l(0)
lt r5.z, r5.z, l(0.5)
movc r0.y, r5.z, l(0), r0.y
mov r5.xy, l(0, 1, 0, 0)
else 
mul r7.xz, cb8[3].wwww, l(0.005, 0, 0.005, 0)
mov r7.y, l(0)
add r8, r1.zwzw, -r7.zyyz
sample_l r5.z, r8.xyxx, t7.xywz, s0, l(2.5)
add r10, r1.zwzw, r7.zyyz
sample_l r5.w, r10.xyxx, t7, s0, l(2.5)
sample_l r6.z, r10.zwzz, t7.xywz, s0, l(2.5)
sample_l r6.w, r8.zwzz, t7, s0, l(2.5)
add r8.x, -r5.z, r5.w
add r8.y, -r6.w, r6.z
mad r9.xy, -r8.xyxx, r7.xxxx, r1.zwzz
add r0.y, r0.y, -cb8[1].x
mov r1.xy, l(0, 0, 0, 0)
mov r5.xy, l(1, 0, 0, 0)
endif 
mov r2.y, r3.x
endif 
else 
add_sat r5.y, r3.z, l(-0.5)
lt r5.z, l(0), r2.x
mad r5.w, -cb8[1].x, l(20), r0.y
min r5.w, r5.w, l(1)
movc r0.y, r5.z, r5.w, r0.y
mov r9.xy, r1.zwzz
mov r2.y, r3.x
endif 
endif 
sample_l r7.xyz, r9.xyxx, t10, s0, l(0)
mad r0.z, r0.z, l(0.4), l(0.1)
lt r0.z, r7.x, r0.z
movc r8.x, r0.z, l(0), r0.y
ge r0.y, l(0), r5.y
if_nz r0.y
sample_l r10, r1.zwzz, t5, s1, l(0)
ne r0.y, l(0, 0, 0, 0), r2.x
if_nz r0.y
mad r0.y, cb8[1].x, l(30), l(1)
div r0.y, l(1, 1, 1, 1), r0.y
add r0.z, -r9.x, r2.y
mad r2.y, r0.y, r0.z, r9.x
add r0.z, -r9.y, r5.x
mad r5.x, r0.y, r0.z, r9.y
mov r1.zw, r9.xxxy
mov r11.x, r8.x
mov r8.y, r2.z
else 
sample_l r12, r1.zwzz, t6.wxyz, s1, l(0)
ult r0.y, cb8[5].w, vThreadID.x
ult r0.z, cb8[4].w, vThreadID.x
add r5.z, cb8[1].x, cb8[1].x
lt r5.w, r8.x, l(1)
mul r6.zw, cb8[1].xxxx, l(0, 0, 100, 0.25)
movc r5.w, r5.w, cb8[1].x, r6.w
movc r0.z, r0.z, r5.z, r5.w
movc r0.y, r0.y, r6.z, r0.z
add r0.y, -r0.y, r8.x
mul r5.zw, r2.wwww, l(0, 0, 13539.5, 196174)
frc r5.zw, r5.zzzw
lt r0.z, l(0.3), r5.z
mul r3.w, r3.w, cb8[1].x
mad r3.w, -r3.w, l(5), r0.y
movc r0.y, r0.z, r3.w, r0.y
sample_l r0.z, r9.xyxx, t5.xywz, s0, l(4)
add r0.z, r0.z, l(-0.9)
mul_sat r6.zw, r0.zzzz, l(0, 0, -3.33333, -5)
mul r0.z, r6.w, l(0.9)
mad r3.w, r6.w, l(3.6), l(-3)
max r3.w, r3.w, l(0)
dp2 r3.w, r3.wwww, cb8[1].xxxx
add r0.y, r0.y, -r3.w
mul r4.x, r4.x, r6.y
ne r3.w, l(0, 0, 0, 0), cb8[6].w
movc r0.z, r3.w, l(0), r0.z
mul r13.xyz, r10.zxyz, r12.zwyz
mad r13.xyz, r10.yzxy, r12.wyzw, -r13.xyzx
dp3 r5.z, r13.xyzx, r13.xyzx
rsq r5.z, r5.z
mul r13.xyz, r5.zzzz, r13.xyzx
dp3 r5.z, r13.xyzx, cb8[6].xyzx
mov_sat r12.x, r12.x
mad r6.w, r12.x, l(-2), l(1)
mul r5.z, r5.z, r6.w
mul_sat r5.z, r5.z, l(0.025)
mad r6.w, r5.z, l(-0.2), l(0.75)
add r7.x, r2.y, -r6.w
mad r2.y, r6.y, r7.x, r6.w
mul r5.z, r5.z, cb8[1].x
mad r0.y, -r5.z, l(0.5), r0.y
lt r5.z, l(0), cb8[8].w
dp3 r6.y, cb8[8].xyzx, r13.xyzx
lt r6.y, l(0.1), r6.y
and r5.z, r5.z, r6.y
lt r6.y, r4.x, l(0.5)
and r5.z, r5.z, r6.y
mul r5.w, r5.w, l(0.5)
lt r5.w, r5.w, cb8[8].w
and r5.z, r5.w, r5.z
movc r11.x, r5.z, l(0), r0.y
if_nz r3.w
sample_l r0.y, r9.xyxx, t5.xwyz, s0, l(2)
lt r0.y, r0.y, l(0.9)
if_nz r0.y
lt r0.y, l(0.95), r7.y
if_nz r0.y
imm_atomic_iadd r14.x, u6, l(0), l(1)
ult r0.y, r14.x, l(64)
if_nz r0.y
mul r9.zw, r1.xxxy, cb8[3].wwww
mul r15.x, r2.y, r2.z
store_structured u5, r14.x, l(0), r9
mov r15.yzw, l(0, 0, 0, 0)
store_structured u5, r14.x, l(16), r15
endif 
endif 
mov r11.x, l(0)
endif 
endif 
eq r0.y, r5.y, l(0)
not r3.w, r3.w
lt r5.z, r6.z, l(0.8)
or r3.w, r3.w, r5.z
and r0.y, r0.y, r3.w
if_nz r0.y
mul r5.zw, r9.xxxy, l(0, 0, 128, 128)
sample_l r5.zw, r5.zwzz, t11.zwxy, s0, l(0)
mad r5.zw, r5.zzzw, l(0, 0, 2, 2), l(0, 0, -1, -1)
lt r6.yz, l(0, 0, 0, 0), r5.zzwz
lt r7.xy, r5.zwzz, l(0, 0, 0, 0)
iadd r6.yz, -r6.yyzy, r7.xxyx
itof r6.yz, r6.yyzy
mad_sat r5.zw, |r5.zzzw|, l(0, 0, 5, 5), l(0, 0, -3.5, -3.5)
mul r5.zw, r5.zzzw, r6.yyyz
mul r6.yzw, r5.wwww, cb8[4].xxyz
mad r6.yzw, cb8[3].xxyz, r5.zzzz, r6.yyzw
dp3 r0.y, r13.xyzx, cb8[2].xyzx
add r0.y, -|r0.y|, l(1)
mul r6.yzw, r0.yyyy, r6.yyzw
dp3 r0.y, cb8[2].xyzx, cb8[2].xyzx
sqrt r0.y, r0.y
add r0.y, r0.y, r0.y
min r0.y, r0.y, l(2)
mad r6.yzw, r6.yyzw, r0.yyyy, cb8[2].xxyz
mad r0.y, r7.z, l(2), l(-1)
mul r7.y, r0.y, cb8[7].x
mov r7.xz, l(0, 0, 0, 0)
add r6.yzw, r6.yyzw, r7.xxyz
dp3 r7.x, r6.yzwy, r10.xyzx
dp3 r7.y, r6.yzwy, r12.yzwy
dp2 r0.y, r7.xyxx, r7.xyxx
rsq r3.w, r0.y
mul r5.zw, r3.wwww, r7.xxxy
lt r0.y, l(897988541), r0.y
if_nz r0.y
mul r7.zw, r5.wwwz, l(0, 0, 1, -1)
mul r12, r5.zwwz, cb8[3].wwww
mad r8.zw, r12.xxxy, l(0, 0, 0.02, 0.02), r9.xxxy
sample_l r9.zw, r8.zwzz, t8, s0, l(2.5)
mad_sat r0.y, -r9.w, l(2), r9.z
mad r9.zw, r12.zzzw, l(0, 0, 0.01, -0.01), r8.zzzw
sample_l r9.zw, r9.zwzz, t8, s0, l(2.5)
mad_sat r3.w, -r9.w, l(2), r9.z
mad r8.zw, -r12.zzzw, l(0, 0, 0.01, -0.01), r8.zzzw
sample_l r8.zw, r8.zwzz, t8, s0, l(2.5)
mad_sat r8.z, -r8.w, l(2), r8.z
add r3.w, -r0.y, r3.w
add r0.y, r0.y, -r8.z
add r0.y, r0.y, r3.w
mul r7.zw, r0.yyyy, r7.zzzw
mad r7.xy, r7.zwzz, l(-0.003, -0.003, 0, 0), r7.xyxx
endif 
dp3 r0.y, r6.yzwy, r13.xyzx
mul r0.y, r0.y, l(0.2)
max r0.y, r0.y, l(0)
min r0.y, r0.y, l(0.6)
max r4.x, r0.y, r4.x
lt r0.y, l(7), r11.x
add r10.z, r11.x, -cb8[1].x
mad r10.xy, r7.xyxx, cb8[1].xxxx, r1.xyxx
ge r3.w, l(0), r5.x
mad r6.y, r0.z, l(-20), l(30)
and r3.w, r3.w, r6.y
mul r6.yz, r3.wwww, r7.xxyx
dp2 r3.w, r1.xyxx, r1.xyxx
sqrt r3.w, r3.w
mad_sat r0.w, r0.w, l(2.5), l(-0.5)
mul r0.w, r0.w, cb8[1].x
mul r0.w, r0.w, l(20)
div r7.zw, r1.xxxy, r3.wwww
dp2 r5.z, r7.zwzz, r5.zwzz
add_sat r5.z, -r5.z, l(1)
mad r0.w, r0.w, r5.z, l(1)
div r0.w, l(1, 1, 1, 1), r0.w
mul r5.zw, r1.xxxy, r0.wwww
mul r6.w, r6.x, cb8[1].x
lt r7.z, l(0.001), r6.x
mad r6.w, r6.w, l(1000), l(1)
div r6.w, l(1, 1, 1, 1), r6.w
rsq r7.w, r6.x
mul r4.zw, r4.zzzw, r7.wwww
mul r4.zw, r3.wwww, r4.zzzw
mad r8.zw, r0.wwww, r1.xxxy, -r4.zzzw
mad r4.zw, r6.wwww, r8.zzzw, r4.zzzw
movc r4.zw, r7.zzzz, r4.zzzw, r5.zzzw
mad r11.yz, r6.yyzy, cb8[1].xxxx, r4.zzwz
movc r11.xyz, r0.yyyy, r10.zxyz, r11.xyzx
dp2 r0.y, r7.xyxx, r7.xyxx
sqrt r0.y, r0.y
add r0.y, r0.y, l(-0.001)
max r0.y, r0.y, l(0)
mad r0.y, -r0.y, l(3), r5.x
add r0.w, r6.x, l(-0.001)
max r0.w, r0.w, l(0)
mad r5.x, -r0.w, l(3), r0.y
dp2 r0.y, r11.yzyy, r11.yzyy
sqrt r0.y, r0.y
mad r0.y, -r0.y, cb8[1].x, r2.z
max r8.y, r0.y, l(0)
mov r1.xy, r11.yzyy
else 
mov r8.y, r2.z
endif 
mad r0.y, -r0.z, l(0.1), l(1)
mul r1.xy, r0.yyyy, r1.xyxx
mul r0.y, cb8[1].x, cb8[3].w
mul r0.yz, r1.xxyx, r0.yyyy
dp2 r0.w, r0.yzyy, r0.yzyy
sqrt r0.w, r0.w
lt r3.w, l(0), r0.w
ne r4.z, l(0, 0, 0, 0), r5.y
min r4.w, r0.w, l(0.008)
mul r5.zw, r0.yyyz, r4.wwww
div r5.zw, r5.zzzw, r0.wwww
movc r0.yz, r4.zzzz, r0.yyzy, r5.zzwz
add r0.yz, r0.yyzy, r9.xxyx
movc r1.zw, r3.wwww, r0.yyyz, r9.xxxy
endif 
eq r0.y, r10.w, l(0)
add r0.zw, r1.zzzw, l(0, 0, -0.5, -0.5)
lt r0.zw, l(0, 0, 0.5, 0.5), |r0.zzzw|
or r0.z, r0.w, r0.z
or r0.y, r0.z, r0.y
lt r0.z, r8.y, l(0)
or r0.y, r0.z, r0.y
movc r8.x, r0.y, l(0), r11.x
else 
mov r1.zw, r9.xxxy
mov r8.y, r2.z
endif 
mov r2.zw, r5.xxxy
else 
mov r8.xy, r2.yzyy
mov r2.yzw, r3.xxyz
endif 
f32tof16 r0.yz, r4.xxyx
imad r0.y, r0.z, l(65536), r0.y
store_structured u0, r0.x, l(0), r1.zwxy
store_structured u0.xy, r0.x, l(16), r8.xyxx
store_structured u0, r0.x, l(28), r2
store_structured u0.x, r0.x, l(44), r0.y
imm_atomic_iadd r1.x, u4, l(12), l(1)
store_structured u2.x, r1.x, l(0), r0.x
else 
imm_atomic_iadd r1.x, u4, l(4), l(1)
store_structured u3.x, r1.x, l(0), r0.x
endif 
endif 
ret 
// instr=408 tex/ld=25
