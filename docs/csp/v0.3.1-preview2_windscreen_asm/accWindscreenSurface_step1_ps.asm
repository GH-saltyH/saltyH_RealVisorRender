// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask3
// OSGN | SV_TARGET0 r0 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb10[1]
dcl_sampler s5
dcl_sampler s9
dcl_resource_texture2d (float) t0
dcl_input_ps linear noperspective v1.xy
dcl_output o0
dcl_temps 7
sample_l r0, v1.xyxx, t0, s5, l(0)
ne r1.x, l(0, 0, 0, 0), r0.w
if_nz r1.x
mov o0, r0
ret 
endif 
mov r0, l(0, 0, 0, 0)
mov r1.xyz, l(0, 1, 0, 0)
loop 
ilt r1.w, l(20), r1.y
mov r1.z, l(0)
breakc_nz r1.w
itof r1.w, r1.y
mul r2.xy, r1.wwww, cb10[0].xyxx
mad r2.xy, r2.xyxx, l(10, 10, 0, 0), v1.xyxx
sample_l r2, r2.xyxx, t0, s9, l(0)
ne r1.w, l(0, 0, 0, 0), r2.w
if_nz r1.w
imul null, r3.x, r1.y, l(10)
mov r4, r0
mov r3.y, r1.x
mov r3.zw, l(0, 0, -9, 0)
loop 
ige r5.x, r3.z, l(0)
mov r3.w, l(0)
breakc_nz r5.x
imad r5.x, r1.y, l(10), r3.z
itof r3.y, r5.x
mad r5.xy, cb10[0].xyxx, r3.yyyy, v1.xyxx
sample_l r4, r5.xyxx, t0, s9, l(0)
ne r5.x, l(0, 0, 0, 0), r4.w
if_nz r5.x
mov r3.w, l(-1)
break 
endif 
iadd r3.z, r3.z, l(1)
mov r3.w, r5.x
mov r4, l(0, 0, 0, 0)
mov r3.y, l(0)
endloop 
mov r0, r4
mov r1.x, r3.y
mov r1.z, r3.w
breakc_nz r3.w
itof r1.x, r3.x
mov r0, r2
mov r1.z, l(-1)
break 
endif 
iadd r1.y, r1.y, l(1)
mov r1.yz, r1.yywy
mov r0, l(0, 0, 0, 0)
mov r1.x, l(0)
endloop 
and r0, r0, r1.zzzz
mov r2, l(0, 0, 0, 0)
mov r1.yw, l(0, 0, 0, 1)
mov r3.x, l(0)
loop 
ilt r3.y, l(20), r1.w
mov r3.x, l(0)
breakc_nz r3.y
itof r3.y, r1.w
mul r3.yz, r3.yyyy, -cb10[0].xxyx
mad r3.yz, r3.yyzy, l(0, 10, 10, 0), v1.xxyx
sample_l r4, r3.yzyy, t0, s9, l(0)
ne r3.y, l(0, 0, 0, 0), r4.w
if_nz r3.y
imul null, r3.z, r1.w, l(10)
mov r5, r2
mov r3.w, r1.y
mov r6.xy, l(-9, 0, 0, 0)
loop 
ige r6.z, r6.x, l(0)
mov r6.y, l(0)
breakc_nz r6.z
imad r6.z, r1.w, l(10), r6.x
itof r3.w, r6.z
mad r6.zw, -cb10[0].xxxy, r3.wwww, v1.xxxy
sample_l r5, r6.zwzz, t0, s9, l(0)
ne r6.z, l(0, 0, 0, 0), r5.w
if_nz r6.z
mov r6.y, l(-1)
break 
endif 
iadd r6.x, r6.x, l(1)
mov r6.xy, r6.xzxx
mov r5, l(0, 0, 0, 0)
mov r3.w, l(0)
endloop 
mov r2, r5
mov r1.y, r3.w
mov r3.x, r6.y
breakc_nz r6.y
itof r1.y, r3.z
mov r2, r4
mov r3.x, l(-1)
break 
endif 
iadd r1.w, r1.w, l(1)
mov r3.x, r3.y
mov r2, l(0, 0, 0, 0)
mov r1.y, l(0)
endloop 
and r2, r2, r3.xxxx
ne r1.w, l(0, 0, 0, 0), r0.w
ne r3.y, l(0, 0, 0, 0), r2.w
and r3.y, r1.w, r3.y
if_nz r3.y
and r1.x, r1.x, r1.z
and r1.y, r1.y, r3.x
mul r3, r1.xxxx, r2
mad r3, r0, r1.yyyy, r3
add r1.x, r1.y, r1.x
div o0, r3, r1.xxxx
ret 
else 
movc o0, r1.wwww, r0, r2
ret 
endif 
ret 
// instr=121 tex/ld=5
