//+------------------------------------------------------------------+
//| GoldFlip V6.3 - 10 Points Forming + 80 Lock + No Max Trades      |
//+------------------------------------------------------------------+
#property copyright "V6.3"
#property version   "6.30"
#property strict

input double LotSize = 0.01;
input int    SL_Points = 150;
input int    TP_Points = 300;
input double FormingFilter = 10;      // 10 points = $0.10 body = INSTANT
input double MomentumFilter = 5;      // small momentum filter
input double LockAt_Points = 80;      // lock at 80 points profit
input double LockTo_Points = 20;      // lock to +20 points

int      trades_today=0;
datetime last_day=0;
bool     is_on=true;
double   start_balance=0;

ENUM_ORDER_TYPE_FILLING GetFilling()
{
   int mode=(int)SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   if((mode & SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC) return ORDER_FILLING_IOC;
   if((mode & SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK) return ORDER_FILLING_FOK;
   return ORDER_FILLING_RETURN;
}

void CreateDashboard()
{
   ObjectCreate(0,"BG",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,"BG",OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,"BG",OBJPROP_YDISTANCE,10);
   ObjectSetInteger(0,"BG",OBJPROP_XSIZE,240);
   ObjectSetInteger(0,"BG",OBJPROP_YSIZE,260);
   ObjectSetInteger(0,"BG",OBJPROP_BGCOLOR,C'18,18,18');
   ObjectSetInteger(0,"BG",OBJPROP_BORDER_TYPE,BORDER_FLAT);

   ObjectCreate(0,"TITLE",OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,"TITLE",OBJPROP_XDISTANCE,20);
   ObjectSetInteger(0,"TITLE",OBJPROP_YDISTANCE,18);
   ObjectSetInteger(0,"TITLE",OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,"TITLE",OBJPROP_COLOR,clrLime);
   ObjectSetString(0,"TITLE",OBJPROP_TEXT,"● CONNECTED - V6.3 10Pts");
   ObjectSetInteger(0,"TITLE",OBJPROP_FONTSIZE,9);

   for(int i=0;i<3;i++)
   {
      string n="L"+IntegerToString(i);
      ObjectCreate(0,n,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_XDISTANCE,20);
      ObjectSetInteger(0,n,OBJPROP_YDISTANCE,50+i*18);
      ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_COLOR,clrWhite);
      ObjectSetInteger(0,n,OBJPROP_FONTSIZE,8);
   }

   ObjectCreate(0,"START_BTN",OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,"START_BTN",OBJPROP_XDISTANCE,20);
   ObjectSetInteger(0,"START_BTN",OBJPROP_YDISTANCE,120);
   ObjectSetInteger(0,"START_BTN",OBJPROP_XSIZE,100);
   ObjectSetInteger(0,"START_BTN",OBJPROP_YSIZE,35);
   ObjectSetString(0,"START_BTN",OBJPROP_TEXT,"START");
   ObjectSetInteger(0,"START_BTN",OBJPROP_BGCOLOR,clrLimeGreen);
   ObjectSetInteger(0,"START_BTN",OBJPROP_COLOR,clrBlack);

   ObjectCreate(0,"STOP_BTN",OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,"STOP_BTN",OBJPROP_XDISTANCE,130);
   ObjectSetInteger(0,"STOP_BTN",OBJPROP_YDISTANCE,120);
   ObjectSetInteger(0,"STOP_BTN",OBJPROP_XSIZE,100);
   ObjectSetInteger(0,"STOP_BTN",OBJPROP_YSIZE,35);
   ObjectSetString(0,"STOP_BTN",OBJPROP_TEXT,"STOPPER");
   ObjectSetInteger(0,"STOP_BTN",OBJPROP_BGCOLOR,clrRed);
   ObjectSetInteger(0,"STOP_BTN",OBJPROP_COLOR,clrWhite);

   ObjectCreate(0,"STATUS",OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,"STATUS",OBJPROP_XDISTANCE,20);
   ObjectSetInteger(0,"STATUS",OBJPROP_YDISTANCE,180);
   ObjectSetInteger(0,"STATUS",OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,"STATUS",OBJPROP_FONTSIZE,8);

   ObjectCreate(0,"MATH",OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,"MATH",OBJPROP_XDISTANCE,20);
   ObjectSetInteger(0,"MATH",OBJPROP_YDISTANCE,200);
   ObjectSetInteger(0,"MATH",OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,"MATH",OBJPROP_FONTSIZE,7);
   ObjectSetInteger(0,"MATH",OBJPROP_COLOR,clrYellow);
}

int OnInit(){start_balance=AccountInfoDouble(ACCOUNT_BALANCE); CreateDashboard(); return(INIT_SUCCEEDED);}
void OnDeinit(const int reason)
{
   ObjectDelete(0,"BG"); ObjectDelete(0,"TITLE");
   for(int i=0;i<3;i++) ObjectDelete(0,"L"+IntegerToString(i));
   ObjectDelete(0,"START_BTN"); ObjectDelete(0,"STOP_BTN"); ObjectDelete(0,"STATUS"); ObjectDelete(0,"MATH");
}
void OnChartEvent(const int id,const long &l,const double &d,const string &s){if(id==CHARTEVENT_OBJECT_CLICK){if(s=="START_BTN") is_on=true; if(s=="STOP_BTN") is_on=false;}}

bool ModifySL(ulong ticket,double new_sl,double tp)
{
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   req.action=TRADE_ACTION_SLTP; req.position=ticket; req.symbol=_Symbol; req.sl=new_sl; req.tp=tp;
   req.type_filling=GetFilling(); req.deviation=30; return OrderSend(req,res);
}

void Manage()
{
   double bal=AccountInfoDouble(ACCOUNT_BALANCE); double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   ObjectSetString(0,"L0",OBJPROP_TEXT,"Balance: "+DoubleToString(bal,2));
   ObjectSetString(0,"L1",OBJPROP_TEXT,"Equity: "+DoubleToString(eq,2));
   ObjectSetString(0,"L2",OBJPROP_TEXT,"Trades Today: "+IntegerToString(trades_today)+" Pos: "+IntegerToString(PositionsTotal()));
   ObjectSetString(0,"STATUS",OBJPROP_TEXT,"Bot: "+(string)(is_on?"RUNNING":"PAUSED"));
   ObjectSetInteger(0,"STATUS",OBJPROP_COLOR,is_on?clrLime:clrRed);

   for(int i=0;i<PositionsTotal();i++)
   {
      if(PositionGetSymbol(i)!=_Symbol) continue;
      ulong ticket=(ulong)PositionGetInteger(POSITION_TICKET);
      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double curr_sl=PositionGetDouble(POSITION_SL);
      double curr_tp=PositionGetDouble(POSITION_TP);
      long type=PositionGetInteger(POSITION_TYPE);
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double pts=0.0;
      if(type==POSITION_TYPE_BUY) pts=(bid-open)/_Point/10.0; else pts=(open-ask)/_Point/10.0;

      if(pts>=LockAt_Points)
      {
         double nsl=0.0;
         if(type==POSITION_TYPE_BUY) nsl=open+LockTo_Points*_Point*10.0;
         else nsl=open-LockTo_Points*_Point*10.0;
         if(type==POSITION_TYPE_BUY && nsl>curr_sl) ModifySL(ticket,nsl,curr_tp);
         if(type==POSITION_TYPE_SELL && (nsl<curr_sl || curr_sl==0.0)) ModifySL(ticket,nsl,curr_tp);
      }
   }
}

bool OpenTrade(ENUM_ORDER_TYPE ot)
{
   double price=(ot==ORDER_TYPE_BUY)?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl=(ot==ORDER_TYPE_BUY)?price-SL_Points*_Point*10.0:price+SL_Points*_Point*10.0;
   double tp=(ot==ORDER_TYPE_BUY)?price+TP_Points*_Point*10.0:price-TP_Points*_Point*10.0;
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   req.action=TRADE_ACTION_DEAL; req.symbol=_Symbol; req.volume=LotSize; req.type=ot;
   req.price=price; req.sl=sl; req.tp=tp; req.deviation=30; req.magic=6300; req.type_filling=GetFilling();
   if(!OrderSend(req,res)) return false;
   trades_today++; return true;
}

void OnTick()
{
   Manage(); if(!is_on) return;
   if(PositionsTotal()>0) return; // 1 trade only, but no daily limit -> keeps opening fresh

   double open_m1=iOpen(_Symbol,PERIOD_M1,0);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double c0=iClose(_Symbol,PERIOD_M1,1);
   double c3=iClose(_Symbol,PERIOD_M1,4);
   if(open_m1==0.0 || c0==0.0 || c3==0.0) return;

   double body=(bid-open_m1)/_Point/10.0;
   double mom=(c0-c3)/_Point/10.0;

   ObjectSetString(0,"MATH",OBJPROP_TEXT,"Body: "+DoubleToString(body,1)+" Mom: "+DoubleToString(mom,1)+" -> 10pts Rule");

   bool buy = (body >= FormingFilter && mom >= MomentumFilter);
   bool sell = (body <= -FormingFilter && mom <= -MomentumFilter);

   if(buy) OpenTrade(ORDER_TYPE_BUY);
   if(sell) OpenTrade(ORDER_TYPE_SELL);
}
