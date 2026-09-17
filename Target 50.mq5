//+------------------------------------------------------------------+
//| Gold $50 NonStop TREND + REVERSAL PROTECT v2 - 30 MIN UPDATE |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

input double Lots = 0.01;
input int MagicNumber = 20260920;
input int MaxTrades = 1;
input int FirstTargetPoints = 80;
input int StopLossPoints = 150;
input int SweepThresholdPoints = 50;
input double DailyProfitTarget = 50.0;
input int SR_Lookback_M5 = 24;
input int SR_Update_Seconds = 1800;
input int TrendPullbackPoints = 300;

CTrade trade;
int h1_fast, h1_slow, m1_fast, m1_slow, m1_rsi;
datetime lastSRUpdate=0;
bool TradingEnabled=true;
enum STATE {WAIT_SWEEP,WAIT_CONFIRM};
STATE currentState=WAIT_SWEEP;
datetime lastSweepTime=0;
int lastSweepDir=0;
double ResLevel=0, SupLevel=0;
double dailyRealized=0;
datetime lastDay=0;
double dayStartBalance=0;
int totalBlocksHit=0;

int OnInit()
{
   h1_fast=iMA(_Symbol,PERIOD_H1,50,0,MODE_EMA,PRICE_CLOSE);
   h1_slow=iMA(_Symbol,PERIOD_H1,200,0,MODE_EMA,PRICE_CLOSE);
   m1_fast=iMA(_Symbol,PERIOD_M1,5,0,MODE_EMA,PRICE_CLOSE);
   m1_slow=iMA(_Symbol,PERIOD_M1,13,0,MODE_EMA,PRICE_CLOSE);
   m1_rsi=iRSI(_Symbol,PERIOD_M1,14,PRICE_CLOSE);
   if(h1_fast==INVALID_HANDLE || h1_slow==INVALID_HANDLE || m1_fast==INVALID_HANDLE || m1_slow==INVALID_HANDLE || m1_rsi==INVALID_HANDLE) return(INIT_FAILED);
   trade.SetExpertMagicNumber(MagicNumber);
   EventSetTimer(60);
   CreateButton();
   lastDay=iTime(_Symbol,PERIOD_D1,0);
   dayStartBalance=AccountInfoDouble(ACCOUNT_BALANCE);
   CalculateSR(); lastSRUpdate=TimeCurrent();
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason){ EventKillTimer(); ObjectDelete(0,"BTN_STARTSTOP"); ObjectDelete(0,"M15_RESISTANCE"); ObjectDelete(0,"M15_SUPPORT"); ObjectDelete(0,"SWEEP_LEVEL"); ObjectDelete(0,"PROGRESS_BG"); ObjectDelete(0,"PROGRESS_BAR"); IndicatorRelease(h1_fast); IndicatorRelease(h1_slow); IndicatorRelease(m1_fast); IndicatorRelease(m1_slow); IndicatorRelease(m1_rsi); }
void OnTimer(){ if(TimeCurrent() - lastSRUpdate >= SR_Update_Seconds){ CalculateSR(); lastSRUpdate=TimeCurrent(); } UpdateDrawings(); }
void OnTick()
{
   CheckNewDay();
   double floating=GetFloatingProfit();
   double totalToday=dailyRealized+floating;
   if(totalToday >= DailyProfitTarget){ CloseAll("BLOCK HIT"); totalBlocksHit++; dailyRealized=0; dayStartBalance=AccountInfoDouble(ACCOUNT_BALANCE); lastDay=iTime(_Symbol,PERIOD_D1,0); PrintFormat("BLOCK %d DONE $%.2f NEXT START",totalBlocksHit,totalToday); return; }
   if(!TradingEnabled){ UpdateDrawings(); return; }
   if(CountTrades() >= MaxTrades){ ManageTrades(); UpdateDrawings(); return; }
   if(TimeCurrent() - lastSRUpdate >= SR_Update_Seconds){ CalculateSR(); lastSRUpdate=TimeCurrent(); }
   int bias=GetH1Bias(); if(bias==0){ UpdateDrawings(); return; }
   if(currentState==WAIT_SWEEP){ CheckForSweep(bias); CheckForTrendPullback(bias); }
   else if(currentState==WAIT_CONFIRM){ if(TimeCurrent()-lastSweepTime>3600){ currentState=WAIT_SWEEP; lastSweepDir=0; } else CheckForConfirmation(bias); }
   ManageTrades(); UpdateDrawings();
}
int GetH1Bias(){ double f[1],s[1]; if(CopyBuffer(h1_fast,0,0,1,f)<=0) return 0; if(CopyBuffer(h1_slow,0,0,1,s)<=0) return 0; if(f[0]>s[0]) return 1; if(f[0]<s[0]) return -1; return 0; }
void CalculateSR(){ double hi=-1, lo=9999999; for(int i=1;i<=SR_Lookback_M5;i++){ double h=iHigh(_Symbol,PERIOD_M5,i); double l=iLow(_Symbol,PERIOD_M5,i); if(h>hi) hi=h; if(l<lo) lo=l; } ResLevel=hi; SupLevel=lo; }
void UpdateDrawings(){ DrawHLine("M15_RESISTANCE",ResLevel,clrRed); DrawHLine("M15_SUPPORT",SupLevel,clrLime); int bias=GetH1Bias(); string bTxt=bias==1?"BUY ▲":bias==-1?"SELL ▼":"NONE"; string sTxt=currentState==WAIT_SWEEP?"WAIT":"CONFIRM"; double floating=GetFloatingProfit(); double totalToday=dailyRealized+floating; double pct=DailyProfitTarget>0? totalToday/DailyProfitTarget*100:0; if(pct<0) pct=0; if(pct>100) pct=100; DrawProgress(pct,totalToday); Comment(StringFormat(" $50 NONSTOP TREND PROTECT | H1:%s RES:%.2f SUP:%.2f BLOCK %d $%.2f/$%.2f Next %d sec", bTxt,ResLevel,SupLevel,totalBlocksHit+1,totalToday,DailyProfitTarget, SR_Update_Seconds - (int)(TimeCurrent()-lastSRUpdate))); }
void DrawHLine(string name,double price,color col){ if(price<=0) return; if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_HLINE,0,0,price); ObjectSetDouble(0,name,OBJPROP_PRICE,price); ObjectSetInteger(0,name,OBJPROP_COLOR,col); ObjectSetInteger(0,name,OBJPROP_WIDTH,2); }
void DrawProgress(double pct, double total){ string bg="PROGRESS_BG"; string bar="PROGRESS_BAR"; if(ObjectFind(0,bg)<0){ ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,20); ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,65); ObjectSetInteger(0,bg,OBJPROP_XSIZE,200); ObjectSetInteger(0,bg,OBJPROP_YSIZE,20); ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,clrDimGray); } if(ObjectFind(0,bar)<0){ ObjectCreate(0,bar,OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,bar,OBJPROP_XDISTANCE,20); ObjectSetInteger(0,bar,OBJPROP_YDISTANCE,65); ObjectSetInteger(0,bar,OBJPROP_YSIZE,20); } int w=(int)(200*pct/100.0); ObjectSetInteger(0,bar,OBJPROP_XSIZE,w); color c= pct>=100?clrLime: pct>=50?clrGold:clrDodgerBlue; ObjectSetInteger(0,bar,OBJPROP_BGCOLOR,c); }
void CheckForSweep(int bias){ double m5_high=iHigh(_Symbol,PERIOD_M5,0); double m5_low=iLow(_Symbol,PERIOD_M5,0); double m5_close=iClose(_Symbol,PERIOD_M5,0); double thresh=SweepThresholdPoints*_Point; if(bias==1 && m5_low < SupLevel - thresh && m5_close > SupLevel){ lastSweepDir=1; lastSweepTime=TimeCurrent(); currentState=WAIT_CONFIRM; DrawHLine("SWEEP_LEVEL",m5_low,clrYellow); } if(bias==-1 && m5_high > ResLevel + thresh && m5_close < ResLevel){ lastSweepDir=-1; lastSweepTime=TimeCurrent(); currentState=WAIT_CONFIRM; DrawHLine("SWEEP_LEVEL",m5_high,clrYellow); } }
void CheckForTrendPullback(int bias){ double f[1],s[1],r[1], fP[1],sP[1],rP[1]; if(CopyBuffer(m1_fast,0,0,1,f)<=0) return; if(CopyBuffer(m1_slow,0,0,1,s)<=0) return; if(CopyBuffer(m1_rsi,0,0,1,r)<=0) return; if(CopyBuffer(m1_fast,0,1,1,fP)<=0) return; if(CopyBuffer(m1_slow,0,1,1,sP)<=0) return; if(CopyBuffer(m1_rsi,0,1,1,rP)<=0) return; bool upCross=fP[0]<=sP[0] && f[0]>s[0]; bool downCross=fP[0]>=sP[0] && f[0]<s[0]; bool rsiUp=r[0]>45 && r[0]<70; bool rsiDown=r[0]<55 && r[0]>30; double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); if(bias==1){ double dist=(bid - SupLevel)/_Point; if(dist>=0 && dist<=TrendPullbackPoints && upCross && rsiUp){ OpenTrade(ORDER_TYPE_BUY); return; } } if(bias==-1){ double dist=(ResLevel - ask)/_Point; if(dist>=0 && dist<=TrendPullbackPoints && downCross && rsiDown){ OpenTrade(ORDER_TYPE_SELL); return; } } }
void CheckForConfirmation(int bias){ double f[1],s[1],r[1], fP[1],sP[1],rP[1]; if(CopyBuffer(m1_fast,0,0,1,f)<=0) return; if(CopyBuffer(m1_slow,0,0,1,s)<=0) return; if(CopyBuffer(m1_rsi,0,0,1,r)<=0) return; if(CopyBuffer(m1_fast,0,1,1,fP)<=0) return; if(CopyBuffer(m1_slow,0,1,1,sP)<=0) return; if(CopyBuffer(m1_rsi,0,1,1,rP)<=0) return; bool up=fP[0]<=sP[0] && f[0]>s[0]; bool dn=fP[0]>=sP[0] && f[0]<s[0]; bool rUp=rP[0]<35 && r[0]>40; bool rDn=rP[0]>65 && r[0]<60; if(bias==1 && lastSweepDir==1 && up && rUp){ OpenTrade(ORDER_TYPE_BUY); currentState=WAIT_SWEEP; lastSweepDir=0; } if(bias==-1 && lastSweepDir==-1 && dn && rDn){ OpenTrade(ORDER_TYPE_SELL); currentState=WAIT_SWEEP; lastSweepDir=0; } }
void OpenTrade(ENUM_ORDER_TYPE type){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double sl=(type==ORDER_TYPE_BUY)? bid-StopLossPoints*_Point : ask+StopLossPoints*_Point; if(type==ORDER_TYPE_BUY) trade.Buy(Lots,_Symbol,0,sl,0,"TREND BUY"); else trade.Sell(Lots,_Symbol,0,sl,0,"TREND SELL"); }

