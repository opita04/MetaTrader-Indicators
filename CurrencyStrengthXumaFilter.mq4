/*
File: CurrencyStrengthXumaFilter.mq4
Author: unknown
Source: unknown
Description: Currency Strength filtered by XUMA signal - shows arrows when CS and XUMA indicators agree
Purpose: Combine a currency strength indicator with a XUMA-based filter to produce trade signals (arrows)
Parameters: See the XUMA and Currency Strength settings sections below in the file
Version: 1.00
Last Modified: 2025.11.06
Compatibility: MetaTrader 4 (MT4)
*/
//+------------------------------------------------------------------+
#property copyright "Currency Strength XUMA Filter"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- plot Up Arrow
#property indicator_label1  "Up Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLimeGreen

//--- plot Down Arrow
#property indicator_label2  "Down Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed

//--- Currency Strength Indicator Settings
extern string __CurrencyStrengthSettings = ""; // Currency Strength Settings
extern string CurrencyStrengthIndicator = "CurrencyStrengthWizard"; // Currency Strength Indicator Name
extern int    CS_Line1Buffer = 0;              // Currency Strength Line 1 Buffer
extern int    CS_Line2Buffer = 1;              // Currency Strength Line 2 Buffer

//--- XUMA Indicator Settings
extern string __XumaSettings = ""; // XUMA Filter Settings
extern string XumaIndicator = "3x Xuma(eAverages + histo + BT)1.2"; // XUMA Indicator Name
extern int    Xuma_FirstMaPeriod = 34;         // First Ma period
extern int    Xuma_SecondMaPeriod = 34;        // Second Ma period
extern int    Xuma_ThirdMaPeriod = 34;         // Third Ma period

//--- Arrow Settings
extern string __ArrowSettings = ""; // Arrow Settings
extern int    ArrowUpCode = 233;   // Up Arrow Code (Wingdings)
extern int    ArrowDownCode = 234; // Down Arrow Code (Wingdings)
extern int    ArrowSize = 3;       // Arrow Size

