-- Shortest-arc rigid interpolation. Rows follow the existing CSP pose contract.
local M={}
local function cp(t)local r={};for i,row in ipairs(t)do r[i]={row[1],row[2],row[3],row[4]}end;return r end
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function rotation(p)
 assert(type(p)=='table'and #p==4,'pose rows')
 for _,r in ipairs(p)do assert(#r==4,'pose width');for _,v in ipairs(r)do assert(finite(v),'finite pose')end end
 assert(p[1][4]==0 and p[2][4]==0 and p[3][4]==0 and p[4][4]==1,'affine pose')
 local scale=math.sqrt(p[1][1]^2+p[1][2]^2+p[1][3]^2);assert(scale>0,'pose scale')
 local r={};for i=1,3 do r[i]={};for j=1,3 do r[i][j]=p[i][j]/scale end end
 local tolerance=64*2^-23
 for i=1,3 do for j=i,3 do local dot=0;for k=1,3 do dot=dot+r[i][k]*r[j][k]end;assert(math.abs(dot-(i==j and 1 or 0))<=tolerance,'rigid uniform basis')end end
 local a,b,c=r[1],r[2],r[3];assert(a[1]*(b[2]*c[3]-b[3]*c[2])-a[2]*(b[1]*c[3]-b[3]*c[1])+a[3]*(b[1]*c[2]-b[2]*c[1])>0,'right handed pose')
 local x,y,z,w;local trace=r[1][1]+r[2][2]+r[3][3]
 if trace>0 then local s=math.sqrt(trace+1)*2;w=s/4;x=(r[3][2]-r[2][3])/s;y=(r[1][3]-r[3][1])/s;z=(r[2][1]-r[1][2])/s
 elseif r[1][1]>r[2][2]and r[1][1]>r[3][3]then local s=math.sqrt(1+r[1][1]-r[2][2]-r[3][3])*2;w=(r[3][2]-r[2][3])/s;x=s/4;y=(r[1][2]+r[2][1])/s;z=(r[1][3]+r[3][1])/s
 elseif r[2][2]>r[3][3]then local s=math.sqrt(1+r[2][2]-r[1][1]-r[3][3])*2;w=(r[1][3]-r[3][1])/s;x=(r[1][2]+r[2][1])/s;y=s/4;z=(r[2][3]+r[3][2])/s
 else local s=math.sqrt(1+r[3][3]-r[1][1]-r[2][2])*2;w=(r[2][1]-r[1][2])/s;x=(r[1][3]+r[3][1])/s;y=(r[2][3]+r[3][2])/s;z=s/4 end
 local n=math.sqrt(x*x+y*y+z*z+w*w);return{x/n,y/n,z/n,w/n},scale
end
function M.resolve(endpoint)
 local a,b,t=endpoint.from,endpoint.to,endpoint.fraction
 assert(finite(t)and t>=0 and t<=1,'pose fraction')
 local x,sa=rotation(a);local y,sb=rotation(b);assert(math.abs(sa-sb)<=math.max(sa,sb)*8*2^-23,'physical scale change')
 if t==0 then return cp(a)elseif t==1 then return cp(b)end
 local dot=0;for i=1,4 do dot=dot+x[i]*y[i]end
 if dot<0 then dot=-dot;for i=1,4 do y[i]=-y[i]end end
 local left,right=1-t,t
 if dot<.9995 then local angle=math.acos(math.max(-1,math.min(1,dot)));local sine=math.sin(angle);left=math.sin((1-t)*angle)/sine;right=math.sin(t*angle)/sine end
 local q={};local n=0;for i=1,4 do q[i]=x[i]*left+y[i]*right;n=n+q[i]*q[i]end;n=math.sqrt(n);for i=1,4 do q[i]=q[i]/n end
 local x,y,z,w=q[1],q[2],q[3],q[4];local s=sa
 return{{(1-2*(y*y+z*z))*s,2*(x*y-z*w)*s,2*(x*z+y*w)*s,0},
 {2*(x*y+z*w)*s,(1-2*(x*x+z*z))*s,2*(y*z-x*w)*s,0},
 {2*(x*z-y*w)*s,2*(y*z+x*w)*s,(1-2*(x*x+y*y))*s,0},
 {a[4][1]+(b[4][1]-a[4][1])*t,a[4][2]+(b[4][2]-a[4][2])*t,a[4][3]+(b[4][3]-a[4][3])*t,1}}
end
return M