// REVERSAL PROTECT v2 + TRAIL
void ManageTrades()
{
   int bias=GetH1Bias();
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(PositionGetSymbol(i)!=_Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double curr=PositionGetDouble(POSITION_PRICE_CURRENT);
      double sl=PositionGetDouble(POSITION_SL);
      long pType=PositionGetInteger(POSITION_TYPE);
      ulong ticket=(ulong)PositionGetInteger(POSITION_TICKET);
      double pts=(pType==POSITION_TYPE_BUY)? (curr-open)/_Point : (open-curr)/_Point;
      bool isBuy=(pType==POSITION_TYPE_BUY);

      // 1. LOCK BE+20 at +80
      if(pts>=FirstTargetPoints)
      {
         double be=isBuy? open+20*_Point : open-20*_Point;
         bool need=(isBuy && (sl<be || sl==0)) || (!isBuy && (sl>be || sl==0));
         if(need) trade.PositionModify(ticket,be,0);
      }

      // 2. REVERSAL PROTECT + TRAIL after lock
      if(pts>=FirstTargetPoints)
      {
         double f[1],s[1],r[1];
         CopyBuffer(m1_fast,0,0,1,f);
         CopyBuffer(m1_slow,0,0,1,s);
         CopyBuffer(m1_rsi,0,0,1,r);

         // M1 flips against you -> protect profit
         if(isBuy && f[0] < s[0] && r[0] < 50)
         {
            if(trade.PositionClose(ticket)){ PrintFormat("REVERSAL PROTECT BUY CLOSE pts %.0f",pts); continue; }
         }
         if(!isBuy && f[0] > s[0] && r[0] > 50)
         {
            if(trade.PositionClose(ticket)){ PrintFormat("REVERSAL PROTECT SELL CLOSE pts %.0f",pts); continue; }
         }

         // H1 flips -> close
         if(isBuy && bias==-1){ if(trade.PositionClose(ticket)) continue; }
         if(!isBuy && bias==1){ if(trade.PositionClose(ticket)) continue; }

         // TRAIL: at +150 pts, trail 100 pts behind price
         if(pts>=150)
         {
            double newSL = isBuy? curr - 100*_Point : curr + 100*_Point;
            bool improve = isBuy? newSL > sl : newSL < sl;
            if(improve) trade.PositionModify(ticket,newSL,0);
         }
      }

      // 3. GREEN LINE TARGET
      if(!isBuy){ if( (curr <= SupLevel+50*_Point && pts>=100) || pts>=350 ) trade.PositionClose(ticket); }
      else { if( (curr >= ResLevel-50*_Point && pts>=100) || pts>=350 ) trade.PositionClose(ticket); }
   }
}
int CountTrades(){ int c=0; for(int i=0;i<PositionsTotal();i++){ if(PositionGetSymbol(i)!=_Symbol) continue; if((long)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue; c++; } return c; }
double GetFloatingProfit(){ double p=0; for(int i=0;i<PositionsTotal();i++){ if(PositionGetSymbol(i)!=_Symbol) continue; if((long)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue; p+=PositionGetDouble(POSITION_PROFIT); } return p; }
void CloseAll(string reason){ for(int i=PositionsTotal()-1;i>=0;i--){ if(PositionGetSymbol(i)!=_Symbol) continue; if((long)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue; ulong ticket=(ulong)PositionGetInteger(POSITION_TICKET); trade.PositionClose(ticket); } }
void CheckNewDay(){ datetime d=iTime(_Symbol,PERIOD_D1,0); if(d!=lastDay){ lastDay=d; dailyRealized=0; totalBlocksHit=0; dayStartBalance=AccountInfoDouble(ACCOUNT_BALANCE); } dailyRealized=0; HistorySelect(lastDay, TimeCurrent()); for(int i=0;i<HistoryDealsTotal();i++){ ulong ticket=HistoryDealGetTicket(i); if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=_Symbol) continue; if((long)HistoryDealGetInteger(ticket,DEAL_MAGIC)!=MagicNumber) continue; dailyRealized+=HistoryDealGetDouble(ticket,DEAL_PROFIT); } if(dailyRealized >= DailyProfitTarget) dailyRealized=0; }
void PrintProgress(string src){ double floating=GetFloatingProfit(); double total=dailyRealized+floating; PrintFormat("[%s] Bias=%d RES=%.2f SUP=%.2f Block=%d $%.2f", src,GetH1Bias(),ResLevel,SupLevel,totalBlocksHit+1,total); }
void CreateButton(){ if(ObjectFind(0,"BTN_STARTSTOP")>=0) ObjectDelete(0,"BTN_STARTSTOP"); ObjectCreate(0,"BTN_STARTSTOP",OBJ_BUTTON,0,0,0); ObjectSetInteger(0,"BTN_STARTSTOP",OBJPROP_XDISTANCE,20); ObjectSetInteger(0,"BTN_STARTSTOP",OBJPROP_YDISTANCE,20); ObjectSetInteger(0,"BTN_STARTSTOP",OBJPROP_XSIZE,140); ObjectSetInteger(0,"BTN_STARTSTOP",OBJPROP_YSIZE,36); ObjectSetInteger(0,"BTN_STARTSTOP",OBJPROP_CORNER,CORNER_LEFT_UPPER); UpdateButton(); }
void UpdateButton(){ ObjectSetString(0,"BTN_STARTSTOP",OBJPROP_TEXT,TradingEnabled?"STOP TRADING":"START TRADING"); ObjectSetInteger(0,"BTN_STARTSTOP",OBJPROP_BGCOLOR,TradingEnabled?clrLimeGreen:clrTomato); ObjectSetInteger(0,"BTN_STARTSTOP",OBJPROP_COLOR,clrBlack); }
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam){ if(id==CHARTEVENT_OBJECT_CLICK && sparam=="BTN_STARTSTOP"){ TradingEnabled=!TradingEnabled; UpdateButton(); ChartRedraw(); } }
