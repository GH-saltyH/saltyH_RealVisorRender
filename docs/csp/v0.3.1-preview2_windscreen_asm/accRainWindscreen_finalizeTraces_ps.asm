// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask3
// OSGN | SV_TARGET0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_immediateConstantBuffer { 0.426589, -0.0285677, 0.427544, 0, -0.495862, 0.628468, 0.800532, 0, 0.151011, -0.967221, 0.978939, 0, -0.882342, -0.0611149, 0.884456, 0, 0.359446, 0.887765, 0.957772, 0 }
dcl_constantbuffer cb12[2]
dcl_constantbuffer cb10[1]
dcl_sampler s0
dcl_sampler s2
dcl_sampler s8
dcl_resource_texture2d (float) t0
dcl_resource_texture2d (float) t1
dcl_resource_texture2d (float) t2
dcl_resource_texture2d (float) t3
dcl_resource_texture2d (float) t4
dcl_resource_texture2d (float) t5
dcl_resource_texture2d (float) t9
dcl_resource_texture2d (float) t20
dcl_input_ps_siv v0.xy sv1
dcl_input_ps linear noperspective v1.xy
dcl_output o0
dcl_temps 6
mov r0.xy, l(0, 0, 0, 0)
loop 
uge r0.z, r0.y, l(5)
breakc_nz r0.z
mad r0.zw, icb[r0.y].xxxy, l(0, 0, 0.01, 0.01), v1.xxxy
sample_l r0.z, r0.zwzz, t2.xywz, s8, l(2.5)
add r0.x, r0.z, r0.x
iadd r0.y, r0.y, l(1)
endloop 
mul r0.y, r0.x, l(0.2)
sample_l r0.z, v1.xyxx, t0.xywz, s0, l(3.5)
sample_l r1.xy, v1.xyxx, t5.zwxy, s0, l(0)
sample_l r0.w, v1.xyxx, t2, s0, l(0)
sample_l r1.z, v1.xyxx, t5, s2, l(0)
ftoi r2.xy, v0.xyxx
mov r2.zw, l(0, 0, 0, 0)
ld r2.xyz, r2, t1
sample_l r3.xyz, v1.xyxx, t9.xywz, s2, l(0)
sample_l r1.w, v1.xyxx, t4.yzwx, s0, l(0)
mul r4.xyz, r1.yxxy, l(10, 1.3, 0.7, 0)
mad r4.w, cb10[0].x, l(0.1), r4.z
sample_l r4.yzw, r4.ywyy, t20.wxyz, s0, l(0)
add r1.x, r4.z, r4.y
add r2.w, r4.w, l(-0.3)
mul_sat r2.w, r2.w, l(2.5)
mad r2.w, r2.w, l(0.5), l(0.5)
mul_sat r1.x, r1.x, r2.w
mov r5.y, l(0)
mov r2.w, l(0)
mov r3.w, l(0)
loop 
uge r4.y, r3.w, l(4)
breakc_nz r4.y
utof r4.y, r3.w
mad r4.y, r4.y, l(0.25), l(-0.5)
mad r5.x, r4.y, l(0.02), r1.z
sample_l r4.y, r5.xyxx, t3.yxzw, s8, l(0)
add r2.w, r2.w, r4.y
iadd r3.w, r3.w, l(1)
endloop 
mul r1.z, r2.w, l(0.25)
sqrt r0.y, r0.y
mad_sat r0.y, -r2.y, l(10), r0.y
mad_sat r0.z, r0.z, l(10), l(-0.1)
mul r2.w, r0.z, r0.y
mad r1.x, r1.x, l(0.4), l(0.1)
mul r1.x, r1.z, r1.x
mov_sat r4.x, r4.x
mul r1.x, r1.x, r4.x
mul r1.z, r1.w, l(0.6)
mad r1.x, r1.x, l(0.7), r1.z
add r1.z, r3.z, l(-0.51)
mad_sat r1.z, r1.z, l(-100), l(1)
mul r1.w, r1.z, r3.x
add r3.xw, r2.xxxz, -cb12[0].zzzw
max r0.w, r0.w, r1.y
mul r0.w, r0.w, cb12[0].x
mad r0.w, -r0.w, l(10), r3.x
mul r2.w, r2.w, cb12[0].x
mad r0.y, r0.y, r0.z, -r2.x
mul_sat r0.y, r0.y, l(10)
mul r0.y, r0.y, r2.w
mad r0.y, r0.y, l(4), r0.w
max r0.y, r0.y, r1.x
add r0.z, -r0.y, l(1)
mad_sat r0.w, r3.z, l(2), l(-1)
mul r0.z, r0.w, r0.z
mad r4.x, r0.z, cb12[0].z, r0.y
mul r0.y, r1.w, cb12[0].x
add_sat r0.z, r1.w, r1.w
mad_sat r0.w, r2.z, l(2), l(-1)
add r0.z, -r0.w, r0.z
max r0.z, r0.z, l(0)
mad r0.y, r0.y, r0.z, r3.w
min r0.y, r0.y, l(0.95)
mad r0.z, -r3.y, r1.z, l(1)
min r4.z, r0.z, r0.y
max r0.y, r1.y, r2.y
add r4.y, r0.y, -cb12[0].y
mad o0.w, r0.x, l(-0.2), l(1)
min o0.xyz, r4.xyzx, cb12[1].xxxx
ret 
// instr=82 tex/ld=10
