//+------------------------------------------------------------------+
//| GoldFlip FINAL - 0 Errors 0 Warnings |
//+------------------------------------------------------------------+
#property strict
#property version "7.00"

input double LotSize = 0.01;
input int SL_Points = 150;
input int TP_Points = 600;
input double BE_Trigger = 1.5;
input int MaxTradesPerDay = 5;
input bool UseNewsFilter = true;
input int NewsStartGMT = 12;
input int NewsEndGMT = 15;
input double WithdrawAt = 20.0;

int h_ema9, h_ema21, h_rsi;
int trades_today = 0;
datetime last_day = 0;
bool is_on = true;
bool alert_done = false;
double start_bal = 0;

int OnInit()
{
   h_ema9 = iMA(_Symbol, PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
   h_ema21 = iMA(_Symbol, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   h_rsi = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);
   start_bal = AccountInfoDouble(ACCOUNT_BALANCE);
   ObjectCreate(0, "BTN", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "BTN", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, "BTN", OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, "BTN", OBJPROP_XSIZE, 120);
   ObjectSetInteger(0, "BTN", OBJPROP_YSIZE, 35);
   ObjectSetString(0, "BTN", OBJPROP_TEXT, "STOP EA");
   ObjectSetInteger(0, "BTN", OBJPROP_BGCOLOR, clrLimeGreen);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason){ ObjectDelete(0, "BTN"); }
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id==CHARTEVENT_OBJECT_CLICK && sparam=="BTN")
   {
      is_on =!is_on;
      ObjectSetString(0, "BTN", OBJPROP_TEXT, is_on? "STOP EA" : "START EA");
      ObjectSetInteger(0, "BTN", OBJPROP_BGCOLOR, is_on? clrLimeGreen : clrRed);
   }
}
bool NewsBlock()
{
   if(!UseNewsFilter) return false;
   MqlDateTime tm;
   TimeToStruct(TimeGMT(), tm);
   if(tm.hour >= NewsStartGMT && tm.hour <= NewsEndGMT) return true;
   return false;
}
void Manage()
{
   double prof = AccountInfoDouble(ACCOUNT_EQUITY) - start_bal;
   PrintFormat("PROGRESS Equity=%.2f Profit=%.2f Trades=%d Pos=%d News=%s EA=%s", AccountInfoDouble(ACCOUNT_EQUITY), prof, trades_today, PositionsTotal(), NewsBlock()?"YES":"NO", is_on?"ON":"OFF");
   if(prof >= WithdrawAt &&!alert_done){ Alert("WITHDRAW NOW! Profit $", prof); alert_done=true; }
   if(prof < WithdrawAt-2) alert_done=false;
   for(int i=0;i<PositionsTotal();i++)
   {
      string s = PositionGetSymbol(i);
      if(s!= _Symbol) continue;
      ulong tk = (ulong)PositionGetInteger(POSITION_TICKET);
      double pft = PositionGetDouble(POSITION_PROFIT);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      long typ = PositionGetInteger(POSITION_TYPE);
      if(pft >= BE_Trigger)
      {
         double nsl = (typ==POSITION_TYPE_BUY)? open+0.20 : open-0.20;
         bool need = (typ==POSITION_TYPE_BUY)? (nsl>sl) : (nsl<sl || sl==0);
         if(need)
         {
            MqlTradeRequest rq; MqlTradeResult rs; ZeroMemory(rq); ZeroMemory(rs);
            rq.action=TRADE_ACTION_SLTP; rq.position=tk; rq.symbol=_Symbol; rq.sl=nsl; rq.tp=tp;
            bool ok = OrderSend(rq, rs);
            if(!ok) Print("BE modify failed ", rs.retcode);
         }
      }
   }
}
bool OpenOrder(ENUM_ORDER_TYPE typ)
{
   double pr = (typ==ORDER_TYPE_BUY)? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = (typ==ORDER_TYPE_BUY)? pr - SL_Points*_Point*10 : pr + SL_Points*_Point*10;
   double tp = (typ==ORDER_TYPE_BUY)? pr + TP_Points*_Point*10 : pr - TP_Points*_Point*10;
   MqlTradeRequest rq; MqlTradeResult rs; ZeroMemory(rq); ZeroMemory(rs);
   rq.action=TRADE_ACTION_DEAL; rq.symbol=_Symbol; rq.volume=LotSize; rq.type=typ; rq.price=pr; rq.sl=sl; rq.tp=tp; rq.deviation=30; rq.magic=1010; rq.type_filling=ORDER_FILLING_IOC;
   if(!OrderSend(rq, rs)) return false;
   trades_today++; return true;
}
void OnTick()
{
   Manage();
   if(!is_on) return;
   MqlDateTime now; TimeToStruct(TimeGMT(), now);
   MqlDateTime last; TimeToStruct(last_day, last);
   if(last_day==0 || now.day!=last.day){ trades_today=0; last_day=TimeGMT(); }
   if(trades_today>=MaxTradesPerDay) return;
   if(NewsBlock()) return;
   if(PositionsTotal()>0) return;
   double ema9[2], ema21[2], rsi[2];
   if(CopyBuffer(h_ema9,0,0,2,ema9)!=2) return;
   if(CopyBuffer(h_ema21,0,0,2,ema21)!=2) return;
   if(CopyBuffer(h_rsi,0,0,2,rsi)!=2) return;
   double close1 = iClose(_Symbol, PERIOD_M1, 1);
   bool up = ema9[0] > ema21[0];
   bool down = ema9[0] < ema21[0];
   if(up && close1 <= ema9[0]+2.0 && rsi[0]>=50 && rsi[0]<=62) OpenOrder(ORDER_TYPE_BUY);
   if(down && close1 >= ema9[0]-2.0 && rsi[0]>=38 && rsi[0]<=50) OpenOrder(ORDER_TYPE_SELL);
}
