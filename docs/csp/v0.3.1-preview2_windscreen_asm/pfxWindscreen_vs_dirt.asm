// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_VERTEXID0 r0 sv6 mask1
// OSGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD1 r1 sv0 mask3; TEXCOORD2 r1 sv0 mask4
vs_5_0
dcl_globalFlags 0x1
dcl_immediateConstantBuffer { -1, -1, 0, 0, 1, -1, 0, 0, -1, 1, 0, 0, -1, 1, 0, 0, 1, -1, 0, 0, 1, 1, 0, 0 }
dcl_constantbuffer cb6[1]
dcl_resource_structured t0 stride=48
dcl_resource_structured t1 stride=4
dcl_input_sgv v0.x sv6
dcl_output_siv o0 sv1
dcl_output o1.xy
dcl_output o1.z
dcl_temps 5
udiv r0.x, null, v0.x, l(6)
ld_structured r0.x, r0.x, l(0), t1.xxxx
ld_structured r1, r0.x, l(8), t0
ld_structured r0, r0.x, l(24), t0.yxzw
ge r2.x, l(0.01), r1.z
ge r2.y, l(0.1), r0.x
or r2.x, r2.y, r2.x
if_nz r2.x
mov o0, l(-1, -1, -1, -1)
mov o1.xyz, l(0, 0, 0, 0)
ret 
endif 
udiv null, r2.x, v0.x, l(6)
dp2 r2.y, r1.xyxx, r1.xyxx
sqrt r2.y, r2.y
eq r2.z, r2.y, l(0)
div r3.xy, r1.xyxx, r2.yyyy
mul r3.xy, r3.xyxx, l(1, -1, 0, 0)
movc r3.xy, r2.zzzz, l(1, 0, 0, 0), r3.xyxx
mul r4.x, r1.z, l(10)
mad r1.w, r1.w, l(0.004), l(0.004)
dp2 r1.w, cb6[0].xxxx, r1.wwww
mov_sat r4.x, r4.x
mul r1.w, r1.w, r4.x
mul r2.y, r2.y, l(0.0153846)
mov r3.z, -r3.x
mul r4, r3.xyyz, icb[r2.x].xxyy
add r2.zw, r4.zzzw, r4.xxxy
mul r3.xy, r3.xyxx, r2.yyyy
add r3.xy, r3.xyxx, r3.xyxx
lt r2.y, l(0), icb[r2.x].x
lt r3.z, icb[r2.x].x, l(0)
iadd r2.y, -r2.y, r3.z
itof r2.y, r2.y
mul r3.xy, r2.yyyy, r3.xyxx
mad r2.yz, r1.wwww, r2.zzwz, r3.xxyx
mad r0.zw, -r1.xxxy, l(0, 0, 0.02, 0.02), r0.zzzw
frc r3.xy, r0.zwzz
add r3.z, -r3.y, l(1)
mad r0.zw, r3.xxxz, l(0, 0, 2, 2), l(0, 0, -1, -1)
mad o0.xy, r2.yzyy, l(1.3, 1.3, 0, 0), r0.zwzz
mov o0.zw, l(0, 0, 0, 1)
mov_sat r0.x, r0.x
mul_sat r0.z, r1.z, l(20)
mul r0.x, r0.z, r0.x
mul r0.y, r0.y, l(1519.66)
frc r0.y, r0.y
mad r0.y, r0.y, l(0.5), l(0.5)
mul o1.z, r0.y, r0.x
mov o1.xy, icb[r2.x].xyxx
ret 
// instr=51 tex/ld=3
