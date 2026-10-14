"""Local, timestamped P2 video samples. Originals are never modified."""
from pathlib import Path
import json, subprocess
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/diagnostics/2026-10-15/s80/frames'
BIN=Path('C:/Users/songak/AppData/Local/Overwolf/Extensions/ncfplpkmiejjaklknfnkgcpapnhkggmlcppckhcb/270.0.10/obs/bin/64bit')
OUT.mkdir(parents=True,exist_ok=True)
reports=[]
for i,path in enumerate(sorted((ROOT/'docs/videos').glob('_P2*.mp4'))):
    metadata=json.loads(subprocess.check_output([str(BIN/'ffprobe.exe'),'-v','quiet','-print_format','json','-show_format','-show_streams',str(path)]))
    duration=float(metadata['format']['duration']); stream=next(s for s in metadata['streams'] if s['codec_type']=='video')
    times=[duration*j/9 for j in range(1,9)]
    sheet=Image.new('RGB',(1280,4*390),'#222222'); draw=ImageDraw.Draw(sheet)
    for j,t in enumerate(times):
        dest=OUT/f'video{i}_{j}.png'
        subprocess.run([str(BIN/'ffmpeg.exe'),'-v','error','-y','-ss',str(t),'-i',str(path),'-frames:v','1',str(dest)],check=True)
        frame=Image.open(dest).convert('RGB'); frame.thumbnail((640,360))
        x=(j%2)*640;y=(j//2)*390
        sheet.paste(frame,(x,y+30));draw.text((x+8,y+8),f'Video {i}, {t:.3f} s',fill='white')
    sheet.save(OUT/f'video{i}_sheet.jpg',quality=92)
    reports.append(dict(index=i,path=path.relative_to(ROOT).as_posix(),durationSeconds=duration,
                        width=stream['width'],height=stream['height'],frameRate=stream['avg_frame_rate'],samplesSeconds=times))
(OUT/'metadata.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(reports,ensure_ascii=False,indent=2))
