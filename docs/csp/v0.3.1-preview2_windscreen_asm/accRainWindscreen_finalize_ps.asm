// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask3
// OSGN | SV_TARGET0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_sampler s8
dcl_resource_texture2d (float) t0
dcl_input_ps linear noperspective v1.xy
dcl_output o0
dcl_temps 3
add r0, v1.xyxy, l(-0.0005, 0, 0, -0.0005)
sample_l r0.xy, r0.xyxx, t0.zwxy, s8, l(1.5)
sample_l r0.zw, r0.zwzz, t0, s8, l(1.5)
max r0.xz, r0.yywy, r0.xxzx
sample_l r0.yw, v1.xyxx, t0.xzyw, s8, l(1.5)
max r0.y, r0.w, r0.y
add r1.xy, -r0.yyyy, r0.xzxx
add r2, v1.xyxy, l(0.0005, 0, 0, 0.0005)
sample_l r0.xz, r2.xyxx, t0.zxwy, s8, l(1.5)
sample_l r1.zw, r2.zwzz, t0, s8, l(1.5)
max r0.w, r1.w, r1.z
max r0.x, r0.z, r0.x
add r2.xy, -r0.yyyy, r0.xwxx
add r0.xy, -r1.xyxx, r2.xyxx
mad o0.xy, r0.xyxx, l(-1.1, -1.1, 0, 0), l(0.5, 0.5, 0, 0)
sample_l r0.xy, v1.xyxx, t0.zwxy, s8, l(0)
mov o0.zw, r0.xxxy
ret 
// instr=18 tex/ld=6
