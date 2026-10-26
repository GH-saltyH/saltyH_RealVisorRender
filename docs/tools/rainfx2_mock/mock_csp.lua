-- Minimal CSP API stubs to exercise rainfx2/init.lua control flow under texlua (Lua 5.3).
local V3={} V3.__index=V3
function vec3(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},V3) end
V3.__add=function(a,b) return vec3(a.x+b.x,a.y+b.y,a.z+b.z) end
V3.__sub=function(a,b) return vec3(a.x-b.x,a.y-b.y,a.z-b.z) end
V3.__mul=function(a,b) if type(a)=='number' then a,b=b,a end return vec3(a.x*b,a.y*b,a.z*b) end
V3.__div=function(a,b) return vec3(a.x/b,a.y/b,a.z/b) end
function V3:length() return math.sqrt(self.x^2+self.y^2+self.z^2) end
function V3:set(x,y,z) self.x,self.y,self.z=x,y,z return self end
function V3:scale(k) self.x,self.y,self.z=self.x*k,self.y*k,self.z*k return self end
local V2={} V2.__index=V2
function vec2(x,y) return setmetatable({x=x or 0,y=y or 0},V2) end
function rgb(r,g,b) return {r=r,g=g,b=b} end
local M4={} M4.__index=M4
mat4x4={identity=function() return setmetatable({},M4) end}
function M4:clone() return setmetatable({},M4) end
function M4:inverse() return self end
function M4:transformVector(v) return vec3(v.x,v.y,v.z) end
function M4:transformPoint(v) return vec3(v.x,v.y,v.z) end
calls={}
local Canvas={} Canvas.__index=Canvas
ui={ExtraCanvas=function(res,mips,aa,fmt) assert(res.x and mips and fmt,'bad canvas args') return setmetatable({res=res,mips=mips},Canvas) end,
  text=function() end, separator=function() end, button=function() return true end, checkbox=function() return false end, slider=function(_,v) return v end}
function Canvas:setName(n) self.name=n return self end
function Canvas:clear() return self end
function Canvas:updateWithShader(p)
  for k,v in pairs(p.textures) do assert(v~=self,'reads own target '..k) end
  for k,v in pairs(p.values) do assert(v~=nil,'nil value '..k) end
  calls[#calls+1]=self.name return true end
Canvas.updateSceneWithShader=Canvas.updateWithShader
function Canvas:mipsUpdate() calls[#calls+1]='mips' end
function Canvas:dispose() end
function Canvas:accessData(cb)
  local d={} function d:colorTo(c,x,y) c.rgb.r,c.rgb.g,c.rgb.b,c.mult=0.5,0.1,0.2,1 return c end function d:dispose() end
  cb(nil,d) return self end
function rgbm(r,g,b,m) return {rgb={r=r or 0,g=g or 0,b=b or 0},mult=m or 1} end
render={AntialiasingMode={None=0},TextureFormat={R32G32B32A32={Float=2},R8G8B8A8={UNorm=28},R16G16B16A16={Float=10,UNorm=11}},
  BlendMode={Opaque=0,AlphaBlend=1},DepthMode={Normal=0,ReadOnly=1},CullMode={None=0},
  setCullMode=function() end,setBlendMode=function() end,setDepthMode=function() end,
  getRenderTargetSize=function() return vec2(2560,1440) end,
  mesh=function(p) assert(p.textures.txR2Scene and p.textures.txR2State and p.textures.txR2Field,'missing textures') for k,v in pairs(p.values) do assert(v~=nil,k) end calls[#calls+1]='mesh:'..(p.shader:find('^#define R2_DEPTH_ONLY') and 'depth' or 'colour') return true end}
local store={}
ac={storage=function(t) for k,v in pairs(t) do store[k]=v end return store end,
  VertexBuffer=function(n) local b={n=n} function b:set(i,v) self[i]=v end return b end,
  IndicesBuffer=function(n) local b={n=n} function b:set(i,v) self[i]=v end return b end,
  MeshVertex={new=function(p,n,uv) return {pos=p,normal=n,uv=uv} end},
  getSim=function() return {cameraFOV=56,cameraClipNear=0.02,cameraClipFar=3000} end,
  getCar=function(i) return {position=vec3(0,0,(i or 0)*20),isConnected=true,velocity=vec3(0,0,60),acceleration=vec3(0.2,0,-1),side=vec3(1,0,0),up=vec3(0,1,0),look=vec3(0,0,1)} end}
local Mesh={} Mesh.__index=Mesh
function Mesh.__len() return 1 end
function Mesh:setVisible() end function Mesh:setShadows() end function Mesh:dispose() end
function Mesh:getWorldTransformationRaw() return setmetatable({},M4) end
function Mesh:getVertices() local t={} function t:get(i) return {pos=vec3(),normal=vec3(0,0,1),uv=vec2(0.5,-0.5)} end return setmetatable(t,{__len=function() return 3 end}) end
function Mesh:getIndices() local t={} function t:get(i) return i-1 end return setmetatable(t,{__len=function() return 3 end}) end
function Mesh:getParent() return setmetatable({},Mesh) end
function Mesh:findNodes() return nil end
function Mesh:createMesh() return setmetatable({},Mesh) end
target=setmetatable({},Mesh)
