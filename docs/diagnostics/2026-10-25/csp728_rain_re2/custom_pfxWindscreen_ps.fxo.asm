// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD1 r1 sv0 mask3; TEXCOORD2 r1 sv0 maskc; TEXCOORD3 r2 sv0 mask1; TEXCOORD4 r2 sv0 mask2; TEXCOORD5 r2 sv0 mask4; TEXCOORD6 r2 sv0 mask8
// OSGN | SV_TARGET0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_sampler s5
dcl_resource_texture2d (float) t20
dcl_input_ps linear v1.xy
dcl_input_ps linear v1.zw
dcl_input_ps linear v2.x
dcl_input_ps linear v2.y
dcl_input_ps linear v2.z
dcl_input_ps linear v2.w
dcl_output o0
dcl_temps 2
add r0.x, v2.x, l(0.6)
mad r0.yz, v2.xxxx, l(0, 0.4, -0.3, 0), l(0, 0.1, 0.5, 0)
mad r0.yw, v1.xxxy, r0.yyyy, v2.yyyy
sample_l r0.y, r0.ywyy, t20.yxzw, s5, l(0)
mad r0.x, r0.y, r0.x, l(0.8)
mul r0.xy, r0.xxxx, v1.xyxx
dp2 r0.x, r0.xyxx, r0.xyxx
add r0.y, -r0.x, l(1)
sqrt r0.x, r0.x
lt r0.y, r0.y, l(0)
discard_nz r0.y
add r0.y, -r0.z, l(1)
mad r0.z, -r0.z, l(2), -r0.y
add r0.z, r0.z, l(1)
mad r0.w, r0.x, v2.w, -r0.y
mad r0.x, r0.x, v2.w, l(-1)
add_sat r0.x, -r0.x, l(1)
mul r0.x, r0.x, l(0.2)
add r0.y, -r0.y, l(1)
div r0.yz, r0.wwww, r0.yyzy
add_sat r0.yz, -r0.yyzy, l(0, 1, 1, 0)
add r0.z, r0.z, l(-1)
mad r0.z, v2.x, r0.z, l(1)
add r0.w, -v2.x, l(1)
mul r0.x, r0.w, r0.x
max r0.x, r0.x, r0.y
mul r0.w, r0.z, r0.x
mul r0.xy, r0.wwww, v1.zwzz
mov r1.z, r0.w
mov r0.z, v2.z
mov r1.xw, l(10, 0, 0, 1)
mul o0, r0, r1.xxzw
ret 
// instr=33 tex/ld=1
