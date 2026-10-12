// Offscreen D3D11 WARP fixture: execute the production pixel shader, with
// constant input textures, and return a float HDR pixel. No game resources.
#include <d3d11.h>
#include <d3dcompiler.h>
#include <wrl/client.h>
#include <fstream>
#include <vector>
#include <cstdio>
#include <stdexcept>
using Microsoft::WRL::ComPtr;
void check(HRESULT hr) { if (FAILED(hr)) throw std::runtime_error("D3D failure"); }
int main(int argc,char** argv) {
    try {
        if(argc!=3) return 2;
        std::ifstream shader(argv[1],std::ios::binary);
        std::vector<char> code((std::istreambuf_iterator<char>(shader)),{});
        std::ifstream inputs(argv[2],std::ios::binary);
        unsigned count=0;inputs.read(reinterpret_cast<char*>(&count),4);
        bool spatial=(count&0x80000000u)!=0;count&=0x7fffffffu;
        if(code.empty() || count>11) return 2;
        ComPtr<ID3D11Device> device;ComPtr<ID3D11DeviceContext> context;
        check(D3D11CreateDevice(nullptr,D3D_DRIVER_TYPE_WARP,nullptr,0,nullptr,0,D3D11_SDK_VERSION,&device,nullptr,&context));
        const char* vsSource=R"(
            struct VS_OUT {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;};
            VS_OUT main(uint id:SV_VertexID) {
                VS_OUT o;o.PosH=float4(id==2?3:-1,id==1?3:-1,.5,1);
                o.PosC=float3(0,0,1);o.NormalW=float3(0,0,1);o.Tex=float2(.5,.5);return o;
            })";
        ComPtr<ID3DBlob> vertexCode,errors;
        check(D3DCompile(vsSource,strlen(vsSource),nullptr,nullptr,nullptr,"main","vs_5_0",0,0,&vertexCode,&errors));
        ComPtr<ID3D11VertexShader> vs;ComPtr<ID3D11PixelShader> ps;
        check(device->CreateVertexShader(vertexCode->GetBufferPointer(),vertexCode->GetBufferSize(),nullptr,&vs));
        check(device->CreatePixelShader(code.data(),code.size(),nullptr,&ps));
        D3D11_TEXTURE2D_DESC desc={};desc.Width=desc.Height=desc.MipLevels=desc.ArraySize=1;
        desc.Format=DXGI_FORMAT_R32G32B32A32_FLOAT;desc.SampleDesc.Count=1;desc.BindFlags=D3D11_BIND_SHADER_RESOURCE;
        std::vector<ComPtr<ID3D11Texture2D>> textures(count);
        std::vector<ComPtr<ID3D11ShaderResourceView>> views(count);std::vector<ID3D11ShaderResourceView*> raw(count);
        for(unsigned i=0;i<count;i++) {
            unsigned width=1,height=1;
            if(spatial) {inputs.read(reinterpret_cast<char*>(&width),4);inputs.read(reinterpret_cast<char*>(&height),4);}
            if(!width || !height || width>4096 || height>4096)return 2;
            std::vector<float> rgba(width*height*4);inputs.read(reinterpret_cast<char*>(rgba.data()),rgba.size()*4);if(!inputs) return 2;
            desc.Width=width;desc.Height=height;
            D3D11_SUBRESOURCE_DATA data={rgba.data(),width*16,0};check(device->CreateTexture2D(&desc,&data,&textures[i]));
            check(device->CreateShaderResourceView(textures[i].Get(),nullptr,&views[i]));raw[i]=views[i].Get();
        }
        ComPtr<ID3D11Texture2D> target,staging;ComPtr<ID3D11RenderTargetView> targetView;
        desc.Width=desc.Height=1;
        desc.BindFlags=D3D11_BIND_RENDER_TARGET;check(device->CreateTexture2D(&desc,nullptr,&target));
        check(device->CreateRenderTargetView(target.Get(),nullptr,&targetView));
        desc.BindFlags=0;desc.Usage=D3D11_USAGE_STAGING;desc.CPUAccessFlags=D3D11_CPU_ACCESS_READ;
        check(device->CreateTexture2D(&desc,nullptr,&staging));
        D3D11_SAMPLER_DESC sd={};sd.AddressU=sd.AddressV=sd.AddressW=D3D11_TEXTURE_ADDRESS_CLAMP;
        sd.MaxLOD=D3D11_FLOAT32_MAX;sd.Filter=D3D11_FILTER_MIN_MAG_MIP_POINT;
        ComPtr<ID3D11SamplerState> point,linear;check(device->CreateSamplerState(&sd,&point));
        sd.Filter=D3D11_FILTER_MIN_MAG_MIP_LINEAR;check(device->CreateSamplerState(&sd,&linear));
        ID3D11SamplerState* samplers[]={point.Get(),linear.Get()};context->PSSetSamplers(0,2,samplers);
        D3D11_RASTERIZER_DESC rs={};rs.FillMode=D3D11_FILL_SOLID;rs.CullMode=D3D11_CULL_NONE;rs.DepthClipEnable=TRUE;
        ComPtr<ID3D11RasterizerState> raster;check(device->CreateRasterizerState(&rs,&raster));context->RSSetState(raster.Get());
        D3D11_VIEWPORT viewport={0,0,1,1,0,1};context->RSSetViewports(1,&viewport);
        auto rtv=targetView.Get();context->OMSetRenderTargets(1,&rtv,nullptr);
        context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        context->VSSetShader(vs.Get(),nullptr,0);context->PSSetShader(ps.Get(),nullptr,0);
        // Data canvases explicitly use Opaque, including coverage alpha zero.
        // Two writes over a bright previous frame must not accumulate history.
        const float previousFrame[4]={1000,1000,1000,1};
        context->ClearRenderTargetView(targetView.Get(),previousFrame);
        context->PSSetShaderResources(0,count,raw.data());context->Draw(3,0);context->Draw(3,0);
        context->CopyResource(staging.Get(),target.Get());D3D11_MAPPED_SUBRESOURCE mapped={};
        check(context->Map(staging.Get(),0,D3D11_MAP_READ,0,&mapped));
        const float* result=static_cast<const float*>(mapped.pData);
        printf("%.9g %.9g %.9g %.9g\n",result[0],result[1],result[2],result[3]);
        context->Unmap(staging.Get(),0);return 0;
    } catch(const std::exception& e) { fprintf(stderr,"%s\n",e.what());return 1; }
}
