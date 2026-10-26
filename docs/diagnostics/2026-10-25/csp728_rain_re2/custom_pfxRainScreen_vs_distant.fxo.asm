// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_VERTEXID0 r0 sv6 mask1
// OSGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD1 r1 sv0 mask3; TEXCOORD2 r1 sv0 mask4; TEXCOORD3 r1 sv0 mask8; TEXCOORD4 r2 sv0 mask3; TEXCOORD5 r2 sv0 mask4; TEXCOORD6 r2 sv0 mask8
vs_5_0
dcl_globalFlags 0x1
dcl_immediateConstantBuffer { -1, -1, 0, 0, 1, -1, 0, 0, -1, 1, 0, 0, -1, 1, 0, 0, 1, -1, 0, 0, 1, 1, 0, 0 }
dcl_constantbuffer cb10[1]
dcl_resource_structured t0 stride=32
dcl_resource_structured t1 stride=4
dcl_input_sgv v0.x sv6
dcl_output_siv o0 sv1
dcl_output o1.xy
dcl_output o1.z
dcl_output o1.w
dcl_output o2.xy
dcl_output o2.z
dcl_output o2.w
dcl_temps 4
udiv r0.x, null, v0.x, l(6)
ld_structured r0.x, r0.x, l(0), t1.xxxx
ld_structured r0.yz, r0.x, l(16), t0.xxyx
ge r0.w, l(0), r0.y
if_nz r0.w
mov o0, l(-10, -10, -10, -10)
mov o1, l(0, 0, 0, 0)
mov o2, l(0, 0, 0, 0)
ret 
endif 
udiv null, r0.w, v0.x, l(6)
ld_structured r1, r0.x, l(0), t0
dp2 r0.x, r1.zwzz, r1.zwzz
sqrt r0.x, r0.x
eq r2.x, r0.x, l(0)
div r1.zw, r1.zzzw, r0.xxxx
mul r1.zw, r1.zzzw, l(0, 0, 1, -1)
movc r2.xy, r2.xxxx, l(1, 0, 0, 0), r1.zwzz
mul r3.xz, r0.yyzy, l(10, 0, 193.72, 0)
mad r0.z, r0.z, l(0.4), l(1)
mov_sat r3.x, r3.x
sqrt r1.z, r3.x
mul r0.z, r0.z, r1.z
mul r0.z, r0.z, l(0.03)
mov_sat r1.z, r0.y
log r1.z, r1.z
mul r1.z, r1.z, l(80)
exp r1.z, r1.z
mad r2.w, r1.z, l(2), l(1)
mul r0.z, r0.z, r2.w
mad r1.w, r0.x, l(0.04), r0.z
mul r3.xy, r2.xyxx, r1.wwww
mov r2.z, -r2.x
mul r0.xz, r0.zzzz, r2.yyzy
mul r0.xz, r0.xxzx, icb[r0.w].yyyy
mad r0.xz, r3.xxyx, icb[r0.w].xxxx, r0.xxzx
mad r2.xy, r1.xyxx, l(1, -1, 0, 0), l(0, 1, 0, 0)
mad r2.xy, r2.xyxx, l(2, 2, 0, 0), l(-1, -1, 0, 0)
mul r0.z, r0.z, cb10[0].x
add o0.xy, r0.xzxx, r2.xyxx
mov o0.zw, l(0, 0, 0, 1)
frc o1.z, r3.z
add_sat r0.x, r0.y, r0.y
mul o1.w, r0.x, l(0.333)
mov o1.xy, icb[r0.w].xyxx
mov o2, r1
ret 
// instr=47 tex/ld=3
