/*
File: Arrows.mq4
Author: unknown
Source: unknown
Description: Arrow indicator for line crossovers, draws arrows and optional background zones
Purpose: Highlight crossovers between two indicator lines and optionally draw zone/background objects
Parameters: See indicator settings for Arrow and Background options near the top of the file
Version: 1.00
Last Modified: 2025.11.06
Compatibility: MetaTrader 4 (MT4)
*/
//+------------------------------------------------------------------+
#property copyright "Line Crossover Arrows"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

// Arrow plots
#property indicator_label1  "Cross Arrow Up"
#property indicator_type1   DRAW_ARROW
#property indicator_label2  "Cross Arrow Down"
#property indicator_type2   DRAW_ARROW

//--- Indicator Parameters
extern string __IndicatorName = ""; // Indicator Settings
extern string IndicatorName = "CurrencyStrengthWizard";           // Indicator Name (REQUIRED)
extern int    Line1Buffer = 0;             // Line 1 Buffer Number
extern int    Line2Buffer = 1;             // Line 2 Buffer Number
extern int    BarsToLookBack = 1000;       // Bars to Look Back

extern string __ArrowSettings = ""; // Arrow Settings
extern bool   ShowArrows = false;           // Show Arrows
extern int    ArrowCodeUp = 233;           // Arrow Code Up (233 = up arrow)
extern int    ArrowCodeDown = 234;         // Arrow Code Down (234 = down arrow)
extern color  ArrowUpColor = clrLightGreen; // Arrow Up Color
extern color  ArrowDnColor = clrRed;       // Arrow Down Color
extern int    ArrowWidth = 2;              // Arrow Width
extern double ArrowGapPercent = 10.0;      // Arrow Gap (% of candle height)

extern string __BackgroundSettings = ""; // Background Settings
extern bool   ColorBackground = false;     // Color Background
extern color  UpZoneColor = clrLightGreen; // Up Zone Color
extern color  DnZoneColor = clrRed;        // Down Zone Color (Red)
extern int    ZoneWidth = 1;               // Zone Width
extern bool   ShowVerticalLines = false;   // Show Vertical Lines
extern ENUM_LINE_STYLE VerticalLinesStyle = STYLE_DOT; // Vertical Lines Style
extern int    VerticalLinesWidth = 1;      // Vertical Lines Width
extern bool   IsMaster = false;            // Is Master (sets global variables for lines)
extern bool   CopyFromMaster = false;      // Copy Vertical Lines from Master
extern bool   CopyBackgroundFromMaster = false; // Copy Background Zones from Master

// Buffers
double CrossArrowUp[];
double CrossArrowDown[];

