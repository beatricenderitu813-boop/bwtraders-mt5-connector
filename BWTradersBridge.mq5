//+------------------------------------------------------------------+
//| BWTraders MT5 Bridge                                             |
//| DEMO data bridge - no automatic trading                         |
//+------------------------------------------------------------------+
#property strict
#property version   "1.0"

input string ConnectorURL =
   "https://bwtraders-mt5-connector.onrender.com/mt5/market";

input string BWTradersAPIKey = "";

input string Symbol1 = "EURUSD";
input string Symbol2 = "XAUUSD";

input int SendIntervalSeconds = 10;

datetime lastSend = 0;


//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("BWTraders MT5 Bridge started.");
   Print("MODE: DEMO - trading disabled.");

   if(!SymbolSelect(Symbol1, true))
      Print("Could not select ", Symbol1);

   if(!SymbolSelect(Symbol2, true))
      Print("Could not select ", Symbol2);

   EventSetTimer(SendIntervalSeconds);

   return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();

   Print("BWTraders MT5 Bridge stopped.");
}


//+------------------------------------------------------------------+
//| Timer                                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   SendMarketData(Symbol1);
   SendMarketData(Symbol2);
}


//+------------------------------------------------------------------+
//| Send market data                                                 |
//+------------------------------------------------------------------+
void SendMarketData(string symbol)
{
   MqlTick tick;

   if(!SymbolInfoTick(symbol, tick))
   {
      Print("Unable to get tick data for ", symbol);
      return;
   }

   double price = tick.last;

   if(price <= 0)
   {
      if(tick.bid > 0)
         price = tick.bid;
      else
         price = tick.ask;
   }

   string json =
      "{"
      "\"symbol\":\"" + symbol + "\","
      "\"timeframe\":\"M5\","
      "\"bid\":" + DoubleToString(tick.bid, 8) + ","
      "\"ask\":" + DoubleToString(tick.ask, 8) + ","
      "\"price\":" + DoubleToString(price, 8) + ","
      "\"timestamp\":\"" +
      TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) +
      "\""
      "}";

   string headers =
      "Content-Type: application/json\r\n"
      "X-API-Key: " + BWTradersAPIKey + "\r\n";

   char post[];
   char result[];
   string resultHeaders;

   StringToCharArray(json, post, 0, StringLen(json));

   ResetLastError();

   int response = WebRequest(
      "POST",
      ConnectorURL,
      headers,
      10000,
      post,
      result,
      resultHeaders
   );

   if(response == -1)
   {
      Print(
         "BWTraders connection error for ",
         symbol,
         ". Error: ",
         GetLastError()
      );

      return;
   }

   string responseText = CharArrayToString(result);

   Print(
      "BWTraders response [",
      symbol,
      "] HTTP ",
      response,
      ": ",
      responseText
   );
}
