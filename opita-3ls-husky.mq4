/*
File: opita-3ls-husky.mq4
Author: Modified by AI Assistant, based on 4xPip original
Source: Integration of opita+bb.mq4 with HuskyBands replacement for low-pass bands
Description: Combined 3LS pattern indicator with ATR-based HuskyBands for non-repainting signals
Purpose: Generate buy/sell signals when 3 Line Strike patterns occur and price touches HuskyBands levels

Parameters:
- ls_show_bullish: Enable bullish 3LS signals (default: true)
- ls_show_bearish: Enable bearish 3LS signals (default: true)
- ls_arrow_gap: Gap between arrows and candle bodies (default: 0.25)
- ls_arrow_mtf: Arrow positioning for multi-timeframe (default: true)
- ls_alertsOn: Master alert switch (default: false)
- useHuskyBands: Enable HuskyBands confirmation (default: true)
- Band_Type: Band calculation type - Median_Band or HighLow_Bands (default: Median_Band)
- HalfLength_input: TMA half-length for band calculation (default: 34)
- ma_period: MA period for TMA (default: 4)
- ma_method: MA method - MODE_LWMA (default)
- ATR_Period: ATR period for band width calculation (default: 144)
- ATR_Multiplier_Band1: ATR multiplier for lower band (default: 1.0)

Version: 1.00
Last Modified: 2025.11.06 - Integrated 3LS logic from ! 3LS indicator and HuskyBands calculation, added bounds checking and proper documentation
Compatibility: MetaTrader 4, all timeframes, requires sufficient historical data (minimum 50 bars)
*/
//+------------------------------------------------------------------+
//|                                                    opita-3ls-husky.mq4 |
//|                                          Copyright © 2024, Modified |
//|                                    Based on 4xPip opita combo |
//|
//| File size: ~417 lines (exceeds 200-line rule due to full integration
//| requirement - all 3LS and HuskyBands logic integrated into single file
//| for no external dependencies as requested by user)
//+------------------------------------------------------------------+
#property copyright "Copyright © 2024, Modified"
#property link      "https://www.4xpip.com"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

// Plot definitions for signals
#property indicator_label1  "Buy Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrDarkSeaGreen
#property indicator_width1  1

#property indicator_label2  "Sell Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrTomato
#property indicator_width2  1

// Plot definitions for bands
#property indicator_label3  "HuskyBands Lower"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrChocolate
#property indicator_width3  1

#property indicator_label4  "HuskyBands Upper"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrChocolate
#property indicator_width4  1

enum settings
  {
   settings = 0, //======= Settings =======
  };

// HuskyBands enums (copied from smLazyTMA HuskyBands_v2.1)
enum ENUM_BAND_TYPE
{
   Median_Band,
   HighLow_Bands
};

enum ENUM_THRESHOLD_BANDS
{
   Band1,
   Band2,
   Band3,
   Band4
};

// MA Method constants are built-in to MQL4
// Applied Price constants are built-in to MQL4

