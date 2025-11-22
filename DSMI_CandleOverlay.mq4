//+------------------------------------------------------------------+
//|                              DSMI_CandleOverlay.mq4              |
//|              DSMI Candle Color Overlay Indicator                |
//|                        Colors candles based on DSMI trend        |
//+------------------------------------------------------------------+
#property copyright "DSMI Candle Overlay"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- DSMI Parameters (must match DSMI.mq4)
extern string s1 = "===== DSMI Parameters =====";
extern string IndicatorName = "DSMI";           // DSMI Indicator Name
extern int    DSMI_Period = 20;                 // DSMI Period (must match DSMI.mq4)
extern int    WeakThreshold = 10;               // Weak Trend Threshold
extern color  BullColor = clrLimeGreen;         // BULLISH Color
extern color  BearColor = clrCrimson;           // BEARISH Color
extern color  NeutralColor = C'128,128,128';    // NEUTRAL Color
extern bool   ShowCandleColor = true;           // Show Candle Colors

//--- Global Variables
string ObjectPrefix = "DSMI_Candle_";
datetime LastBarTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorShortName("DSMI Candle Overlay");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Remove all candle color objects
   for(int i = ObjectsTotal() - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i);
      if(StringFind(objName, ObjectPrefix) == 0)
         ObjectDelete(0, objName);
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(!ShowCandleColor)
      return(rates_total);
   
   if(rates_total < DSMI_Period + 1)
      return(0);
   
   //--- Set arrays as series
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   int limit;
   if(prev_calculated == 0)
      limit = rates_total - 1;
   else
      limit = rates_total - prev_calculated;
   
      //--- Get DSMI values from main indicator
      //--- Buffer 2 = DSMI, Buffer 8 = PlusDS, Buffer 9 = MinusDS
      for(int i = limit; i >= 0; i--)
      {
         double dsmi = iCustom(Symbol(), Period(), IndicatorName, 2, i);
         double plusDS = iCustom(Symbol(), Period(), IndicatorName, 8, i);
         double minusDS = iCustom(Symbol(), Period(), IndicatorName, 9, i);
      
      //--- Check if we have valid data
      if(dsmi == EMPTY_VALUE || plusDS == EMPTY_VALUE || minusDS == EMPTY_VALUE)
         continue;
      
      //--- Determine trend direction and color
      bool isBull = (plusDS > minusDS);
      color candleColor = NeutralColor;
      if(dsmi >= WeakThreshold)
         candleColor = isBull ? BullColor : BearColor;
      
      //--- Create or update colored rectangle behind candle
      string objName = ObjectPrefix + IntegerToString((int)time[i]);
      
      //--- Remove old object if exists
      ObjectDelete(0, objName);
      
      //--- Create colored vertical line behind the candle (doesn't obscure candles)
      datetime barTime = time[i];
      double barHigh = high[i];
      double barLow = low[i];
      
      //--- Use a thin vertical line that extends slightly beyond candle range
      double range = barHigh - barLow;
      if(range == 0) range = Point * 10; // Minimum range
      double lineHigh = barHigh + range * 0.1;
      double lineLow = barLow - range * 0.1;
      
      //--- Create vertical line
      ObjectCreate(0, objName, OBJ_TREND, 0, barTime, lineHigh, barTime, lineLow);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, candleColor);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3); // Thick line for visibility
      ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, objName, OBJPROP_RAY_LEFT, false);
   }
   
   //--- Clean up old objects (keep only last 500 bars)
   if(rates_total > 500)
   {
      datetime oldestTime = time[500];
      for(int i = ObjectsTotal() - 1; i >= 0; i--)
      {
         string objName = ObjectName(0, i);
         if(StringFind(objName, ObjectPrefix) == 0)
         {
            //--- Extract time from object name and check if it's too old
            string timeStr = StringSubstr(objName, StringLen(ObjectPrefix));
            datetime objTime = (datetime)StringToInteger(timeStr);
            if(objTime < oldestTime)
               ObjectDelete(0, objName);
         }
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+

