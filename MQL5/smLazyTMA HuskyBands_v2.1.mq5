/*
File: smLazyTMA HuskyBands_v2.1.mq5
Author: SwingMan (original) / unknown (current)
Source: Copyright 22.06.2019, SwingMan
Description: HuskyBands (TMA-based bands) indicator providing multiple band levels and signal arrows (MQL5 port)
Purpose: Compute TMA-centered bands and optional entry/exit arrows based on band thresholds
Parameters: See input parameters (HalfLength, MA method, ATR multipliers, draw options)
Version: 2.1
Last Modified: 2025.11.06
Compatibility: MetaTrader 5 (MT5)
*/
//+------------------------------------------------------------------+
#property copyright "Copyright 22.06.2019, SwingMan"
#property version   "2.1"
#property indicator_chart_window
#property indicator_buffers 19
#property indicator_plots   16
#property indicator_type1   DRAW_LINE
#property indicator_type2   DRAW_LINE

// TMA UP/DN
#property indicator_label1  "TMA UP"
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "TMA DN"
#property indicator_color2  clrTomato
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

// Bands UP
#property indicator_label3  "Band UP 1"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrChocolate
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

#property indicator_label4  "Band UP 2"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrHotPink
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

#property indicator_label5  "Band UP 3"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrMagenta
#property indicator_style5  STYLE_DOT
#property indicator_width5  1

#property indicator_label6  "Band UP 4"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrMagenta
#property indicator_style6  STYLE_DOT
#property indicator_width6  1

// Bands DN
#property indicator_label7  "Band DN 1"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrChocolate
#property indicator_style7  STYLE_DOT
#property indicator_width7  1

#property indicator_label8  "Band DN 2"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrSpringGreen
#property indicator_style8  STYLE_SOLID
#property indicator_width8  2

#property indicator_label9  "Band DN 3"
#property indicator_type9   DRAW_LINE
#property indicator_color9  clrMediumSeaGreen
#property indicator_style9  STYLE_SOLID
#property indicator_width9  1

#property indicator_label10 "Band DN 4"
#property indicator_type10  DRAW_LINE
#property indicator_color10 clrMediumSeaGreen
#property indicator_style10 STYLE_DOT
#property indicator_width10 1

// Entry/Exit arrows
#property indicator_label11 "LONG entry"
#property indicator_type11  DRAW_ARROW
#property indicator_color11 clrAqua
#property indicator_width11 1

#property indicator_label12 "SHORT entry"
#property indicator_type12  DRAW_ARROW
#property indicator_color12 clrMagenta
#property indicator_width12 1

#property indicator_label13 "LONG exit"
#property indicator_type13  DRAW_ARROW
#property indicator_color13 clrAqua
#property indicator_width13 1

#property indicator_label14 "SHORT exit"
#property indicator_type14  DRAW_ARROW
#property indicator_color14 clrMagenta
#property indicator_width14 1

// TMA High/Low
#property indicator_label15 "TMA Highs"
#property indicator_type15  DRAW_LINE
#property indicator_color15 clrMagenta
#property indicator_width15 2

#property indicator_label16 "TMA Lows"
#property indicator_type16  DRAW_LINE
#property indicator_color16 clrMediumSeaGreen
#property indicator_width16 2

// Enums
enum ENUM_THRESHOLD_BANDS
{
   Band1,
   Band2, 
   Band3,
   Band4
};

enum ENUM_BAND_TYPE
{
   Median_Band,
   HighLow_Bands
};

// Input parameters
input ENUM_BAND_TYPE         Band_Type       = Median_Band;
input int HalfLength_input = 34;            // Half Length
input int ma_period       = 4;             // MA averaging period
input ENUM_MA_METHOD        ma_method       = MODE_LWMA;     // MA averaging method
input int                    ATR_Period      = 144;          // ATR Period
input int                    Total_Bars      = 1000;
input string                ___Bands_Deviation_Multiplier = "----------------------------------------------";
input double                ATR_Multiplier_Band1   = 1.0;
input double                ATR_Multiplier_Band2   = 1.618;
input double                ATR_Multiplier_Band3   = 2.236;
input double                ATR_Multiplier_Band4   = 2.854;
input string                ___Bands_To_Draw = "----------------------------------------------";
input bool                  Draw_HighLow_TMA = true;
input bool                  Draw_Band1 = true;
input bool                  Draw_Band2 = true;
input bool                  Draw_Band3 = true;
input bool                  Draw_Band4 = true;
input string                ___Signal_Arrows = "----------------------------------------------";
input bool                  Draw_SignalArrows = true;
input ENUM_THRESHOLD_BANDS  Threshold_Band = Band1;
input bool                  SendSignal_Alerts = true;
input bool                  SendSignal_Emails = false;
input int                   ArrowCode_EntrySignal = 181;
input int                   ArrowCode_ExitSignal = 203;
input int                   Arrow_Width = 1;
input color                 ArrowColor_SignalUP = clrAqua;
input color                 ArrowColor_SignalDOWN = clrMagenta;
input bool                  Show_Comments = false;
input int MA_Period = 14;         // MA Period
input bool Debug_Mode = false;    // Enable Debug Mode
input ENUM_MA_METHOD MA_Method = MODE_SMA;    // Moving Average Method
input int           MA_Shift  = 0;            // MA Shift

