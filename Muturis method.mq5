//+------------------------------------------------------------------+
//| Muturi Method - Breakout Checklist EA (Educational Only)        |
//| Steps 1-5: Range -> Body Breakout -> Retest -> Entry -> Partials|
//| DISCLAIMER: Educational, not financial advice. Test on demo.    |
//+------------------------------------------------------------------+
#property copyright "Educational Template - Muturi Method"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//--- Inputs
input int RangeLookback = 40;          // Step1: candles to find range
input int RangeMinWidthPoints = 100;   // Min range width in points
input double LotSize = 0.01;
input int SL_Points = 300;
input int TP1_Points = 150;            // Partial 1
input int TP2_Points = 350;            // Final TP
input double PartialPercent = 50;      // % to close at TP1
input long Magic = 20260917;

//--- Globals
bool isRunning = false;
int btnStartStop;
string lblStatus = "lblStatus";
double rangeHigh = 0, rangeLow = 0;
bool hasBreakout = false;
bool isBreakoutUp = false;
datetime breakoutTime = 0;
bool tradeTaken = false;

//+------------------------------------------------------------------+
int OnInit()
  {
   // Create Start/Stop button
   btnStartStop = 0;
   ObjectCreate(0, "btnStartStop", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "btnStartStop", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, "btnStartStop", OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, "btnStartStop", OBJPROP_XSIZE, 120);
   ObjectSetInteger(0, "btnStartStop", OBJPROP_YSIZE, 30);
   ObjectSetString(0, "btnStartStop", OBJPROP_TEXT, "START");
   ObjectSetInteger(0, "btnStartStop", OBJPROP_BGCOLOR, clrLimeGreen);
   
   ObjectCreate(0, lblStatus, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, lblStatus, OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, lblStatus, OBJPROP_YDISTANCE, 60);
   ObjectSetString(0, lblStatus, OBJPROP_TEXT, "Status: STOPPED");
   Print("Muturi EA Initialized. Click START to run.");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   ObjectDelete(0, "btnStartStop");
   ObjectDelete(0, lblStatus);
   ObjectDelete(0, "RangeHighLine");
   ObjectDelete(0, "RangeLowLine");
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == "btnStartStop")
     {
      isRunning = !isRunning;
      if(isRunning)
        {
         ObjectSetString(0, "btnStartStop", OBJPROP_TEXT, "STOP");
         ObjectSetInteger(0, "btnStartStop", OBJPROP_BGCOLOR, clrTomato);
         Print("EA STARTED - Scanning for tradable range...");
         UpdateStatus("SCANNING RANGE...");
        }
      else
        {
         ObjectSetString(0, "btnStartStop", OBJPROP_TEXT, "START");
         ObjectSetInteger(0, "btnStartStop", OBJPROP_BGCOLOR, clrLimeGreen);
         Print("EA STOPPED by user.");
         UpdateStatus("STOPPED");
        }
     }
  }

void UpdateStatus(string txt)
  {
   ObjectSetString(0, lblStatus, OBJPROP_TEXT, "Status: " + txt);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   if(!isRunning) return;
   if(PositionSelect(_Symbol)) // Manage partials if in trade
     {
      ManagePartials();
      return;
     }

   //--- STEP 1: FIND TRADABLE RANGE
   FindRange();
   if(rangeHigh == 0 || rangeLow == 0)
     {
      UpdateStatus("STEP1: No valid range yet");
      return;
     }
   DrawRangeLines();
   PrintFormat("STEP1 OK: Range High=%.2f Low=%.2f Width=%.2f", rangeHigh, rangeLow, rangeHigh-rangeLow);
   UpdateStatus("STEP1 RANGE FOUND");

   //--- STEP 2: CONFIRM REAL BREAKOUT (Body close, not wick)
   if(!hasBreakout)
     {
      double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
      double open1  = iOpen(_Symbol, PERIOD_CURRENT, 1);
      // Up breakout: body close above range high
      if(close1 > rangeHigh && open1 > rangeLow) // body closed outside
        {
         hasBreakout = true;
         isBreakoutUp = true;
         breakoutTime = iTime(_Symbol, PERIOD_CURRENT, 1);
         PrintFormat("STEP2 BREAKOUT UP: Body close %.2f > RangeHigh %.2f", close1, rangeHigh);
         UpdateStatus("STEP2 BREAKOUT UP - Waiting Retest");
         return;
        }
      // Down breakout
      if(close1 < rangeLow && open1 < rangeHigh)
        {
         hasBreakout = true;
         isBreakoutUp = false;
         breakoutTime = iTime(_Symbol, PERIOD_CURRENT, 1);
         PrintFormat("STEP2 BREAKDOWN: Body close %.2f < RangeLow %.2f", close1, rangeLow);
         UpdateStatus("STEP2 BREAKDOWN - Waiting Retest");
         return;
        }
      UpdateStatus("STEP2: Waiting body-close breakout...");
      return;
     }

   //--- STEP 3: WAIT FOR RETEST
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);

   if(isBreakoutUp)
     {
      // Price came back to test RangeHigh
      if(low1 <= rangeHigh + 50*_Point && close1 > rangeHigh) // retest and holds above
        {
         Print("STEP3 RETEST HOLD UP confirmed - preparing entry");
         UpdateStatus("STEP3 RETEST HOLD - Entry next");
         ExecuteTrade(true);
        }
      else if(close1 < rangeHigh) // body closed back inside = fakeout
        {
         Print("STEP3 FAKEOUT: Body closed back inside range - resetting scan");
         ResetScan();
         UpdateStatus("FAKEOUT - Rescanning...");
        }
     }
   else // Down breakout case
     {
      if(high1 >= rangeLow - 50*_Point && close1 < rangeLow)
        {
         Print("STEP3 RETEST HOLD DOWN confirmed");
         UpdateStatus("STEP3 RETEST HOLD DOWN");
         ExecuteTrade(false);
        }
      else if(close1 > rangeLow)
        {
         Print("STEP3 FAKEOUT DOWN - resetting");
         ResetScan();
        }
     }
  }

