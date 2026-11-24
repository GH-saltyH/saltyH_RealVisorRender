// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask3
// OSGN | SV_TARGET0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_immediateConstantBuffer { -0.608921, -0.450188, 0.757267, 0, -0.00981352, 0.720582, 0.720648, 0, -0.625022, 0.355785, 0.719191, 0, 0.163966, -0.973345, 0.987059, 0, 0.194564, -0.074192, 0.208228, 0, 0.690341, 0.686608, 0.973654, 0, 0.819938, -0.549265, 0.98691, 0 }
dcl_sampler s8
dcl_resource_texture2d (float) t0
dcl_input_ps linear noperspective v1.xy
dcl_output o0
dcl_temps 2
mov r0.xyz, l(0, 0, 0, 0)
loop 
uge r0.w, r0.y, l(7)
breakc_nz r0.w
mad r1.xy, icb[r0.y].xyxx, l(0.002, 0.002, 0, 0), v1.xyxx
sample_l r1.xy, r1.xyxx, t0.xzyw, s8, l(0)
add r0.xz, r0.xxzx, r1.xxyx
iadd r0.y, r0.y, l(1)
endloop 
sample_l r1, v1.xyxx, t0, s8, l(0)
add r0.xy, r0.xzxx, r1.xzxx
mul o0.xz, r0.xxyx, l(0.125, 0, 0.125, 0)
mov o0.yw, r1.yyyw
ret 
// instr=14 tex/ld=2
