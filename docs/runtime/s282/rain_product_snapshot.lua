return [[
float4 main(PS_IN pin){
 uint i=min((uint)(pin.Tex.x*160),159u),row=i/4u,component=i%4u;
 float4 v=0;
 if(row<4u)v=txReceipt.Load(int3(row,0,0));
 else if(row>=4u&&row<12u&&txReceipt.Load(int3(0,0,0)).w==0)v=txSourceLedger.Load(int3(0,row-4u,0));
 else if(row>=12u&&row<23u&&txReceipt.Load(int3(0,0,0)).w==0)v=txSourceTotals.Load(int3(0,row-12u,0));
 else if(row==30u&&txReceipt.Load(int3(0,0,0)).w==0)v=float4(282,3,19,1);
 else if(row==31u)v=txSourceDecision.Load(int3(0,0,0));
 else if(row==32u&&txSourceDecision.Load(int3(0,0,0)).r!=1){uint found=0;[loop]for(uint k=0;k<(uint)gCount;k++){float4 status=txSourcePackets.Load(int3(k,7,0));if(status.r!=0){found=k;v=status;break;}}}
 else if(row==33u&&txSourceDecision.Load(int3(0,0,0)).r!=1){[loop]for(uint k=0;k<(uint)gCount;k++){float4 status=txSourcePackets.Load(int3(k,7,0));if(status.r!=0){v=txSourceOriginal.Load(int3(k,0,0));break;}}}
 else if(row==34u&&txSourceDecision.Load(int3(0,0,0)).r!=1){[loop]for(uint k=0;k<(uint)gCount;k++){float4 status=txSourcePackets.Load(int3(k,7,0));if(status.r!=0){v=txDecoded.Load(int3(k,0,0));break;}}}
 else if(row==35u)v=txSourceTotals.Load(int3(0,0,0));
 else if(row==36u)v=txSourceTotals.Load(int3(0,1,0));
 else if(row==37u)v=txSourceLedger.Load(int3(0,1,0));
 else if(row==38u)v=txSourceTotals.Load(int3(0,8,0));
 else if(row==39u)v=txSourceTotals.Load(int3(0,9,0));
 float word=v[component];return i<16u?word:(isfinite(word)?word:3.402823466e38);
}
]]
