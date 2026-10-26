// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | 
// OSGN | 
cs_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb8[6]
dcl_sampler s2
dcl_resource_texture2d (float) t20
dcl_uav_structured u0 stride=32
dcl_uav_structured u1 stride=4
dcl_uav_structured u2 stride=4
dcl_uav_structured u3 stride=4
dcl_uav_raw u4
dcl_uav_structured u6 stride=4
dcl_input vThreadID.x
dcl_temps 5
dcl_thread_group 256, 1, 1
ld_raw r0.x, l(0), u4.xxxx
ult r0.x, vThreadID.x, r0.x
if_nz r0.x
ld_structured r0.x, vThreadID.x, l(0), u1.xxxx
ld_structured r1, r0.x, l(0), u0
ld_structured r0.yzw, r0.x, l(16), u0.xxyz
lt r2.x, l(0), r0.y
if_nz r2.x
ne r2.x, l(0, 0, 0, 0), cb8[5].w
if_nz r2.x
sample_l r2.y, r1.xyxx, t20.yxzw, s2, l(3)
add r3, r1.xyxy, l(-0.05, 0, 0, -0.05)
sample_l r2.z, r3.xyxx, t20.yzxw, s2, l(3)
sample_l r2.w, r3.zwzz, t20.yzwx, s2, l(3)
add r3, r1.xyxy, l(0.05, 0, 0, 0.05)
sample_l r3.x, r3.xyxx, t20, s2, l(3)
sample_l r3.y, r3.zwzz, t20.yxzw, s2, l(3)
add r3.x, -r2.y, r3.x
add r2.zw, -r2.zzzw, r2.yyyy
add r2.z, -r3.x, r2.z
mad r4.x, r2.z, l(0.5), r3.x
add r2.z, -r2.y, r3.y
add r2.w, -r2.z, r2.w
mad r4.y, r2.w, l(0.5), r2.z
dp2 r2.z, r4.xyxx, r4.xyxx
rsq r2.z, r2.z
mul r2.zw, r2.zzzz, r4.xxxy
mad_sat r2.y, r2.y, l(2), l(-1)
else 
mov r2.yzw, l(0, 0, 0, 0)
endif 
mul r3.xy, cb8[2].xzxx, l(0.2, 0.15, 0, 0)
mad r3.z, r1.x, l(2), l(-1)
max r3.w, cb8[2].z, l(0)
mad r4.x, r3.z, r3.w, r3.x
max r3.x, r3.y, l(0)
mad r4.y, cb8[2].y, l(0.2), -r3.x
mad r3.x, r2.y, l(3), l(1)
mul r2.zw, r2.yyyy, r2.zzzw
mul r2.zw, r2.zzzw, l(0, 0, -2, -2)
mad r2.zw, r4.xxxy, r3.xxxx, r2.zzzw
lt r3.x, l(0), r0.w
dp2 r3.y, r2.zwzz, r2.zwzz
sqrt r3.y, r3.y
mad r2.y, r3.y, cb8[1].x, r2.y
add r4.z, r0.w, -r2.y
mul r2.yz, r2.zzwz, cb8[1].xxxx
movc r2.x, r2.x, l(1), l(0.4)
mad r2.xy, r2.yzyy, r2.xxxx, r1.zwzz
mov r4.xy, r1.zwzz
mov r2.z, r0.w
movc r2.xyz, r3.xxxx, r4.xyzx, r2.xyzx
mad r1.xy, r2.xyxx, cb8[1].xxxx, r1.xyxx
lt r0.w, l(0), r2.z
mul r2.w, cb8[1].x, l(0.3)
movc r0.w, r0.w, r2.w, cb8[1].x
mul r2.w, |cb8[2].z|, l(0.5)
min r2.w, r2.w, l(1)
mad r2.w, r2.w, l(0.5), l(0.5)
mad r0.y, -r0.w, r2.w, r0.y
lt r3.xy, r1.xyxx, l(-0.5, -0.5, 0, 0)
lt r3.zw, l(0, 0, 1.5, 1.5), r1.xxxy
or r3.xy, r3.zwzz, r3.xyxx
or r0.w, r3.y, r3.x
movc r0.y, r0.w, l(0), r0.y
store_structured u6.x, r0.x, l(0), r0.z
mov r1.zw, r2.xxxy
store_structured u0, r0.x, l(0), r1
store_structured u0.x, r0.x, l(16), r0.y
store_structured u0.x, r0.x, l(24), r2.z
imm_atomic_iadd r1.x, u4, l(12), l(1)
store_structured u2.x, r1.x, l(0), r0.x
else 
imm_atomic_iadd r1.x, u4, l(4), l(1)
store_structured u3.x, r1.x, l(0), r0.x
endif 
endif 
ret 
// instr=78 tex/ld=9
