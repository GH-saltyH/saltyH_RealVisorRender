// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_VERTEXID0 r0 sv6 mask1
// OSGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD1 r1 sv0 mask3; TEXCOORD2 r1 sv0 mask4; TEXCOORD3 r1 sv0 mask8
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
dcl_temps 3
udiv r0.x, r1.x, v0.x, l(6)
ld_structured r0.x, r0.x, l(0), t1.xxxx
ld_structured r0.yz, r0.x, l(16), t0.xxyx
ld_structured r2, r0.x, l(0), t0
mul r0.xw, r0.yyyz, l(20, 0, 0, 193.72)
mov_sat r0.x, r0.x
frc o1.z, r0.w
sqrt r0.x, r0.x
add r0.z, r0.z, l(1)
mul r0.x, r0.x, r0.z
mov_sat r0.z, r0.y
add_sat r0.y, r0.y, r0.y
mul o1.w, r0.y, l(0.333)
log r0.y, r0.z
mul r0.xy, r0.xyxx, l(0.07, 20, 0, 0)
exp r0.y, r0.y
add r0.y, r0.y, l(1)
mul r0.x, r0.y, r0.x
dp2 r0.y, r2.zwzz, r2.zwzz
sqrt r0.y, r0.y
div r0.zw, r2.zzzw, r0.yyyy
mad r1.yz, r2.xxyx, l(0, 1, -1, 0), l(0, 0, 1, 0)
mad r1.yz, r1.yyzy, l(0, 2, 2, 0), l(0, -1, -1, 0)
mul r0.zw, r0.zzzw, l(0, 0, 1, -1)
eq r1.w, r0.y, l(0)
mad r0.y, r0.y, l(0.04), r0.x
movc r2.xy, r1.wwww, l(1, 0, 0, 0), r0.zwzz
mov r2.z, -r2.x
mul r0, r0.xyxy, r2.yxzy
mul r0.xz, r0.xxzx, icb[r1.x].yyyy
mad r0.xy, r0.ywyy, icb[r1.x].xxxx, r0.xzxx
mov o1.xy, icb[r1.x].xyxx
mul r0.y, r0.y, cb10[0].x
add o0.xy, r0.xyxx, r1.yzyy
mov o0.zw, l(0, 0, 0, 1)
ret 
// instr=36 tex/ld=3
