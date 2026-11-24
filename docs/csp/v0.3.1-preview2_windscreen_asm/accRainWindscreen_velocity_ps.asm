// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask3
// OSGN | SV_TARGET0 r0 sv0 mask3
ps_5_0
dcl_globalFlags 0x1
dcl_sampler s8
dcl_resource_texture2d (float) t0
dcl_input_ps linear noperspective v1.xy
dcl_output o0.xy
dcl_temps 2
sample_l_aoff(-2,0,0) r0.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.z, r0.z, l(0.9), l(0.1)
mul r0.xy, r0.zzzz, r0.xyxx
sample_l_aoff(-2,-1,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.z, r0.w
sample_l_aoff(-2,1,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.w, r0.z
sample_l_aoff(-1,-2,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.w, r0.z
sample_l_aoff(-1,-1,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.w, r0.z
sample_l_aoff(-1,0,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.w, r0.z
sample_l_aoff(-1,1,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.w, r0.z
sample_l_aoff(-1,2,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.w, r0.z
sample_l_aoff(0,-2,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.w, r0.z
sample_l_aoff(0,-1,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.w, r0.z
sample_l_aoff(0,0,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.w, r0.z
sample_l_aoff(0,1,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.w, r0.z
sample_l_aoff(0,2,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.w, r0.z
sample_l_aoff(1,-2,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.w, r0.z
sample_l_aoff(1,-1,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.w, r0.z
sample_l_aoff(1,0,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.w, r0.z
sample_l_aoff(1,1,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.w, r0.z
sample_l_aoff(1,2,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.w, r0.z
sample_l_aoff(2,-1,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.w, r0.z
sample_l_aoff(2,0,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.w, r0.z
sample_l_aoff(2,1,0) r1.xyz, v1.xyxx, t0.xywz, s8, l(0)
mad r0.w, r1.z, l(0.9), l(0.1)
mad r0.xy, r1.xyxx, r0.wwww, r0.xyxx
add r0.z, r0.w, r0.z
div o0.xy, r0.xyxx, r0.zzzz
ret 
// instr=85 tex/ld=21
