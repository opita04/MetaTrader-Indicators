/*
File: 3LS+LowBand.mq4
Author: unknown
Source: unknown
Description: 3 Line Strike combined with LowBand/HuskyBands support
Purpose: Provide 3LS signals with low-band confirmation levels
Parameters: See parameter sections below for 3LS and band settings
Version: 1.00
Last Modified: 2025.11.06
Compatibility: MetaTrader 4 (MT4)
*/
//+------------------------------------------------------------------+
#property copyright "Copyright © 2024, Modified"
#property link      "https://www.4xpip.com"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_label1 "Buy Signal"
#property indicator_label2 "Sell Signal"
#property indicator_width1 1
#property indicator_width2 1
#property indicator_color1 clrDarkSeaGreen
#property indicator_color2 clrTomato

enum settings
  {
   settings = 0, //======= Settings =======
  };

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
input settings lss = 0;                                          // ======= ! 3LS (mtf _ alerts) =======
input TIMEFRAMES ls_tf = 0;                                      // Time frame to use
bool ls_show_bearish = true;                               // Show Bearish 3 Line Strike
bool ls_show_bullish = true;                               // Show Bullish 3 Line Strike
double ls_arrow_gap = 0.25;                                // Arrow gap
bool ls_arrow_mtf = true;                                  // Arrow on first mtf bar
bool ls_alertsOn = false;                                  // alertsOn
bool ls_alerts_current = false;                            // alertsOnCurrent
bool ls_alerts_msg = false;                                // alertsMessage
bool ls_alerts_snd = false;                                // alertsSound
bool ls_alerts_mail = false;                               // alertsEmail
bool ls_alerts_noti = false;                               // alertsNotify

input settings husky            = 0;                               // ===== HuskyBands Settings =====
input bool useHuskyBands      = true;                            // Use HuskyBands?
extern ENUM_BAND_TYPE Band_Type = Median_Band;                 // Band Type
extern int HalfLength_input   = 34;                             // Half Length
extern int ma_period          = 4;                              // MA averaging period
extern ENUM_MA_METHOD ma_method = MODE_LWMA;                    // MA averaging method
extern int ATR_Period         = 144;                            // ATR Period
extern int Total_Bars         = 1000;                           // Total Bars
extern double ATR_Multiplier_Band1 = 1.0;                      // ATR Multiplier for Band 1

input settings ogs = 0;                                          // ======= Combo Indicator Arrow =======
input double arrow_gap = 1;                                      // Arrow Gap

input settings als         = 0;                                  // ======= Alerts =======
input bool     allowAlerts = true;                               // Desktop Alerts
input bool     allowMobile = true;                               // Mobile Notification
input bool     allowEmail  = true;                               // Email Notification

double buyBuff[], sellBuff[];
datetime prevBuy, prevSell;
string indicatorName = "Opita 3LS + HuskyBands";
string dir = "";
//opita04\\
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
//--- indicator buffers mapping
   SetIndexStyle(0, DRAW_ARROW, EMPTY);
   SetIndexArrow(0, 233);
   SetIndexBuffer(0, buyBuff);
   SetIndexStyle(1, DRAW_ARROW, EMPTY);
   SetIndexArrow(1, 234);
   SetIndexBuffer(1, sellBuff);

   IndicatorShortName(indicatorName);
//---
   return(0);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
  {
//---
   int counted_bars = IndicatorCounted();
   int limit = Bars - counted_bars;

   for(int i = limit - 1; i >= 1; i--)
     {
      buyBuff[i] = EMPTY_VALUE;
      sellBuff[i] = EMPTY_VALUE;

      int signal_ls = signalLS(i);

      // Only check for BUY signals when 3LS bullish signal and price touches Lower Band 1
      if(signal_ls == OP_BUY && Low[i] <= getHuskyBand_Value(i))
        {
         buyBuff[i] = Low[i] - getPoint() * arrow_gap;

         if(i == 1 && useHuskyBands)
           {
            doAlert("Buy Signal", Symbol() + " " + TFName() + ": Buy Signal - 3LS + HuskyBands Lower Band 1 touch");
           }
        }

      // SELL signals removed - only using lower band for buy signals as requested
     }

   return(0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int signalLS(int index)
  {

   double value_buy = iCustom(Symbol(), Period(), dir + "! 3LS (mtf _ alerts)",
                              ls_tf, ls_show_bearish, ls_show_bullish, ls_arrow_gap, ls_arrow_mtf, ls_alertsOn,
                              ls_alerts_current, ls_alerts_msg, ls_alerts_snd, ls_alerts_mail, ls_alerts_msg,
                              ls_alerts_noti, 0, index);
   double value_sell = iCustom(Symbol(), Period(), dir + "! 3LS (mtf _ alerts)",
                               ls_tf, ls_show_bearish, ls_show_bullish, ls_arrow_gap, ls_arrow_mtf, ls_alertsOn,
                               ls_alerts_current, ls_alerts_msg, ls_alerts_snd, ls_alerts_mail, ls_alerts_msg,
                               ls_alerts_noti, 1, index);

   if(hasValue(value_buy))
      return OP_BUY;
   if(hasValue(value_sell))
      return OP_SELL;

   return -1;
  }
//+------------------------------------------------------------------------+
//| Function to return True if the double has some value, false otherwise  |
//+------------------------------------------------------------------------+
bool hasValue(double val)
  {
   return (val != 0 && val != EMPTY_VALUE);
  }
//+------------------------------------------------------------------+
//| Get HuskyBands Lower Band 1 value                                |
//+------------------------------------------------------------------+
double getHuskyBand_Value(int shift)
  {
   // Buffer 6 = Lower Band 1 (bandDN1)
   return iCustom(Symbol(), Period(), "smLazyTMA HuskyBands_v2.1",
                  Band_Type, HalfLength_input, ma_period, ma_method, ATR_Period, Total_Bars,
                  ATR_Multiplier_Band1, 1.618, 2.236, 2.854, // Additional multipliers (not used)
                  true, true, true, true, true, // Draw options (not used)
                  true, Band1, true, false, 181, 203, 1, clrAqua, clrMagenta, false, 14,
                  6, shift); // Buffer 6 = Lower Band 1, shift
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int getMtfIndex(int tf)
  {
   return (Period() < tf) ? iBarShift(Symbol(), tf, Time[1]) : 1;
  }//+------------------------------------------------------------------+
//| Period to String                                                 |
//+------------------------------------------------------------------+
string TFName()
  {
   switch(Period())
     {
      case PERIOD_M1:
         return("M1");
      case PERIOD_M5:
         return("M5");
      case PERIOD_M15:
         return("M15");
      case PERIOD_M30:
         return("M30");
      case PERIOD_H1:
         return("H1");
      case PERIOD_H4:
         return("H4");
      case PERIOD_D1:
         return("Daily");
      case PERIOD_W1:
         return("Weekly");
      case PERIOD_MN1:
         return("Monthly");
      default:
         return  "";
     }
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
