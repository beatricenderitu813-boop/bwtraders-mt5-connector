//+------------------------------------------------------------------+
//| Gold10Flip V3 - Anytime + Button + $20 Alert |
//+------------------------------------------------------------------+
#property strict

input double LotSize = 0.01;
input double SL_Points = 150;
input double TP_Points = 600; // let it run, we protect with BE
input double BE_Trigger = 1.5;
input double BE_Lock = 0.3;
input int MaxTradesPerDay = 5;
input bool UseNewsFilter = true;
input int NewsBlockMin = 30;
input double WithdrawAlertAt = 20.0; // account profit

int ema9, ema21, rsi;
int tradesToday=0;
datetime lastDay=0;
bool isTradingOn = true;
bool alertSent = false;
double startBalance=0;

//+------------------------------------------------------------------+
int OnInit(){
   ema9 = iMA(_Symbol, PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
   ema21 = iMA(_Symbol, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   rsi = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);

   startBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   // Create Button
   ObjectCreate(0, "START_STOP", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "START_STOP", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, "START_STOP", OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, "START_STOP", OBJPROP_XSIZE, 120);
   ObjectSetInteger(0, "START_STOP", OBJPROP_YSIZE, 35);
   ObjectSetString(0, "START_STOP", OBJPROP_TEXT, "STOP EA");
   ObjectSetInteger(0, "START_STOP", OBJPROP_BGCOLOR, clrLimeGreen);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason){
   ObjectDelete(0, "START_STOP");
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam){
   if(id==CHARTEVENT_OBJECT_CLICK && sparam=="START_STOP"){
      isTradingOn =!isTradingOn;
      ObjectSetString(0, "START_STOP", OBJPROP_TEXT, isTradingOn? "STOP EA" : "START EA");
      ObjectSetInteger(0, "START_STOP", OBJPROP_BGCOLOR, isTradingOn? clrLimeGreen : clrRed);
      Print(isTradingOn? "EA RESUMED" : "EA PAUSED by button");
   }
}

//+------------------------------------------------------------------+
bool IsNews(){
   if(!UseNewsFilter) return false;
   datetime now = TimeGMT();
   MqlCalendarValue vals[];
   if(CalendarValueHistory(vals, now-21600, now+21600, "United States", NULL)){
      for(int i=0;i<ArraySize(vals);i++){
         if(vals[i].impact_type==CALENDAR_IMPACT_HIGH){
            long diff = (long)(vals[i].time - now)/60;
            if(MathAbs(diff) <= NewsBlockMin) return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
void ManageTrades(){
   double totalProfit = AccountInfoDouble(ACCOUNT_EQUITY) - startBalance;

   // Progress in Experts tab
   PrintFormat("PROGRESS | Equity: %.2f | Profit today: %.2f | Trades: %d/%d | Pos: %d | NewsBlock: %s | EA: %s",
      AccountInfoDouble(ACCOUNT_EQUITY), totalProfit, tradesToday, MaxTradesPerDay,
      PositionsTotal(), IsNews()? "YES" : "NO", isTradingOn? "ON" : "OFF");

   // $20 Withdrawal Alert
   if(totalProfit >= WithdrawAlertAt &&!alertSent){
      Alert("WITHDRAW NOW! Profit hit $", DoubleToString(totalProfit,2), " - Protect capital!");
      Print(">>> WITHDRAW $", totalProfit, " NOW - SL still protecting <<<");
      alertSent=true;
   }
   if(totalProfit < WithdrawAlertAt-2) alertSent=false; // reset

   // Breakeven logic - lock but don't close
   for(int i=0;i<PositionsTotal();i++){
      string sym = PositionGetSymbol(i);
      if(sym!= _Symbol) continue;
      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double currSL = PositionGetDouble(POSITION_SL);

      if(profit >= BE_Trigger){
         double newSL = 0;
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(type==POSITION_TYPE_BUY){
            newSL = open + 5*_Point*10; // lock small
            if(newSL > currSL){
               MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req);
               req.action=TRADE_ACTION_SLTP; req.position=ticket; req.symbol=_Symbol;
               req.sl=newSL; req.tp=PositionGetDouble(POSITION_TP);
               OrderSend(req,res);
               Print("Locked BUY to BE+ at ", newSL);
            }
         } else {
            newSL = open - 5*_Point*10;
            if(newSL < currSL || currSL==0){
               MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req);
               req.action=TRADE_ACTION_SLTP; req.position=ticket; req.symbol=_Symbol;
               req.sl=newSL; req.tp=PositionGetDouble(POSITION_TP);
               OrderSend(req,res);
               Print("Locked SELL to BE+ at ", newSL);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
void OnTick(){
   ManageTrades();
   if(!isTradingOn) return;

   MqlDateTime dt; TimeToStruct(TimeGMT(), dt);
   if(dt.day!= TimeDay(lastDay) || lastDay==0){ tradesToday=0; lastDay=TimeGMT(); }
   if(tradesToday >= MaxTradesPerDay) return;
   if(IsNews()) return;
   if(PositionsTotal() > 0) return; // let winner run, don't spam

   double b9[], b21[], brsi[];
   CopyBuffer(ema9,0,0,2,b9); CopyBuffer(ema21,0,0,2,b21); CopyBuffer(rsi,0,0,2,brsi);
   ArraySetAsSeries(b9,true); ArraySetAsSeries(b21,true); ArraySetAsSeries(brsi,true);

   double m1_close = iClose(_Symbol, PERIOD_M1, 1);
   bool up = b9[0] > b21[0];
   bool down = b9[0] < b21[0];

   if(up && m1_close <= b9[0]+2.0 && brsi[0]>=50 && brsi[0]<=62) Open(ORDER_TYPE_BUY);
   if(down && m1_close >= b9[0]-2.0 && brsi[0]>=38 && brsi[0]<=50) Open(ORDER_TYPE_SELL);
}

//+------------------------------------------------------------------+
void Open(ENUM_ORDER_TYPE t){
   double price = (t==ORDER_TYPE_BUY)? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = (t==ORDER_TYPE_BUY)? price - SL_Points*_Point*10 : price + SL_Points*_Point*10;
   double tp = (t==ORDER_TYPE_BUY)? price + TP_Points*_Point*10 : price - TP_Points*_Point*10;
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req);
   req.action=TRADE_ACTION_DEAL; req.symbol=_Symbol; req.volume=LotSize; req.type=t;
   req.price=price; req.sl=sl; req.tp=tp; req.deviation=30; req.magic=1010;
   if(OrderSend(req,res)){ tradesToday++; Print("Trade opened, today: ", tradesToday); }
}
