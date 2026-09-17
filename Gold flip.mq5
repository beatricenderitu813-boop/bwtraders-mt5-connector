//+------------------------------------------------------------------+
//| GoldFlip V4 - Clean Compile 0 Errors 0 Warnings |
//| Anytime trading, News time block, $1.50 BE lock, $20 alert, Btn |
//+------------------------------------------------------------------+
#property strict
#property version "4.00"

input double LotSize = 0.01;
input int SL_Points = 150;
input int TP_Points = 600;
input double BE_Trigger_Dollars = 1.5;
input double BE_Lock_Dollars = 0.3;
input int MaxTradesPerDay = 5;
input bool UseNewsFilter = true;
input int NewsStartHourGMT = 12;
input int NewsEndHourGMT = 15;
input double WithdrawAlertAt = 20.0;

int handle_ema9, handle_ema21, handle_rsi;
int trades_today = 0;
datetime last_day = 0;
bool is_on = true;
bool alert_sent = false;
double start_balance = 0.0;

//+------------------------------------------------------------------+
int OnInit()
{
   handle_ema9 = iMA(_Symbol, PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
   handle_ema21 = iMA(_Symbol, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   handle_rsi = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);
   if(handle_ema9==INVALID_HANDLE || handle_ema21==INVALID_HANDLE || handle_rsi==INVALID_HANDLE)
      return(INIT_FAILED);
   start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   ObjectCreate(0, "START_STOP", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "START_STOP", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, "START_STOP", OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, "START_STOP", OBJPROP_XSIZE, 120);
   ObjectSetInteger(0, "START_STOP", OBJPROP_YSIZE, 35);
   ObjectSetString(0, "START_STOP", OBJPROP_TEXT, "STOP EA");
   ObjectSetInteger(0, "START_STOP", OBJPROP_BGCOLOR, clrLimeGreen);
   ObjectSetInteger(0, "START_STOP", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0, "START_STOP");
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id==CHARTEVENT_OBJECT_CLICK && sparam=="START_STOP")
   {
      is_on =!is_on;
      ObjectSetString(0, "START_STOP", OBJPROP_TEXT, is_on? "STOP EA" : "START EA");
      ObjectSetInteger(0, "START_STOP", OBJPROP_BGCOLOR, is_on? clrLimeGreen : clrRed);
      Print(is_on? "EA RESUMED" : "EA PAUSED by button");
   }
}

