// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask3
// OSGN | SV_TARGET0 r0 sv0 mask1
ps_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb8[2]
dcl_sampler s5
dcl_resource_texture2d (float) t0
dcl_resource_texture2d (float) t1
dcl_resource_texture2d (float) t2
dcl_input_ps linear noperspective v1.xy
dcl_output o0.x
dcl_temps 1
mul r0.x, cb8[1].y, l(100)
mov_sat r0.x, r0.x
sample_l r0.y, v1.xyxx, t0.yxzw, s5, l(0)
add r0.y, r0.y, l(-1)
mul r0.x, r0.y, r0.x
add r0.y, -cb8[0].y, l(1)
mad r0.y, r0.y, l(0.8), cb8[0].y
sample_l r0.z, v1.xyxx, t2.yzxw, s5, l(0)
add r0.z, -r0.z, l(1)
mul r0.y, r0.z, r0.y
mad r0.x, r0.y, r0.x, l(1)
sample_l r0.y, v1.xyxx, t1.yxzw, s5, l(0)
mad r0.y, cb8[1].x, l(0.05), r0.y
add_sat r0.y, r0.y, l(0.01)
mul o0.x, r0.y, r0.x
ret 
// instr=16 tex/ld=3
