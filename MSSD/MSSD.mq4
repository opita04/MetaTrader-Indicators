//+------------------------------------------------------------------+
//|                                                         MSSD.mq4 |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Antigravity"
#property link      "https://www.mql5.com"
#property version   "1.06"
#property strict
#property indicator_chart_window

//--- Visibility Settings ---
input string Sep1 = "=== Visibility Settings ==="; // .
input bool   Show_M1  = true;
input bool   Show_M5  = true;
input bool   Show_M15 = true;
input bool   Show_H1  = true;

//--- Color Settings ---
input string Sep2 = "=== Color Settings ==="; // .
input color  Color_Up   = clrLime; // Green for Lows (Up)
input color  Color_Down = clrRed;  // Red for Highs (Down)

//--- Size Settings ---
input string SepSize = "=== Size Settings ==="; // .
input int    Size_M1  = 1;
input int    Size_M5  = 2;
input int    Size_M15 = 3;
input int    Size_H1  = 4;

//--- Gap Settings ---
input string Sep3 = "=== Gap Settings (Points) ==="; // .
input int    Gap_M1_Points = 2;
input int    Gap_M5_Points = 12;
input int    Gap_M15_Points = 2000;
input int    Gap_H1_Points = 4000;

//--- Icon Settings ---
input string Sep4 = "=== Icon Settings (Wingdings) ==="; // .
input int    Icon_M1  = 159;
input int    Icon_M5  = 164;
input int    Icon_M15 = 171;
input int    Icon_H1  = 181;

//--- Alert Settings ---
input string Sep5 = "=== Alert Settings ==="; // .
input bool   Alert_M1 = false;
input bool   Alert_M5 = false;
input bool   Alert_M15 = false;
input bool   Alert_H1 = false;
input bool   Use_Push = false; // Send Mobile Notifications

//--- Sequence Alerts ---
input string SepSeq = "=== Sequence Alerts ==="; // .
input bool   Alert_Seq_M5_M1  = false;
input bool   Alert_Seq_M15_M1 = false;

//--- Line Settings ---
input string Sep6 = "=== Line Settings ==="; // .
input bool   Show_Lines = true;
input int    Line_Length = 10;

//--- Constants for Visuals
#define ARROW_SIZE 1

//--- Arrays to store state to avoid full recalculation every tick
datetime LastTime_M1 = 0;
datetime LastTime_M5 = 0;
datetime LastTime_M15 = 0;
datetime LastTime_H1 = 0;

//--- Alert State
datetime LastAlertTime_M1 = 0;
datetime LastAlertTime_M5 = 0;
datetime LastAlertTime_M15 = 0;
datetime LastAlertTime_H1 = 0;

//--- Trend State (1=Up, -1=Down)
int Trend_M1 = 0;
int Trend_M5 = 0;
int Trend_M15 = 0;
int Trend_H1 = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "MSSD_");
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
   //--- Run logic for each timeframe
   //--- Run logic for each timeframe (Higher TFs first to establish trend for sequences)
   // Only calculate/show if the timeframe is >= current chart timeframe
   if(Show_H1 && PERIOD_H1 >= Period())   CalculateFrame(PERIOD_H1, "H1", Size_H1, LastTime_H1, Gap_H1_Points, Alert_H1, LastAlertTime_H1, Icon_H1, Trend_H1);
   if(Show_M15 && PERIOD_M15 >= Period()) CalculateFrame(PERIOD_M15, "M15", Size_M15, LastTime_M15, Gap_M15_Points, Alert_M15, LastAlertTime_M15, Icon_M15, Trend_M15);
   if(Show_M5 && PERIOD_M5 >= Period())   CalculateFrame(PERIOD_M5, "M5", Size_M5, LastTime_M5, Gap_M5_Points, Alert_M5, LastAlertTime_M5, Icon_M5, Trend_M5);
   if(Show_M1 && PERIOD_M1 >= Period())   CalculateFrame(PERIOD_M1, "M1", Size_M1, LastTime_M1, Gap_M1_Points, Alert_M1, LastAlertTime_M1, Icon_M1, Trend_M1);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//| MSSD Logic for a specific timeframe                              |