//+------------------------------------------------------------------+
bool IsNewsBlocked()
{
   if(!UseNewsFilter) return false;
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   if(dt.hour >= NewsStartHourGMT && dt.hour <= NewsEndHourGMT)
   {
      if(dt.hour==NewsStartHourGMT && dt.min < 30) return false;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetFilling()
{
   int mode = (int)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((mode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) return ORDER_FILLING_IOC;
   if((mode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) return ORDER_FILLING_FOK;
   return ORDER_FILLING_RETURN;
}

//+------------------------------------------------------------------+
bool ModifySL(ulong ticket, double new_sl, double current_tp)
{
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action = TRADE_ACTION_SLTP;
   req.position = ticket;
   req.symbol = _Symbol;
   req.sl = new_sl;
   req.tp = current_tp;
   req.type_filling = GetFilling();
   req.deviation = 30;
   if(!OrderSend(req, res))
   {
      Print("ModifySL failed: ", res.retcode);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
void ManageTrades()
{
   double total_profit = AccountInfoDouble(ACCOUNT_EQUITY) - start_balance;
   PrintFormat("PROGRESS | Equity: %.2f | Profit: %.2f | TradesToday: %d/%d | Positions: %d | NewsBlock: %s | EA: %s",
               AccountInfoDouble(ACCOUNT_EQUITY), total_profit, trades_today, MaxTradesPerDay,
               PositionsTotal(), IsNewsBlocked()? "YES" : "NO", is_on? "ON" : "OFF");
   if(total_profit >= WithdrawAlertAt &&!alert_sent)
   {
      Alert("WITHDRAW NOW! Profit hit $", DoubleToString(total_profit,2));
      Print(">>> WITHDRAW $", DoubleToString(total_profit,2), " NOW - SL still protecting capital <<<");
      alert_sent = true;
   }
   if(total_profit < (WithdrawAlertAt - 2.0))
      alert_sent = false;
   for(int i=0; i<PositionsTotal(); i++)
   {
      string sym = PositionGetSymbol(i);
      if(sym!= _Symbol) continue;
      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double price_open = PositionGetDouble(POSITION_PRICE_OPEN);
      double curr_sl = PositionGetDouble(POSITION_SL);
      double curr_tp = PositionGetDouble(POSITION_TP);
      long type = PositionGetInteger(POSITION_TYPE);
      if(profit >= BE_Trigger_Dollars)
      {
         double new_sl = 0.0;
         if(type == POSITION_TYPE_BUY)
         {
            new_sl = price_open + 0.20;
            if(new_sl > curr_sl)
            {
               bool ok = ModifySL(ticket, new_sl, curr_tp);
               if(!ok) Print("BE Buy failed");
            }
         }
         else if(type == POSITION_TYPE_SELL)
         {
            new_sl = price_open - 0.20;
            if(new_sl < curr_sl || curr_sl==0.0)
            {
               bool ok = ModifySL(ticket, new_sl, curr_tp);
               if(!ok) Print("BE Sell failed");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
bool OpenTrade(ENUM_ORDER_TYPE order_type)
{
   double price = (order_type==ORDER_TYPE_BUY)? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = (order_type==ORDER_TYPE_BUY)? price - SL_Points * _Point * 10 : price + SL_Points * _Point * 10;
   double tp = (order_type==ORDER_TYPE_BUY)? price + TP_Points * _Point * 10 : price - TP_Points * _Point * 10;
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action = TRADE_ACTION_DEAL;
   req.symbol = _Symbol;
   req.volume = LotSize;
   req.type = order_type;
   req.price = price;
   req.sl = sl;
   req.tp = tp;
   req.deviation = 30;
   req.magic = 1010;
   req.type_filling = GetFilling();
   if(!OrderSend(req, res))
   {
      Print("OrderSend failed: ", res.retcode);
      return false;
   }
   trades_today++;
   Print("Trade opened. Ticket: ", res.order, " Today count: ", trades_today);
   return true;
}

//+------------------------------------------------------------------+
void OnTick()
{
   ManageTrades();
   if(!is_on) return;
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   MqlDateTime dt_last;
   TimeToStruct(last_day, dt_last);
   if(last_day==0 || dt.day!=dt_last.day)
   {
      trades_today = 0;
      last_day = TimeGMT();
   }
   if(trades_today >= MaxTradesPerDay) return;
   if(IsNewsBlocked()) return;
   if(PositionsTotal() > 0) return;
   double ema9_buf[];
   double ema21_buf[];
   double rsi_buf[];
   ArraySetAsSeries(ema9_buf,true);
   ArraySetAsSeries(ema21_buf,true);
   ArraySetAsSeries(rsi_buf,true);
   if(CopyBuffer(handle_ema9,0,0,2,ema9_buf)!=2) return;
   if(CopyBuffer(handle_ema21,0,0,2,ema21_buf)!=2) return;
   if(CopyBuffer(handle_rsi,0,0,2,rsi_buf)!=2) return;
   double m1_close = iClose(_Symbol, PERIOD_M1, 1);
   bool uptrend = ema9_buf[0] > ema21_buf[0];
   bool downtrend = ema9_buf[0] < ema21_buf[0];
   if(uptrend && m1_close <= ema9_buf[0]+2.0 && rsi_buf[0]>=50.0 && rsi_buf[0]<=62.0)
   {
      bool ok = OpenTrade(ORDER_TYPE_BUY);
      if(!ok) Print("Buy failed");
   }
   if(downtrend && m1_close >= ema9_buf[0]-2.0 && rsi_buf[0]>=38.0 && rsi_buf[0]<=50.0)
   {
      bool ok = OpenTrade(ORDER_TYPE_SELL);
      if(!ok) Print("Sell failed");
   }
}
//+------------------------------------------------------------------+