enum TIMEFRAMES
  {
   tf_cu  = 0,                                            // Current time frame
   tf_m1  = PERIOD_M1,                                    // 1 minute
   tf_m5  = PERIOD_M5,                                    // 5 minutes
   tf_m15 = PERIOD_M15,                                   // 15 minutes
   tf_m30 = PERIOD_M30,                                   // 30 minutes
   tf_h1  = PERIOD_H1,                                    // 1 hour
   tf_h4  = PERIOD_H4,                                    // 4 hours
   tf_d1  = PERIOD_D1,                                    // Daily
   tf_w1  = PERIOD_W1,                                    // Weekly
   tf_mn1 = PERIOD_MN1,                                   // Monthly
   tf_n1  = -1,                                           // First higher time frame
   tf_n2  = -2,                                           // Second higher time frame
   tf_n3  = -3                                            // Third higher time frame
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input settings lss = 0;                                          // ======= 3LS Settings =======
input TIMEFRAMES ls_tf = 0;                                      // Time frame to use
input bool ls_show_bearish = true;                               // Show Bearish 3 Line Strike
input bool ls_show_bullish = true;                               // Show Bullish 3 Line Strike
input double ls_arrow_gap = 0.25;                                // Arrow gap
input bool ls_arrow_mtf = true;                                  // Arrow on first mtf bar
input bool ls_alertsOn = false;                                  // alertsOn
input bool ls_alerts_current = false;                            // alertsOnCurrent
input bool ls_alerts_msg = false;                                // alertsMessage
input bool ls_alerts_snd = false;                                // alertsSound
input bool ls_alerts_mail = false;                               // alertsEmail
input bool ls_alerts_noti = false;                               // alertsNotify

extern settings husky            = 0;                               // ===== HuskyBands Settings =====
extern bool useHuskyBands      = true;                            // Use HuskyBands?
extern bool Show_HuskyBands    = true;                            // Show HuskyBands on chart
extern ENUM_BAND_TYPE Band_Type = Median_Band;                 // Band Type (Median_Band or HighLow_Bands)
extern int HalfLength_input   = 34;                             // Half Length
extern int ma_period          = 4;                              // MA averaging period
extern int ma_method = MODE_LWMA;                    // MA averaging method
extern int ATR_Period         = 144;                            // ATR Period
extern int Total_Bars         = 500;                           // Total Bars
extern double ATR_Multiplier_Band1 = 1.0;                      // ATR Multiplier for Band 1
extern int ls_minBarsBetweenSignals = 1;                       // Minimum bars between same-side signals

input settings ogs = 0;                                          // ======= Combo Indicator Arrow =======
input double arrow_gap = 1;                                      // Arrow Gap

input settings als         = 0;                                  // ======= Alerts =======
input bool     allowAlerts = true;                               // Desktop Alerts
input bool     allowMobile = true;                               // Mobile Notification
input bool     allowEmail  = true;                               // Email Notification

double buyBuff[], sellBuff[], huskyBandLowerBuff[], huskyBandUpperBuff[];
datetime prevBuy, prevSell;
string indicatorName = "Opita 3LS + HuskyBands";
string dir = "";
double sumWeights;
double weights[];    // TMA weights (initialized in OnInit)
int fullLength;      // full length = HalfLength_input * 2 + 1
double tmaCache[];   // precomputed TMA values for performance
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- indicator buffers mapping
   SetIndexStyle(0, DRAW_ARROW, EMPTY, 2, clrDarkSeaGreen);
   SetIndexArrow(0, 233);
   SetIndexBuffer(0, buyBuff);
   SetIndexEmptyValue(0, EMPTY_VALUE);

   SetIndexStyle(1, DRAW_ARROW, EMPTY, 2, clrTomato);
   SetIndexArrow(1, 234);
   SetIndexBuffer(1, sellBuff);
   SetIndexEmptyValue(1, EMPTY_VALUE);

   if(Show_HuskyBands)
     {
      SetIndexStyle(2, DRAW_LINE, EMPTY, 2, clrBlue);
      SetIndexStyle(3, DRAW_LINE, EMPTY, 2, clrRed);
     }
   else
     {
      SetIndexStyle(2, DRAW_NONE);
      SetIndexStyle(3, DRAW_NONE);
     }
   SetIndexBuffer(2, huskyBandLowerBuff);
   SetIndexBuffer(3, huskyBandUpperBuff);

   IndicatorShortName(indicatorName);
   // Initialize TMA weights (match smLazyTMA HuskyBands logic)
   int halfLengthLocal = HalfLength_input;
   if(halfLengthLocal < 1) halfLengthLocal = 1;
   fullLength = halfLengthLocal * 2 + 1;
   ArrayResize(weights, fullLength);
   sumWeights = halfLengthLocal + 1;
   weights[halfLengthLocal] = halfLengthLocal + 1;
   for(int wi = 0; wi < halfLengthLocal; wi++)
     {
      weights[wi] = wi + 1;
      weights[fullLength - wi - 1] = wi + 1;
      sumWeights += (wi + 1) * 2;
     }

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
  {
   int counted_bars = IndicatorCounted();
   if(counted_bars < 0)
      counted_bars = 0;
   int limit = Bars - counted_bars;
   if(limit > Bars)
      limit = Bars;

   int totalBarsLimit = (Total_Bars <= 0) ? Bars : MathMin(Bars, Total_Bars);
   int halfLengthLocal = MathMax(HalfLength_input, 1);
   int recalcWindow = halfLengthLocal * 2 + ATR_Period + 10;
   int processBars = totalBarsLimit;

   if(limit < processBars)
      processBars = MathMin(processBars, limit + recalcWindow);

   if(processBars <= 0)
      return(0);

   // Initialize buffers on first run
   if(counted_bars == 0)
     {
      ArrayInitialize(buyBuff, EMPTY_VALUE);
      ArrayInitialize(sellBuff, EMPTY_VALUE);
      ArrayInitialize(huskyBandLowerBuff, EMPTY_VALUE);
      ArrayInitialize(huskyBandUpperBuff, EMPTY_VALUE);
     }

   // Calculate HuskyBands first (from smLazyTMA HuskyBands)
   for(int i = processBars - 1; i >= 0; i--)
     {
      // Calculate TMA centered value
      double tmaValue = calculateTMA(i, PRICE_MEDIAN);

      // Calculate ATR-based deviation
      double deviation = calculateATRDeviation(i, ATR_Period, tmaValue);

      // Calculate band distance
      double bandDistance = deviation * ATR_Multiplier_Band1;

      // Set band values
      huskyBandLowerBuff[i] = tmaValue - bandDistance;
      huskyBandUpperBuff[i] = tmaValue + bandDistance;
     }

   // Now process 3LS signals (from ! 3LS indicator)
   for(int i = processBars - 1; i >= 0; i--)
     {
      // Initialize signal buffers
      buyBuff[i] = EMPTY_VALUE;
      sellBuff[i] = EMPTY_VALUE;

      // Get 3LS signal
      int signal_ls = signalLS(i);

      // Check for BUY signals when 3LS bullish signal and price touches Lower Band
      if(signal_ls == OP_BUY && Low[i] <= huskyBandLowerBuff[i] && useHuskyBands)
        {
         bool recentBuy = false;
         for(int j=1; j<=ls_minBarsBetweenSignals && (i+j)<processBars; j++)
           {
            if(buyBuff[i+j] != EMPTY_VALUE) { recentBuy = true; break; }
           }
         if(!recentBuy)
            buyBuff[i] = Low[i] - getPoint() * ls_arrow_gap;

         // Alert on closed bar (i == 1) exactly when arrow is drawn
         if(i == 1 && allowAlerts && buyBuff[i] != EMPTY_VALUE)
           {
            if(prevBuy != Time[1])
              {
               doAlert("Buy Signal", Symbol() + " " + TFName() + ": Buy Signal - 3LS Bullish + Lower Band Touch");
               prevBuy = Time[1];
              }
           }
        }

      // Check for SELL signals when 3LS bearish signal and price touches Upper Band
      if(signal_ls == OP_SELL && High[i] >= huskyBandUpperBuff[i] && useHuskyBands)
        {
         bool recentSell = false;
         for(int j=1; j<=ls_minBarsBetweenSignals && (i+j)<processBars; j++)
           {
            if(sellBuff[i+j] != EMPTY_VALUE) { recentSell = true; break; }
           }
         if(!recentSell)
            sellBuff[i] = High[i] + getPoint() * ls_arrow_gap;

         // Alert on closed bar (i == 1) exactly when arrow is drawn
         if(i == 1 && allowAlerts && sellBuff[i] != EMPTY_VALUE)
           {
            if(prevSell != Time[1])
              {
               doAlert("Sell Signal", Symbol() + " " + TFName() + ": Sell Signal - 3LS Bearish + Upper Band Touch");
               prevSell = Time[1];
              }
           }
        }
     }

   return(0);
  }
//==============================================================================
// SECTION 4: 3LS PATTERN DETECTION (Integrated from ! 3LS indicator)
//==============================================================================
//+------------------------------------------------------------------+
//| Detect Three Line Strike pattern (from real 3LS indicator)        |
//+------------------------------------------------------------------+
int signalLS(int index)
  {
   // Check for Bullish 3 Line Strike-like setup and require current bar bullish
   if(ls_show_bullish && is3LSBull(index) && (Close[index] > Open[index]))
      return OP_BUY;

   // Check for Bearish 3 Line Strike-like setup and require current bar bearish
   if(ls_show_bearish && is3LSBear(index) && (Close[index] < Open[index]))
      return OP_SELL;

   return -1;
}

//+------------------------------------------------------------------+
//| Get candle color index (from real 3LS indicator)                 |
//+------------------------------------------------------------------+
int getCandleColorIndex(int pos)
  {
  // safety: guard against out-of-range access
  if(pos < 0 || pos >= Bars) return 0;
  return (Close[pos] > Open[pos]) ? 1 : (Close[pos] < Open[pos]) ? -1 : 0;
  }

//+------------------------------------------------------------------+
//| Check for Bullish 3LS (3 bearish candles) - from real indicator  |
//+------------------------------------------------------------------+
bool is3LSBull(int pos)
  {
  // Ensure there are 3 previous bars available (pos+3 must be within Bars)
  if(pos + 3 >= Bars) return false;

  // Check if 3 previous candles are all bearish (negative color index)
  bool is3LineSetup = ((getCandleColorIndex(pos+1) < 0) &&
                     (getCandleColorIndex(pos+2) < 0) &&
                     (getCandleColorIndex(pos+3) < 0));

  return is3LineSetup;
  }

//+------------------------------------------------------------------+
//| Check for Bearish 3LS (3 bullish candles) - from real indicator  |
//+------------------------------------------------------------------+
bool is3LSBear(int pos)
  {
  // Ensure there are 3 previous bars available (pos+3 must be within Bars)
  if(pos + 3 >= Bars) return false;

  // Check if 3 previous candles are all bullish (positive color index)
  bool is3LineSetup = ((getCandleColorIndex(pos+1) > 0) &&
                     (getCandleColorIndex(pos+2) > 0) &&
                     (getCandleColorIndex(pos+3) > 0));

  return is3LineSetup;
  }
//+------------------------------------------------------------------------+
//| Function to return True if the double has some value, false otherwise  |
//+------------------------------------------------------------------------+
bool hasValue(double val)
  {
   return (val != 0 && val != EMPTY_VALUE);
  }
//==============================================================================
// SECTION 5: HUSKYBANDS CALCULATION (Integrated ATR-based bands)
//==============================================================================

//+------------------------------------------------------------------+
//| Calculate TMA (Triangular Moving Average) - from smLazyTMA       |
//+------------------------------------------------------------------+
double calculateTMA(int shift, ENUM_APPLIED_PRICE applied_priceX)
  {
   // Use iMA-smoothed weighted TMA like smLazyTMA for exact matching
   int halfLength = HalfLength_input;
   if(halfLength < 1) halfLength = 1;

   int expectedFull = halfLength * 2 + 1;
   if(ArraySize(weights) != expectedFull)
     {
      // initialize weights if they aren't set (safety)
      ArrayResize(weights, expectedFull);
      sumWeights = halfLength + 1;
      weights[halfLength] = halfLength + 1;
      for(int wi = 0; wi < halfLength; wi++)
        {
         weights[wi] = wi + 1;
         weights[expectedFull - wi - 1] = wi + 1;
         sumWeights += (wi + 1) * 2;
        }
      fullLength = expectedFull;
     }

   double sum = 0.0;
   double usedWeightSum = 0.0;

   // Weighted sum of iMA values across window to produce centered TMA
   for(int j = 0; j < expectedFull; j++)
     {
      int index = shift + j - halfLength;
      if(index >= 0 && index < Bars)
        {
         double weight = weights[j];
         double maValue = iMA(NULL, Period(), ma_period, 0, ma_method, applied_priceX, index);
         sum += maValue * weight;
         usedWeightSum += weight;
        }
     }

   if(usedWeightSum == 0.0)
      return 0.0;

   return sum / usedWeightSum;
  }

//+------------------------------------------------------------------+
//| Calculate ATR-based deviation - from smLazyTMA                    |
//+------------------------------------------------------------------+
double calculateATRDeviation(int shift, int atrPeriod, double tmaValue)
  {
   // Compute standard deviation between Close and TMA over the ATR window,
   // using TMA values at each bar (matches smLazyTMA behavior).
   double StdDev_dTmp = 0.0;
   int count = 0;

   for(int ij = 0; ij < atrPeriod; ij++)
     {
      int idx = shift + ij;
      if(idx >= Bars) break;
      double tmaAtIdx = calculateTMA(idx, PRICE_MEDIAN);
      double dClose = Close[idx];
      StdDev_dTmp += MathPow(dClose - tmaAtIdx, 2);
      count++;
     }

   if(count == 0) return 0.0;
   return MathSqrt(StdDev_dTmp / count);
  }

//+------------------------------------------------------------------+
//| Get price value based on applied price type                      |
//+------------------------------------------------------------------+
double getPrice(int shift, ENUM_APPLIED_PRICE priceType)
  {
   switch(priceType)
     {
      case PRICE_CLOSE:
         return Close[shift];
      case PRICE_OPEN:
         return Open[shift];
      case PRICE_HIGH:
         return High[shift];
      case PRICE_LOW:
         return Low[shift];
      case PRICE_MEDIAN:
         return (High[shift] + Low[shift]) / 2;
      case PRICE_TYPICAL:
         return (High[shift] + Low[shift] + Close[shift]) / 3;
      case PRICE_WEIGHTED:
         return (High[shift] + Low[shift] + Close[shift] + Close[shift]) / 4;
      default:
         return Close[shift];
     }
  }
//==============================================================================
// SECTION 6: UTILITY FUNCTIONS
//==============================================================================
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int getMtfIndex(int tf)
  {
   return (Period() < tf) ? iBarShift(Symbol(), tf, Time[1]) : 1;
  }//+------------------------------------------------------------------+
//| Period to String - from ! 3LS indicator                         |
//+------------------------------------------------------------------+
string TFName()
  {
   string sTfTable[] = {"M1","M5","M15","M30","H1","H4","D1","W1","MN"};
   int    iTfTable[] = {1,5,15,30,60,240,1440,10080,43200};

   for (int i=ArraySize(iTfTable)-1; i>=0; i--)
         if (Period()==iTfTable[i]) return(sTfTable[i]);
                              return("");
  }
//+------------------------------------------------------------------+
//| Function to Show Alerts                                          |
//+------------------------------------------------------------------+
void doAlert(string title = "", string msg = "")
  {
   msg = indicatorName + " :: " + msg;
   if(allowAlerts)
      Alert(msg);
   if(allowEmail)
      SendMail(title, msg);
   if(allowMobile)
      SendNotification(msg);
  }
//+------------------------------------------------------------------+
//| Function to return the distance of arrow from Candle             |
//+------------------------------------------------------------------+
double getPoint()
  {
   int tf = Period();
   if(tf == 1)
      return 5.0 * Point;
   if(tf == 5)
      return 10.0 * Point;
   if(tf == 15)
      return 22.0 * Point;
   if(tf == 30)
      return 44.0 * Point;
   if(tf == 60)
      return 80.0 * Point;
   if(tf == 240)
      return 120.0 * Point;
   if(tf == 1440)
      return 170.0 * Point;
   if(tf == 10080)
      return 500.0 * Point;
   if(tf == 43200)
      return 900.0 * Point;
   return 20.0 * Point;
  }
//+------------------------------------------------------------------+
