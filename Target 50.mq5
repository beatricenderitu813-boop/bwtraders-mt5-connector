//+------------------------------------------------------------------+
//| Gold $50 Tonight - Lock + Green Hold + Reversal Protect + Button |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

input double Lots = 0.01;
input int MagicNumber = 20260920;
input int MaxTrades = 1;
input int FirstTargetPoints = 80; // lock
input int StopLossPoints = 150;
input int SweepThresholdPoints = 100;
input double MaxDailyLossDollars = 3.0;
input double DailyProfitTarget = 50.0; // Tonight target

CTrade trade;
int h1_fast, h1_slow, m1_fast, m1_slow, m1_rsi;
datetime lastM15Time=0;
bool TradingEnabled=true;
enum STATE {WAIT_SWEEP,WAIT_CONFIRM};
STATE currentState=WAIT_SWEEP;
datetime lastSweepTime=0;
int lastSweepDir=0;
double ResLevel=0, SupLevel=0;
double dailyRealized=0;
datetime lastDay=0;
double dayStartBalance=0;

//+------------------------------------------------------------------+
int OnInit()
{
   h1_fast=iMA(_Symbol,PERIOD_H1,50,0,MODE_EMA,PRICE_CLOSE);
   h1_slow=iMA(_Symbol,PERIOD_H1,200,0,MODE_EMA,PRICE_CLOSE);
   m1_fast=iMA(_Symbol,PERIOD_M1,5,0,MODE_EMA,PRICE_CLOSE);
   m1_slow=iMA(_Symbol,PERIOD_M1,13,0,MODE_EMA,PRICE_CLOSE);
   m1_rsi=iRSI(_Symbol,PERIOD_M1,14,PRICE_CLOSE);
   if(h1_fast==INVALID_HANDLE || h1_slow==INVALID_HANDLE || m1_fast==INVALID_HANDLE || m1_slow==INVALID_HANDLE || m1_rsi==INVALID_HANDLE)
      return(INIT_FAILED);
   trade.SetExpertMagicNumber(MagicNumber);
   EventSetTimer(300);
   CreateButton();
   lastDay=iTime(_Symbol,PERIOD_D1,0);
   dayStartBalance=AccountInfoDouble(ACCOUNT_BALANCE);
   dailyRealized=0;
   PrintFormat("$50 TONIGHT STARTED | Target=$%.2f | Lock=%d | Magic=%d",DailyProfitTarget,FirstTargetPoints,MagicNumber);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectDelete(0,"BTN_STARTSTOP");
   ObjectDelete(0,"M15_RESISTANCE");
   ObjectDelete(0,"M15_SUPPORT");
   ObjectDelete(0,"SWEEP_LEVEL");
   ObjectDelete(0,"PROGRESS_BG");
   ObjectDelete(0,"PROGRESS_BAR");
   IndicatorRelease(h1_fast); IndicatorRelease(h1_slow);
   IndicatorRelease(m1_fast); IndicatorRelease(m1_slow); IndicatorRelease(m1_rsi);
}
//+------------------------------------------------------------------+
void OnTimer(){ PrintProgress("TIMER"); UpdateDrawings(); }

