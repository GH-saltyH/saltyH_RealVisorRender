// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask3
// OSGN | SV_TARGET0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb10[1]
dcl_sampler s5
dcl_sampler s8
dcl_resource_texture2d (float) t0
dcl_resource_texture2d (float) t1
dcl_input_ps linear noperspective v1.xy
dcl_output o0
dcl_temps 4
sample_l r0.x, v1.xyxx, t1, s5, l(0)
lt r0.y, r0.x, l(0.00166667)
if_nz r0.y
mov o0, l(0, 0, 0, 0)
ret 
endif 
mul r0.xy, r0.xxxx, l(3, 6, 0, 0)
mov r1.x, l(1)
mov r1.y, cb10[0].x
mad r2, l(0.00447738, -0.000787822, 0.00217613, -0.00249241), r1.xyxy, v1.xyxy
sample_l r0.z, r2.xyxx, t1.yzxw, s5, l(0.5)
deriv_rtx_coarse r2.x, r0.z
deriv_rty_coarse r2.y, r0.z
sample_l r0.z, r2.zwzz, t1.yzxw, s5, l(0.5)
deriv_rtx_coarse r3.x, r0.z
deriv_rty_coarse r3.y, r0.z
add r0.zw, r2.xxxy, r3.xxxy
mad r2, l(0.00384789, 0.00180837, 0.000661926, 0.000248786), r1.xyxy, v1.xyxy
sample_l r1.z, r2.xyxx, t1.yzxw, s5, l(0.5)
deriv_rtx_coarse r2.x, r1.z
deriv_rty_coarse r2.y, r1.z
add r0.zw, r0.zzzw, r2.xxxy
sample_l r1.z, r2.zwzz, t1.yzxw, s5, l(0.5)
deriv_rtx_coarse r2.x, r1.z
deriv_rty_coarse r2.y, r1.z
add r0.zw, r0.zzzw, r2.xxxy
mad r2, l(0.00105281, 0.00455486, 0.00113887, 0.00247239), r1.xyxy, v1.xyxy
sample_l r1.z, r2.xyxx, t1.yzxw, s5, l(0.5)
deriv_rtx_coarse r2.x, r1.z
deriv_rty_coarse r2.y, r1.z
add r0.zw, r0.zzzw, r2.xxxy
sample_l r1.z, r2.zwzz, t1.yzxw, s5, l(0.5)
deriv_rtx_coarse r2.x, r1.z
deriv_rty_coarse r2.y, r1.z
add r0.zw, r0.zzzw, r2.xxxy
mad r2, l(-0.00190137, 0.00057357, -0.000555947, -0.00141797), r1.xyxy, v1.xyxy
sample_l r1.z, r2.xyxx, t1.yzxw, s5, l(0.5)
deriv_rtx_coarse r2.x, r1.z
deriv_rty_coarse r2.y, r1.z
add r0.zw, r0.zzzw, r2.xxxy
sample_l r1.z, r2.zwzz, t1.yzxw, s5, l(0.5)
deriv_rtx_coarse r2.x, r1.z
deriv_rty_coarse r2.y, r1.z
add r0.zw, r0.zzzw, r2.xxxy
mad r2, l(-0.00114127, 0.00285664, -0.00267321, -0.00133361), r1.xyxy, v1.xyxy
sample_l r1.z, r2.xyxx, t1.yzxw, s5, l(0.5)
deriv_rtx_coarse r2.x, r1.z
deriv_rty_coarse r2.y, r1.z
add r0.zw, r0.zzzw, r2.xxxy
sample_l r1.z, r2.zwzz, t1.yzxw, s5, l(0.5)
deriv_rtx_coarse r2.x, r1.z
deriv_rty_coarse r2.y, r1.z
add r0.zw, r0.zzzw, r2.xxxy
mad r2, l(-0.00294709, -0.00381323, -0.00105278, -0.00482041), r1.xyxy, v1.xyxy
sample_l r1.z, r2.xyxx, t1.yzxw, s5, l(0.5)
deriv_rtx_coarse r2.x, r1.z
deriv_rty_coarse r2.y, r1.z
add r0.zw, r0.zzzw, r2.xxxy
sample_l r1.z, r2.zwzz, t1.yzxw, s5, l(0.5)
deriv_rtx_coarse r2.x, r1.z
deriv_rty_coarse r2.y, r1.z
add r0.zw, r0.zzzw, r2.xxxy
mad r2, l(-0.0031918, 0.00237793, -0.00464267, 0.000750924), r1.xyxy, v1.xyxy
sample_l r1.z, r2.xyxx, t1.yzxw, s5, l(0.5)
deriv_rtx_coarse r2.x, r1.z
deriv_rty_coarse r2.y, r1.z
add r0.zw, r0.zzzw, r2.xxxy
sample_l r1.z, r2.zwzz, t1.yzxw, s5, l(0.5)
deriv_rtx_coarse r2.x, r1.z
deriv_rty_coarse r2.y, r1.z
add r0.zw, r0.zzzw, r2.xxxy
mad r1, l(0.00196915, -0.00457233, -0.00468074, -0.00160706), r1.xyxy, v1.xyxy
sample_l r1.x, r1.xyxx, t1, s5, l(0.5)
deriv_rtx_coarse r2.x, r1.x
deriv_rty_coarse r2.y, r1.x
add r0.zw, r0.zzzw, r2.xxxy
sample_l r1.x, r1.zwzz, t1, s5, l(0.5)
deriv_rtx_coarse r2.x, r1.x
deriv_rty_coarse r2.y, r1.x
add r0.zw, r0.zzzw, r2.xxxy
mul_sat r0.zw, r0.zzzw, l(0, 0, 0.0625, 0.0625)
mul r0.xz, r0.xxxx, r0.zzwz
mad r0.xz, -r0.xxzx, l(3.5, 0, 3.5, 0), v1.xxyx
sample_l r1, r0.xzxx, t0, s8, r0.y
dp4 r0.x, r1, l(1, 1, 1, 1)
ne r0.x, l(0, 0, 0, 0), r0.x
not r0.x, r0.x
discard_nz r0.x
mov_sat o0.w, r0.y
mov o0.xyz, r1.xyzx
ret 
// instr=91 tex/ld=18