//--- Indicator Buffers
double UpArrowBuffer[];
double DownArrowBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
{
    // Set up indicator buffers
    IndicatorBuffers(2);
    SetIndexBuffer(0, UpArrowBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, DownArrowBuffer, INDICATOR_DATA);

    // Set index styles for arrows
    SetIndexStyle(0, DRAW_ARROW, EMPTY, ArrowSize, clrLimeGreen);
    SetIndexArrow(0, ArrowUpCode);
    SetIndexEmptyValue(0, EMPTY_VALUE);

    SetIndexStyle(1, DRAW_ARROW, EMPTY, ArrowSize, clrRed);
    SetIndexArrow(1, ArrowDownCode);
    SetIndexEmptyValue(1, EMPTY_VALUE);

    IndicatorShortName("CS XUMA Filter");
    
    return(0);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
int deinit()
{
    return(0);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
{
    int counted_bars = IndicatorCounted();
    int limit;
    
    if(counted_bars > 0)
        limit = Bars - counted_bars - 1;
    else
        limit = Bars - 1;

    // Initialize buffers if needed
    if(counted_bars == 0)
    {
        ArrayInitialize(UpArrowBuffer, EMPTY_VALUE);
        ArrayInitialize(DownArrowBuffer, EMPTY_VALUE);
    }

    // Get current chart timeframe
    ENUM_TIMEFRAMES chartTF = Period();
    
    // Get higher timeframe for currency strength
    ENUM_TIMEFRAMES higherTF = GetHigherTimeframe(chartTF);
    
    // Process bars
    for(int i = limit; i >= 0; i--)
    {
        // Get currency strength signal from higher timeframe
        int csSignal = GetCurrencyStrengthSignal(i, higherTF);
        
        // Get XUMA signal from current chart timeframe
        int xumaSignal = GetXumaSignal(i, chartTF);
        
        // Only show arrow if both signals match
        if(csSignal == 1 && xumaSignal == 1)
        {
            // Both bullish - show up arrow
            UpArrowBuffer[i] = Low[i] - (Point * 10);
            DownArrowBuffer[i] = EMPTY_VALUE;
        }
        else if(csSignal == -1 && xumaSignal == -1)
        {
            // Both bearish - show down arrow
            UpArrowBuffer[i] = EMPTY_VALUE;
            DownArrowBuffer[i] = High[i] + (Point * 10);
        }
        else
        {
            // Signals don't match - no arrow
            UpArrowBuffer[i] = EMPTY_VALUE;
            DownArrowBuffer[i] = EMPTY_VALUE;
        }
    }

    return(0);
}

//+------------------------------------------------------------------+
//| Get Currency Strength Signal (following CurrencyStrengthZones pattern) |
//+------------------------------------------------------------------+
int GetCurrencyStrengthSignal(int bar, ENUM_TIMEFRAMES timeframe)
{
    string symbol = Symbol();
    datetime barTime = Time[bar];
    string indicatorPath;
    
    // Find the bar on the higher timeframe
    int tf_bar = iBarShift(symbol, timeframe, barTime, false);
    if(tf_bar < 0) return 0;
    
    // First try standard location
    indicatorPath = CurrencyStrengthIndicator;
    double line1_current = iCustom(symbol, timeframe, indicatorPath, CS_Line1Buffer, tf_bar);
    double line1_previous = iCustom(symbol, timeframe, indicatorPath, CS_Line1Buffer, tf_bar + 1);
    double line2_current = iCustom(symbol, timeframe, indicatorPath, CS_Line2Buffer, tf_bar);
    double line2_previous = iCustom(symbol, timeframe, indicatorPath, CS_Line2Buffer, tf_bar + 1);
    
    // If not found, try subfolder
    if(line1_current == EMPTY_VALUE && line2_current == EMPTY_VALUE &&
       line1_previous == EMPTY_VALUE && line2_previous == EMPTY_VALUE)
    {
        indicatorPath = "Millionaire Maker\\" + CurrencyStrengthIndicator;
        line1_current = iCustom(symbol, timeframe, indicatorPath, CS_Line1Buffer, tf_bar);
        line1_previous = iCustom(symbol, timeframe, indicatorPath, CS_Line1Buffer, tf_bar + 1);
        line2_current = iCustom(symbol, timeframe, indicatorPath, CS_Line2Buffer, tf_bar);
        line2_previous = iCustom(symbol, timeframe, indicatorPath, CS_Line2Buffer, tf_bar + 1);
    }
    
    // Check if we have valid data
    if(line1_current == EMPTY_VALUE || line2_current == EMPTY_VALUE ||
       line1_previous == EMPTY_VALUE || line2_previous == EMPTY_VALUE)
    {
        return 0; // Neutral
    }
    
    // Check for crossover or current position
    bool crossAbove = (line1_previous <= line2_previous) && (line1_current > line2_current);
    bool crossBelow = (line1_previous >= line2_previous) && (line1_current < line2_current);
    
    if(crossAbove)
        return 1;  // Up signal
    else if(crossBelow)
        return -1; // Down signal
    else
    {
        if(line1_current > line2_current)
            return 1;  // Currently above
        else if(line1_current < line2_current)
            return -1; // Currently below
        else
            return 0;  // Neutral
    }
}

//+------------------------------------------------------------------+
//| Get XUMA Signal                                                  |
//+------------------------------------------------------------------+
int GetXumaSignal(int bar, ENUM_TIMEFRAMES timeframe)
{
    string symbol = Symbol();
    
    // Call XUMA indicator with only the three MA period parameters
    // Format: iCustom(symbol, timeframe, indicator_name, param1, param2, param3, buffer_index, shift)
    // Based on screenshot, buffers 0 and 1 appear to be the first two MAs
    
    double ma1_current = iCustom(symbol, timeframe, XumaIndicator,
        Xuma_FirstMaPeriod,
        Xuma_SecondMaPeriod,
        Xuma_ThirdMaPeriod,
        0, // Buffer 0 - First MA
        bar);
    
    double ma2_current = iCustom(symbol, timeframe, XumaIndicator,
        Xuma_FirstMaPeriod,
        Xuma_SecondMaPeriod,
        Xuma_ThirdMaPeriod,
        1, // Buffer 1 - Second MA
        bar);
    
    double ma1_previous = iCustom(symbol, timeframe, XumaIndicator,
        Xuma_FirstMaPeriod,
        Xuma_SecondMaPeriod,
        Xuma_ThirdMaPeriod,
        0, // Buffer 0 - First MA
        bar + 1);
    
    double ma2_previous = iCustom(symbol, timeframe, XumaIndicator,
        Xuma_FirstMaPeriod,
        Xuma_SecondMaPeriod,
        Xuma_ThirdMaPeriod,
        1, // Buffer 1 - Second MA
        bar + 1);
    
    // Check if we have valid data
    if(ma1_current == EMPTY_VALUE || ma2_current == EMPTY_VALUE ||
       ma1_previous == EMPTY_VALUE || ma2_previous == EMPTY_VALUE)
    {
        return 0; // Neutral
    }
    
    // Check for crossover or current position
    bool crossAbove = (ma1_previous <= ma2_previous) && (ma1_current > ma2_current);
    bool crossBelow = (ma1_previous >= ma2_previous) && (ma1_current < ma2_current);
    
    if(crossAbove)
        return 1;  // Up signal
    else if(crossBelow)
        return -1; // Down signal
    else
    {
        if(ma1_current > ma2_current)
            return 1;  // Currently above
        else if(ma1_current < ma2_current)
            return -1; // Currently below
        else
            return 0;  // Neutral
    }
}

//+------------------------------------------------------------------+
//| Get Higher Timeframe                                             |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetHigherTimeframe(ENUM_TIMEFRAMES timeframe)
{
    switch(timeframe)
    {
        case PERIOD_M1:   return PERIOD_M5;
        case PERIOD_M5:   return PERIOD_M15;
        case PERIOD_M15:  return PERIOD_M30;
        case PERIOD_M30:  return PERIOD_H1;
        case PERIOD_H1:   return PERIOD_H4;
        case PERIOD_H4:   return PERIOD_D1;
        case PERIOD_D1:   return PERIOD_W1;
        case PERIOD_W1:   return PERIOD_MN1;
        default:          return PERIOD_H1; // Default fallback
    }
}

//+------------------------------------------------------------------+

