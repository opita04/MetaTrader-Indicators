//+------------------------------------------------------------------+
//|                                      CurrencyStrengthHistogram.mq4 |
//|                        Currency Strength Multi-Timeframe Histogram |
//+------------------------------------------------------------------+
#property copyright "Currency Strength Histogram"
#property version   "1.00"
#property strict
#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   8
#property indicator_minimum 0
#property indicator_maximum 5

//--- plot TF1 UP
#property indicator_label1  "TF1 UP"
#property indicator_type1   DRAW_ARROW

//--- plot TF1 DOWN
#property indicator_label2  "TF1 DOWN"
#property indicator_type2   DRAW_ARROW

//--- plot TF2 UP
#property indicator_label3  "TF2 UP"
#property indicator_type3   DRAW_ARROW

//--- plot TF2 DOWN
#property indicator_label4  "TF2 DOWN"
#property indicator_type4   DRAW_ARROW

//--- plot TF3 UP
#property indicator_label5  "TF3 UP"
#property indicator_type5   DRAW_ARROW

//--- plot TF3 DOWN
#property indicator_label6  "TF3 DOWN"
#property indicator_type6   DRAW_ARROW

//--- plot TF4 UP
#property indicator_label7  "TF4 UP"
#property indicator_type7   DRAW_ARROW

//--- plot TF4 DOWN
#property indicator_label8  "TF4 DOWN"
#property indicator_type8   DRAW_ARROW

//--- Indicator Parameters
extern string IndicatorName = "CurrencyStrengthWizard"; // Source Indicator Name (REQUIRED)
extern int    Line1Buffer = 0;             // Line 1 Buffer Number
extern int    Line2Buffer = 1;             // Line 2 Buffer Number

extern int    NumTimeframes = 4;            // Number of Timeframes to Display (1-4)
extern ENUM_TIMEFRAMES Timeframe1 = PERIOD_H4;   // Timeframe 1
extern ENUM_TIMEFRAMES Timeframe2 = PERIOD_H1;   // Timeframe 2
extern ENUM_TIMEFRAMES Timeframe3 = PERIOD_M30;  // Timeframe 3
extern ENUM_TIMEFRAMES Timeframe4 = PERIOD_M5;   // Timeframe 4

extern int    BarsToLookBack = 100;         // Bars to Look Back for Data

//--- Tag Settings
extern bool   ShowTags = true;              // Show timeframe labels on the right
extern string TagFont = "Arial Black";      // Font for timeframe labels
extern int    TagFontSize = 8;              // Font size for timeframe labels
extern color  TagColor = clrBisque;         // Color for timeframe labels

//--- Indicator Buffers
double TF1UpBuffer[];
double TF1DownBuffer[];
double TF2UpBuffer[];
double TF2DownBuffer[];
double TF3UpBuffer[];
double TF3DownBuffer[];
double TF4UpBuffer[];
double TF4DownBuffer[];

//--- Global Variables
ENUM_TIMEFRAMES Timeframes[4];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
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

    // Validate and set number of timeframes (1-4)
    if(NumTimeframes < 1) NumTimeframes = 1;
    if(NumTimeframes > 4) NumTimeframes = 4;

    // Initialize timeframes array
    Timeframes[0] = Timeframe1;
    Timeframes[1] = Timeframe2;
    Timeframes[2] = Timeframe3;
    Timeframes[3] = Timeframe4;

    // Validate timeframes - cannot show lower timeframes than current chart
    ENUM_TIMEFRAMES currentTF = Period();
    int validTimeframes = 0;
    ENUM_TIMEFRAMES validTFs[4];

    for(int i = 0; i < 4; i++)
    {
        if(Timeframes[i] >= currentTF)
        {
            validTFs[validTimeframes] = Timeframes[i];
            validTimeframes++;
        }
    }

    // Update NumTimeframes to reflect only valid timeframes
    NumTimeframes = validTimeframes;

    // Reassign valid timeframes back to Timeframes array
    for(int i = 0; i < 4; i++)
    {
        if(i < validTimeframes)
            Timeframes[i] = validTFs[i];
        else
            Timeframes[i] = currentTF; // Set to current TF to avoid issues
    }

    // Set up indicator buffers
    IndicatorBuffers(8);

    // Main buffers
    int i=0;
    SetIndexBuffer(i++,TF1UpBuffer,INDICATOR_DATA);
    SetIndexBuffer(i++,TF1DownBuffer,INDICATOR_DATA);
    SetIndexBuffer(i++,TF2UpBuffer,INDICATOR_DATA);
    SetIndexBuffer(i++,TF2DownBuffer,INDICATOR_DATA);
    SetIndexBuffer(i++,TF3UpBuffer,INDICATOR_DATA);
    SetIndexBuffer(i++,TF3DownBuffer,INDICATOR_DATA);
    SetIndexBuffer(i++,TF4UpBuffer,INDICATOR_DATA);
    SetIndexBuffer(i++,TF4DownBuffer,INDICATOR_DATA);

    // Set index styles for arrows
    SetIndexStyle(0,DRAW_ARROW,EMPTY,2,clrSkyBlue);
    SetIndexArrow(0,110);
    SetIndexEmptyValue(0,EMPTY_VALUE);

    SetIndexStyle(1,DRAW_ARROW,EMPTY,2,clrTomato);
    SetIndexArrow(1,110);
    SetIndexEmptyValue(1,EMPTY_VALUE);

    SetIndexStyle(2,DRAW_ARROW,EMPTY,2,clrSkyBlue);
    SetIndexArrow(2,110);
    SetIndexEmptyValue(2,EMPTY_VALUE);

    SetIndexStyle(3,DRAW_ARROW,EMPTY,2,clrTomato);
    SetIndexArrow(3,110);
    SetIndexEmptyValue(3,EMPTY_VALUE);

    SetIndexStyle(4,DRAW_ARROW,EMPTY,2,clrSkyBlue);
    SetIndexArrow(4,110);
    SetIndexEmptyValue(4,EMPTY_VALUE);

    SetIndexStyle(5,DRAW_ARROW,EMPTY,2,clrTomato);
    SetIndexArrow(5,110);
    SetIndexEmptyValue(5,EMPTY_VALUE);

    SetIndexStyle(6,DRAW_ARROW,EMPTY,2,clrSkyBlue);
    SetIndexArrow(6,110);
    SetIndexEmptyValue(6,EMPTY_VALUE);

    SetIndexStyle(7,DRAW_ARROW,EMPTY,2,clrTomato);
    SetIndexArrow(7,110);
    SetIndexEmptyValue(7,EMPTY_VALUE);

    // Set indicator name
    string tfString = GetTimeframeString(Timeframes[0]);
    for(int j = 1; j < NumTimeframes; j++)
    {
        tfString = tfString + "/" + GetTimeframeString(Timeframes[j]);
    }
    IndicatorShortName("CS Histogram (" + Symbol() + " - " + tfString + ")");

    return(0);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