void OnTick()
{
   CheckNewDay();
   double floating=GetFloatingProfit();
   double totalToday=dailyRealized+floating;
   double progress=DailyProfitTarget>0? totalToday/DailyProfitTarget*100:0;

   // $50 TARGET HIT
   if(totalToday >= DailyProfitTarget)
   {
      CloseAll("TARGET $50 HIT");
      TradingEnabled=false;
      UpdateButton();
      PrintFormat("!!! $50 TARGET REACHED $%.2f -> STOP FOR TONIGHT!!!",totalToday);
      Comment(StringFormat("$$ TARGET $50 DONE $%.2f $$\nSTOPPED FOR TONIGHT",totalToday));
      return;
   }

   if(dailyRealized <= -MaxDailyLossDollars)
   {
      TradingEnabled=false; UpdateButton(); return;
   }
   if(!TradingEnabled) { UpdateDrawings(); return; }
   if(CountTrades() >= MaxTrades){ ManageTrades(); UpdateDrawings(); return; }

   datetime m15t=iTime(_Symbol,PERIOD_M15,0);
   if(m15t!=lastM15Time){ lastM15Time=m15t; CalculateSR(); UpdateDrawings(); PrintProgress("NEW M15"); }

   int bias=GetH1Bias(); if(bias==0){ UpdateDrawings(); return; }

   if(currentState==WAIT_SWEEP) CheckForSweep(bias);
   else if(currentState==WAIT_CONFIRM)
   {
      if(TimeCurrent()-lastSweepTime>3600){ currentState=WAIT_SWEEP; lastSweepDir=0; Print("TIMEOUT -> WAIT_SWEEP"); }
      else CheckForConfirmation(bias);
   }
   ManageTrades();
   UpdateDrawings();
}
//+------------------------------------------------------------------+
int GetH1Bias()
{
   double f[1],s[1];
   if(CopyBuffer(h1_fast,0,0,1,f)<=0) return 0;
   if(CopyBuffer(h1_slow,0,0,1,s)<=0) return 0;
   if(f[0]>s[0]) return 1; if(f[0]<s[0]) return -1; return 0;
}
void CalculateSR()
{
   double hi=-1, lo=9999999;
   for(int i=1;i<=40;i++){ double h=iHigh(_Symbol,PERIOD_M15,i); double l=iLow(_Symbol,PERIOD_M15,i); if(h>hi) hi=h; if(l<lo) lo=l; }
   ResLevel=hi; SupLevel=lo;
}
void UpdateDrawings()
{
   DrawHLine("M15_RESISTANCE",ResLevel,clrRed);
   DrawHLine("M15_SUPPORT",SupLevel,clrLime);
   int bias=GetH1Bias();
   string bTxt=bias==1?"BUY ▲":bias==-1?"SELL ▼":"NONE";
   string sTxt=currentState==WAIT_SWEEP?"WAIT_SWEEP":"WAIT_CONFIRM";
   double floating=GetFloatingProfit();
   double totalToday=dailyRealized+floating;
   double pct=DailyProfitTarget>0? totalToday/DailyProfitTarget*100:0;
   if(pct<0) pct=0; if(pct>100) pct=100;

   DrawProgress(pct, totalToday);

   Comment(StringFormat(" $50 TONIGHT | H1:%s\nRES:%.2f SUP:%.2f GREEN TARGET\nSTATE:%s | Trades:%d\nTODAY: $%.2f / $%.2f (%.1f%%) | Float:$%.2f\nLock +%d pts -> hold to green | Reversal protect ON",
           bTxt,ResLevel,SupLevel,sTxt,CountTrades(),totalToday,DailyProfitTarget,pct,floating,FirstTargetPoints));
}
void DrawHLine(string name,double price,color col)
{
   if(price<=0) return;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_HLINE,0,0,price);
   ObjectSetDouble(0,name,OBJPROP_PRICE,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
}
void DrawProgress(double pct, double total)
{
   string bg="PROGRESS_BG"; string bar="PROGRESS_BAR";
   if(ObjectFind(0,bg)<0){ ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,20); ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,65); ObjectSetInteger(0,bg,OBJPROP_XSIZE,200); ObjectSetInteger(0,bg,OBJPROP_YSIZE,20); ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,clrDimGray); }
   if(ObjectFind(0,bar)<0){ ObjectCreate(0,bar,OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,bar,OBJPROP_XDISTANCE,20); ObjectSetInteger(0,bar,OBJPROP_YDISTANCE,65); ObjectSetInteger(0,bar,OBJPROP_YSIZE,20); }
   int w=(int)(200*pct/100.0); ObjectSetInteger(0,bar,OBJPROP_XSIZE,w);
   color c= pct>=100?clrLime: pct>=50?clrGold:clrDodgerBlue;
   ObjectSetInteger(0,bar,OBJPROP_BGCOLOR,c);
}
//+------------------------------------------------------------------+
void CheckForSweep(int bias)
{
   double m5_high=iHigh(_Symbol,PERIOD_M5,0);
   double m5_low=iLow(_Symbol,PERIOD_M5,0);
   double m5_close=iClose(_Symbol,PERIOD_M5,0);
   double thresh=SweepThresholdPoints*_Point;
   if(bias==1 && m5_low < SupLevel - thresh && m5_close > SupLevel)
   {
      lastSweepDir=1; lastSweepTime=TimeCurrent(); currentState=WAIT_CONFIRM;
      DrawHLine("SWEEP_LEVEL",m5_low,clrYellow);
      PrintFormat("SWEEP SUP Low=%.2f Close=%.2f BUY",m5_low,m5_close);
   }
   if(bias==-1 && m5_high > ResLevel + thresh && m5_close < ResLevel)
   {
      lastSweepDir=-1; lastSweepTime=TimeCurrent(); currentState=WAIT_CONFIRM;
      DrawHLine("SWEEP_LEVEL",m5_high,clrYellow);
      PrintFormat("SWEEP RES High=%.2f Close=%.2f SELL",m5_high,m5_close);
   }
}
void CheckForConfirmation(int bias)
{
   double f[1],s[1],r[1], fP[1],sP[1],rP[1];
   if(CopyBuffer(m1_fast,0,0,1,f)<=0) return;
   if(CopyBuffer(m1_slow,0,0,1,s)<=0) return;
   if(CopyBuffer(m1_rsi,0,0,1,r)<=0) return;
   if(CopyBuffer(m1_fast,0,1,1,fP)<=0) return;
   if(CopyBuffer(m1_slow,0,1,1,sP)<=0) return;
   if(CopyBuffer(m1_rsi,0,1,1,rP)<=0) return;
   bool up=fP[0]<=sP[0] && f[0]>s[0];
   bool dn=fP[0]>=sP[0] && f[0]<s[0];
   bool rUp=rP[0]<35 && r[0]>40;
   bool rDn=rP[0]>65 && r[0]<60;
   if(bias==1 && lastSweepDir==1 && up && rUp){ OpenTrade(ORDER_TYPE_BUY); currentState=WAIT_SWEEP; lastSweepDir=0; }
   if(bias==-1 && lastSweepDir==-1 && dn && rDn){ OpenTrade(ORDER_TYPE_SELL); currentState=WAIT_SWEEP; lastSweepDir=0; }
}
void OpenTrade(ENUM_ORDER_TYPE type)
{
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl=(type==ORDER_TYPE_BUY)? bid-StopLossPoints*_Point : ask+StopLossPoints*_Point;
   bool ok=false;
   if(type==ORDER_TYPE_BUY) ok=trade.Buy(Lots,_Symbol,0,sl,0,"$50 TONIGHT BUY");
   else ok=trade.Sell(Lots,_Symbol,0,sl,0,"$50 TONIGHT SELL");
   if(ok) PrintFormat("EXECUTED: %s SL=%d LOCK +%d hold green | Trades=%d",EnumToString(type),StopLossPoints,FirstTargetPoints,CountTrades()+1);
}
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

      // LOCK at +80 without closing
      if(pts>=FirstTargetPoints)
      {
         double be=isBuy? open+20*_Point : open-20*_Point;
         bool need=(isBuy && (sl<be || sl==0)) || (!isBuy && (sl>be || sl==0));
         if(need){ trade.PositionModify(ticket,be,0); PrintFormat("LOCKED +%.0f pts SL->BE+20 HOLD GREEN %.2f",pts,isBuy?ResLevel:SupLevel); }
      }

      // REVERSAL PROTECTION - if H1 flips after lock, protect profit
      if(pts>=FirstTargetPoints)
      {
         if(isBuy && bias==-1){ if(trade.PositionClose(ticket)) PrintFormat("REVERSAL CLOSE BUY bias SELL pts %.0f",pts); continue; }
         if(!isBuy && bias==1){ if(trade.PositionClose(ticket)) PrintFormat("REVERSAL CLOSE SELL bias BUY pts %.0f",pts); continue; }
      }

      // CLOSE at GREEN line
      if(!isBuy)
      {
         if( (curr <= SupLevel+50*_Point && pts>=100) || pts>=350 ){ if(trade.PositionClose(ticket)) PrintFormat("GREEN HIT SELL %.2f SUP %.2f pts %.0f",curr,SupLevel,pts); }
      }
      else
      {
         if( (curr >= ResLevel-50*_Point && pts>=100) || pts>=350 ){ if(trade.PositionClose(ticket)) PrintFormat("GREEN HIT BUY %.2f RES %.2f pts %.0f",curr,ResLevel,pts); }
      }
   }
}
int CountTrades(){ int c=0; for(int i=0;i<PositionsTotal();i++){ if(PositionGetSymbol(i)!=_Symbol) continue; if((long)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue; c++; } return c; }
double GetFloatingProfit(){ double p=0; for(int i=0;i<PositionsTotal();i++){ if(PositionGetSymbol(i)!=_Symbol) continue; if((long)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue; p+=PositionGetDouble(POSITION_PROFIT); } return p; }
void CloseAll(string reason)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(PositionGetSymbol(i)!=_Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      ulong ticket=(ulong)PositionGetInteger(POSITION_TICKET);
      trade.PositionClose(ticket);
   }
   PrintFormat("CLOSE ALL: %s",reason);
}
void CheckNewDay()
{
   datetime d=iTime(_Symbol,PERIOD_D1,0);
   if(d!=lastDay)
   {
      // calc yesterday realized from history
      lastDay=d; dailyRealized=0; dayStartBalance=AccountInfoDouble(ACCOUNT_BALANCE);
      Print("NEW DAY reset daily $0");
   }
   // update realized from history today
   dailyRealized=0;
   HistorySelect(lastDay, TimeCurrent());
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong ticket=HistoryDealGetTicket(i);
      if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=_Symbol) continue;
      if((long)HistoryDealGetInteger(ticket,DEAL_MAGIC)!=MagicNumber) continue;
      dailyRealized+=HistoryDealGetDouble(ticket,DEAL_PROFIT);
   }
}
void PrintProgress(string src)
{
   double floating=GetFloatingProfit();
   double total=dailyRealized+floating;
   PrintFormat("[%s] Bias=%d RES=%.2f SUP=%.2f State=%s Today $%.2f/$%.2f (%.1f%%) Trades=%d",
               src,GetH1Bias(),ResLevel,SupLevel,currentState==WAIT_SWEEP?"WAIT":"CONFIRM",total,DailyProfitTarget,DailyProfitTarget>0?total/DailyProfitTarget*100:0,CountTrades());
}
void CreateButton()
{
   if(ObjectFind(0,"BTN_STARTSTOP")>=0) ObjectDelete(0,"BTN_STARTSTOP");
   ObjectCreate(0,"BTN_STARTSTOP",OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,"BTN_STARTSTOP",OBJPROP_XDISTANCE,20);
   ObjectSetInteger(0,"BTN_STARTSTOP",OBJPROP_YDISTANCE,20);
   ObjectSetInteger(0,"BTN_STARTSTOP",OBJPROP_XSIZE,140);
   ObjectSetInteger(0,"BTN_STARTSTOP",OBJPROP_YSIZE,36);
   ObjectSetInteger(0,"BTN_STARTSTOP",OBJPROP_CORNER,CORNER_LEFT_UPPER);
   UpdateButton();
}
void UpdateButton()
{
   ObjectSetString(0,"BTN_STARTSTOP",OBJPROP_TEXT,TradingEnabled?"STOP TRADING":"START TRADING");
   ObjectSetInteger(0,"BTN_STARTSTOP",OBJPROP_BGCOLOR,TradingEnabled?clrLimeGreen:clrTomato);
   ObjectSetInteger(0,"BTN_STARTSTOP",OBJPROP_COLOR,clrBlack);
}
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_OBJECT_CLICK && sparam=="BTN_STARTSTOP")
   {
      TradingEnabled=!TradingEnabled; UpdateButton();
      PrintFormat("BUTTON: Trading %s",TradingEnabled?"ON":"OFF"); ChartRedraw();
   }
}
//+------------------------------------------------------------------+
