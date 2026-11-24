// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_VERTEXID0 r0 sv6 mask1
// OSGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD1 r1 sv0 mask3; TEXCOORD2 r1 sv0 maskc; TEXCOORD3 r2 sv0 mask1; TEXCOORD4 r2 sv0 mask2; TEXCOORD5 r2 sv0 mask4; TEXCOORD6 r2 sv0 mask8
vs_5_0
dcl_globalFlags 0x1
dcl_immediateConstantBuffer { -1, -1, 0, 0, 1, -1, 0, 0, -1, 1, 0, 0, -1, 1, 0, 0, 1, -1, 0, 0, 1, 1, 0, 0 }
dcl_constantbuffer cb2[10]
dcl_constantbuffer cb6[1]
dcl_resource_structured t0 stride=48
dcl_resource_structured t1 stride=4
dcl_input_sgv v0.x sv6
dcl_output_siv o0 sv1
dcl_output o1.xy
dcl_output o1.zw
dcl_output o2.x
dcl_output o2.y
dcl_output o2.z
dcl_output o2.w
dcl_temps 6
udiv r0.x, null, v0.x, l(6)
ld_structured r0.x, r0.x, l(0), t1.xxxx
ld_structured r1, r0.x, l(16), t0
ge r0.y, l(1e-05), r1.x
lt r0.z, l(0.1), r1.w
or r0.y, r0.z, r0.y
if_nz r0.y
mov o0, l(-1, -1, -1, -1)
mov o1, l(0, 0, 0, 0)
mov o2, l(0, 0, 0, 0)
ret 
endif 
udiv null, r0.y, v0.x, l(6)
ld_structured r2, r0.x, l(0), t0
ld_structured r0.z, r0.x, l(32), t0.xxxx
ld_structured r0.xw, r0.x, l(40), t0.xxxy
f16tof32 r0.w, r0.w
lt r0.x, l(0.1), r0.x
dp2 r1.w, r2.zwzz, r2.zwzz
sqrt r1.w, r1.w
eq r3.x, r1.w, l(0)
div r3.yz, r2.zzwz, r1.wwww
mul r3.yz, r3.yyzy, l(0, 1, -1, 0)
movc r3.xy, r3.xxxx, l(1, 0, 0, 0), r3.yzyy
mad r3.w, cb2[9].z, l(3), l(1)
mul r0.z, r0.z, cb6[0].x
mad r4.xy, r1.yyyy, l(0.0022, 0.02, 0, 0), l(0.0006, 0.98, 0, 0)
mul r0.z, r0.z, r4.x
mul_sat r1.x, r1.x, r3.w
mul r0.z, r0.z, r1.x
mad r1.xy, r0.wwww, l(1.6, 0.333333, 0, 0), l(1, -0.5, 0, 0)
mul r0.z, r0.z, r1.x
mul r1.xw, r1.wwww, l(0.0153846, 0, 0, 5)
mov r3.z, -r3.x
mul r5, r3.xyyz, icb[r0.y].xxyy
add r3.zw, r5.zzzw, r5.xxxy
mul r5.xy, r0.zzzz, r3.zwzz
add r0.z, r0.z, r0.z
min r0.z, r0.z, r1.x
mul r0.zw, r0.zzzz, r3.xxxy
lt r1.x, l(0), icb[r0.y].x
lt r3.x, icb[r0.y].x, l(0)
iadd r1.x, -r1.x, r3.x
itof r1.x, r1.x
mad r3.xy, r0.zwzz, r1.xxxx, r5.xyxx
min r0.z, r1.w, l(1)
add r3.z, r0.z, l(1)
mov r5.z, l(1)
movc r3.xyz, r0.xxxx, r5.xyzx, r3.xyzx
frc r5.xy, r2.xyxx
add r5.z, -r5.y, l(1)
mad r0.zw, r5.xxxz, l(0, 0, 2, 2), l(0, 0, -1, -1)
mul r1.xw, r3.zzzz, r3.xxxy
mad o0.xy, r1.xwxx, l(1.43, 1.43, 0, 0), r0.zwzz
mov o0.zw, l(0, 0, 0, 1)
mov_sat o2.x, r1.y
movc o2.z, r0.x, l(0), r4.y
mov o1.xy, icb[r0.y].xyxx
mov o1.zw, r2.zzzw
mov o2.y, r1.z
mov o2.w, r3.z
ret 
// instr=62 tex/ld=5
