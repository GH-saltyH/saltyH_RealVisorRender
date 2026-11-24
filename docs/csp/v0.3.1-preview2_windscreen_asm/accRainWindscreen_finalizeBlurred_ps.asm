// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | SV_POSITION0 r0 sv1 maskf; TEXCOORD0 r1 sv0 mask3
// OSGN | SV_TARGET0 r0 sv0 mask1
ps_5_0
dcl_globalFlags 0x1
dcl_immediateConstantBuffer { 0.895477, -0.157564, 0.909233, 0, 0.435226, -0.498482, 0.661745, 0, 0.769578, 0.361673, 0.850328, 0, 0.132385, 0.0497573, 0.141427, 0, 0.210562, 0.910972, 0.93499, 0, 0.227773, 0.494479, 0.544417, 0, -0.380273, 0.114714, 0.397199, 0, -0.111189, -0.283593, 0.304611, 0, -0.228253, 0.571329, 0.615237, 0, -0.534642, -0.266723, 0.597481, 0, -0.589418, -0.762647, 0.963869, 0, -0.210555, -0.964082, 0.986807, 0, -0.638359, 0.475587, 0.796044, 0, -0.928533, 0.150185, 0.940601, 0, 0.39383, -0.914465, 0.995665, 0, -0.936148, -0.321412, 0.989787, 0 }
dcl_constantbuffer cb12[2]
dcl_sampler s2
dcl_sampler s5
dcl_sampler s8
dcl_resource_texture2d (float) t0
dcl_resource_texture2d (float) t1
dcl_resource_texture2d (float) t2
dcl_resource_texture2d (float) t9
dcl_input_ps_siv v0.xy sv1
dcl_input_ps linear noperspective v1.xy
dcl_output o0.x
dcl_temps 2
mov r0.xy, l(0, 0, 0, 0)
loop 
uge r0.z, r0.y, l(16)
breakc_nz r0.z
mad r0.zw, icb[r0.y].xxxy, l(0, 0, 0.015, 0.015), v1.xxxy
sample_l r0.z, r0.zwzz, t0.xywz, s8, l(4.5)
add r0.x, r0.z, r0.x
iadd r0.y, r0.y, l(1)
endloop 
mul r0.x, r0.x, l(0.1875)
ftoi r1.xy, v0.xyxx
mov r1.zw, l(0, 0, 0, 0)
ld r0.y, r1, t1.yxzw
sample_l r0.z, v1.xyxx, t2.xywz, s5, l(2.5)
sample_l r0.w, v1.xyxx, t9, s2, l(0)
add r1.x, r0.y, -cb12[0].z
mul r1.y, r0.x, cb12[0].x
mad r0.x, -r0.y, l(2), r0.x
mul_sat r0.x, r0.x, l(4)
mad r0.x, r1.y, r0.x, r1.x
add r0.y, -r0.z, l(1)
mul r0.z, r0.y, r0.x
mad r0.x, -r0.x, r0.y, l(1)
mad_sat r0.y, r0.w, l(3), l(-2)
mul r0.x, r0.y, r0.x
mad r0.x, r0.x, cb12[0].x, r0.z
min o0.x, r0.x, cb12[1].x
ret 
// instr=28 tex/ld=4
