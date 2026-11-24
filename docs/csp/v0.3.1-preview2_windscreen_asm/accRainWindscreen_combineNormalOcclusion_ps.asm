// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask3
// OSGN | SV_TARGET0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_sampler s2
dcl_resource_texture2d (float) t0
dcl_resource_texture2d (float) t1
dcl_input_ps linear noperspective v1.xy
dcl_output o0
dcl_temps 2
sample_l r0, v1.xyxx, t0, s2, l(0)
dp4 r0.w, r0, l(1, 1, 1, 1)
ne r0.w, l(0, 0, 0, 0), r0.w
if_z r0.w
sample_l_aoff(-1,0,0) r1, v1.xyxx, t0, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
and r1, r1, l(1, 1, 1, 1)
dp4 r0.w, r1, l(1, 1, 1, 1)
ne r0.w, l(0, 0, 0, 0), r0.w
sample_l_aoff(1,0,0) r1, v1.xyxx, t0, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(0,-1,0) r1, v1.xyxx, t0, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(0,1,0) r1, v1.xyxx, t0, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(-1,-1,0) r1, v1.xyxx, t0, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(-1,1,0) r1, v1.xyxx, t0, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(1,1,0) r1, v1.xyxx, t0, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(1,-1,0) r1, v1.xyxx, t0, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(-2,0,0) r1, v1.xyxx, t0, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(2,0,0) r1, v1.xyxx, t0, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(0,-2,0) r1, v1.xyxx, t0, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(0,2,0) r1, v1.xyxx, t0, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(-2,-1,0) r1, v1.xyxx, t0, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(-2,1,0) r1, v1.xyxx, t0, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(2,-1,0) r1, v1.xyxx, t0, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(2,1,0) r1, v1.xyxx, t0, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(-1,-2,0) r1, v1.xyxx, t0, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(1,-2,0) r1, v1.xyxx, t0, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(-1,2,0) r1, v1.xyxx, t0, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(1,2,0) r1.xyz, v1.xyxx, t0, s2, l(0)
ne r1.xyz, l(0, 0, 0, 0), r1.xyzx
or r1.xyz, r0.wwww, r1.xyzx
and r0.xyz, r1.xyzx, l(1, 1, 1, 0)
endif 
sample_l r1, v1.xyxx, t1, s2, l(0)
dp4 r0.w, r1, l(1, 1, 1, 1)
ne r0.w, l(0, 0, 0, 0), r0.w
if_nz r0.w
mov o0.w, r1.x
else 
sample_l_aoff(-1,0,0) r1, v1.xyxx, t1, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
and r1, r1, l(1, 1, 1, 1)
dp4 r0.w, r1, l(1, 1, 1, 1)
ne r0.w, l(0, 0, 0, 0), r0.w
sample_l_aoff(1,0,0) r1, v1.xyxx, t1, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(0,-1,0) r1, v1.xyxx, t1, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(0,1,0) r1, v1.xyxx, t1, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(-1,-1,0) r1, v1.xyxx, t1, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(-1,1,0) r1, v1.xyxx, t1, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(1,1,0) r1, v1.xyxx, t1, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(1,-1,0) r1, v1.xyxx, t1, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(-2,0,0) r1, v1.xyxx, t1, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(2,0,0) r1, v1.xyxx, t1, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(0,-2,0) r1, v1.xyxx, t1, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(0,2,0) r1, v1.xyxx, t1, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(-2,-1,0) r1, v1.xyxx, t1, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(-2,1,0) r1, v1.xyxx, t1, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(2,-1,0) r1, v1.xyxx, t1, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(2,1,0) r1, v1.xyxx, t1, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(-1,-2,0) r1, v1.xyxx, t1, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(1,-2,0) r1, v1.xyxx, t1, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(-1,2,0) r1, v1.xyxx, t1, s2, l(0)
ne r1, l(0, 0, 0, 0), r1
or r1, r0.wwww, r1
and r1, r1, l(1, 1, 1, 1)
dp4 r1.x, r1, l(1, 1, 1, 1)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
sample_l_aoff(1,2,0) r1.x, v1.xyxx, t1, s2, l(0)
ne r1.x, l(0, 0, 0, 0), r1.x
or r0.w, r0.w, r1.x
and o0.w, r0.w, l(1)
endif 
dp3 r0.w, r0.xyzx, r0.xyzx
rsq r0.w, r0.w
mul r0.xyz, r0.wwww, r0.xyzx
mad o0.xyz, r0.xyzx, l(0.5, 0.5, 0.5, 0), l(0.5, 0.5, 0.5, 0)
ret 
// instr=287 tex/ld=42
