// T1 (H3 spec 8m): the haze pass binds the substep wipe mask in the big-drop slot (14 textures: t14 is CSP's). common.hlsl
// still names txR2Big in visor-only helpers the haze pass never calls; they compile against the mask instead.
#define txR2Big txR2Wm