//+------------------------------------------------------------------+
void CalculateFrame(int tf, string tf_label, int size, datetime &last_calc_time, int gap_points, bool alerts, datetime &last_alert_time, int icon_code, int &trend_state)
{
   int bars = iBars(NULL, tf);
   
   // Find the bar index corresponding to the last calculated time
   int start_bar = iBarShift(NULL, tf, last_calc_time);
   
   // If last_calc_time is 0, calculate all history
   if(last_calc_time == 0) start_bar = bars - 1;
   
   int lookback = 2000; // Recalculate last 2000 bars of the timeframe
   if (start_bar > lookback) start_bar = lookback;
   if (start_bar < 1) start_bar = 1; // Always keep at least 1 bar closed

   // Initial State
   int i = bars - 1;
   
   int trend = 1;
   double init_O = iOpen(NULL, tf, i);
   double init_C = iClose(NULL, tf, i);
   double body_high_init = MathMax(init_O, init_C);
   double body_low_init = MathMin(init_O, init_C);

   double conf_level = body_low_init;
   
   // Logic Peak (Body)
   double peak = body_high_init;
   // Visual Peak (Wick)
   double peak_visual = iHigh(NULL, tf, i);
   int peak_visual_idx = i;
   
   // Logic Valley (Body)
   double valley = body_low_init;
   // Visual Valley (Wick)
   double valley_visual = iLow(NULL, tf, i);
   int valley_visual_idx = i;
   
   // Loop forward
   for(i = bars - 2; i >= 1; i--)
     {
      double O = iOpen(NULL, tf, i);
      double H = iHigh(NULL, tf, i); 
      double L = iLow(NULL, tf, i);  
      double C = iClose(NULL, tf, i);
      datetime T = iTime(NULL, tf, i);
      
      double body_high = MathMax(O, C);
      double body_low = MathMin(O, C);
      
      bool is_bull = (C > O);
      bool is_bear = (C < O);
      
      if (trend == 1)
      {
         // Track Logic Peak (Body)
         if (body_high >= peak) {
            peak = body_high;
         }
         // Track Visual Peak (Wick) - For Icon Placement
         if (H >= peak_visual) {
            peak_visual = H;
            peak_visual_idx = i;
         }
         
         // Update Confirmation (Body Low of Bullish Candle)
         if (is_bull) {
            conf_level = body_low; // which is O
         }
         
         // Check Break (Close below Confirmation)
         if (C < conf_level) {
            trend = -1;
            // Trend changed to Down. The previous Peak is a Valid High.
            // Use Visual Peak (Wick) for the signal
            CreateSignal(tf, peak_visual_idx, peak_visual, 1, size, gap_points, icon_code); // 1 = High
            
            // Alert Logic
            if (i == 1 && last_alert_time != T) {
               // 1. Standard Alert
               if (alerts) {
                  string msg = "MSSD " + tf_label + " Bearish Break! Valid High Formed.";
                  Alert(msg);
                  if(Use_Push) SendNotification(msg);
               }
               
               // 2. Sequence Alert (M1 only)
               if (tf == PERIOD_M1) {
                  // Debug Print
                  Print("MSSD Debug: M1 Bearish Signal at ", TimeToString(T), ". Trend_M5=", Trend_M5, ", Trend_M15=", Trend_M15, ", Alert_Seq_M5_M1=", Alert_Seq_M5_M1);
                  
                  if (Alert_Seq_M5_M1 && Trend_M5 == -1) {
                     string msg = "MSSD Sequence: M5 Down -> M1 Down";
                     Alert(msg);
                     if(Use_Push) SendNotification(msg);
                     CreateSequenceArrow(T, H, 1, 218, Color_Down, gap_points, "M5");
                  }
                  if (Alert_Seq_M15_M1 && Trend_M15 == -1) {
                     string msg = "MSSD Sequence: M15 Down -> M1 Down";
                     Alert(msg);
                     if(Use_Push) SendNotification(msg);
                     CreateSequenceArrow(T, H, 1, 222, Color_Down, gap_points, "M15");
                  }
               }
               
               // Mark alert as sent for this bar
               last_alert_time = T;
            }
            
            // Reset for Downtrend
            valley = body_low;
            valley_visual = L;
            valley_visual_idx = i;
            
            conf_level = body_high; 
            if (is_bear) conf_level = body_high; 
         }
      }
      else // trend == -1
      {
         // Track Logic Valley (Body)
         if (body_low <= valley) {
            valley = body_low;
         }
         // Track Visual Valley (Wick) - For Icon Placement
         if (L <= valley_visual) {
            valley_visual = L;
            valley_visual_idx = i;
         }
         
         // Update Confirmation (Body High of Bearish Candle)
         if (is_bear) {
            conf_level = body_high; 
         }
         
         // Check Break (Close above Confirmation)
         if (C > conf_level) {
            trend = 1;
            // Trend changed to Up. The previous Valley is a Valid Low.
            // Use Visual Valley (Wick) for the signal
            CreateSignal(tf, valley_visual_idx, valley_visual, -1, size, gap_points, icon_code); // -1 = Low
            
            // Alert
            // Alert Logic
            if (i == 1 && last_alert_time != T) {
               // 1. Standard Alert
               if (alerts) {
                  string msg = "MSSD " + tf_label + " Bullish Break! Valid Low Formed.";
                  Alert(msg);
                  if(Use_Push) SendNotification(msg);
               }
               
               // 2. Sequence Alert (M1 only)
               if (tf == PERIOD_M1) {
                  // Debug Print
                  Print("MSSD Debug: M1 Bullish Signal at ", TimeToString(T), ". Trend_M5=", Trend_M5, ", Trend_M15=", Trend_M15, ", Alert_Seq_M5_M1=", Alert_Seq_M5_M1);
                  
                  if (Alert_Seq_M5_M1 && Trend_M5 == 1) {
                     string msg = "MSSD Sequence: M5 Up -> M1 Up";
                     Alert(msg);
                     if(Use_Push) SendNotification(msg);
                     CreateSequenceArrow(T, L, -1, 217, Color_Up, gap_points, "M5");
                  }
                  if (Alert_Seq_M15_M1 && Trend_M15 == 1) {
                     string msg = "MSSD Sequence: M15 Up -> M1 Up";
                     Alert(msg);
                     if(Use_Push) SendNotification(msg);
                     CreateSequenceArrow(T, L, -1, 221, Color_Up, gap_points, "M15");
                  }
               }
               
               // Mark alert as sent for this bar
               last_alert_time = T;
            }
            
            // Reset for Uptrend
            peak = body_high;
            peak_visual = H;
            peak_visual_idx = i;
            
            conf_level = body_low; 
            if (is_bull) conf_level = body_low; 
         }
      }
     }
     
   last_calc_time = iTime(NULL, tf, 0);
   trend_state = trend; // Update global trend state
}

