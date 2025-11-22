//+------------------------------------------------------------------+
//|                                    DSMI.mq4                      |
//|              Directional Strength and Momentum Index             |
//|                        Converted from Pine Script                |
//+------------------------------------------------------------------+
#property copyright "Directional Strength and Momentum Index"
#property version   "1.00"
#property strict
#property indicator_separate_window
#property indicator_buffers 10
#property indicator_plots   2
#property indicator_minimum 0
#property indicator_maximum 100

//--- Plot PlusDS as Histogram
#property indicator_label1  "+DS"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrLimeGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot MinusDS as Histogram
#property indicator_label2  "-DS"
#property indicator_type2   DRAW_HISTOGRAM
#property indicator_color2  clrCrimson
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- DSMI Parameters
extern string s1 = "===== DSMI Parameters =====";
extern int    DSMI_Period = 20;              // DSMI Period

//--- Extreme Zones
extern string s2 = "===== Extreme Zones =====";
extern int    LowerExtreme = 20;             // Lower Extreme Level (1-99)
extern int    UpperExtreme = 80;             // Upper Extreme Level (1-99)
extern color  BandColor = C'84,85,89';       // Extreme Zone Line Color
extern color  OutsideGradientColor = C'84,85,89'; // Gradient Color Outside Zones

//--- Trend Strength Levels
extern string s3 = "===== Trend Strength Levels =====";
extern int    WeakThreshold = 10;            // Weak Trend - below = neutral
extern int    NeutralThreshold = 35;         // Moderate Trend - up to
extern int    StrongThreshold = 45;          // Strong Trend - up to
extern int    OverheatThreshold = 55;        // Overheated Trend - up to

//--- Trend Colors
extern string s4 = "===== Trend Colors =====";
extern color  BullColor = clrLimeGreen;      // BULLISH Color
extern color  BearColor = clrCrimson;        // BEARISH Color
extern color  NeutralColor = C'128,128,128'; // NEUTRAL Color

//--- Entry Signals
extern string s5 = "===== Entry Signals =====";
extern bool   ShowEntrySignal = true;        // Show Entry Signal Highlight
extern int    EntryLevel = 20;               // DSMI Entry Level (1-100)

//--- Candle Coloring
extern string s6 = "===== Candle Coloring =====";
extern bool   ShowCandleColor = true;        // Color Candles by Trend

//--- Trend Strength Table
extern string s7 = "===== Display Settings =====";
extern bool   ShowTrendStrengthTable = true; // Show Trend Strength Table
extern int    TableX = 20;                   // Table X Position
extern int    TableY = 20;                   // Table Y Position

//--- Debug Logging
extern string s8 = "===== Debug Logging =====";
extern bool   EnableDebugLogs = false;       // Enable detailed logging
extern string DebugFileName = "DSMI_Debug.csv"; // CSV file name (MQL4/Files)
extern bool   DebugAppend = true;            // Append to existing log
extern int    DebugLogShift = 1;             // Shift to log (1 = closed bar)

//--- Indicator Buffers
double DSMI_Buffer[];
double PlusDS_HistBuffer[];
double MinusDS_HistBuffer[];
double PlusDM_EMA_Buffer[];
double MinusDM_EMA_Buffer[];
double CandleSize_EMA_Buffer[];
double DX_Buffer[];
double Direction_Buffer[];
double PlusDS_Buffer[];
double MinusDS_Buffer[];

