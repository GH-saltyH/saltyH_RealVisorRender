-- Product policy: cumulative historical momentum is diagnostic, not a solver
-- gate. Current-stock, per-step momentum, mass, finite/state/identity stay hard.
local M={}
local old='all(abs(oldSum)<=max(oldScale*128*1.1920928955078125e-7,1e-9))'
local new='all(abs(newSum)<=max(newScale*128*1.1920928955078125e-7,1e-9))'
local replacementOld='abs(oldSum.r)<=max(oldScale.r*128*1.1920928955078125e-7,1e-9)'
local replacementNew='abs(newSum.r)<=max(newScale.r*128*1.1920928955078125e-7,1e-9)'
local joint='all(abs(sum)<=max(scale*(128*1.1920928955078125e-7),1e-9))'
local jointMass='abs(sum.r)<=max(scale.r*(128*1.1920928955078125e-7),1e-9)'
local function section(s,first,edit)
 local a,j=s:find(first,1,true);assert(a,'diagnostic policy entry')
 local depth,b=1,j+1
 while depth>0 do local c=s:sub(b,b);assert(c~='','balanced admission function')
  if c=='{'then depth=depth+1 elseif c=='}'then depth=depth-1 end;b=b+1
 end
 return s:sub(1,a-1)..edit(s:sub(a,b-1))..s:sub(b)
end
local function replace(s,a,b)
 local i,j=s:find(a,1,true);assert(i,'scoped diagnostic comparison')
 assert(not s:find(a,j+1,true),'single comparison per scoped section')
 return s:sub(1,i-1)..b..s:sub(j+1)
end
function M.source(s)
 if not s:find('bool ledgerAdmission(){',1,true)then return s,false end
 -- Leave the separate main() diagnostic mask unchanged, including128/256.
 s=section(s,'bool ledgerAdmission(){',function(body)
  body=replace(body,old,replacementOld);return replace(body,new,replacementNew)
 end)
 return s,true
end
function M.receipt(s)
 local i,j=s:find(joint,1,true);assert(i,'product cumulative receipt gate')
 s=s:sub(1,i-1)..jointMass..s:sub(j+1)
 -- The reason-mask check mirrors hard admission. Source mask still reports
 -- cumulative momentum differences; accepted receipt keeps residual XYZ.
 s=replace(s,joint,jointMass)
 return s
end
function M.wrap(graph)
 if graph.productDiagnosticPolicy then return graph end
 local bind=graph.bind;local patched=setmetatable({},{__mode='k'});local bodies={}
 function graph:bind(...)
  local r=bind(self,...);local sourceCount,receiptCount=0,0
  for _,p in ipairs(r.passes)do
   if not patched[p]then
    local entry=bodies[p.shader]
    if entry==nil then
     if p.kind=='jointReceipt'then entry={body=M.receipt(p.shader),kind='receipt'}
     else local s,changed=M.source(p.shader);entry=changed and{body=s,kind='source'}or false end
     bodies[p.shader]=entry
    end
    if entry then p.shader=entry.body;p.cacheKey=p.cacheKey+33000000;patched[p]=entry.kind end
   end
   if patched[p]=='source'then sourceCount=sourceCount+1 elseif patched[p]=='receipt'then receiptCount=receiptCount+1 end
  end
  assert(sourceCount==7 and receiptCount==1,'source decision/commits and product receipt share diagnostic policy')
  return r
 end
 graph.productDiagnosticPolicy=true;return graph
end
return M