//+------------------------------------------------------------------+
//| Create Signal Object                                             |
//+------------------------------------------------------------------+
void CreateSignal(int tf, int bar_idx, double price, int type, int size, int gap_points, int icon_code)
{
   // 1. Find Exact Time
   // The bar_idx is relative to the timeframe 'tf'.
   datetime bar_time = iTime(NULL, tf, bar_idx);
   datetime exact_time = bar_time;
   
   // If we are on a lower timeframe (e.g. M1) and the signal is from M15,
   // we want to find the M1 bar that actually hit that High/Low.
   if (Period() < tf)
   {
      int m1_start = iBarShift(NULL, Period(), bar_time);
      int duration_bars = tf / Period() + 2; // Add buffer for gaps/misalignment
      
      for (int k = duration_bars; k >= 0; k--) // Search backwards (Latest to Earliest)
      {
         int idx = m1_start - k;
         if (idx < 0) continue;
         
         double h = iHigh(NULL, Period(), idx);
         double l = iLow(NULL, Period(), idx);
         
         // Check if High or Low matches the price (Wick)
         if (type == 1 && MathAbs(h - price) < Point) {
            exact_time = iTime(NULL, Period(), idx);
            break;
         }
         if (type == -1 && MathAbs(l - price) < Point) {
            exact_time = iTime(NULL, Period(), idx);
            break;
         }
      }
   }
   
   // 2. Object Name
   string name = "MSSD_" + IntegerToString(tf) + "_" + TimeToString(exact_time);
   string line_name = name + "_Line";
   
   // 3. Calculate Draw Price (Gap)
   // Adjust for 3/5 digit brokers to use Pips instead of Points
   double pip_val = Point;
   if(Digits == 3 || Digits == 5) pip_val *= 10;
   
   double offset = gap_points * pip_val;
   double draw_price = price;
   if (type == 1) draw_price += offset;
   else           draw_price -= offset;

   // 4. Determine Color
   color clr = (type == 1) ? Color_Down : Color_Up;

   // 5. Create or Update Icon
   if(ObjectFind(0, name) < 0) 
   {
      ObjectCreate(0, name, OBJ_ARROW, 0, exact_time, draw_price);
   }
   else
   {
      // Update position if gap changed
      ObjectMove(0, name, 0, exact_time, draw_price);
   }
   
   // Update properties
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, icon_code);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, size); 
   
   // Anchor
   if (type == 1) ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
   else           ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_TOP);
   
   ObjectSetString(0, name, OBJPROP_TOOLTIP, "MSSD " + IntegerToString(tf) + " " + (type==1?"High":"Low"));
   
   // 6. Create or Update Line (if enabled)
   if (Show_Lines)
   {
      if(ObjectFind(0, line_name) < 0)
      {
         ObjectCreate(0, line_name, OBJ_TREND, 0, exact_time, price, exact_time + (Line_Length * PeriodSeconds()), price);
         ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
      }
      else
      {
          // Update line position if needed (though price shouldn't change, length might)
          ObjectMove(0, line_name, 0, exact_time, price);
          ObjectMove(0, line_name, 1, exact_time + (Line_Length * PeriodSeconds()), price);
      }
      
      ObjectSetInteger(0, line_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
   }
   else
   {
      // If lines disabled, remove existing
      ObjectDelete(0, line_name);
   }
}

//+------------------------------------------------------------------+
//| Create Sequence Arrow Object                                     |
//+------------------------------------------------------------------+
void CreateSequenceArrow(datetime time, double price, int type, int code, color clr, int gap_points, string suffix)
{
   string name = "MSSD_Seq_" + suffix + "_" + TimeToString(time);
   
   // Calculate Gap (Pips)
   double pip_val = Point;
   if(Digits == 3 || Digits == 5) pip_val *= 10;
   double offset = gap_points * pip_val;
   
   double draw_price = price;
   if (type == 1) draw_price += offset; // Down arrow above High
   else           draw_price -= offset; // Up arrow below Low
   
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_ARROW, 0, time, draw_price);
   } else {
      ObjectMove(0, name, 0, time, draw_price);
   }
   
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2); // Standard size
   
   if (type == 1) ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
   else           ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_TOP);
   
   ObjectSetString(0, name, OBJPROP_TOOLTIP, "MSSD Sequence " + suffix);
}
