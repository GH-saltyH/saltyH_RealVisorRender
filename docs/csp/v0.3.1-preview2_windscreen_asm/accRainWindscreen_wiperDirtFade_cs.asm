// chunks: ['ISGN', 'OSGN', 'SHEX']
// ISGN | 
// OSGN | 
cs_5_0
dcl_globalFlags 0x1
dcl_uav_typed_texture2d u7
dcl_input vThreadID.xy
dcl_temps 2
dcl_thread_group 16, 16, 1
ishl r0.x, vThreadID.y, l(4)
iadd r0.x, r0.x, vThreadID.x
mov r0.yzw, l(0, 0, 0, 0)
ld_uav_typed r1.x, r0.xwww, u7
mad r1.x, r1.x, l(0.95), l(-0.05)
max r1.x, r1.x, l(0)
store_uav_typed u7, r0, r1.xxxx
ret 
// instr=8 tex/ld=1
