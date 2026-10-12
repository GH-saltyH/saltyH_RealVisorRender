"""Read user MP4s with Windows Media Foundation; make timestamped contact sheets."""
from pathlib import Path
import subprocess, tempfile, struct, json, sys
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
CPP=r'''
#include <windows.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <wrl/client.h>
#include <cstdio>
#include <fstream>
#include <stdexcept>
using Microsoft::WRL::ComPtr;
void ck(HRESULT h) {if(FAILED(h)){printf("HRESULT %08x\n",(unsigned)h);throw std::runtime_error("MF failed");}}
int wmain(int argc,wchar_t** argv) {try {
 ck(CoInitializeEx(nullptr,COINIT_MULTITHREADED));ck(MFStartup(MF_VERSION));
 ComPtr<IMFAttributes> attrs;ck(MFCreateAttributes(&attrs,2));ck(attrs->SetUINT32(MF_SOURCE_READER_ENABLE_VIDEO_PROCESSING,1));
 ComPtr<IMFSourceReader> reader;ck(MFCreateSourceReaderFromURL(argv[1],attrs.Get(),&reader));
 ck(reader->SetStreamSelection(MF_SOURCE_READER_ALL_STREAMS,FALSE));ck(reader->SetStreamSelection(MF_SOURCE_READER_FIRST_VIDEO_STREAM,TRUE));
 ComPtr<IMFMediaType> type;ck(MFCreateMediaType(&type));ck(type->SetGUID(MF_MT_MAJOR_TYPE,MFMediaType_Video));ck(type->SetGUID(MF_MT_SUBTYPE,MFVideoFormat_RGB32));
 ck(reader->SetCurrentMediaType(MF_SOURCE_READER_FIRST_VIDEO_STREAM,nullptr,type.Get()));
 ck(reader->GetCurrentMediaType(MF_SOURCE_READER_FIRST_VIDEO_STREAM,&type));
 UINT32 w,h;ck(MFGetAttributeSize(type.Get(),MF_MT_FRAME_SIZE,&w,&h));
 PROPVARIANT duration;PropVariantInit(&duration);ck(reader->GetPresentationAttribute(MF_SOURCE_READER_MEDIASOURCE,MF_PD_DURATION,&duration));
 auto ticks=duration.uhVal.QuadPart;PropVariantClear(&duration);printf("%u %u %.6f\n",w,h,ticks/1e7);
 LONG defaultStride;UINT32 stride; if(SUCCEEDED(type->GetUINT32(MF_MT_DEFAULT_STRIDE,&stride)))defaultStride=(LONG)stride;else ck(MFGetStrideForBitmapInfoHeader(MFVideoFormat_RGB32.Data1,w,&defaultStride));
 for(int i=0;i<16;i++) {
   LONGLONG wanted=(LONGLONG)(ticks*(.02+.95*i/15.));PROPVARIANT pos;PropVariantInit(&pos);pos.vt=VT_I8;pos.hVal.QuadPart=wanted;
   ck(reader->SetCurrentPosition(GUID_NULL,pos));PropVariantClear(&pos);
   for(int attempt=0;attempt<1000;attempt++) {
     DWORD flags;LONGLONG time;ComPtr<IMFSample> sample;ck(reader->ReadSample(MF_SOURCE_READER_FIRST_VIDEO_STREAM,0,nullptr,&flags,&time,&sample));
     if(flags&MF_SOURCE_READERF_ENDOFSTREAM)break;if(!sample || time<wanted)continue;
     ComPtr<IMFMediaBuffer> buf;ck(sample->ConvertToContiguousBuffer(&buf));BYTE* pixels;DWORD maxlen,len;LONG pitch=defaultStride;
     ComPtr<IMF2DBuffer> two;bool lock2d=SUCCEEDED(buf.As(&two));if(lock2d)ck(two->Lock2D(&pixels,&pitch));else {ck(buf->Lock(&pixels,&maxlen,&len));if(pitch<0)pixels+=(h-1)*(-pitch);}
     wchar_t path[MAX_PATH];swprintf_s(path,L"%s/%02d.raw",argv[2],i);std::ofstream out(path,std::ios::binary);
     out.write((char*)&w,4);out.write((char*)&h,4);for(UINT32 y=0;y<h;y++)out.write((char*)(pixels+y*pitch),w*4);
     if(lock2d)two->Unlock2D();else buf->Unlock();printf("%d %.6f\n",i,time/1e7);break;
   }
 }
 return 0;
}catch(const std::exception& e){fprintf(stderr,"%s\n",e.what());return 1;}}
'''
VC=Path('C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Auxiliary/Build/vcvars64.bat')
OUT=ROOT/'docs/diagnostics/2026-10-10'
if len(sys.argv)>2 and sys.argv[1]=='--output-dir':
    OUT=ROOT/sys.argv[2]
    del sys.argv[1:3]
OUT.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='video_inspect_',dir=ROOT/'docs/tools') as tmp:
    tmp=Path(tmp);src=tmp/'reader.cpp';exe=tmp/'reader.exe';src.write_text(CPP)
    subprocess.run(f'"{VC}" && cl /nologo /EHsc /std:c++17 "{src}" /Fo"{tmp / "reader.obj"}" /Fe"{exe}" /link mfplat.lib mfreadwrite.lib mfuuid.lib ole32.lib',
                   shell=True,cwd=tmp,check=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    for index,name in enumerate(sys.argv[1:],1):
        result=subprocess.check_output([str(exe),name,str(tmp)],text=True)
        rows=result.strip().splitlines();w,h,duration=rows[0].split()
        sheet=Image.new('RGB',(4*640,4*390),(20,20,20));draw=ImageDraw.Draw(sheet)
        for row in rows[1:]:
            i,time=row.split();i=int(i);raw=(tmp/f'{i:02d}.raw').read_bytes();w,h=struct.unpack_from('<II',raw)
            im=Image.frombytes('RGB',(w,h),raw[8:],'raw','BGRX')
            if i in (0,5,10,15):im.save(OUT/f'video{index}_{i:02d}.jpg',quality=92)
            im.thumbnail((640,360));x,y=i%4*640,i//4*390
            sheet.paste(im,(x,y+28));draw.text((x+8,y+8),f'{float(time):.3f} s',fill='white')
        sheet.save(OUT/f'video{index}_contact.jpg',quality=90)
        print(json.dumps({'file':name,'duration':float(duration),'sheet':str(OUT/f'video{index}_contact.jpg')},ensure_ascii=False))
