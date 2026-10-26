// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | 
// OSGN | 
cs_5_0
dcl_globalFlags 0x1
dcl_immediateConstantBuffer { 0.249953, 0.0527238, 0.255453, 0, 0.066026, 0.851116, 0.853673, 0, -0.806837, 0.203145, 0.832018, 0, 0.167273, -0.898331, 0.913771, 0 }
dcl_constantbuffer cb8[17]
dcl_sampler s1
dcl_sampler s2
dcl_sampler s8 comparison
dcl_resource_structured t19 stride=32
dcl_resource_texture2d (float) t21
dcl_resource_texture2darray (float) t22
dcl_resource_texture2d (float) t23
dcl_uav_structured u0 stride=32
dcl_uav_structured u1 stride=4
dcl_uav_structured u3 stride=4
dcl_uav_raw u4
dcl_input vThreadID.xyz
dcl_temps 5
dcl_thread_group 256, 1, 1
ld_raw r0.x, l(8), u4.xxxx
ld_structured r0.y, vThreadID.y, l(0), t19.xxxx
umin r0.x, r0.y, r0.x
ult r0.x, vThreadID.x, r0.x
if_nz r0.x
utof r0, vThreadID.xxyz
mul r1.y, r0.x, l(0.00390625)
dp3 r0.x, r0.yzwy, l(0.01, 0.01, 0.01, 0)
add r1.x, r0.x, cb8[0].w
dp2 r0.x, r1.xyxx, l(12.9898, 78.233, 0, 0)
mul r1, r0.xxxx, l(0.12345, 1.12345, 2.12345, 3.12345)
sincos r1, null, r1
mul r1, r1, l(43758.5, 43758.5, 43758.5, 43758.5)
frc r1, r1
mul r1, r1, l(0.99, 0.99, 0.01, 0.01)
add r1.xy, r1.zwzz, r1.xyxx
mad r0.yz, r1.xxyx, l(0, 2, 2, 0), l(0, -1, -1, 0)
mul r2.xy, r0.yzyy, l(1, -1, 0, 0)
mov r2.zw, l(0, 0, 0.5, 1)
dp4 r3.x, r2, cb8[6]
dp4 r3.y, r2, cb8[7]
dp4 r3.z, r2, cb8[8]
dp3 r0.z, r3.xyzx, r3.xyzx
rsq r0.z, r0.z
mul r2.xyz, r0.zzzz, r3.xyzx
mad r3.xyz, r3.xyzx, r0.zzzz, cb8[3].xyzx
dp3 r0.z, cb8[5].xyzx, r2.xyzx
mad r2.xyz, -cb8[5].xyzx, r0.zzzz, r3.xyzx
mov r2.w, l(1)
dp4 r0.z, r2, cb8[12]
lt r0.w, r0.z, l(1)
if_nz r0.w
dp4 r3.x, r2, cb8[10]
dp4 r3.y, r2, cb8[11]
mov r4.z, l(1)
mov r0.w, l(0)
mov r2.w, l(0)
loop 
uge r3.z, r2.w, l(4)
breakc_nz r3.z
mad r4.xy, icb[r2.w].xyxx, l(0.0015, 0.0015, 0, 0), r3.xyxx
add r3.z, l(1), icb[r2.w].z
mad r3.z, -r3.z, l(0.001), r0.z
sample_c_lz r3.z, r4.xyzx, t22.xxxx, s8, r3.z
add r0.w, r0.w, r3.z
iadd r2.w, r2.w, l(1)
endloop 
mul r0.z, r0.w, l(0.25)
else 
mov r0.z, l(1)
endif 
mad r0.w, cb8[2].x, l(0.1), r0.y
dp3 r2.w, cb8[5].xyzx, cb8[4].xyzx
mad_sat r2.w, r2.w, l(-2), l(0.2)
mul r0.z, r0.z, r2.w
mul r0.yw, |r0.yyyw|, |r0.yyyw|
mad r0.w, r0.w, l(0.9), l(0.1)
mul r0.w, r0.w, cb8[4].w
mul r0.z, r0.w, r0.z
mad r0.y, r0.y, l(0.67), l(0.33)
mul r0.y, r0.y, r0.z
sample_l r0.zw, r1.xyxx, t21, s2, l(0)
lt r0.zw, l(0, 0, 0, 0), r0.wwwz
and r0.z, r0.w, r0.z
mul r3.xyz, r0.xxxx, l(4.12345, 5.12345, 6.12345, 0)
sincos r3.xyz, null, r3.xyzx
mul r3.xyz, r3.xyzx, l(43758.5, 43758.5, 43758.5, 0)
frc r3.xyz, r3.xyzx
add r0.x, r3.x, r3.x
lt r0.x, r0.x, r0.y
or r0.x, r0.x, r0.z
and r0.x, r0.x, l(1)
ne r0.y, l(0, 0, 0, 0), cb8[2].w
add r2.xyz, r2.xyzx, -cb8[3].xyzx
mad r2.xyz, r2.xyzx, l(0.25, 0.25, 0.25, 0), cb8[3].xyzx
mov r2.w, l(1)
dp4 r4.x, r2, cb8[14]
dp4 r4.y, r2, cb8[15]
dp4 r4.z, r2, cb8[16]
add r2.xyz, r4.xyzx, l(-0.5, -0.5, -0.5, 0)
lt r2.xyz, |r2.xyzx|, l(0.5, 0.5, 0.5, 0)
and r0.z, r2.y, r2.x
and r0.z, r2.z, r0.z
sample_l r0.w, r4.xyxx, t23.yzwx, s1, l(0)
lt r0.w, r0.w, r4.z
and r0.z, r0.w, r0.z
and r0.y, r0.z, r0.y
movc r3.x, r0.y, l(0), r0.x
imm_atomic_iadd r0.x, u4, l(4), l(-1)
iadd r0.x, r0.x, l(-1)
ld_structured r0.x, r0.x, l(0), u3.xxxx
mov r1.zw, l(0, 0, 0, 0)
store_structured u0, r0.x, l(0), r1
mov r3.w, l(0)
store_structured u0, r0.x, l(16), r3
imm_atomic_iadd r1.x, u4, l(0), l(1)
store_structured u1.x, r1.x, l(0), r0.x
endif 
ret 
// instr=99 tex/ld=6
