-- Compiler-witnessed elimination only; shader declarations remain type complete.
local M={}
function M.replace(body,name,replacement)
 local a,b=body:find('bool '..name..'%([^)]*%)%s*{');if not a then return body,false end
 local depth,i=1,b+1;while depth>0 do local x=body:sub(i,i);assert(x~='','balanced shader function');if x=='{'then depth=depth+1 elseif x=='}'then depth=depth-1 end;i=i+1 end
 return body:sub(1,a-1)..replacement..body:sub(i),true
end
function M.apply(p,manifest,hash)
 local e=assert(manifest[tostring(p.cacheKey)],'compiled source binding witness');assert(hash(p.shader)==e.shaderSha256,'source shader witness changed')
 local keep={};for _,n in ipairs(e.active)do keep[n]=assert(p.textures[n],n)end
 local declarations={};for n in pairs(p.textures)do if not keep[n]then declarations[#declarations+1]='Texture2D<float4> '..n..';'end end;table.sort(declarations)
 p.shader=table.concat(declarations,'\n')..'\n'..p.shader;p.textures=keep;return p
end
return M