//--- Global Variables
int      DebugFileHandle = INVALID_HANDLE;
datetime LastLoggedBarTime = 0;
bool PreviousIsBull[];
datetime LastBarTime = 0;
string TableName = "DSMI_Table";
int GradientSteps = 30;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Validate inputs
   if(DSMI_Period < 1) DSMI_Period = 20;
   if(LowerExtreme < 1 || LowerExtreme > 99) LowerExtreme = 20;
   if(UpperExtreme < 1 || UpperExtreme > 99) UpperExtreme = 80;
   if(UpperExtreme <= LowerExtreme) UpperExtreme = LowerExtreme + 1;
   if(EntryLevel < 1 || EntryLevel > 100) EntryLevel = 20;
   if(DebugLogShift < 0) DebugLogShift = 0;
   
   //--- Set indicator buffers
   SetIndexBuffer(0, PlusDS_HistBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, MinusDS_HistBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, DSMI_Buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, PlusDM_EMA_Buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, MinusDM_EMA_Buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, CandleSize_EMA_Buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, DX_Buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, Direction_Buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, PlusDS_Buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, MinusDS_Buffer, INDICATOR_CALCULATIONS);
   
   //--- Set indicator labels
   SetIndexLabel(0, "+DS");
   SetIndexLabel(1, "-DS");
   
   //--- Explicitly hide any potential line plots by setting empty labels for calculation buffers
   SetIndexLabel(2, "");  // DSMI_Buffer - hide
   SetIndexLabel(8, "");  // PlusDS_Buffer - hide
   SetIndexLabel(9, "");  // MinusDS_Buffer - hide
   
   //--- Configure histograms
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_HISTOGRAM);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, STYLE_SOLID);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 0);
   
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_HISTOGRAM);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, STYLE_SOLID);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 0);
   
   //--- Set plot colors
   IndicatorShortName("DSMI(" + IntegerToString(DSMI_Period) + ")");
   
   //--- Initialize arrays
   ArraySetAsSeries(DSMI_Buffer, true);
   ArraySetAsSeries(PlusDS_HistBuffer, true);
   ArraySetAsSeries(MinusDS_HistBuffer, true);
   ArraySetAsSeries(PlusDM_EMA_Buffer, true);
   ArraySetAsSeries(MinusDM_EMA_Buffer, true);
   ArraySetAsSeries(CandleSize_EMA_Buffer, true);
   ArraySetAsSeries(DX_Buffer, true);
   ArraySetAsSeries(Direction_Buffer, true);
   ArraySetAsSeries(PlusDS_Buffer, true);
   ArraySetAsSeries(MinusDS_Buffer, true);
   
   //--- Initialize previous direction array
   ArrayResize(PreviousIsBull, Bars);
   ArrayInitialize(PreviousIsBull, false);
   
   //--- Draw horizontal lines for extreme zones
   CreateExtremeZoneLines();
   
   //--- Create trend strength table
   if(ShowTrendStrengthTable)
      CreateTrendStrengthTable();
   
   if(EnableDebugLogs)
      InitializeDebugFile();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Remove horizontal lines
   ObjectDelete(0, "DSMI_UpperExtreme");
   ObjectDelete(0, "DSMI_LowerExtreme");
   ObjectDelete(0, "DSMI_Top");
   ObjectDelete(0, "DSMI_Bottom");
   ObjectDelete(0, "DSMI_FillTop");
   ObjectDelete(0, "DSMI_FillBottom");
   
   //--- Remove table objects
   ObjectDelete(0, TableName + "_BG");
   ObjectDelete(0, TableName + "_Color");
   ObjectDelete(0, TableName + "_Text");
   
   //--- Remove entry signal objects
   for(int i = ObjectsTotal() - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i);
      if(StringFind(objName, "DSMI_EntrySignal_") == 0)
         ObjectDelete(0, objName);
   }
   
   ChartRedraw();
   CloseDebugFile();
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
   {
      limit = rates_total - DSMI_Period - 1;
      ArrayInitialize(DSMI_Buffer, 0.0);
      ArrayInitialize(PlusDS_HistBuffer, 0.0);
      ArrayInitialize(MinusDS_HistBuffer, 0.0);
      ArrayInitialize(PlusDS_Buffer, 0.0);
      ArrayInitialize(MinusDS_Buffer, 0.0);
      ArrayInitialize(PlusDM_EMA_Buffer, 0.0);
      ArrayInitialize(MinusDM_EMA_Buffer, 0.0);
      ArrayInitialize(CandleSize_EMA_Buffer, 0.0);
      ArrayInitialize(DX_Buffer, 0.0);
      ArrayInitialize(Direction_Buffer, 0.0);
   }
   else
      limit = rates_total - prev_calculated;
   
   //--- Calculate DSMI
   for(int i = limit; i >= 0; i--)
   {
      //--- Calculate candle size and direction
      double candleSize = high[i] - low[i];
      int direction = 0;
      if(close[i] > open[i])
         direction = 1;
      else if(close[i] < open[i])
         direction = -1;
      
      Direction_Buffer[i] = direction;
      
      //--- Calculate PlusDM and MinusDM
      double plusDM = (direction > 0) ? candleSize : 0.0;
      double minusDM = (direction < 0) ? candleSize : 0.0;
      
      //--- Calculate EMAs
      if(i == rates_total - DSMI_Period - 1)
      {
         //--- Initialize EMAs with SMA
         double sumPlusDM = 0.0;
         double sumMinusDM = 0.0;
         double sumCandleSize = 0.0;
         
         for(int j = i; j < i + DSMI_Period; j++)
         {
            double cs = high[j] - low[j];
            int dir = (close[j] > open[j]) ? 1 : ((close[j] < open[j]) ? -1 : 0);
            sumPlusDM += (dir > 0) ? cs : 0.0;
            sumMinusDM += (dir < 0) ? cs : 0.0;
            sumCandleSize += cs;
         }
         
         PlusDM_EMA_Buffer[i] = sumPlusDM / DSMI_Period;
         MinusDM_EMA_Buffer[i] = sumMinusDM / DSMI_Period;
         CandleSize_EMA_Buffer[i] = sumCandleSize / DSMI_Period;
      }
      else
      {
         //--- Calculate EMA using previous value
         double alpha = 2.0 / (DSMI_Period + 1.0);
         PlusDM_EMA_Buffer[i] = alpha * plusDM + (1.0 - alpha) * PlusDM_EMA_Buffer[i + 1];
         MinusDM_EMA_Buffer[i] = alpha * minusDM + (1.0 - alpha) * MinusDM_EMA_Buffer[i + 1];
         CandleSize_EMA_Buffer[i] = alpha * candleSize + (1.0 - alpha) * CandleSize_EMA_Buffer[i + 1];
      }
      
      //--- Calculate PlusDS and MinusDS
      double candle_EMA_safe = (CandleSize_EMA_Buffer[i] == 0.0) ? 1e-10 : CandleSize_EMA_Buffer[i];
      double plusDS = 100.0 * PlusDM_EMA_Buffer[i] / candle_EMA_safe;
      double minusDS = 100.0 * MinusDM_EMA_Buffer[i] / candle_EMA_safe;
      
      //--- Store raw DS values
      PlusDS_Buffer[i] = plusDS;
      MinusDS_Buffer[i] = minusDS;

      //--- Determine trend direction
      bool isBull = (plusDS > minusDS);
      
      //--- Set histogram values for display
      if(isBull)
      {
         PlusDS_HistBuffer[i] = plusDS;
         MinusDS_HistBuffer[i] = EMPTY_VALUE;
      }
      else
      {
         PlusDS_HistBuffer[i] = EMPTY_VALUE;
         MinusDS_HistBuffer[i] = minusDS;
      }
      
      //--- Calculate DX
      double sumDS = plusDS + minusDS;
      double DX = (sumDS == 0.0) ? 0.0 : 100.0 * MathAbs(plusDS - minusDS) / sumDS;
      DX_Buffer[i] = DX;
      
      //--- Calculate DSMI (EMA of DX)
      if(i == rates_total - DSMI_Period - 1)
      {
         //--- Initialize DSMI with SMA of DX values
         //--- First, we need to calculate all DX values for the period
         double sumDX = DX; // Current DX
         for(int k = 1; k < DSMI_Period; k++)
         {
            int idx = i + k;
            if(idx < rates_total)
            {
               double cs_k = high[idx] - low[idx];
               int dir_k = (close[idx] > open[idx]) ? 1 : ((close[idx] < open[idx]) ? -1 : 0);
               double pdm_k = (dir_k > 0) ? cs_k : 0.0;
               double mdm_k = (dir_k < 0) ? cs_k : 0.0;
               
               //--- Use temporary EMA values (approximate)
               double tempPlusDM_EMA = PlusDM_EMA_Buffer[i];
               double tempMinusDM_EMA = MinusDM_EMA_Buffer[i];
               double tempCandleSize_EMA = CandleSize_EMA_Buffer[i];
               double tempCandle_EMA_safe = (tempCandleSize_EMA == 0.0) ? 1e-10 : tempCandleSize_EMA;
               double tempPlusDS = 100.0 * tempPlusDM_EMA / tempCandle_EMA_safe;
               double tempMinusDS = 100.0 * tempMinusDM_EMA / tempCandle_EMA_safe;
               double tempSumDS = tempPlusDS + tempMinusDS;
               double tempDX = (tempSumDS == 0.0) ? 0.0 : 100.0 * MathAbs(tempPlusDS - tempMinusDS) / tempSumDS;
               sumDX += tempDX;
            }
         }
         DSMI_Buffer[i] = sumDX / DSMI_Period;
      }
      else if(i < rates_total - DSMI_Period - 1)
      {
         //--- Calculate DSMI as EMA of DX
         double alpha = 2.0 / (DSMI_Period + 1.0);
         DSMI_Buffer[i] = alpha * DX + (1.0 - alpha) * DSMI_Buffer[i + 1];
      }
      else
      {
         //--- For bars before initialization, use current DX
         DSMI_Buffer[i] = DX;
      }
      
      //--- Update colors dynamically for each bar based on trend
      color bullHistColor = NeutralColor;
      color bearHistColor = NeutralColor;
      if(DSMI_Buffer[i] >= WeakThreshold)
      {
         bullHistColor = BullColor;
         bearHistColor = BearColor;
      }
      
      if(i == 0)
      {
         PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 1);
         PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, bullHistColor);
         
         PlotIndexSetInteger(1, PLOT_COLOR_INDEXES, 1);
         PlotIndexSetInteger(1, PLOT_LINE_COLOR, 0, bearHistColor);
      }
      
      //--- For histogram display, we want to show PlusDS as positive bars and MinusDS as negative bars
      //--- But since both are 0-100 range, we'll show them both as positive bars
      //--- Alternatively, we could show the difference or show them overlapping
      //--- For now, keep them as separate histograms with dynamic colors
      
      //--- Handle entry signals (only on new bar)
      if(ShowEntrySignal && i == 0 && time[0] != LastBarTime)
      {
         bool crossAbove = (DSMI_Buffer[0] >= EntryLevel) && (rates_total > 1 && DSMI_Buffer[1] < EntryLevel);
         bool trendChanged = false;
         if(rates_total > 1 && ArraySize(PreviousIsBull) > 1)
            trendChanged = (PreviousIsBull[1] != isBull);
         bool alreadyHighAndTrendChange = (DSMI_Buffer[0] >= EntryLevel) && (rates_total > 1 && DSMI_Buffer[1] >= EntryLevel) && trendChanged;
         bool signalTrigger = (crossAbove || alreadyHighAndTrendChange) && (DSMI_Buffer[0] >= WeakThreshold);
         
         if(signalTrigger && ShowEntrySignal)
         {
            if(isBull)
            {
               //--- Bullish entry signal
               CreateEntrySignal(time[0], BullColor, "BULLISH");
               if(AlertEnabled())
                  Alert("DSMI >= entry level + BULLISH TREND START!");
            }
            else
            {
               //--- Bearish entry signal
               CreateEntrySignal(time[0], BearColor, "BEARISH");
               if(AlertEnabled())
                  Alert("DSMI >= entry level + BEARISH TREND START!");
            }
         }
         
         LastBarTime = time[0];
      }
      
      //--- Store current trend direction
      if(i < ArraySize(PreviousIsBull))
         PreviousIsBull[i] = isBull;
      
      //--- Color candles based on trend
      if(ShowCandleColor && i == 0)
      {
         color barColor = NeutralColor;
         if(DSMI_Buffer[0] >= WeakThreshold)
            barColor = isBull ? BullColor : BearColor;
         
         //--- Note: MT4 doesn't support direct candle coloring in indicators
         //--- This would need to be done via an EA or separate indicator
         //--- For now, we'll just store the color information
      }
   }
   
   //--- Debug logging for closed bar
   if(EnableDebugLogs && DebugFileHandle != INVALID_HANDLE && rates_total > DebugLogShift)
   {
      int logShift = DebugLogShift;
      if(logShift < rates_total)
      {
         datetime barTime = time[logShift];
         if(barTime != LastLoggedBarTime)
         {
            LastLoggedBarTime = barTime;
            double candle = high[logShift] - low[logShift];
            double plusDM_log = (close[logShift] > open[logShift]) ? candle : 0.0;
            double minusDM_log = (close[logShift] < open[logShift]) ? candle : 0.0;
            double plusDS_log = PlusDS_Buffer[logShift];
            double minusDS_log = MinusDS_Buffer[logShift];
            double dx_log = DX_Buffer[logShift];
            double dsmi_log = DSMI_Buffer[logShift];
            bool bull_log = plusDS_log > minusDS_log;
            WriteDebugRow(barTime, logShift, plusDM_log, minusDM_log, plusDS_log, minusDS_log, dx_log, dsmi_log, bull_log);
         }
      }
   }
   
   //--- Update trend strength table
   if(ShowTrendStrengthTable && rates_total > 0)
      UpdateTrendStrengthTable(DSMI_Buffer[0], PlusDS_Buffer[0] > MinusDS_Buffer[0]);
   
   //--- Update extreme zone fills
   UpdateExtremeZoneFills();
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Create extreme zone horizontal lines                             |
//+------------------------------------------------------------------+
void CreateExtremeZoneLines()
{
   //--- Upper extreme line
   ObjectCreate(0, "DSMI_UpperExtreme", OBJ_HLINE, 0, 0, UpperExtreme);
   ObjectSetInteger(0, "DSMI_UpperExtreme", OBJPROP_COLOR, BandColor);
   ObjectSetInteger(0, "DSMI_UpperExtreme", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "DSMI_UpperExtreme", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, "DSMI_UpperExtreme", OBJPROP_BACK, true);
   
   //--- Lower extreme line
   ObjectCreate(0, "DSMI_LowerExtreme", OBJ_HLINE, 0, 0, LowerExtreme);
   ObjectSetInteger(0, "DSMI_LowerExtreme", OBJPROP_COLOR, BandColor);
   ObjectSetInteger(0, "DSMI_LowerExtreme", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "DSMI_LowerExtreme", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, "DSMI_LowerExtreme", OBJPROP_BACK, true);
   
   //--- Top line (100)
   ObjectCreate(0, "DSMI_Top", OBJ_HLINE, 0, 0, 100);
   ObjectSetInteger(0, "DSMI_Top", OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, "DSMI_Top", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, "DSMI_Top", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, "DSMI_Top", OBJPROP_BACK, true);
   
   //--- Bottom line (0)
   ObjectCreate(0, "DSMI_Bottom", OBJ_HLINE, 0, 0, 0);
   ObjectSetInteger(0, "DSMI_Bottom", OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, "DSMI_Bottom", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, "DSMI_Bottom", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, "DSMI_Bottom", OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Update extreme zone fills                                        |
//+------------------------------------------------------------------+
void UpdateExtremeZoneFills()
{
   //--- Remove old fills
   ObjectDelete(0, "DSMI_FillTop");
   ObjectDelete(0, "DSMI_FillBottom");
   
   //--- Create fill above upper extreme
   datetime time1 = iTime(Symbol(), Period(), 0);
   datetime time2 = iTime(Symbol(), Period(), 100);
   
   ObjectCreate(0, "DSMI_FillTop", OBJ_RECTANGLE, 0, time1, 100, time2, UpperExtreme);
   ObjectSetInteger(0, "DSMI_FillTop", OBJPROP_COLOR, OutsideGradientColor);
   ObjectSetInteger(0, "DSMI_FillTop", OBJPROP_BACK, true);
   ObjectSetInteger(0, "DSMI_FillTop", OBJPROP_FILL, true);
   
   //--- Create fill below lower extreme
   ObjectCreate(0, "DSMI_FillBottom", OBJ_RECTANGLE, 0, time1, LowerExtreme, time2, 0);
   ObjectSetInteger(0, "DSMI_FillBottom", OBJPROP_COLOR, OutsideGradientColor);
   ObjectSetInteger(0, "DSMI_FillBottom", OBJPROP_BACK, true);
   ObjectSetInteger(0, "DSMI_FillBottom", OBJPROP_FILL, true);
}

//+------------------------------------------------------------------+
//| Create entry signal highlight                                    |
//+------------------------------------------------------------------+
void CreateEntrySignal(datetime signalTime, color signalColor, string signalType)
{
   string objName = "DSMI_EntrySignal_" + TimeToString(signalTime, TIME_DATE|TIME_MINUTES);
   
   //--- Remove old signal if exists
   ObjectDelete(0, objName);
   
   //--- Create rectangle for signal highlight
   datetime time1 = signalTime;
   datetime time2 = signalTime + PeriodSeconds(Period());
   
   ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time1, 100, time2, 0);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, signalColor);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_FILL, true);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
   
   //--- Set description
   ObjectSetString(0, objName, OBJPROP_TEXT, "DSMI " + signalType + " Entry");
}