int deinit()
{
    // Clean up text objects
    for(int i=1; i<=4; i++)
    {
        ObjectDelete("TF_"+IntegerToString(i));
    }
    return(0);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
{
    int counted_bars = IndicatorCounted();
    int maxBarsToProcess = MathMin(Bars, BarsToLookBack);
    int limit;

    if(counted_bars > 0)
        limit = Bars - counted_bars;
    else
        limit = maxBarsToProcess - 1;

    // Initialize buffers
    if(counted_bars == 0)
    {
        ArrayInitialize(TF1UpBuffer, EMPTY_VALUE);
        ArrayInitialize(TF1DownBuffer, EMPTY_VALUE);
        ArrayInitialize(TF2UpBuffer, EMPTY_VALUE);
        ArrayInitialize(TF2DownBuffer, EMPTY_VALUE);
        ArrayInitialize(TF3UpBuffer, EMPTY_VALUE);
        ArrayInitialize(TF3DownBuffer, EMPTY_VALUE);
        ArrayInitialize(TF4UpBuffer, EMPTY_VALUE);
        ArrayInitialize(TF4DownBuffer, EMPTY_VALUE);
    }

    int rv = Bars;
    int k = 1;

    // Process each valid timeframe
    for(int tf_idx = 0; tf_idx < NumTimeframes; tf_idx++)
    {
        ENUM_TIMEFRAMES current_tf = Timeframes[tf_idx];

        for(int i = limit; i >= 0; i--)
        {
            double strengthValue = GetStrengthValue(i, current_tf);
            if(strengthValue != EMPTY_VALUE && strengthValue != 0.0)
            {
                if(strengthValue > 0)
                {
                    // Set the appropriate buffer based on timeframe index
                    switch(tf_idx)
                    {
                        case 0:
                            TF1UpBuffer[i] = k;
                            TF1DownBuffer[i] = EMPTY_VALUE;
                            break;
                        case 1:
                            TF2UpBuffer[i] = k;
                            TF2DownBuffer[i] = EMPTY_VALUE;
                            break;
                        case 2:
                            TF3UpBuffer[i] = k;
                            TF3DownBuffer[i] = EMPTY_VALUE;
                            break;
                        case 3:
                            TF4UpBuffer[i] = k;
                            TF4DownBuffer[i] = EMPTY_VALUE;
                            break;
                    }
                }
                else
                {
                    // Set the appropriate buffer based on timeframe index
                    switch(tf_idx)
                    {
                        case 0:
                            TF1UpBuffer[i] = EMPTY_VALUE;
                            TF1DownBuffer[i] = k;
                            break;
                        case 1:
                            TF2UpBuffer[i] = EMPTY_VALUE;
                            TF2DownBuffer[i] = k;
                            break;
                        case 2:
                            TF3UpBuffer[i] = EMPTY_VALUE;
                            TF3DownBuffer[i] = k;
                            break;
                        case 3:
                            TF4UpBuffer[i] = EMPTY_VALUE;
                            TF4DownBuffer[i] = k;
                            break;
                    }
                }
            }
            else
            {
                // Clear all buffers for this timeframe
                switch(tf_idx)
                {
                    case 0:
                        TF1UpBuffer[i] = EMPTY_VALUE;
                        TF1DownBuffer[i] = EMPTY_VALUE;
                        break;
                    case 1:
                        TF2UpBuffer[i] = EMPTY_VALUE;
                        TF2DownBuffer[i] = EMPTY_VALUE;
                        break;
                    case 2:
                        TF3UpBuffer[i] = EMPTY_VALUE;
                        TF3DownBuffer[i] = EMPTY_VALUE;
                        break;
                    case 3:
                        TF4UpBuffer[i] = EMPTY_VALUE;
                        TF4DownBuffer[i] = EMPTY_VALUE;
                        break;
                }
                rv = 0;
            }
        }

        k++; // Increment level for next timeframe
    }

    // Clear unused timeframe buffers completely
    if(NumTimeframes < 4)
    {
        for(int i = limit; i >= 0; i--)
        {
            // Clear TF4 buffers if not used
            if(NumTimeframes < 4)
            {
                TF4UpBuffer[i] = EMPTY_VALUE;
                TF4DownBuffer[i] = EMPTY_VALUE;
            }
            // Clear TF3 buffers if not used
            if(NumTimeframes < 3)
            {
                TF3UpBuffer[i] = EMPTY_VALUE;
                TF3DownBuffer[i] = EMPTY_VALUE;
            }
            // Clear TF2 buffers if not used
            if(NumTimeframes < 2)
            {
                TF2UpBuffer[i] = EMPTY_VALUE;
                TF2DownBuffer[i] = EMPTY_VALUE;
            }
            // TF1 is always used if NumTimeframes >= 1, so no need to clear it
        }
    }

    // Draw timeframe labels on the right side
    if(ShowTags)
    {
        for(int i=1; i<=NumTimeframes; i++)
        {
            string tfs = GetTimeframeString(Timeframes[i-1]);
            DrawText("TF_"+IntegerToString(i), tfs, Time[0]+Period()*60, i, TagColor, TagFont, TagFontSize, false, ANCHOR_LEFT);
        }

        // Clear unused labels
        for(int i=NumTimeframes+1; i<=4; i++)
        {
            ObjectDelete("TF_"+IntegerToString(i));
        }
    }

    return rv;
}


//+------------------------------------------------------------------+
//| Draw text on chart                                               |
//+------------------------------------------------------------------+
void DrawText(string name, string text, datetime time, double price, color col, string font, int fontSize, bool back, int anchor)
{
    if(ObjectFind(name) < 0)
    {
        ObjectCreate(name, OBJ_TEXT, ChartWindowFind(), time, price);
    }
    if(ObjectFind(name) >= 0)
    {
        ObjectSetText(name, text);
        ObjectSet(name, OBJPROP_COLOR, col);
        ObjectSet(name, OBJPROP_FONT, font);
        ObjectSet(name, OBJPROP_FONTSIZE, fontSize);
        ObjectSet(name, OBJPROP_BACK, back);
        ObjectSet(name, OBJPROP_ANCHOR, anchor);
        ObjectMove(name, 0, time, price);
    }
}


//+------------------------------------------------------------------+
//| Get Currency Strength Value for a specific bar and timeframe     |
//+------------------------------------------------------------------+
double GetStrengthValue(int bar, ENUM_TIMEFRAMES timeframe)
{
    string symbol = Symbol(); // Use current chart's symbol only

    // For current timeframe, use bar directly
    if(timeframe == Period())
    {
        double line1_val = iCustom(symbol, timeframe, IndicatorName, Line1Buffer, bar);
        double line2_val = iCustom(symbol, timeframe, IndicatorName, Line2Buffer, bar);

        // Check if we have valid data
        if(line1_val == EMPTY_VALUE || line2_val == EMPTY_VALUE)
            return EMPTY_VALUE;

        // Calculate strength as difference between lines
        return line1_val - line2_val;
    }

    // For higher timeframes, find the correct bar using bar time
    datetime barTime = Time[bar];

    // Find the bar on the higher timeframe that contains this time
    int tf_bar = iBarShift(symbol, timeframe, barTime, false);

    if(tf_bar < 0)
        return EMPTY_VALUE;

    double line1_val = iCustom(symbol, timeframe, IndicatorName, Line1Buffer, tf_bar);
    double line2_val = iCustom(symbol, timeframe, IndicatorName, Line2Buffer, tf_bar);

    // Check if we have valid data
    if(line1_val == EMPTY_VALUE || line2_val == EMPTY_VALUE)
        return EMPTY_VALUE;

    // Calculate strength as difference between lines
    return line1_val - line2_val;
}

//+------------------------------------------------------------------+
//| Convert Timeframe to String                                      |
//+------------------------------------------------------------------+
string GetTimeframeString(ENUM_TIMEFRAMES timeframe)
{
    switch(timeframe)
    {
        case PERIOD_M1: return "M1";
        case PERIOD_M5: return "M5";
        case PERIOD_M15: return "M15";
        case PERIOD_M30: return "M30";
        case PERIOD_H1: return "H1";
        case PERIOD_H4: return "H4";
        case PERIOD_D1: return "D1";
        case PERIOD_W1: return "W1";
        case PERIOD_MN1: return "MN1";
        default: return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