// Indicator buffers
double tmaUP[];
double tmaDN[];
double bandUP1[];
double bandUP2[];
double bandUP3[];
double bandUP4[];
double bandDN1[];
double bandDN2[];
double bandDN3[];
double bandDN4[];
double arrowUP[];
double arrowDN[];
double exitUP[];
double exitDN[];
double tmaCenteredHighs[];
double tmaCenteredLows[];
double tmaCentered[];
double slope[];
double signalSended[];
double weights[];
double ma[];           // MA values array
double buffer1[];      // TMA buffer
double signalLongEntry[];   // Long entry signals
double signalShortEntry[];  // Short entry signals
double signalLongExit[];    // Long exit signals
double signalShortExit[];   // Short exit signals

// Constants
#define LONG_ENTRY_TREND     1
#define LONG_ENTRY_COUNTER   2
#define LONG_EXIT_TREND      3
#define SHORT_ENTRY_TREND   -1
#define SHORT_ENTRY_COUNTER -2
#define SHORT_EXIT_TREND    -3
#define OP_BUY 0
#define OP_SELL 1
#define OP_NONE -1

// Global variables
datetime thisTime, oldTime;
bool newBar, newRedraw;
double sumWeights = 0;
int fullLength;
string subjectEmailAlert = "smLazyTMA HuskyBands";
int iMomentum_Direction = OP_NONE;
int HalfLength;
double price[];
int g_maHandle = INVALID_HANDLE;

// Fix for global variable hiding
#ifdef sumWeights
#undef sumWeights
#endif

