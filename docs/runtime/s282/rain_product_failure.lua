-- Format data ALREADY retained by the ordinary product audit. No GPU work.
local M={}
local function value(t,i)return t and t[i]or 0 end
function M.summary(f)
 if not f then return nil end
 local w,z=f.words,f.details
 return{serial=f.serial,reason=value(w,16),context=value(w,13),headCode=value(w,14),headSlot=value(w,15),
  sourceMask=value(z,126),aggregateStatus=value(z,127),sourceHeadCode=value(z,129),sourceHeadMask=value(z,131),sourceHeadSlot=value(z,132)}
end
function M.encode(s,Packet)
 local f=assert(s.firstRefused,'retained rejection');local fields=M.summary(f);local out={'RealVisor physical product rejection v1'}
 local function line(k,v)out[#out+1]=k..'='..tostring(v)end
 for _,k in ipairs({'serial','reason','context','headCode','headSlot','sourceMask','aggregateStatus','sourceHeadCode','sourceHeadMask','sourceHeadSlot'})do line(k,fields[k])end
 local e=s.engine;line('submitted',e.submitted);line('audited',e.audited);line('pending',e.pending);line('advancedSeconds',string.format('%.17g',e.advancedSeconds))
 local function hex(name,rows)
  local words={};for _,v in ipairs(rows or{})do
   if type(v)=='table'then for _,x in ipairs(v)do words[#words+1]=Packet.hex32(x)end else words[#words+1]=Packet.hex32(v)end
  end;line(name,table.concat(words))
 end
 hex('receiptHex',f.words);hex('detailsHex',f.details)
 if s.background then
  for _,k in ipairs({'cycles','captureRestarts','excludedRawSeconds','excludedFrames','pausedWallSeconds','policy'})do line('background.'..k,s.background[k])end
 end
 for _,entry in ipairs({{'input',f.context},{'previous',f.previousContext}})do
  local name,c=entry[1],entry[2]
  if c then
   hex(name..'RowsHex',c.rows);hex(name..'UnitsHex',c.unitRows)
   for _,k in ipairs({'frame','rawDt','geometryKey','materialKey','capturedContentKey','originalContentKey','configuredScale','appliedScale'})do
    if c[k]~=nil then line(name..'.'..k,c[k])end
   end
  end
 end
 local text=table.concat(out,'\n')..'\n';assert(#text<=65536,'bounded failure record');return text
end
function M.admission(s)
 local out={'RealVisor physical product admission v1'}
 local function fields(prefix,t,names)
  for _,k in ipairs(names)do if t and t[k]~=nil then out[#out+1]=prefix..k..'='..tostring(t[k])end end
 end
 fields('',s,{'phase','error','rejectedRawSeconds','retainedTotalDebtSeconds','maxPumpMS'})
 fields('engine.',s.engine,{'submitted','audited','pending','active','advancedSeconds','submittedSeconds','debtSeconds','resources'})
 fields('cadence.',s.input and s.input.cadence,{'rawSeconds','auditedSeconds','submittedSeconds','retainedDebtSeconds','heldSteps','peakSteps','capacity','unsealedSeconds','samples'})
 fields('capture.',s.capture,{'rawSeconds','samples','firstFrame','lastFrame'})
 fields('staging.',s.staging,{'frames','seconds','peakFrames','peakSeconds','maxFrames','maxSeconds','retries','recoveredFrames','lastReason'})
 fields('background.',s.background,{'paused','cycles','captureRestarts','excludedRawSeconds','excludedFrames','pausedWallSeconds','policy'})
 local text=table.concat(out,'\n')..'\n';assert(#text<=16384,'bounded admission report');return text
end
return M