// Global
string ZonePrefix = "CrossZone_";
string LinePrefix = "CrossLine_";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                           |
//+------------------------------------------------------------------+
int init()
{
    // Check if indicator name is provided
    if(StringLen(IndicatorName) == 0)
    {
        Alert("ERROR: Indicator name is required! Please specify the IndicatorName parameter.");
        Print("ERROR: Indicator name is required! Please specify the IndicatorName parameter.");
        return(INIT_FAILED);
    }
    
    // Set indicator buffers
    SetIndexBuffer(0, CrossArrowUp);
    SetIndexBuffer(1, CrossArrowDown);
    
    // Set arrow properties for up arrows
    SetIndexStyle(0, DRAW_ARROW, EMPTY, ArrowWidth, ArrowUpColor);
    SetIndexArrow(0, ArrowCodeUp);
    SetIndexEmptyValue(0, EMPTY_VALUE);
    
    // Set arrow properties for down arrows
    SetIndexStyle(1, DRAW_ARROW, EMPTY, ArrowWidth, ArrowDnColor);
    SetIndexArrow(1, ArrowCodeDown);
    SetIndexEmptyValue(1, EMPTY_VALUE);
    
    // Set indicator name
    IndicatorShortName("Cross Arrows");
    
    return(0);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
int deinit()
{
    // Delete all zone and line objects
    for(int obj=ObjectsTotal()-1; obj>=0; obj--)
    {
        string objName = ObjectName(obj);
        if(StringFind(objName, ZonePrefix)==0 || StringFind(objName, LinePrefix)==0) ObjectDelete(objName);
    }
    return(0);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                                |
//+------------------------------------------------------------------+
int start()
{
    int limit;
    int counted_bars = IndicatorCounted();
    int maxBarsToProcess;
    int j;
    int obj;
    int currentSignal = 0;
    int zoneStartBar = -1;
    color zoneColor = clrNONE;
    int zoneId = 0;
    int lineId = 0;
    int lookback;
    double max_price;
    double min_price;
    double range_val;
    double p_high;
    double p_low;
    double line1_current;
    double line1_previous;
    double line2_current;
    double line2_previous;
    double candleHeight;
    datetime start_time_val;
    datetime end_time_val;
    string zoneName;
    string lineName;
    string objName;
    bool crossAbove;
    bool crossBelow;
    bool crossover;
    datetime times[1000];
    color colors[1000];
    int lineCount = 0;
    string sym;
    string prefix;
    int gCount;
    int k;
    datetime gTime;
    color gColor;
    ENUM_LINE_STYLE copyStyle = VerticalLinesStyle;
    int copyWidth = VerticalLinesWidth;
    datetime future_end = Time[0] + Period() * 60;
    
    // Check for minimum bars
    if(Bars < 2) return(0);
    
    // Always limit to BarsToLookBack from the current bar (bar 0)
    maxBarsToProcess = MathMin(Bars, BarsToLookBack);
    
    // Always process the full lookback range to maintain all zones
    limit = maxBarsToProcess - 1;
    
    // Initialize arrow buffers if full init
    if(counted_bars == 0)
    {
        ArrayInitialize(CrossArrowUp, EMPTY_VALUE);
        ArrayInitialize(CrossArrowDown, EMPTY_VALUE);
    }
    
    // Clear arrows beyond the process range
    for(j = maxBarsToProcess; j < Bars; j++)
    {
        CrossArrowUp[j] = EMPTY_VALUE;
        CrossArrowDown[j] = EMPTY_VALUE;
    }
    
    // Delete existing zone objects if ColorBackground or CopyBackgroundFromMaster is true
    if(ColorBackground || CopyBackgroundFromMaster)
    {
        for(obj=ObjectsTotal()-1; obj>=0; obj--)
        {
            objName = ObjectName(obj);
            if(StringFind(objName, ZonePrefix)==0) ObjectDelete(objName);
        }
    }
    
    // Delete existing line objects if ShowVerticalLines or CopyFromMaster is true
    if(ShowVerticalLines || CopyFromMaster)
    {
        for(obj=ObjectsTotal()-1; obj>=0; obj--)
        {
            objName = ObjectName(obj);
            if(StringFind(objName, LinePrefix)==0) ObjectDelete(objName);
        }
    }
    
    for(int i = limit; i >= 0; i--)
    {
        CrossArrowUp[i] = EMPTY_VALUE;
        CrossArrowDown[i] = EMPTY_VALUE;
        
        // Get line values from external indicator using iCustom
        line1_current = iCustom(Symbol(), Period(), IndicatorName, Line1Buffer, i);
        line1_previous = iCustom(Symbol(), Period(), IndicatorName, Line1Buffer, i + 1);
        line2_current = iCustom(Symbol(), Period(), IndicatorName, Line2Buffer, i);
        line2_previous = iCustom(Symbol(), Period(), IndicatorName, Line2Buffer, i + 1);
        
        // Check if we have valid data (not EMPTY_VALUE)
        if(line1_current == EMPTY_VALUE || line2_current == EMPTY_VALUE || 
           line1_previous == EMPTY_VALUE || line2_previous == EMPTY_VALUE)
        {
            continue;
        }
        
        // Set initial signal if not set
        if(currentSignal == 0)
        {
            currentSignal = (line1_current > line2_current) ? 1 : -1;
            zoneColor = (currentSignal == 1) ? UpZoneColor : DnZoneColor;
            zoneStartBar = i;
            
            // Draw vertical line at the start of the initial zone
            if(ShowVerticalLines)
            {
                lineName = LinePrefix + (string)lineId;
                lineId++;
                ObjectCreate(lineName, OBJ_VLINE, 0, Time[i], 0);
                ObjectSet(lineName, OBJPROP_COLOR, zoneColor);
                ObjectSet(lineName, OBJPROP_STYLE, VerticalLinesStyle);
                ObjectSet(lineName, OBJPROP_WIDTH, VerticalLinesWidth);
                ObjectSet(lineName, OBJPROP_BACK, TRUE);
            }
            
            // Collect for master
            if(IsMaster && lineCount < 1000)
            {
                times[lineCount] = Time[i];
                colors[lineCount] = zoneColor;
                lineCount++;
            }
        }
        
        // Detect crossover: Line1 crosses above Line2
        crossAbove = (line1_previous <= line2_previous) && (line1_current > line2_current);
        
        // Detect crossunder: Line1 crosses below Line2
        crossBelow = (line1_previous >= line2_previous) && (line1_current < line2_current);
        
        crossover = crossAbove || crossBelow;
        
        // Draw arrow on any crossover if ShowArrows is true
        if(crossover && ShowArrows)
        {
            // Calculate candle height once
            candleHeight = High[i] - Low[i];
            if(candleHeight == 0) candleHeight = Point * 10; // Fallback if no height
            
            double gap = candleHeight * (ArrowGapPercent / 100.0);
            
            if(crossAbove)
            {
                // Line1 crosses above Line2 - place up arrow below the candle
                CrossArrowUp[i] = Low[i] - gap;
            }
            else // crossBelow
            {
                // Line1 crosses below Line2 - place down arrow above the candle
                CrossArrowDown[i] = High[i] + gap;
            }
        }
        
        // Handle zones regardless of arrows
        if(crossover)
        {
            // If ColorBackground and previous zone active, draw it (from zoneStartBar to i)
            if(ColorBackground && zoneStartBar != -1 && currentSignal != 0)
            {
                // Calculate price range to cover
                lookback = IsMaster ? Bars - 1 : MathMin(100, BarsToLookBack);
                max_price = iHigh(NULL, 0, iHighest(NULL, 0, MODE_HIGH, lookback, 0));
                min_price = iLow(NULL, 0, iLowest(NULL, 0, MODE_LOW, lookback, 0));
                range_val = max_price - min_price;
                if(range_val == 0) range_val = Point * 1000;
                
                p_high = max_price + range_val * 0.5;
                p_low = min_price - range_val * 0.5;
                
                start_time_val = Time[zoneStartBar];
                end_time_val = Time[i];
                
                zoneName = ZonePrefix + (string)zoneId;
                zoneId++;
                ObjectCreate(zoneName, OBJ_RECTANGLE, 0, start_time_val, p_high, end_time_val, p_low);
                ObjectSet(zoneName, OBJPROP_COLOR, zoneColor);
                ObjectSet(zoneName, OBJPROP_STYLE, STYLE_SOLID);
                ObjectSet(zoneName, OBJPROP_WIDTH, ZoneWidth);
                ObjectSet(zoneName, OBJPROP_BACK, TRUE);
                ObjectSet(zoneName, OBJPROP_FILL, TRUE);
            }
            
            // Update signal and start new zone
            currentSignal = crossAbove ? 1 : -1;
            zoneColor = (currentSignal == 1) ? UpZoneColor : DnZoneColor;
            zoneStartBar = i;
            
            // Draw vertical line at the start of the new zone
            if(ShowVerticalLines)
            {
                lineName = LinePrefix + (string)lineId;
                lineId++;
                ObjectCreate(lineName, OBJ_VLINE, 0, Time[i], 0);
                ObjectSet(lineName, OBJPROP_COLOR, zoneColor);
                ObjectSet(lineName, OBJPROP_STYLE, VerticalLinesStyle);
                ObjectSet(lineName, OBJPROP_WIDTH, VerticalLinesWidth);
                ObjectSet(lineName, OBJPROP_BACK, TRUE);
            }
            
            // Collect for master
            if(IsMaster && lineCount < 1000)
            {
                times[lineCount] = Time[i];
                colors[lineCount] = zoneColor;
                lineCount++;
            }
        }
    }
    
    // After the loop, draw the last (current) zone if active
    if(ColorBackground && zoneStartBar != -1 && currentSignal != 0)
    {
        // Calculate price range to cover
        lookback = IsMaster ? Bars - 1 : MathMin(100, BarsToLookBack);
        max_price = iHigh(NULL, 0, iHighest(NULL, 0, MODE_HIGH, lookback, 0));
        min_price = iLow(NULL, 0, iLowest(NULL, 0, MODE_LOW, lookback, 0));
        range_val = max_price - min_price;
        if(range_val == 0) range_val = Point * 1000;
        
        p_high = max_price + range_val * 0.5;
        p_low = min_price - range_val * 0.5;
        
        start_time_val = Time[zoneStartBar];
        end_time_val = future_end;
        
        zoneName = ZonePrefix + (string)zoneId;
        zoneId++;
        ObjectCreate(zoneName, OBJ_RECTANGLE, 0, start_time_val, p_high, end_time_val, p_low);
        ObjectSet(zoneName, OBJPROP_COLOR, zoneColor);
        ObjectSet(zoneName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSet(zoneName, OBJPROP_WIDTH, ZoneWidth);
        ObjectSet(zoneName, OBJPROP_BACK, TRUE);
        ObjectSet(zoneName, OBJPROP_FILL, TRUE);
    }
    
    // Set global variables if IsMaster
    if(IsMaster)
    {
        sym = Symbol();
        prefix = "CrossLines_" + sym + "_";
        GlobalVariablesDeleteAll(prefix);
        GlobalVariableSet(prefix + "Count", lineCount);
        GlobalVariableSet(prefix + "Style", (double)VerticalLinesStyle);
        GlobalVariableSet(prefix + "Width", (double)VerticalLinesWidth);
        for(k = 0; k < lineCount; k++)
        {
            GlobalVariableSet(prefix + "Time_" + (string)k, (double)times[k]);
            GlobalVariableSet(prefix + "Color_" + (string)k, (double)colors[k]);
        }
    }
    
    // Copy vertical lines from master if CopyFromMaster
    if(CopyFromMaster)
    {
        sym = Symbol();
        prefix = "CrossLines_" + sym + "_";
        gCount = (int)GlobalVariableGet(prefix + "Count");
        copyStyle = (ENUM_LINE_STYLE)GlobalVariableGet(prefix + "Style");
        copyWidth = (int)GlobalVariableGet(prefix + "Width");
        for(k = 0; k < gCount; k++)
        {
            gTime = (datetime)GlobalVariableGet(prefix + "Time_" + (string)k);
            gColor = (color)GlobalVariableGet(prefix + "Color_" + (string)k);
            lineName = LinePrefix + "Copy_" + (string)k;
            ObjectCreate(lineName, OBJ_VLINE, 0, gTime, 0);
            ObjectSet(lineName, OBJPROP_COLOR, gColor);
            ObjectSet(lineName, OBJPROP_STYLE, copyStyle);
            ObjectSet(lineName, OBJPROP_WIDTH, copyWidth);
            ObjectSet(lineName, OBJPROP_BACK, TRUE);
        }
    }
    
    // Copy background zones from master if CopyBackgroundFromMaster
    if(CopyBackgroundFromMaster)
    {
        sym = Symbol();
        prefix = "CrossLines_" + sym + "_";
        gCount = (int)GlobalVariableGet(prefix + "Count");
        if(gCount > 0)
        {
            datetime gTimes[];
            color gColors[];
            ArrayResize(gTimes, gCount);
            ArrayResize(gColors, gCount);
            for(k = 0; k < gCount; k++)
            {
                gTimes[k] = (datetime)GlobalVariableGet(prefix + "Time_" + (string)k);
                gColors[k] = (color)GlobalVariableGet(prefix + "Color_" + (string)k);
            }
            
            // Calculate price range to cover (using full history for full coverage)
            lookback = Bars - 1;
            max_price = iHigh(NULL, 0, iHighest(NULL, 0, MODE_HIGH, lookback, 0));
            min_price = iLow(NULL, 0, iLowest(NULL, 0, MODE_LOW, lookback, 0));
            range_val = max_price - min_price;
            if(range_val == 0) range_val = Point * 1000;
            
            p_high = max_price + range_val * 0.5;
            p_low = min_price - range_val * 0.5;
            
            // Draw zones between times
            for(k = 0; k < gCount - 1; k++)
            {
                start_time_val = gTimes[k];
                end_time_val = gTimes[k + 1];
                zoneColor = gColors[k];
                zoneName = ZonePrefix + "Copy_" + (string)zoneId;
                zoneId++;
                ObjectCreate(zoneName, OBJ_RECTANGLE, 0, start_time_val, p_high, end_time_val, p_low);
                ObjectSet(zoneName, OBJPROP_COLOR, zoneColor);
                ObjectSet(zoneName, OBJPROP_STYLE, STYLE_SOLID);
                ObjectSet(zoneName, OBJPROP_WIDTH, ZoneWidth);
                ObjectSet(zoneName, OBJPROP_BACK, TRUE);
                ObjectSet(zoneName, OBJPROP_FILL, TRUE);
            }
            
            // Draw the last zone
            start_time_val = gTimes[gCount - 1];
            end_time_val = future_end;
            zoneColor = gColors[gCount - 1];
            zoneName = ZonePrefix + "Copy_" + (string)zoneId;
            zoneId++;
            ObjectCreate(zoneName, OBJ_RECTANGLE, 0, start_time_val, p_high, end_time_val, p_low);
            ObjectSet(zoneName, OBJPROP_COLOR, zoneColor);
            ObjectSet(zoneName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSet(zoneName, OBJPROP_WIDTH, ZoneWidth);
            ObjectSet(zoneName, OBJPROP_BACK, TRUE);
            ObjectSet(zoneName, OBJPROP_FILL, TRUE);
        }
    }
    
    return(0);
}

//+------------------------------------------------------------------+