// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask7; TEXCOORD1 r2 sv0 mask7; TEXCOORD2 r3 sv0 mask3; TEXCOORD3 r3 sv0 maskc
// OSGN | SV_TARGET0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_immediateConstantBuffer { 0.249953, 0.0527238, 0.255453, 0, 0.066026, 0.851116, 0.853673, 0, -0.806837, 0.203145, 0.832018, 0, 0.167273, -0.898331, 0.913771, 0 }
dcl_constantbuffer cb11[13]
dcl_sampler s0
dcl_sampler s1 comparison
dcl_sampler s5
dcl_resource_texture2d (float) t0
dcl_resource_texture2darray (float) t1
dcl_resource_texture2d (float) t20
dcl_input_ps linear noperspective v1.xyz
dcl_input_ps linear noperspective v2.xyz
dcl_input_ps linear noperspective v3.xy
dcl_input_ps linear noperspective v3.zw
dcl_output o0
dcl_temps 9
lt r0.x, v1.z, l(1)
if_nz r0.x
mov r0.z, l(1)
mov r0.w, l(0)
mov r1.x, l(0)
loop 
uge r1.y, r1.x, l(4)
breakc_nz r1.y
mad r0.xy, icb[r1.x].xyxx, l(0.0015, 0.0015, 0, 0), v1.xyxx
add r1.y, l(1), icb[r1.x].z
mad r1.y, -r1.y, l(0.001), v1.z
sample_c_lz r0.x, r0.xyzx, t1.xxxx, s1, r1.y
add r0.w, r0.x, r0.w
iadd r1.x, r1.x, l(1)
endloop 
mul r0.x, r0.w, l(0.25)
else 
mov r0.x, l(1)
endif 
sample r1, v3.xyxx, t0, s0
mul r0.y, r0.x, l(0.5)
mad r0.x, -r0.x, l(0.5), l(1)
mad o0.w, r1.w, r0.x, r0.y
mul r0.x, r1.w, l(10)
mad r0.yzw, r1.xxyz, l(0, 0.5, 0.5, 0.5), l(0, 0.5, 0.5, 0.5)
mul r1.x, cb11[10].w, l(0.05)
mad r1.y, v3.w, l(0.5), r1.x
mov r1.x, v3.z
mad r1.xy, r1.xyxx, l(16, 32, 0, 0), l(0.5, 0.5, 0, 0)
round_ni r2.xy, r1.xyxx
frc r1.xy, r1.xyxx
mul r2.zw, r1.xxxy, r1.xxxy
mad r1.xy, -r1.xyxx, l(2, 2, 0, 0), l(3, 3, 0, 0)
mad r1.xy, r2.zwzz, r1.xyxx, r2.xyxx
add r1.xy, r1.xyxx, l(-0.5, -0.5, 0, 0)
mul r1.xy, r1.xyxx, l(0.03125, 0.03125, 0, 0)
sample_l r1.x, r1.xyxx, t20, s5, l(0)
add r2.xyz, v2.xyzx, -cb11[8].xyzx
dp3 r1.y, r2.xyzx, r2.xyzx
sqrt r1.y, r1.y
add r1.y, -r1.y, l(0.2)
add r1.x, r1.x, l(-0.5)
mad r1.x, r1.x, l(0.1), r1.y
mul_sat r1.x, r1.x, l(40)
mov_sat r0.x, r0.x
add r0.y, r0.y, -r1.x
mad o0.x, r0.x, r0.y, r1.x
ne r0.x, cb11[9].w, l(0)
if_nz r0.x
ne r0.x, l(0, 0, 0, 0), cb11[11].w
if_nz r0.x
add r1.xyz, v2.xyzx, -cb11[9].xyzx
dp3 r0.x, r1.xyzx, r1.xyzx
sqrt r0.x, r0.x
add r1.xyz, v2.xyzx, -cb11[10].xyzx
dp3 r0.y, r1.xyzx, r1.xyzx
sqrt r0.y, r0.y
mul r0.xy, r0.xyxx, cb11[9].wwww
min r0.x, r0.y, r0.x
add r1.xyz, v2.xyzx, -cb11[11].xyzx
dp3 r0.y, r1.xyzx, r1.xyzx
sqrt r0.y, r0.y
mul r0.y, r0.y, cb11[11].w
min r0.x, r0.y, r0.x
add r1.xyz, v2.xyzx, -cb11[12].xyzx
dp3 r0.y, r1.xyzx, r1.xyzx
sqrt r0.y, r0.y
mul r0.y, r0.y, cb11[11].w
min r0.x, r0.y, r0.x
add_sat r0.x, -r0.x, l(1)
else 
add r1.xyz, -cb11[9].xyzx, cb11[10].xyzx
add r2.xyz, v2.xyzx, -cb11[9].xyzx
add r3.xyz, -cb11[10].xyzx, cb11[11].xyzx
add r4.xyz, v2.xyzx, -cb11[10].xyzx
add r5.xyz, cb11[9].xyzx, -cb11[11].xyzx
add r6.xyz, v2.xyzx, -cb11[11].xyzx
mul r7.xyz, r1.zxyz, r5.yzxy
mad r7.xyz, r1.yzxy, r5.zxyz, -r7.xyzx
mul r8.xyz, r1.zxyz, r7.yzxy
mad r8.xyz, r1.yzxy, r7.zxyz, -r8.xyzx
dp3 r0.y, r8.xyzx, r2.xyzx
lt r2.w, l(0), r0.y
lt r0.y, r0.y, l(0)
iadd r0.y, -r2.w, r0.y
mul r8.xyz, r3.zxyz, r7.yzxy
mad r8.xyz, r3.yzxy, r7.zxyz, -r8.xyzx
dp3 r2.w, r8.xyzx, r4.xyzx
lt r3.w, l(0), r2.w
lt r2.w, r2.w, l(0)
iadd r2.w, -r3.w, r2.w
iadd r0.y, r0.y, r2.w
mul r8.xyz, r5.zxyz, r7.yzxy
mad r8.xyz, r5.yzxy, r7.zxyz, -r8.xyzx
dp3 r2.w, r8.xyzx, r6.xyzx
lt r3.w, l(0), r2.w
lt r2.w, r2.w, l(0)
iadd r2.w, -r3.w, r2.w
iadd r0.y, r0.y, r2.w
itof r0.y, r0.y
lt r0.y, r0.y, l(2)
dp3 r2.w, r1.xyzx, r2.xyzx
dp3 r3.w, r1.xyzx, r1.xyzx
div_sat r2.w, r2.w, r3.w
mad r1.xyz, r1.xyzx, r2.wwww, -r2.xyzx
dp3 r1.x, r1.xyzx, r1.xyzx
dp3 r1.y, r3.xyzx, r4.xyzx
dp3 r1.z, r3.xyzx, r3.xyzx
div_sat r1.y, r1.y, r1.z
mad r3.xyz, r3.xyzx, r1.yyyy, -r4.xyzx
dp3 r1.y, r3.xyzx, r3.xyzx
min r1.x, r1.y, r1.x
dp3 r1.y, r5.xyzx, r6.xyzx
dp3 r1.z, r5.xyzx, r5.xyzx
div_sat r1.y, r1.y, r1.z
mad r3.xyz, r5.xyzx, r1.yyyy, -r6.xyzx
dp3 r1.y, r3.xyzx, r3.xyzx
min r1.x, r1.y, r1.x
dp3 r1.y, r7.xyzx, r2.xyzx
mul r1.y, r1.y, r1.y
dp3 r1.z, r7.xyzx, r7.xyzx
div r1.y, r1.y, r1.z
movc r0.y, r0.y, r1.x, r1.y
sqrt r0.y, r0.y
mad_sat r0.x, -r0.y, cb11[9].w, l(1)
endif 
else 
mov r0.x, l(0)
endif 
mul_sat r0.y, r1.w, l(100)
add r0.z, -r0.x, r0.z
mad o0.y, r0.y, r0.z, r0.x
mov o0.z, r0.w
ret 
// instr=134 tex/ld=3