void FindRange()
  {
   double highest = -DBL_MAX, lowest = DBL_MAX;
   for(int i=1; i<=RangeLookback; i++)
     {
      double h = iHigh(_Symbol, PERIOD_CURRENT, i);
      double l = iLow(_Symbol, PERIOD_CURRENT, i);
      if(h > highest) highest = h;
      if(l < lowest) lowest = l;
     }
   if((highest - lowest) / _Point >= RangeMinWidthPoints)
     {
      rangeHigh = highest;
      rangeLow = lowest;
     }
  }

void DrawRangeLines()
  {
   DrawHLine("RangeHighLine", rangeHigh, clrDodgerBlue);
   DrawHLine("RangeLowLine", rangeLow, clrDodgerBlue);
  }

void DrawHLine(string name, double price, color c)
  {
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
  }

void ExecuteTrade(bool isBuy)
  {
   if(tradeTaken) return;
   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = isBuy ? price - SL_Points*_Point : price + SL_Points*_Point;
   double tp = isBuy ? price + TP2_Points*_Point : price - TP2_Points*_Point;

   bool ok = false;
   if(isBuy) ok = trade.Buy(LotSize, _Symbol, price, sl, tp);
   else ok = trade.Sell(LotSize, _Symbol, price, sl, tp);

   if(ok)
     {
      PrintFormat("STEP4 ENTRY %s executed at %.2f SL %.2f TP %.2f - Partial at %d pts", 
                  isBuy ? "BUY" : "SELL", price, sl, tp, TP1_Points);
      UpdateStatus("STEP4 IN TRADE - Managing partials");
      tradeTaken = true;
      trade.SetExpertMagicNumber(Magic);
     }
   else
      PrintFormat("Entry failed: %d", GetLastError());
  }

void ManagePartials()
  {
   if(!PositionSelect(_Symbol)) return;
   double price = PositionGetDouble(POSITION_PRICE_OPEN);
   double current = PositionGetDouble(POSITION_PRICE_CURRENT);
   long type = PositionGetInteger(POSITION_TYPE);
   double profitPoints = 0;
   if(type == POSITION_TYPE_BUY) profitPoints = (current - price) / _Point;
   else profitPoints = (price - current) / _Point;

   if(profitPoints >= TP1_Points && PositionGetDouble(POSITION_VOLUME) >= LotSize)
     {
      double volToClose = LotSize * PartialPercent / 100.0;
      if(trade.PositionClosePartial(_Symbol, volToClose))
        {
         PrintFormat("STEP5 PARTIAL PROFIT: Closed %.2f lots at +%d points. Letting rest run to TP2", volToClose, TP1_Points);
         // Move SL to breakeven for remainder
         double bePrice = price;
         double tp = PositionGetDouble(POSITION_TP);
         trade.PositionModify(_Symbol, bePrice, tp);
         UpdateStatus("PARTIAL TAKEN - BE set, running to TP2");
        }
     }
   if(profitPoints >= TP2_Points || profitPoints <= -SL_Points)
     {
      Print("Trade ended - TP/SL hit. Starting fresh scan");
      ResetScan();
     }
  }

void ResetScan()
  {
   hasBreakout = false;
   isBreakoutUp = false;
   tradeTaken = false;
   breakoutTime = 0;
   rangeHigh = 0;
   rangeLow = 0;
   if(isRunning) UpdateStatus("SCANNING NEW RANGE...");
  }
//+------------------------------------------------------------------+