//+------------------------------------------------------------------+
//| Create trend strength table                                     |
//+------------------------------------------------------------------+
void CreateTrendStrengthTable()
{
   ObjectDelete(0, TableName);
   
   //--- Create background rectangle
   int x = TableX;
   int y = TableY;
   int width = 150;
   int height = 30;
   
   ObjectCreate(0, TableName + "_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, TableName + "_BG", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, TableName + "_BG", OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, TableName + "_BG", OBJPROP_XSIZE, width);
   ObjectSetInteger(0, TableName + "_BG", OBJPROP_YSIZE, height);
   ObjectSetInteger(0, TableName + "_BG", OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, TableName + "_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, TableName + "_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, TableName + "_BG", OBJPROP_BACK, false);
   
   //--- Create color indicator
   ObjectCreate(0, TableName + "_Color", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, TableName + "_Color", OBJPROP_XDISTANCE, x + 2);
   ObjectSetInteger(0, TableName + "_Color", OBJPROP_YDISTANCE, y + 2);
   ObjectSetInteger(0, TableName + "_Color", OBJPROP_XSIZE, 20);
   ObjectSetInteger(0, TableName + "_Color", OBJPROP_YSIZE, height - 4);
   ObjectSetInteger(0, TableName + "_Color", OBJPROP_BGCOLOR, NeutralColor);
   ObjectSetInteger(0, TableName + "_Color", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, TableName + "_Color", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, TableName + "_Color", OBJPROP_BACK, false);
   
   //--- Create text label
   ObjectCreate(0, TableName + "_Text", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, TableName + "_Text", OBJPROP_XDISTANCE, x + 25);
   ObjectSetInteger(0, TableName + "_Text", OBJPROP_YDISTANCE, y + 8);
   ObjectSetString(0, TableName + "_Text", OBJPROP_TEXT, "WEAK 0");
   ObjectSetInteger(0, TableName + "_Text", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, TableName + "_Text", OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, TableName + "_Text", OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, TableName + "_Text", OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| Update trend strength table                                     |
//+------------------------------------------------------------------+
void UpdateTrendStrengthTable(double dsmi, bool isBull)
{
   if(!ShowTrendStrengthTable)
      return;
   
   string strength = "WEAK";
   color trendColor = NeutralColor;
   
   if(dsmi <= WeakThreshold)
   {
      strength = "WEAK";
      trendColor = NeutralColor;
   }
   else if(dsmi <= NeutralThreshold)
   {
      strength = "MODERATE";
      trendColor = isBull ? BullColor : BearColor;
   }
   else if(dsmi <= StrongThreshold)
   {
      strength = "STRONG";
      trendColor = isBull ? BullColor : BearColor;
   }
   else if(dsmi <= OverheatThreshold)
   {
      strength = "OVERHEATED";
      trendColor = isBull ? BullColor : BearColor;
   }
   else
   {
      strength = "EXTREME";
      trendColor = isBull ? BullColor : BearColor;
   }
   
   //--- Update color indicator
   ObjectSetInteger(0, TableName + "_Color", OBJPROP_BGCOLOR, trendColor);
   
   //--- Update text
   string dsmiText = IntegerToString((int)MathRound(dsmi));
   ObjectSetString(0, TableName + "_Text", OBJPROP_TEXT, strength + " " + dsmiText);
}

//+------------------------------------------------------------------+
//| Get gradient color based on DSMI value                          |
//+------------------------------------------------------------------+
color GetGradientColor(color baseColor, double dsmi, bool isBull)
{
   //--- Normalize DSMI to 0-100
   double normDSMI = MathMax(0, MathMin(100, dsmi));
   
   //--- Calculate gradient index (0 to GradientSteps-1)
   int idx = (int)MathRound(normDSMI / 100.0 * (GradientSteps - 1));
   idx = MathMin(MathMax(idx, 0), GradientSteps - 1);
   
   //--- Calculate transparency (80% to 0%)
   double transparency = 80.0 - (idx / (double)(GradientSteps - 1)) * 80.0;
   
   //--- Extract RGB components
   int r = (baseColor >> 16) & 0xFF;
   int g = (baseColor >> 8) & 0xFF;
   int b = baseColor & 0xFF;
   
   //--- Apply transparency (simplified - MT4 doesn't support alpha directly)
   //--- We'll use a lighter shade instead
   int alpha = (int)(255 * (1.0 - transparency / 100.0));
   r = (int)(r * (1.0 - transparency / 100.0));
   g = (int)(g * (1.0 - transparency / 100.0));
   b = (int)(b * (1.0 - transparency / 100.0));
   
   return((color)((r << 16) | (g << 8) | b));
}

//+------------------------------------------------------------------+
//| Check if alerts are enabled                                     |
//+------------------------------------------------------------------+
bool AlertEnabled()
{
   return(true); // Always enabled for now, can be made configurable
}

//+------------------------------------------------------------------+
//| Debug logging helpers                                            |
//+------------------------------------------------------------------+
void InitializeDebugFile()
{
   CloseDebugFile();
   if(!EnableDebugLogs)
      return;
   
   int flags = FILE_CSV | FILE_WRITE | FILE_SHARE_READ | FILE_READ;
   
   DebugFileHandle = FileOpen(DebugFileName, flags);
   if(DebugFileHandle == INVALID_HANDLE)
   {
      Print("DSMI: failed to open debug file ", DebugFileName, " (error ", GetLastError(), ")");
      EnableDebugLogs = false;
      return;
   }
   
   bool needHeader = !DebugAppend || FileSize(DebugFileHandle) == 0;
   if(!DebugAppend)
      FileSeek(DebugFileHandle, 0, SEEK_SET);
   else
      FileSeek(DebugFileHandle, 0, SEEK_END);
   
   if(needHeader)
   {
      FileWrite(DebugFileHandle, "time", "shift", "plusDM", "minusDM", "plusDS", "minusDS", "DX", "DSMI", "isBull");
   }
   FileSeek(DebugFileHandle, 0, SEEK_END);
}

void CloseDebugFile()
{
   if(DebugFileHandle != INVALID_HANDLE)
   {
      FileClose(DebugFileHandle);
      DebugFileHandle = INVALID_HANDLE;
   }
}

void WriteDebugRow(datetime barTime,
                   int shift,
                   double plusDM,
                   double minusDM,
                   double plusDS,
                   double minusDS,
                   double dx,
                   double dsmi,
                   bool isBull)
{
   if(DebugFileHandle == INVALID_HANDLE)
      return;
   FileWrite(DebugFileHandle,
             TimeToString(barTime, TIME_DATE|TIME_SECONDS),
             shift,
             DoubleToString(plusDM, 6),
             DoubleToString(minusDM, 6),
             DoubleToString(plusDS, 6),
             DoubleToString(minusDS, 6),
             DoubleToString(dx, 6),
             DoubleToString(dsmi, 6),
             isBull ? "bull" : "bear");
   FileFlush(DebugFileHandle);
}

//+------------------------------------------------------------------+

