// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask3
// OSGN | SV_TARGET0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_sampler s0
dcl_resource_texture2d (float) t0
dcl_resource_texture2d (float) t1
dcl_input_ps linear noperspective v1.xy
dcl_output o0
dcl_temps 2
sample_l r0.xy, v1.xyxx, t1, s0, l(0)
dp2 r0.z, r0.xyxx, r0.xyxx
mad r0.xy, r0.xyxx, l(0.002, 0.002, 0, 0), v1.xyxx
sample_l r1, r0.xyxx, t0, s0, l(0)
sqrt r0.x, r0.z
min r0.x, r0.x, l(1)
mad r0.x, r0.x, l(-0.005), l(0.005)
mad_sat r0.y, r1.w, l(1.08), l(-0.04)
mov o0.xyz, r1.xyzx
add o0.w, -r0.x, r0.y
ret 
// instr=11 tex/ld=2
