#!/usr/bin/env python3
"""RainFX v2 evaluation: per-run medians of the metrics CSVs vs docs/RAINFX_V2_EVAL.md targets.
Usage: python docs/tools/rainfx2_eval.py docs/videos/rev12_GAME_REVIEW > table.md
File names: revNN_profile_<id>_<name>_T<k>.csv"""
import csv, glob, os, re, statistics as S, sys
D=sys.argv[1]
rows=[]
def regime(q, cars, nearest, water, kmh):
    if cars>0 and 0<=nearest<=40 and water>=0.5 and kmh>=150: return 'A'
    return 'A' if q>=0.10 else 'B' if q>=0.03 else 'C'
T={'C':dict(film=(0,0.05),drops=(0.02,0.12),haze=(0,0.10)),
   'B':dict(film=(0.05,0.35),drops=(0.08,0.25),haze=(0.05,0.25)),
   'A':dict(film=(0.50,1),drops=(0,0.20),haze=(0.15,1))}
print('| profile | T | km/h | q_rain | spray (cars, near) | film supply | regime | filmCover | dropCover | haze | verdict |')
print('|---|---|---|---|---|---|---|---|---|---|---|')
for f in sorted(glob.glob(D+'/*.csv')):
    r=list(csv.DictReader(open(f)))
    if not r: continue
    n=re.sub(r'^rev\d+_profile_','',os.path.basename(f)[:-4]); prof,t=n.rsplit('_',1)
    med=lambda k: S.median(float(x[k]) for x in r)
    mx=lambda k: max(float(x[k]) for x in r)
    kmh=med('carKmh'); q=med('rainFluxMMs'); sp=med('spray'); cars=mx('sprayCars'); near=med('nearestM')
    film=med('filmCover'); drops=med('dropCover'); haze=med('haze'); water=med('rainWater')
    if t=='T1': reg='C*'
    else: reg=regime(q,cars,near,water,kmh)
    tg=T[reg.strip('*')]
    if t=='T1': tg=dict(film=(0,0.05),drops=(0,1),haze=(0,1))
    v=[]
    for k,val in (('film',film),('drops',drops),('haze',haze)):
        lo,hi=tg[k]
        if val<lo: v.append(k+'↓')
        elif val>hi: v.append(k+'↑')
    print(f'| {prof} | {t} | {kmh:.0f} | {q:.3f} | {sp:.2f} ({cars:.0f}, {near:.0f}) | {mx("filmRate"):.3f} | {reg} | {film*100:.1f}% | {drops*100:.1f}% | {haze:.3f} | {"OK" if not v else " ".join(v)} |')
