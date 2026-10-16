"""Production shader /WX: scene-independent link debug, s87 normal equivalence."""
from pathlib import Path
import sys
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'docs/tools/check_s81_film_lens.py'
text=path.read_text()
text=text.replace("OUT=ROOT/'docs/diagnostics/2026-10-15/s81'","OUT=ROOT/'docs/diagnostics/2026-10-16/s89'")
text=text.replace('old=header+metric+','old=header+newUniforms+metric+')
anchor="Image.fromarray((np.clip(a[:,:,:3],0,1)*255).astype(np.uint8)).save(OUT/'physical_film_lens.png')"
assert text.count(anchor)==1
extra='''
linkHeight=height.copy();linkHeight[10:18,205:225,1]=20
linkTx={**tx,'txDynamicWaterTrail':linkHeight,'txDynamicBirthMask':head}
linkValues={**values,'gDynamicDropP3Debug':5,'gDynamicDropWFThreshold':.35}
v5=full_render('view5_reference',old,linkTx,linkValues,(W,H))
v5current=full_render('view5_preserved',full,linkTx,linkValues,(W,H))
assert np.array_equal(v5,v5current)
v6=full_render('isolated_channels',full,linkTx,{**linkValues,'gDynamicDropP3Debug':6},(W,H))
assert np.array_equal(v6[:,:,:3],v5[:,:,:3]) and np.min(v6[:,:,3])==1
assert v6[28:32,120:130,0].min()>.5 and v6[28:32,120:130,1].min()>.9
assert v6[11:17,207:223,2].min()>.4 and np.max(v6[11:17,207:223,:2])==0
assert np.max(v6[:8,:,:3])==0 # Dry field black despite arbitrary checkerboard scene.
changedScene=np.ones_like(scene);changedScene[:,:,:3]=(1,.2,.7)
second=full_render('isolated_changed_scene',full,{**linkTx,'txDynamicSnapshot':changedScene},
    {**linkValues,'gDynamicDropP3Debug':6},(W,H))
assert np.array_equal(v6,second)
hidden=full_render('native_excludes_isolated',full,{**linkTx,'txDynamicOcclusion':depth},
    {**linkValues,'gDynamicDropP3Debug':6,'gDynamicDropOcclusionOn':1},(W,H))
assert np.max(abs(hidden))==0
normal=full_render('normal_s87_reference',old,tx,values,(W,H))
assert np.array_equal(a,normal)
mixedValues={**headValues,**values,'gDynamicDropWaterField':1}
mixed=full_render('normal_head_field',full,headTx,mixedValues,(W,H))
mixedReference=full_render('normal_head_field_s87',old,headTx,mixedValues,(W,H))
assert np.array_equal(mixed,mixedReference)
# Exact depth must stay identical: opaque debug alpha does not become solid water.
depthValues={**linkValues,'gDynamicDropP3Debug':6,'gDynamicDropDepthOnly':1,
    'gDynamicDropDepthExact':1,'gDynamicDropDepthAlphaMin':.5}
depth6=full_render('isolated_no_solid_depth','#define RAIN_DEPTH_ONLY 1\\n'+coverage,tx,depthValues,(W,H))
assert np.max(abs(depth6))==0
Image.fromarray((np.clip(v6[:,:,:3],0,1)*255).astype(np.uint8)).save(OUT/'isolated_link_view.png')
'''
text=text.replace(anchor,extra+'\n'+anchor)
text=text.replace('transparentFilmWritesNoOpaqueDepth=True)',
    'transparentFilmWritesNoOpaqueDepth=True,view5BitIdentical=True,view6SameChannelsOpaque=True,view6SceneIndependent=True,view6EmptyBlack=True,view6NativeExcluded=True,view6NoSolidDepth=True,normalBitIdenticalToS87=True,mixedNormalBitIdenticalToS87=True)')
text=text.replace('P3OffBitIdenticalToP2Stamp=True','P3OffBitIdenticalToS87=True')
exec(compile(text,str(path),'exec'),{'__file__':str(path)})
