// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask3
// OSGN | SV_TARGET0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_sampler s0
dcl_sampler s2
dcl_resource_texture2d (float) t0
dcl_input_ps linear noperspective v1.xy
dcl_output o0
dcl_temps 2
sample_l r0, v1.xyxx, t0, s2, l(0)
eq r0.w, r0.w, l(0)
if_nz r0.w
mov o0, l(0, 0, 0, 0)
ret 
endif 
sample_l_aoff(-4,-2,0) r0.w, v1.xyxx, t0, s0, l(1)
sample_l_aoff(-4,0,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
sample_l_aoff(-4,2,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
sample_l_aoff(-2,-4,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
sample_l_aoff(-2,-2,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
sample_l_aoff(-2,0,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
sample_l_aoff(-2,2,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
sample_l_aoff(-2,4,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
sample_l_aoff(0,-4,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
sample_l_aoff(0,-2,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
sample_l_aoff(0,0,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
sample_l_aoff(0,2,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
sample_l_aoff(0,4,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
sample_l_aoff(2,-4,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
sample_l_aoff(2,-2,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
sample_l_aoff(2,0,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
sample_l_aoff(2,2,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
sample_l_aoff(2,4,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
sample_l_aoff(4,-2,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
sample_l_aoff(4,0,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
sample_l_aoff(4,2,0) r1.x, v1.xyxx, t0.wxyz, s0, l(1)
add r0.w, r0.w, r1.x
deriv_rtx_coarse r1.x, r0.w
deriv_rty_coarse r1.y, r0.w
add r1.x, |r1.y|, |r1.x|
lt r1.x, l(0.5), r1.x
lt r0.w, r0.w, l(16.8)
or r0.w, r0.w, r1.x
if_nz r0.w
mov o0.xyz, r0.xyzx
mov o0.w, l(0.33)
ret 
endif 
mov o0.xyz, r0.xyzx
mov o0.w, l(1)
ret 
// instr=61 tex/ld=22