//+------------------------------------------------------------------+
//| Get Calculation Limit                                              |
//+------------------------------------------------------------------+
int Get_CalculationLimit(const int rates_total, const int prev_calculated)
{
    int limit;
    
    if(prev_calculated == 0)
    {
        // Start from oldest available data point that allows full calculation
        limit = rates_total - MA_Period - HalfLength * 2 - 1;
    }
    else
    {
        // Only calculate new bars
        limit = rates_total - prev_calculated;
    }
    
    // Ensure we have enough bars for MA calculation
    return MathMin(limit, rates_total - MA_Period - HalfLength * 2 - 1);
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                           |
//+------------------------------------------------------------------+
int OnInit()
{
    PrintFormat("=== OnInit Start ===");
    
    // Initialize arrays with proper sizes
    ArrayResize(ma, HalfLength * 2 + 1);
    ArraySetAsSeries(ma, true);
    
    // Set indicator buffers
    SetIndexBuffer(0, tmaCentered, INDICATOR_DATA);
    SetIndexBuffer(1, tmaUP, INDICATOR_DATA);
    SetIndexBuffer(2, tmaDN, INDICATOR_DATA);
    SetIndexBuffer(3, bandUP1, INDICATOR_DATA);
    SetIndexBuffer(4, bandUP2, INDICATOR_DATA);
    SetIndexBuffer(5, bandUP3, INDICATOR_DATA);
    SetIndexBuffer(6, bandUP4, INDICATOR_DATA);
    SetIndexBuffer(7, bandDN1, INDICATOR_DATA);
    SetIndexBuffer(8, bandDN2, INDICATOR_DATA);
    SetIndexBuffer(9, bandDN3, INDICATOR_DATA);
    SetIndexBuffer(10, bandDN4, INDICATOR_DATA);
    SetIndexBuffer(11, signalLongEntry, INDICATOR_DATA);
    SetIndexBuffer(12, signalShortEntry, INDICATOR_DATA);
    SetIndexBuffer(13, signalLongExit, INDICATOR_DATA);
    SetIndexBuffer(14, signalShortExit, INDICATOR_DATA);
    SetIndexBuffer(15, slope, INDICATOR_CALCULATIONS);
    SetIndexBuffer(16, buffer1, INDICATOR_CALCULATIONS);
    
    // Set arrays as timeseries
    ArraySetAsSeries(tmaCentered, true);
    ArraySetAsSeries(tmaUP, true);
    ArraySetAsSeries(tmaDN, true);
    ArraySetAsSeries(bandUP1, true);
    ArraySetAsSeries(bandUP2, true);
    ArraySetAsSeries(bandUP3, true);
    ArraySetAsSeries(bandUP4, true);
    ArraySetAsSeries(bandDN1, true);
    ArraySetAsSeries(bandDN2, true);
    ArraySetAsSeries(bandDN3, true);
    ArraySetAsSeries(bandDN4, true);
    ArraySetAsSeries(signalLongEntry, true);
    ArraySetAsSeries(signalShortEntry, true);
    ArraySetAsSeries(signalLongExit, true);
    ArraySetAsSeries(signalShortExit, true);
    ArraySetAsSeries(slope, true);
    ArraySetAsSeries(buffer1, true);
    
    // Initialize MA handle
    g_maHandle = iMA(Symbol(), Period(), ma_period, 0, ma_method, PRICE_MEDIAN);
    
    if(g_maHandle == INVALID_HANDLE)
    {
        Print("Error creating MA indicator handle");
        return INIT_FAILED;
    }
    
    // Initialize lengths
    HalfLength = HalfLength_input;
    fullLength = HalfLength * 2 + 1;
    
    // Initialize weights array
    ArrayResize(weights, fullLength);
    ArraySetAsSeries(weights, true);  // Make weights array series
    
    // Calculate weights
    sumWeights = HalfLength + 1;
    weights[HalfLength] = HalfLength + 1;
    for(int i = 0; i < HalfLength; i++)
    {
        weights[i] = i + 1;
        weights[fullLength-i-1] = i + 1;
        sumWeights += i + i + 2;
    }
    
    // Set indicator buffers
    SetIndexBuffer(0, tmaUP, INDICATOR_DATA);
    SetIndexBuffer(1, tmaDN, INDICATOR_DATA);
    SetIndexBuffer(2, bandUP1, INDICATOR_DATA);
    SetIndexBuffer(3, bandUP2, INDICATOR_DATA);
    SetIndexBuffer(4, bandUP3, INDICATOR_DATA);
    SetIndexBuffer(5, bandUP4, INDICATOR_DATA);
    SetIndexBuffer(6, bandDN1, INDICATOR_DATA);
    SetIndexBuffer(7, bandDN2, INDICATOR_DATA);
    SetIndexBuffer(8, bandDN3, INDICATOR_DATA);
    SetIndexBuffer(9, bandDN4, INDICATOR_DATA);
    SetIndexBuffer(10, arrowUP, INDICATOR_DATA);
    SetIndexBuffer(11, arrowDN, INDICATOR_DATA);
    SetIndexBuffer(12, exitUP, INDICATOR_DATA);
    SetIndexBuffer(13, exitDN, INDICATOR_DATA);
    SetIndexBuffer(14, tmaCenteredHighs, INDICATOR_DATA);
    SetIndexBuffer(15, tmaCenteredLows, INDICATOR_DATA);

    // Set drawing properties for all plots
    for(int i = 0; i < 16; i++)
    {
        PlotIndexSetInteger(i, PLOT_DRAW_BEGIN, HalfLength);
        PlotIndexSetInteger(i, PLOT_SHOW_DATA, true);
    }

    // Set specific empty values for TMA lines
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    
    // Set specific line properties for TMA
    PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);
    PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
    PlotIndexSetInteger(0, PLOT_LINE_STYLE, STYLE_SOLID);
    PlotIndexSetInteger(1, PLOT_LINE_STYLE, STYLE_SOLID);
    PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 1);
    PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 1);

    // Restore specific plot types for arrows
    PlotIndexSetInteger(10, PLOT_DRAW_TYPE, DRAW_ARROW);
    PlotIndexSetInteger(11, PLOT_DRAW_TYPE, DRAW_ARROW);
    PlotIndexSetInteger(12, PLOT_DRAW_TYPE, DRAW_ARROW);
    PlotIndexSetInteger(13, PLOT_DRAW_TYPE, DRAW_ARROW);

    // Set arrow codes
    PlotIndexSetInteger(10, PLOT_ARROW, ArrowCode_EntrySignal);
    PlotIndexSetInteger(11, PLOT_ARROW, ArrowCode_EntrySignal);
    PlotIndexSetInteger(12, PLOT_ARROW, ArrowCode_ExitSignal);
    PlotIndexSetInteger(13, PLOT_ARROW, ArrowCode_ExitSignal);

    // Hide plots based on input parameters
    if(!Draw_Band1)
    {
        PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
        PlotIndexSetInteger(6, PLOT_DRAW_TYPE, DRAW_NONE);
    }
    if(!Draw_Band2)
    {
        PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_NONE);
        PlotIndexSetInteger(7, PLOT_DRAW_TYPE, DRAW_NONE);
    }
    if(!Draw_Band3)
    {
        PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_NONE);
        PlotIndexSetInteger(8, PLOT_DRAW_TYPE, DRAW_NONE);
    }
    if(!Draw_Band4)
    {
        PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_NONE);
        PlotIndexSetInteger(9, PLOT_DRAW_TYPE, DRAW_NONE);
    }

    // Initialize buffers with EMPTY_VALUE
    ArrayInitialize(tmaUP, EMPTY_VALUE);
    ArrayInitialize(tmaDN, EMPTY_VALUE);
    ArrayInitialize(bandUP1, EMPTY_VALUE);
    ArrayInitialize(bandUP2, EMPTY_VALUE);
    ArrayInitialize(bandUP3, EMPTY_VALUE);
    ArrayInitialize(bandUP4, EMPTY_VALUE);
    ArrayInitialize(bandDN1, EMPTY_VALUE);
    ArrayInitialize(bandDN2, EMPTY_VALUE);
    ArrayInitialize(bandDN3, EMPTY_VALUE);
    ArrayInitialize(bandDN4, EMPTY_VALUE);
    ArrayInitialize(arrowUP, EMPTY_VALUE);
    ArrayInitialize(arrowDN, EMPTY_VALUE);
    ArrayInitialize(exitUP, EMPTY_VALUE);
    ArrayInitialize(exitDN, EMPTY_VALUE);
    ArrayInitialize(tmaCenteredHighs, EMPTY_VALUE);
    ArrayInitialize(tmaCenteredLows, EMPTY_VALUE);

    // Set buffer directions
    ArraySetAsSeries(tmaUP, true);
    ArraySetAsSeries(tmaDN, true);
    ArraySetAsSeries(bandUP1, true);
    ArraySetAsSeries(bandUP2, true);
    ArraySetAsSeries(bandUP3, true);
    ArraySetAsSeries(bandUP4, true);
    ArraySetAsSeries(bandDN1, true);
    ArraySetAsSeries(bandDN2, true);
    ArraySetAsSeries(bandDN3, true);
    ArraySetAsSeries(bandDN4, true);
    ArraySetAsSeries(arrowUP, true);
    ArraySetAsSeries(arrowDN, true);
    ArraySetAsSeries(exitUP, true);
    ArraySetAsSeries(exitDN, true);
    ArraySetAsSeries(tmaCenteredHighs, true);
    ArraySetAsSeries(tmaCenteredLows, true);
    ArraySetAsSeries(tmaCentered, true);
    ArraySetAsSeries(slope, true);
    ArraySetAsSeries(signalSended, true);
    ArraySetAsSeries(price, true);

    // Fix arrow properties
    PlotIndexSetInteger(10, PLOT_ARROW_SHIFT, 5);
    PlotIndexSetInteger(11, PLOT_ARROW_SHIFT, -5);
    PlotIndexSetInteger(12, PLOT_ARROW_SHIFT, 5);
    PlotIndexSetInteger(13, PLOT_ARROW_SHIFT, -5);

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                                |
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
    // Add early validation
    if(rates_total <= 0)
    {
        Print("Invalid rates_total: ", rates_total);
        return 0;
    }
    
    // Add MA handle validation at start
    if(g_maHandle == INVALID_HANDLE)
    {
        Print("MA Handle is invalid at calculation start");
        return 0;
    }
    
    int limit = Get_CalculationLimit(rates_total, prev_calculated);
    
    if(limit > 43190)
    {
        Print("=== Debug Info for Critical Range ===");
        Print("MA Handle: ", g_maHandle);
        Print("MA Period: ", MA_Period);
        Print("MA Method: ", EnumToString(MA_Method));
        Print("MA Shift: ", MA_Shift);
        Print("HalfLength: ", HalfLength);
        Print("Bars calculated for MA: ", BarsCalculated(g_maHandle));
        Print("Current rates total: ", rates_total);
        Print("Previous calculated: ", prev_calculated);
        Print("Calculation limit: ", limit);
    }
    
    for(int i = 0; i < limit && !IsStopped(); i++)
    {
        if(i > 43190)
        {
            Print("=== Processing bar ", i, " ===");
            Print("Copying MA values from index ", i);
            
            // Add array size validation
            Print("MA array size before copy: ", ArraySize(ma));
            Print("Required size: ", HalfLength * 2 + 1);
            
            // Add data availability check
            int available = SeriesInfoInteger(Symbol(), Period(), SERIES_BARS_COUNT);
            Print("Total available bars: ", available);
            Print("Required bars for calculation: ", i + HalfLength * 2 + 1);
        }
        
        // Initialize array before copy
        ArrayInitialize(ma, 0);
        
        // Copy with enhanced error checking
        ResetLastError();
        int copied = CopyBuffer(g_maHandle, 0, i, HalfLength * 2 + 1, ma);
        
        if(copied != HalfLength * 2 + 1)
        {
            int err = GetLastError();
            if(i > 43190)
            {
                Print("CopyBuffer failed for bar ", i);
                Print("Error code: ", err);
                Print("Copied values: ", copied);
                Print("Expected values: ", HalfLength * 2 + 1);
                Print("MA Handle: ", g_maHandle);
                Print("Bars calculated: ", BarsCalculated(g_maHandle));
                Print("Current bar index: ", i);
                Print("Data start pos: ", i);
                Print("Data length: ", HalfLength * 2 + 1);
            }
            buffer1[i] = EMPTY_VALUE;
            continue;
        }
        
        if(i > 43190)
        {
            // Dump MA array contents for debugging
            for(int j = 0; j < HalfLength * 2 + 1; j++)
            {
                Print("MA[", j, "] = ", ma[j],
                      " Valid: ", MathIsValidNumber(ma[j]),
                      " Empty: ", ma[j] == EMPTY_VALUE,
                      " Zero: ", ma[j] == 0);
            }
        }
        
        // Initialize tracking variables
        double minMA = DBL_MAX;
        double maxMA = -DBL_MAX;
        bool hasInvalidValue = false;
        
        // First pass - find min/max and validate
        for(int j = 0; j < HalfLength * 2 + 1; j++)
        {
            if(!MathIsValidNumber(ma[j]) || ma[j] == EMPTY_VALUE)
            {
                if(i > 43190) Print("Invalid MA value at position ", j, ": ", ma[j]);
                hasInvalidValue = true;
                break;
            }
            
            minMA = MathMin(minMA, ma[j]);
            maxMA = MathMax(maxMA, ma[j]);
        }
        
        // Validate range
        if(maxMA - minMA < DBL_EPSILON)
        {
            if(i > 43190) Print("Invalid MA range: min=", minMA, " max=", maxMA);
            buffer1[i] = EMPTY_VALUE;
            continue;
        }
        
        // Track running sums with validation
        double localSumWeights = 0;
        double sumProducts = 0;
        
        for(int j = 0; j < HalfLength * 2 + 1; j++)
        {
            double weight = (j <= HalfLength) ? j + 1 : HalfLength * 2 + 1 - j;
            double norm = (ma[j] - minMA) / (maxMA - minMA);
            
            if(!MathIsValidNumber(norm))
            {
                if(i > 43190) Print("Invalid normalization at j=", j, 
                                  ": ma=", ma[j], 
                                  " minMA=", minMA,
                                  " maxMA=", maxMA);
                hasInvalidValue = true;
                break;
            }
            
            double prod = norm * weight;
            sumProducts += prod;
            localSumWeights += weight;
            
            if(!MathIsValidNumber(sumProducts))
            {
                if(i > 43190) Print("Invalid sumProducts at j=", j,
                                  ": norm=", norm,
                                  " weight=", weight,
                                  " prod=", prod);
                hasInvalidValue = true;
                break;
            }
        }
        
        if(hasInvalidValue || localSumWeights <= 0)
        {
            buffer1[i] = EMPTY_VALUE;
            continue;
        }
        
        double result = sumProducts / localSumWeights;
        if(!MathIsValidNumber(result))
        {
            if(i > 43190) Print("Invalid final result: ", result,
                              " sumProducts=", sumProducts,
                              " sumWeights=", localSumWeights);
            buffer1[i] = EMPTY_VALUE;
        }
        else
        {
            buffer1[i] = result;
        }
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate TMA Average                                              |
//+------------------------------------------------------------------+
void Calculate_TMA_AVERAGE(int rates_total, int limit, ENUM_APPLIED_PRICE applied_price,
                          double &tmaCenteredOut[], double &tmaUPOut[], double &tmaDNOut[], 
                          double &slopeOut[])
{
    // Use temporary buffer for calculations
    Calculate_TMA_centered(rates_total, limit, applied_price, buffer1);
    
    // Copy results to output buffers
    for(int i = limit; i >= 0 && !IsStopped(); i--)
    {
        tmaCenteredOut[i] = buffer1[i];
        tmaUPOut[i] = EMPTY_VALUE;
        tmaDNOut[i] = EMPTY_VALUE;
        slopeOut[i] = EMPTY_VALUE;
        
        if(i < rates_total - 1)
        {
            slopeOut[i] = buffer1[i] - buffer1[i+1];
            
            if(slopeOut[i] >= 0)
            {
                tmaUPOut[i] = buffer1[i];
            }
            else
            {
                tmaDNOut[i] = buffer1[i];
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate TMA Centered                                             |
//+------------------------------------------------------------------+
void Calculate_TMA_centered(int rates_total, int limit, ENUM_APPLIED_PRICE applied_price, double &out[])
{
    for(int i = limit; i >= 0 && !IsStopped(); i--)
    {
        bool isDebugBar = (i > 43190);
        
        if(isDebugBar)
        {
            Print("=== Processing bar ", i, " ===");
            Print("Starting TMA calculation");
            Print("Debug condition active: isDebugBar=", isDebugBar);
        }
        
        // Copy MA values with enhanced error checking
        ResetLastError();
        int copied = CopyBuffer(g_maHandle, 0, i, HalfLength * 2 + 1, ma);
        
        if(isDebugBar) Print("CopyBuffer result: copied=", copied, " required=", HalfLength * 2 + 1);
        
        if(copied != HalfLength * 2 + 1)
        {
            if(isDebugBar)
            {
                Print("Failed to copy MA values. Error=", GetLastError(), 
                      " Copied=", copied, 
                      " Required=", HalfLength * 2 + 1);
            }
            out[i] = EMPTY_VALUE;
            continue;
        }
        
        // Initialize min/max tracking with validation
        if(isDebugBar) Print("Starting min/max initialization");
        
        if(ArraySize(ma) < 1)
        {
            if(isDebugBar) Print("Error: MA array is empty");
            continue;
        }
        
        double minMA = ma[0];
        double maxMA = ma[0];
        
        if(isDebugBar) 
        {
            Print("=== Finding Min/Max Values ===");
            Print("Starting values: minMA=", DoubleToString(minMA, 8), 
                  " maxMA=", DoubleToString(maxMA, 8));
            Print("Array size=", ArraySize(ma));
            Print("Starting min/max calculation loop with HalfLength=", HalfLength);
        }
        
        // First pass - find min/max with explicit logging
        for(int j = 1; j < HalfLength * 2 + 1 && !IsStopped(); j++)
        {
            if(isDebugBar) 
            {
                if(j == 1) Print("Entering min/max loop");
                if(j % 10 == 0) Print("Processing min/max position ", j);
            }
            
            if(j >= ArraySize(ma))
            {
                if(isDebugBar) Print("Error: Array bounds exceeded at j=", j);
                break;
            }
            
            double prevMin = minMA;
            double prevMax = maxMA;
            
            minMA = MathMin(minMA, ma[j]);
            maxMA = MathMax(maxMA, ma[j]);
            
            if(isDebugBar && (minMA != prevMin || maxMA != prevMax))
            {
                Print("Update at position ", j, 
                      ": MA=", DoubleToString(ma[j], 8),
                      " MinMA=", DoubleToString(minMA, 8),
                      " MaxMA=", DoubleToString(maxMA, 8));
            }
        }
        
        if(isDebugBar) 
        {
            Print("Finished min/max calculation");
            Print("Final MinMA=", DoubleToString(minMA, 8));
            Print("Final MaxMA=", DoubleToString(maxMA, 8));
        }
        
        // Validate range with explicit logging
        double range = maxMA - minMA;
        
        if(isDebugBar)
        {
            Print("=== Range Validation ===");
            Print("Range=", DoubleToString(range, 8));
            Print("DBL_EPSILON=", DoubleToString(DBL_EPSILON, 8));
        }
        
        if(range < DBL_EPSILON)
        {
            if(isDebugBar) Print("Range too small - skipping calculation");
            out[i] = EMPTY_VALUE;
            continue;
        }
        
        // Calculate weighted sum with explicit logging
        double localSumProducts = 0.0;  // Renamed to avoid conflicts
        double localSumWeights = 0.0;   // Renamed to avoid conflicts
        
        if(isDebugBar) 
        {
            Print("=== Weight Calculations ===");
            Print("Starting weight calculation loop...");
        }
        
        for(int j = 0; j < HalfLength * 2 + 1; j++)
        {
            double weight = (j <= HalfLength) ? (double)(j + 1) : (double)(HalfLength * 2 + 1 - j);
            double norm = (ma[j] - minMA) / range;
            double product = norm * weight;
            
            double prevSumProducts = localSumProducts;
            double prevSumWeights = localSumWeights;
            
            localSumProducts += product;
            localSumWeights += weight;
            
            if(isDebugBar && (j % 10 == 0 || j == HalfLength * 2))
            {
                Print("Position ", j, ":");
                Print("  MA=", DoubleToString(ma[j], 8));
                Print("  Weight=", DoubleToString(weight, 8));
                Print("  Norm=", DoubleToString(norm, 8));
                Print("  Product=", DoubleToString(product, 8));
                Print("  SumProducts delta=", DoubleToString(localSumProducts - prevSumProducts, 8));
                Print("  SumWeights delta=", DoubleToString(localSumWeights - prevSumWeights, 8));
            }
        }
        
        if(isDebugBar) Print("Finished weight calculation loop");
        
        if(localSumWeights <= 0)
        {
            if(isDebugBar) Print("Invalid weight sum: ", DoubleToString(localSumWeights, 8));
            out[i] = EMPTY_VALUE;
            continue;
        }
        
        // Calculate final result with explicit logging
        double result = localSumProducts / localSumWeights;
        
        if(isDebugBar)
        {
            Print("=== Final Calculation ===");
            Print("Final SumProducts=", DoubleToString(localSumProducts, 8));
            Print("Final SumWeights=", DoubleToString(localSumWeights, 8));
            Print("Final Result=", DoubleToString(result, 8));
        }
        
        out[i] = result;
    }
}

//+------------------------------------------------------------------+
//| Calculate TMA Bands                                                |
//+------------------------------------------------------------------+
void Calculate_TMA_BANDS(const int rates_total, const int limitX, const ENUM_BAND_TYPE bandType,
                        double &tmaCenteredX[], double &tmaUPX[], double &tmaDNX[],
                        double &bandUP1X[], double &bandUP2X[], double &bandUP3X[], double &bandUP4X[],
                        double &bandDN1X[], double &bandDN2X[], double &bandDN3X[], double &bandDN4X[])
{
    double atr = 0;
    for(int i = limitX; i >= 0 && !IsStopped(); i--)
    {
        // Calculate ATR-style deviation
        double sum = 0;
        for(int j = 0; j < ATR_Period; j++)
        {
            double high = iHigh(Symbol(), PERIOD_CURRENT, i + j);
            double low = iLow(Symbol(), PERIOD_CURRENT, i + j);
            sum += high - low;
        }
        atr = sum / ATR_Period;
        
        // Use ATR for band distances
        double bandDistance1 = atr * ATR_Multiplier_Band1;
        double bandDistance2 = atr * ATR_Multiplier_Band2;
        double bandDistance3 = atr * ATR_Multiplier_Band3;
        double bandDistance4 = atr * ATR_Multiplier_Band4;

        double tmaValue = EMPTY_VALUE;  // Initialize with EMPTY_VALUE

        switch(bandType)
        {
            case Median_Band:
                tmaValue = tmaCenteredX[i];
                if(tmaValue == EMPTY_VALUE || MathIsValidNumber(tmaValue) == false)
                {
                    PrintFormat("Invalid TMA value at index %d: %f", i, tmaValue);
                    continue;
                }
                break;
                
            case HighLow_Bands:
                tmaValue = tmaUPX[i];
                if(tmaValue == EMPTY_VALUE || MathIsValidNumber(tmaValue) == false)
                {
                    PrintFormat("Invalid TMA High value at index %d: %f", i, tmaValue);
                    continue;
                }
                
                // Calculate upper bands
                if(MathIsValidNumber(tmaValue))
                {
                    bandUP1X[i] = tmaValue + (bandDistance1 * Point());
                    bandUP2X[i] = tmaValue + (bandDistance2 * Point());
                    bandUP3X[i] = tmaValue + (bandDistance3 * Point());
                    bandUP4X[i] = tmaValue + (bandDistance4 * Point());
                }
                
                // Get low value for lower bands
                tmaValue = tmaDNX[i];
                if(tmaValue == EMPTY_VALUE || MathIsValidNumber(tmaValue) == false)
                {
                    PrintFormat("Invalid TMA Low value at index %d: %f", i, tmaValue);
                    continue;
                }
                break;
        }
        
        // Add validation before calculating bands
        if(MathIsValidNumber(tmaValue))
        {
            if(bandType == Median_Band)
            {
                bandUP1X[i] = tmaValue + (bandDistance1 * Point());
                bandUP2X[i] = tmaValue + (bandDistance2 * Point());
                bandUP3X[i] = tmaValue + (bandDistance3 * Point());
                bandUP4X[i] = tmaValue + (bandDistance4 * Point());
            }
            
            bandDN1X[i] = tmaValue - (bandDistance1 * Point());
            bandDN2X[i] = tmaValue - (bandDistance2 * Point());
            bandDN3X[i] = tmaValue - (bandDistance3 * Point());
            bandDN4X[i] = tmaValue - (bandDistance4 * Point());
        }
        else
        {
            PrintFormat("Invalid calculation at index %d, tmaValue: %f", i, tmaValue);
        }
    }
}

//+------------------------------------------------------------------+
//| Get Applied Price                                                  |
//+------------------------------------------------------------------+
double GetAppliedPrice(ENUM_APPLIED_PRICE applied_price_type, int index)
{
    switch(applied_price_type)
    {
        case PRICE_CLOSE:    return price[index];
        case PRICE_OPEN:     return iOpen(Symbol(), PERIOD_CURRENT, index);
        case PRICE_HIGH:     return iHigh(Symbol(), PERIOD_CURRENT, index);
        case PRICE_LOW:      return iLow(Symbol(), PERIOD_CURRENT, index);
        case PRICE_MEDIAN:   return (iHigh(Symbol(), PERIOD_CURRENT, index) + iLow(Symbol(), PERIOD_CURRENT, index)) / 2.0;
        case PRICE_TYPICAL:  return (iHigh(Symbol(), PERIOD_CURRENT, index) + iLow(Symbol(), PERIOD_CURRENT, index) + price[index]) / 3.0;
        case PRICE_WEIGHTED: return (iHigh(Symbol(), PERIOD_CURRENT, index) + iLow(Symbol(), PERIOD_CURRENT, index) + price[index] * 2) / 4.0;
        default: return price[index];
    }
}

//+------------------------------------------------------------------+
//| Get Slope Momentum Values                                          |
//+------------------------------------------------------------------+
void Get_SlopeMomentumValues(string symbol, ENUM_TIMEFRAMES timeFrame, int iBar)
{
    // Skip if we already processed this bar
    if(signalSended[iBar] != 0)
        return;
        
    double dSlope = slope[iBar];
    double dEntryPrice = price[iBar];
    
    int iSignalDirection = OP_NONE;
    int iSignalType = 0;
    int iBandPosition = 0;
    
    // Check band penetration
    if(dEntryPrice < bandDN1[iBar])
    {
        iSignalDirection = OP_BUY;
        iBandPosition = Get_BandPosition(dEntryPrice, iBar, false);
        iSignalType = (dSlope >= 0) ? LONG_ENTRY_TREND : LONG_ENTRY_COUNTER;
    }
    else if(dEntryPrice > bandUP1[iBar])
    {
        iSignalDirection = OP_SELL;
        iBandPosition = Get_BandPosition(dEntryPrice, iBar, true);
        iSignalType = (dSlope <= 0) ? SHORT_ENTRY_TREND : SHORT_ENTRY_COUNTER;
    }
    
    // Send signal if conditions are met
    if(iSignalDirection != OP_NONE && iBandPosition >= (int)Threshold_Band + 1)
    {
        signalSended[iBar] = iSignalType;
        
        if(SendSignal_Alerts || SendSignal_Emails)
        {
            string signal = (iSignalDirection == OP_BUY) ? "LONG" : "SHORT";
            string trend = (iSignalType == LONG_ENTRY_TREND || iSignalType == SHORT_ENTRY_TREND) ? "Trend" : "CounterTrend";
            string alert = StringFormat("%s, %s, %s entry %s%s, Band: %d",
                symbol,
                Get_PeriodString(timeFrame),
                signal,
                trend,
                TimeToString(iTime(symbol, timeFrame, iBar)),
                iBandPosition);
                
            if(SendSignal_Alerts) Alert(alert);
            if(SendSignal_Emails) SendMail(subjectEmailAlert, alert);
        }
    }
}

//+------------------------------------------------------------------+
//| Send Alerts                                                        |
//+------------------------------------------------------------------+
void SendAlerts(int iBar, int iSignalDirection, string sSymbol, ENUM_TIMEFRAMES iPeriod, double &slopeX[])
{
    if(SendSignal_Alerts == false && SendSignal_Emails == false) return;
    if(signalSended[iBar] != 0 && signalSended[iBar] != EMPTY_VALUE) return;

    string sPeriod = " (" + Get_PeriodString(iPeriod) + ") ";
    double dEntryPrice = GetAppliedPrice(PRICE_CLOSE, iBar);
    string sEntryPrice = " " + DoubleToString(dEntryPrice, _Digits);
    string sTime = "  " + TimeToString(TimeCurrent(), TIME_MINUTES|TIME_SECONDS) + "  ";
    string sBarTime = "  Bar: " + TimeToString(iTime(sSymbol, iPeriod, iBar), TIME_MINUTES|TIME_SECONDS) + "  ";

    int iBandPosition = 0, iSignalType = 0;
    string sText, sTextAlert;
    double dSlope = slopeX[iBar];

    // LONG Entry Signal
    if(iSignalDirection == OP_BUY)
    {
        if(dEntryPrice < bandDN4[iBar]) iBandPosition = 4;
        else if(dEntryPrice < bandDN3[iBar]) iBandPosition = 3;
        else if(dEntryPrice < bandDN2[iBar]) iBandPosition = 2;
        else if(dEntryPrice < bandDN1[iBar]) iBandPosition = 1;

        if(dSlope > 0) {iSignalType = LONG_ENTRY_TREND; sText = " LONG entry Trend";}
        else if(dSlope < 0) {iSignalType = LONG_ENTRY_COUNTER; sText = " LONG entry CounterTrend";}
    }
    // SHORT Entry Signal
    else if(iSignalDirection == OP_SELL)
    {
        if(dEntryPrice > bandUP4[iBar]) iBandPosition = 4;
        else if(dEntryPrice > bandUP3[iBar]) iBandPosition = 3;
        else if(dEntryPrice > bandUP2[iBar]) iBandPosition = 2;
        else if(dEntryPrice > bandUP1[iBar]) iBandPosition = 1;

        if(dSlope < 0) {iSignalType = SHORT_ENTRY_TREND; sText = " SHORT entry Trend";}
        else if(dSlope > 0) {iSignalType = SHORT_ENTRY_COUNTER; sText = " SHORT entry CounterTrend";}
    }

    // Send alerts
    sTextAlert = sSymbol + sPeriod + sText + sTime + "  HuskyBand: " + IntegerToString(iBandPosition);

    if(SendSignal_Alerts) Alert(sTextAlert);
    if(SendSignal_Emails) SendMail(subjectEmailAlert, sTextAlert);

    signalSended[iBar] = iSignalType;
}

//+------------------------------------------------------------------+
//| Get Period String                                                  |
//+------------------------------------------------------------------+
string Get_PeriodString(ENUM_TIMEFRAMES iPeriod)
{
    int seconds = PeriodSeconds(iPeriod);
    
    // Handle standard timeframes first
    switch(iPeriod)
    {
        case PERIOD_MN1:  return "MN1";
        case PERIOD_W1:   return "W1";
        case PERIOD_D1:   return "D1";
    }
    
    // Handle hour-based timeframes
    if(seconds >= 3600)  // If period is 1 hour or more
    {
        int hours = seconds / 3600;
        return "H" + IntegerToString(hours);
    }
    
    // Handle minute-based timeframes
    int minutes = seconds / 60;
    return "M" + IntegerToString(minutes);
}

//+------------------------------------------------------------------+
//| Get Direction String                                               |
//+------------------------------------------------------------------+
string Get_DirectionString(int iCondition)
{
    switch(iCondition)
    {
        case OP_BUY:  return "LONG";
        case OP_SELL: return "SHORT";
        case OP_NONE: return "NONE";
        default:      return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(g_maHandle != INVALID_HANDLE) {
        IndicatorRelease(g_maHandle);
    }
    if(Show_Comments)
        Comment("");
}

//+------------------------------------------------------------------+
//| Get Band Position                                                  |
//+------------------------------------------------------------------+
int Get_BandPosition(double priceValue, int iBar, bool isShort)
{
    if(isShort)
    {
        // For short positions, check upper bands
        if(priceValue > bandUP4[iBar]) return 4;
        if(priceValue > bandUP3[iBar]) return 3;
        if(priceValue > bandUP2[iBar]) return 2;
        if(priceValue > bandUP1[iBar]) return 1;
    }
    else
    {
        // For long positions, check lower bands
        if(priceValue < bandDN4[iBar]) return 4;
        if(priceValue < bandDN3[iBar]) return 3;
        if(priceValue < bandDN2[iBar]) return 2;
        if(priceValue < bandDN1[iBar]) return 1;
    }
    
    return 0;  // No band penetration
}

//+------------------------------------------------------------------+
//| Initialize Buffers                                                 |
//+------------------------------------------------------------------+
void InitializeBuffers()
{
    ArrayInitialize(tmaUP, EMPTY_VALUE);
    ArrayInitialize(tmaDN, EMPTY_VALUE);
    ArrayInitialize(tmaCentered, EMPTY_VALUE);
    ArrayInitialize(slope, EMPTY_VALUE);
    ArrayInitialize(bandUP1, EMPTY_VALUE);
    ArrayInitialize(bandUP2, EMPTY_VALUE);
    ArrayInitialize(bandUP3, EMPTY_VALUE);
    ArrayInitialize(bandUP4, EMPTY_VALUE);
    ArrayInitialize(bandDN1, EMPTY_VALUE);
    ArrayInitialize(bandDN2, EMPTY_VALUE);
    ArrayInitialize(bandDN3, EMPTY_VALUE);
    ArrayInitialize(bandDN4, EMPTY_VALUE);
    ArrayInitialize(signalLongEntry, EMPTY_VALUE);
    ArrayInitialize(signalShortEntry, EMPTY_VALUE);
    ArrayInitialize(signalLongExit, EMPTY_VALUE);
    ArrayInitialize(signalShortExit, EMPTY_VALUE);
}