"""Full production /WX shader: same-UV head/film/micro diagnostic only."""
from pathlib import Path
import sys
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'docs/tools/check_s86_pool_lens.py';scope={'__file__':str(path)}
prefix=path.read_text().split("exec(compile(text,",1)[0];exec(prefix,scope)
text=scope['text'].replace("OUT=ROOT/'docs/diagnostics/2026-10-15/s86'","OUT=ROOT/'docs/diagnostics/2026-10-16/s87'")
anchor="Image.fromarray((np.clip(a[:,:,:3],0,1)*255).astype(np.uint8)).save(OUT/'physical_film_lens.png')";assert text.count(anchor)==1
extra='''
linkHeight=height.copy();linkHeight[10:18,205:225,1]=20
linkHead=head.copy()
link=full_render('head_film_link_debug',full,{**tx,'txDynamicWaterTrail':linkHeight,'txDynamicBirthMask':linkHead},
    {**values,'gDynamicDropP3Debug':5,'gDynamicDropWFThreshold':.35},(W,H))
assert link[28:32,120:130,0].min()>.5 and link[28:32,120:130,1].min()>.9
assert np.max(link[28:32,80:90,1])==0 and link[28:32,80:90,0].min()>.3
assert link[11:17,207:223,2].min()>.4 and np.max(link[11:17,207:223,:2])==0
hiddenLink=full_render('native_occludes_link_debug',full,{**tx,'txDynamicWaterTrail':linkHeight,'txDynamicBirthMask':linkHead,'txDynamicOcclusion':depth},
    {**values,'gDynamicDropP3Debug':5,'gDynamicDropOcclusionOn':1},(W,H))
assert np.max(abs(hiddenLink))==0
normal=full_render('s87_normal_reference',old,tx,values,(W,H))
assert np.array_equal(a,normal)
mixedValues={**headValues,**values,'gDynamicDropWaterField':1}
mixed=full_render('normal_head_plus_field',full,headTx,mixedValues,(W,H))
mixedReference=full_render('s86_head_plus_field',old,headTx,mixedValues,(W,H))
assert np.array_equal(mixed,mixedReference) and np.max(abs(mixed-a))>.01
Image.fromarray((np.clip(link[:,:,:3],0,1)*255).astype(np.uint8)).save(OUT/'link_view.png')
'''
text=text.replace(anchor,extra+'\n'+anchor)
text=text.replace('nativeAlsoOccludesPoolDebug=True)','nativeAlsoOccludesPoolDebug=True,\n            view5SameCoordinates=True,view5FilmHeadMicroChannels=True,view5NativeOccluded=True,normalOutputBitIdenticalToS86=True,mixedHeadAndFilmNormalBitIdentical=True)')
text=text.replace('P3OffBitIdenticalToP2Stamp=True','P3OffBitIdenticalToS86=True')
exec(compile(text,str(ROOT/'docs/tools/check_s81_film_lens.py'),'exec'),{'__file__':str(ROOT/'docs/tools/check_s81_film_lens.py')})
