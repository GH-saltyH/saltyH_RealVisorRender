"""Full production shader /WX: returned-pool marker and existing optics/depth gates."""
from pathlib import Path
import sys
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'docs/tools/check_s81_film_lens.py';text=path.read_text()
text=text.replace("OUT=ROOT/'docs/diagnostics/2026-10-15/s81'","OUT=ROOT/'docs/diagnostics/2026-10-15/s86'")
# The staged s85 shader already has the same P3 uniforms, unlike pre-P3 s80.
text=text.replace("old=header+metric+",'old=header+newUniforms+metric+')
anchor="Image.fromarray((np.clip(a[:,:,:3],0,1)*255).astype(np.uint8)).save(OUT/'physical_film_lens.png')"
assert text.count(anchor)==1
extra='''
marker=height.copy();marker[:,:,2]=0;marker[28:34,120:132,2]=500
marked=full_render('pool_return_debug',full,{**tx,'txDynamicWaterTrail':marker},
                   {**values,'gDynamicDropP3Debug':4},(W,H))
assert marked[28:34,120:132,0].min()>.5
assert np.max(marked[:20,:,:3])==0
ordinary=full_render('pool_marker_not_inventory',full,{**tx,'txDynamicWaterTrail':marker},values,(W,H))
assert np.array_equal(ordinary,a)
hiddenMarker=full_render('native_occludes_pool_debug',full,{**tx,'txDynamicWaterTrail':marker,'txDynamicOcclusion':depth},
    {**values,'gDynamicDropP3Debug':4,'gDynamicDropOcclusionOn':1},(W,H))
assert np.max(abs(hiddenMarker))==0
'''
text=text.replace(anchor,extra+'\n'+anchor)
text=text.replace('transparentFilmWritesNoOpaqueDepth=True)','transparentFilmWritesNoOpaqueDepth=True,\n            poolDebugVisible=True,poolDebugDoesNotAffectOptics=True,nativeAlsoOccludesPoolDebug=True)')
exec(compile(text,str(path),'exec'),{'__file__':str(path)})
