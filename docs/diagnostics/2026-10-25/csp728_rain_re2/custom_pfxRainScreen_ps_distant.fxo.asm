// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD1 r1 sv0 mask3; TEXCOORD2 r1 sv0 mask4; TEXCOORD3 r1 sv0 mask8; TEXCOORD4 r2 sv0 mask3; TEXCOORD5 r2 sv0 mask4; TEXCOORD6 r2 sv0 mask8
// OSGN | SV_Target0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb10[1]
dcl_sampler s5
dcl_sampler s8
dcl_resource_texture2d (float) t0
dcl_resource_texture2d (float) t20
dcl_input_ps_siv v0.xy sv1
dcl_input_ps linear v1.xy
dcl_input_ps linear v1.z
dcl_input_ps linear v2.xy
dcl_input_ps linear v2.z
dcl_input_ps linear v2.w
dcl_output o0
dcl_temps 2
mad r0.xy, v0.xyxx, cb10[0].zwzz, -v2.xyxx
mul r1.x, r0.x, cb10[0].x
mov r1.y, r0.y
div r0.zw, r1.xxxy, v2.wwww
mul r1.x, v2.z, v2.z
mad r1.y, r1.x, l(0.4), l(0.1)
mad r0.zw, r0.zzzw, r1.yyyy, v1.zzzz
sample_l r0.z, r0.zwzz, t20.yzxw, s5, l(0)
mad r0.z, r0.z, r1.x, l(1)
mul r0.zw, r0.zzzz, v1.xxxy
dp2 r0.z, r0.zwzz, r0.zwzz
sqrt r0.z, r0.z
add r0.w, -r0.z, l(1)
add r0.z, r0.z, l(1)
mad r0.xy, -r0.xyxx, r0.zzzz, v2.xyxx
sample_b r1, r0.xyxx, t0, s8, l(2)
lt r0.x, r0.w, l(0)
max r0.y, r0.w, l(0)
discard_nz r0.x
mad r0.x, r0.y, l(-2), l(3)
mul r0.y, r0.y, r0.y
mul r0.x, r0.y, r0.x
mul o0.w, r0.x, r1.w
mov o0.xyz, r1.xyzx
ret 
// instr=25 tex/ld=2
