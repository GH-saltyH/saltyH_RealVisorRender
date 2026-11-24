// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 maskf; TEXCOORD2 r2 sv0 mask3
// OSGN | SV_Target0 r0 sv0 maskf; SV_Target1 r1 sv0 maskf; SV_Target2 r2 sv0 maskf; SV_Target3 r3 sv0 maskf
ps_5_0
dcl_globalFlags 0x1
dcl_constantbuffer cb10[5]
dcl_constantbuffer cb11[96] dynamicIndexed
dcl_input_ps linear noperspective v1.xyz
dcl_output o0
dcl_output o1
dcl_output o2
dcl_output o3
dcl_temps 2
deriv_rtx_coarse r0.xyz, v1.xyzx
deriv_rty_coarse r1.xyz, v1.xyzx
mul o0.xyz, r0.xyzx, cb10[4].xxxx
mul o1.xyz, r1.xyzx, cb10[4].xxxx
mov r0.xy, l(1, 0, 0, 0)
loop 
uge r0.z, r0.y, l(16)
breakc_nz r0.z
imul null, r0.z, r0.y, l(3)
mad r1.xyz, v1.xyzx, cb11[r0.z + 1].xyzx, cb11[r0.z].xyzx
dp3 r0.w, r1.xyzx, r1.xyzx
sqrt r0.w, r0.w
min r0.w, r0.w, l(1)
mad_sat r0.w, r0.w, cb11[r0.z].w, cb11[r0.z + 1].w
add r1.x, r0.x, -cb11[r0.z + 2].x
mad_sat r0.x, r0.w, r1.x, cb11[r0.z + 2].x
iadd r0.y, r0.y, l(1)
endloop 
mov o3.x, r0.x
mov r0.xy, l(1, 0, 0, 0)
loop 
uge r0.z, r0.y, l(8)
breakc_nz r0.z
imul null, r0.z, r0.y, l(3)
mad r1.xyz, v1.xyzx, cb11[r0.z + 49].xyzx, cb11[r0.z + 48].xyzx
dp3 r0.w, r1.xyzx, r1.xyzx
sqrt r0.w, r0.w
min r0.w, r0.w, l(1)
mad_sat r0.w, r0.w, cb11[r0.z + 48].w, cb11[r0.z + 49].w
add r1.x, r0.x, -cb11[r0.z + 50].x
mad_sat r0.x, r0.w, r1.x, cb11[r0.z + 50].x
iadd r0.y, r0.y, l(1)
endloop 
mul o3.y, r0.x, cb10[4].z
mov r0.xy, l(0, 0, 0, 0)
loop 
uge r0.z, r0.y, l(8)
breakc_nz r0.z
imul null, r0.z, r0.y, l(3)
mad r1.xyz, v1.xyzx, cb11[r0.z + 73].xyzx, cb11[r0.z + 72].xyzx
dp3 r0.w, r1.xyzx, r1.xyzx
sqrt r0.w, r0.w
min r0.w, r0.w, l(1)
mad_sat r0.w, r0.w, cb11[r0.z + 72].w, cb11[r0.z + 73].w
add r1.x, r0.x, -cb11[r0.z + 74].x
mad r0.z, r0.w, r1.x, cb11[r0.z + 74].x
max r0.z, r0.z, l(-1)
min r0.x, r0.z, l(1)
iadd r0.y, r0.y, l(1)
endloop 
mad o3.z, r0.x, l(0.5), l(0.5)
mov o0.w, l(1)
mov o1.w, cb10[4].y
mov o2.xyz, v1.xyzx
mov o2.w, l(1)
mov o3.w, l(1)
ret 
// instr=57 tex/ld=0
