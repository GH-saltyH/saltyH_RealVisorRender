// Offscreen D3D11 WARP runner for a compiled CSP material shader.
// Textures and named constant values come from a fixture, not game resources.
#define NOMINMAX
#include <d3d11.h>
#include <d3dcompiler.h>
#include <wrl/client.h>
#include <fstream>
#include <vector>
#include <map>
#include <string>
#include <sstream>
#include <cstdio>
#include <stdexcept>
#include <cstring>
using Microsoft::WRL::ComPtr;
void check(HRESULT hr){if(FAILED(hr))throw std::runtime_error("D3D failure");}
unsigned readU(std::ifstream& f){unsigned x;f.read((char*)&x,4);if(!f)throw std::runtime_error("input EOF");return x;}
std::string readName(std::ifstream& f){std::string s(readU(f),'\0');f.read(s.data(),s.size());return s;}
int main(int argc,char** argv){try{
 if(argc!=7)return 2;
 unsigned w=std::stoul(argv[5]),h=std::stoul(argv[6]);
 std::ifstream source(argv[1],std::ios::binary);std::vector<char> code((std::istreambuf_iterator<char>(source)),{});
 ComPtr<ID3D11Device> d;ComPtr<ID3D11DeviceContext> c;
 check(D3D11CreateDevice(nullptr,D3D_DRIVER_TYPE_WARP,nullptr,0,nullptr,0,D3D11_SDK_VERSION,&d,nullptr,&c));
 ComPtr<ID3D11ShaderReflection> reflect;check(D3DReflect(code.data(),code.size(),IID_ID3D11ShaderReflection,(void**)&reflect));
 std::map<std::string,std::vector<float>> constants;
 std::ifstream params(argv[3]);std::string line;
 while(std::getline(params,line)){std::istringstream ss(line);std::string name;ss>>name;float value;while(ss>>value)constants[name].push_back(value);}
 D3D11_SHADER_DESC shaderDesc;reflect->GetDesc(&shaderDesc);
 std::vector<ComPtr<ID3D11Buffer>> buffers;
 for(unsigned i=0;i<shaderDesc.ConstantBuffers;i++){
  auto cb=reflect->GetConstantBufferByIndex(i);D3D11_SHADER_BUFFER_DESC bd;cb->GetDesc(&bd);
  D3D11_SHADER_INPUT_BIND_DESC binding;check(reflect->GetResourceBindingDescByName(bd.Name,&binding));
  std::vector<char> data(bd.Size,0);
  for(unsigned j=0;j<bd.Variables;j++){
   auto variable=cb->GetVariableByIndex(j);D3D11_SHADER_VARIABLE_DESC vd;variable->GetDesc(&vd);
   auto values=constants.find(vd.Name);
   if(values!=constants.end()){
    if(values->second.size()*4>vd.Size)throw std::runtime_error(std::string("constant too long: ")+vd.Name);
    D3D11_SHADER_TYPE_DESC td;variable->GetType()->GetDesc(&td);
    for(unsigned k=0;k<values->second.size();k++){
     if(td.Type==D3D_SVT_UINT){unsigned v=(unsigned)values->second[k];memcpy(data.data()+vd.StartOffset+k*4,&v,4);}
     else memcpy(data.data()+vd.StartOffset+k*4,&values->second[k],4);
    }
   }
  }
  D3D11_BUFFER_DESC desc={};desc.ByteWidth=bd.Size;desc.BindFlags=D3D11_BIND_CONSTANT_BUFFER;
  D3D11_SUBRESOURCE_DATA initial={data.data(),0,0};ComPtr<ID3D11Buffer> buffer;
  check(d->CreateBuffer(&desc,&initial,&buffer));auto raw=buffer.Get();c->PSSetConstantBuffers(binding.BindPoint,1,&raw);buffers.push_back(buffer);
 }
 std::ifstream input(argv[2],std::ios::binary);unsigned num=readU(input);
 std::vector<ComPtr<ID3D11Texture2D>> textures;std::vector<ComPtr<ID3D11ShaderResourceView>> views;
 for(unsigned i=0;i<num;i++){
  std::string name=readName(input);unsigned tw=readU(input),th=readU(input),levels=readU(input),faces=readU(input);
  std::vector<std::vector<float>> pixels(levels*faces);std::vector<D3D11_SUBRESOURCE_DATA> initial(levels*faces);
  for(unsigned face=0;face<faces;face++)for(unsigned mip=0;mip<levels;mip++){
   unsigned mw=std::max(1u,tw>>mip),mh=std::max(1u,th>>mip),index=face*levels+mip;
   pixels[index].resize(mw*mh*4);input.read((char*)pixels[index].data(),pixels[index].size()*4);
   initial[index]={pixels[index].data(),mw*16,0};
  }
  if(!input)throw std::runtime_error("texture EOF");
  D3D11_SHADER_INPUT_BIND_DESC binding;
  if(FAILED(reflect->GetResourceBindingDescByName(name.c_str(),&binding)))continue;
  D3D11_TEXTURE2D_DESC desc={};desc.Width=tw;desc.Height=th;desc.MipLevels=levels;desc.ArraySize=faces;
  desc.Format=DXGI_FORMAT_R32G32B32A32_FLOAT;desc.SampleDesc.Count=1;desc.BindFlags=D3D11_BIND_SHADER_RESOURCE;
  if(faces==6)desc.MiscFlags=D3D11_RESOURCE_MISC_TEXTURECUBE;
  ComPtr<ID3D11Texture2D> texture;check(d->CreateTexture2D(&desc,initial.data(),&texture));
  ComPtr<ID3D11ShaderResourceView> view;check(d->CreateShaderResourceView(texture.Get(),nullptr,&view));
  auto raw=view.Get();c->PSSetShaderResources(binding.BindPoint,1,&raw);textures.push_back(texture);views.push_back(view);
 }
 ComPtr<ID3D11Texture2D> target,staging;ComPtr<ID3D11RenderTargetView> rtv;
 D3D11_TEXTURE2D_DESC td={};td.Width=w;td.Height=h;td.MipLevels=td.ArraySize=1;td.SampleDesc.Count=1;
 td.Format=DXGI_FORMAT_R32G32B32A32_FLOAT;td.BindFlags=D3D11_BIND_RENDER_TARGET;
 check(d->CreateTexture2D(&td,nullptr,&target));check(d->CreateRenderTargetView(target.Get(),nullptr,&rtv));
 td.BindFlags=0;td.Usage=D3D11_USAGE_STAGING;td.CPUAccessFlags=D3D11_CPU_ACCESS_READ;check(d->CreateTexture2D(&td,nullptr,&staging));
 std::vector<ComPtr<ID3D11SamplerState>> samplers;
 for(unsigned i=0;i<16;i++){
  D3D11_SAMPLER_DESC sd={};sd.Filter=i==1?D3D11_FILTER_COMPARISON_MIN_MAG_MIP_LINEAR:D3D11_FILTER_MIN_MAG_MIP_LINEAR;
  sd.AddressU=sd.AddressV=sd.AddressW=D3D11_TEXTURE_ADDRESS_CLAMP;sd.ComparisonFunc=D3D11_COMPARISON_LESS_EQUAL;
  sd.MaxLOD=D3D11_FLOAT32_MAX;ComPtr<ID3D11SamplerState> s;check(d->CreateSamplerState(&sd,&s));auto raw=s.Get();c->PSSetSamplers(i,1,&raw);samplers.push_back(s);
 }
 const char* vsCode="float4 main(uint i:SV_VertexID):SV_POSITION{return float4(i==2?3:-1,i==1?3:-1,.5,1);}";
 ComPtr<ID3DBlob> vsBlob,errors;check(D3DCompile(vsCode,strlen(vsCode),nullptr,nullptr,nullptr,"main","vs_5_0",0,0,&vsBlob,&errors));
 ComPtr<ID3D11VertexShader> vs;ComPtr<ID3D11PixelShader> ps;
 check(d->CreateVertexShader(vsBlob->GetBufferPointer(),vsBlob->GetBufferSize(),nullptr,&vs));check(d->CreatePixelShader(code.data(),code.size(),nullptr,&ps));
 c->VSSetShader(vs.Get(),nullptr,0);c->PSSetShader(ps.Get(),nullptr,0);c->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
 D3D11_RASTERIZER_DESC rs={};rs.FillMode=D3D11_FILL_SOLID;rs.CullMode=D3D11_CULL_NONE;rs.DepthClipEnable=TRUE;
 ComPtr<ID3D11RasterizerState> raster;check(d->CreateRasterizerState(&rs,&raster));c->RSSetState(raster.Get());
 D3D11_VIEWPORT vp={0,0,(float)w,(float)h,0,1};c->RSSetViewports(1,&vp);auto raw=rtv.Get();c->OMSetRenderTargets(1,&raw,nullptr);
 c->Draw(3,0);c->CopyResource(staging.Get(),target.Get());D3D11_MAPPED_SUBRESOURCE mapped;
 check(c->Map(staging.Get(),0,D3D11_MAP_READ,0,&mapped));std::ofstream out(argv[4],std::ios::binary);
 for(unsigned y=0;y<h;y++)out.write((char*)mapped.pData+y*mapped.RowPitch,w*16);
 c->Unmap(staging.Get(),0);puts("D3D11 WARP render and float readback complete");return 0;
 }catch(const std::exception& e){fprintf(stderr,"%s\n",e.what());return 1;}}
