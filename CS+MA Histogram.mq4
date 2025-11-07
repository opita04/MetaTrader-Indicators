/*
File: CS+MA Histogram.mq4
Author: unknown
Source: unknown
Description: Currency Strength Histogram with optional integrated 2-MA source for one timeframe
Purpose: Display currency strength across multiple timeframes and optionally use an internal 2-MA data source
Parameters: See 'Indicator Parameters' section for data source and MA settings
Version: 1.00
Last Modified: 2025.11.06
Compatibility: MetaTrader 4 (MT4)
*/
//+------------------------------------------------------------------+
#property copyright "Currency Strength Histogram"
#property version   "1.00"
#property strict
#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   8
#property indicator_minimum 0
#property indicator_maximum 4

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
#property indicator_label7  "CS Line1"
#property indicator_type7   DRAW_LINE
#property indicator_label8  "CS Line2"
#property indicator_type8   DRAW_LINE

//--- Indicator Parameters
extern string IndicatorName = "CurrencyStrengthWizard"; // Source Indicator Name (REQUIRED)
extern int    Line1Buffer = 0;             // Line 1 Buffer Number
extern int    Line2Buffer = 1;             // Line 2 Buffer Number
extern string IndicatorSubfolder = "";   // Optional subfolder for the custom indicator
extern bool   ShowCustomHistory = true;    // Show history lines from the custom CS indicator
extern color  CustomLine1Color = clrYellow; // Color for Line1 history
extern color  CustomLine2Color = clrAqua;  // Color for Line2 history
extern int    CustomLineWidth = 1;         // Line width for history plots

extern int    NumTimeframes = 3;            // Number of Timeframes to Display (1-3)
extern ENUM_TIMEFRAMES Timeframe1 = PERIOD_H1;   // Timeframe 1
extern ENUM_TIMEFRAMES Timeframe2 = PERIOD_M5;   // Timeframe 2
extern ENUM_TIMEFRAMES Timeframe3 = PERIOD_M5;   // Timeframe 3

extern int    BarsToLookBack = 500;         // Bars to Look Back for Data
extern bool DebugMode = false;              // Enable debug prints for troubleshooting

//--- ====================== Data Source Settings ==================
// Per-timeframe data source: 0 = custom iCustom(IndicatorName), 1 = 2-MA calculation
enum DataSource { CUSTOM=0, MA2=1 };
extern DataSource TF1Source = CUSTOM;        // Source for Timeframe1
extern DataSource TF2Source = CUSTOM;        // Source for Timeframe2
extern DataSource TF3Source = MA2;        // Source for Timeframe3

//--- 2-MA parameters (used when DataSource == MA2)
extern int MA_MA1_Periods = 34;
extern ENUM_APPLIED_PRICE MA1_Price = PRICE_CLOSE;
extern ENUM_MA_METHOD MA1_Method = MODE_EMA;

extern int MA_MA2_Periods = 34;
extern ENUM_APPLIED_PRICE MA2_Price = PRICE_MEDIAN;
extern ENUM_MA_METHOD MA2_Method = MODE_EMA;
// The 2MA calculation is done internally using the MA parameters below.
// No external indicator calls are made for the MA2 data source.

//--- ====================== Tag Settings ======================
extern bool   ShowTags = true;              // Show timeframe labels on the right
extern string TagFont = "Arial Black";      // Font for timeframe labels
extern int    TagFontSize = 8;              // Font size for timeframe labels
extern color  TagColor = clrBisque;         // Color for timeframe labels

//--- =================== Histogram Color Settings ==================
// Editable colors for each timeframe/up-down plot
extern color TF1UpColor   = clrSkyBlue;     // TF1 up color
extern color TF1DownColor = clrTomato;      // TF1 down color
extern color TF2UpColor   = clrSkyBlue;     // TF2 up color
extern color TF2DownColor = clrTomato;      // TF2 down color
extern color TF3UpColor   = clrSkyBlue;     // TF3 up color
extern color TF3DownColor = clrTomato;      // TF3 down color

//--- ================== Vertical Line Settings ==================
extern bool   ShowVerticalLines = true;     // Show vertical lines at TF1 histogram start
extern int    VerticalLineStyle = STYLE_SOLID; // Style for vertical lines
extern int    VerticalLineWidth = 3;        // Width for vertical lines

//--- ================== Alert Settings ==================
extern bool   AlertsEnabled = true;         // Master switch for alerts
extern bool   AlertPopup    = true;         // Show popup alerts
extern bool   AlertPush     = true;         // Send push notifications (requires terminal settings)
extern bool   AlertsOnlyOneTF = false;      // If true, only alert for one selected TF
extern int    AlertTFIndex = 1;             // 1..3 index into displayed Timeframes[]
extern bool   AlertSound   = true;          // Play sound on alert
extern string AlertSoundFile = "alert.wav"; // Sound file located in terminal/sounds

//--- Indicator Buffers
double TF1UpBuffer[];
double TF1DownBuffer[];
double TF2UpBuffer[];
double TF2DownBuffer[];
double TF3UpBuffer[];
double TF3DownBuffer[];
// History display buffers for the custom Currency Strength indicator
double CSLine1History[];
double CSLine2History[];

//--- Global Variables
ENUM_TIMEFRAMES Timeframes[3];
int      LastAlertState[3];          // -1 = down, 0 = none, 1 = up
datetime LastAlertBarTime[3];        // chart timeframe bar time when last alert fired per TF index

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

    // Validate and set number of timeframes (1-3)
    if(NumTimeframes < 1) NumTimeframes = 1;
    if(NumTimeframes > 3) NumTimeframes = 3;

    // Initialize timeframes array
    Timeframes[0] = Timeframe1;
    Timeframes[1] = Timeframe2;
    Timeframes[2] = Timeframe3;

    // Validate timeframes - cannot show lower timeframes than current chart
    int currentPeriod = Period();
    ENUM_TIMEFRAMES currentTF = (ENUM_TIMEFRAMES)currentPeriod;
    int validTimeframes = 0;
    ENUM_TIMEFRAMES validTFs[3];
    // Initialize array to avoid uninitialized variable warning
    for(int init_i = 0; init_i < 3; init_i++)
        validTFs[init_i] = currentTF;

    for(int i = 0; i < NumTimeframes; i++)  // Only check the requested number of timeframes
    {
        if(Timeframes[i] >= currentTF)
        {
            validTFs[validTimeframes] = Timeframes[i];
            validTimeframes++;
        }
    }

    // Update NumTimeframes to reflect only valid timeframes among the requested ones
    NumTimeframes = validTimeframes;

    // Reassign valid timeframes back to Timeframes array
    for(int i = 0; i < 3; i++)
    {
        if(i < validTimeframes)
            Timeframes[i] = validTFs[i];
        else
            Timeframes[i] = currentTF; // Set to current TF to avoid issues
    }

    // Set up indicator buffers (including two history line plots)
    IndicatorBuffers(8);

    // Main buffers
    int i=0;
    SetIndexBuffer(i++,TF1UpBuffer,INDICATOR_DATA);
    SetIndexBuffer(i++,TF1DownBuffer,INDICATOR_DATA);
    SetIndexBuffer(i++,TF2UpBuffer,INDICATOR_DATA);
    SetIndexBuffer(i++,TF2DownBuffer,INDICATOR_DATA);
    SetIndexBuffer(i++,TF3UpBuffer,INDICATOR_DATA);
    SetIndexBuffer(i++,TF3DownBuffer,INDICATOR_DATA);
    // History lines from the custom Currency Strength indicator
    SetIndexBuffer(i++,CSLine1History,INDICATOR_DATA);
    SetIndexBuffer(i++,CSLine2History,INDICATOR_DATA);

    // Set index styles for arrows
    SetIndexStyle(0,DRAW_ARROW,EMPTY,2,TF1UpColor);
    SetIndexArrow(0,110);
    SetIndexEmptyValue(0,EMPTY_VALUE);

    SetIndexStyle(1,DRAW_ARROW,EMPTY,2,TF1DownColor);
    SetIndexArrow(1,110);
    SetIndexEmptyValue(1,EMPTY_VALUE);

    SetIndexStyle(2,DRAW_ARROW,EMPTY,2,TF2UpColor);
    SetIndexArrow(2,110);
    SetIndexEmptyValue(2,EMPTY_VALUE);

    SetIndexStyle(3,DRAW_ARROW,EMPTY,2,TF2DownColor);
    SetIndexArrow(3,110);
    SetIndexEmptyValue(3,EMPTY_VALUE);

    SetIndexStyle(4,DRAW_ARROW,EMPTY,2,TF3UpColor);
    SetIndexArrow(4,110);
    SetIndexEmptyValue(4,EMPTY_VALUE);

    SetIndexStyle(5,DRAW_ARROW,EMPTY,2,TF3DownColor);
    SetIndexArrow(5,110);
    SetIndexEmptyValue(5,EMPTY_VALUE);

    // History line styles
    SetIndexStyle(6,DRAW_LINE,EMPTY,CustomLineWidth,CustomLine1Color);
    SetIndexEmptyValue(6,EMPTY_VALUE);

    SetIndexStyle(7,DRAW_LINE,EMPTY,CustomLineWidth,CustomLine2Color);
    SetIndexEmptyValue(7,EMPTY_VALUE);

    // Set indicator name
    string tfString = GetTimeframeString(Timeframes[0]);
    for(int j = 1; j < NumTimeframes; j++)
    {
        tfString = tfString + "/" + GetTimeframeString(Timeframes[j]);
    }
    IndicatorShortName("CS Histogram (" + Symbol() + " - " + tfString + ")");

    // Initialize alert state tracking
    for(int ai = 0; ai < 3; ai++)
    {
        LastAlertState[ai] = 0;
        LastAlertBarTime[ai] = 0;
    }

    // Clamp single TF alert index
    if(AlertsOnlyOneTF)
    {
        if(AlertTFIndex < 1) AlertTFIndex = 1;
        if(AlertTFIndex > NumTimeframes) AlertTFIndex = NumTimeframes;
    }

    return(0);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
int deinit()
{
    // Clean up text objects
    for(int i=1; i<=3; i++)
    {
        ObjectDelete("TF_"+IntegerToString(i));
    }
    // Clean up vertical line objects (delete any object whose name starts with "VLine_")
    int totalObjects = ObjectsTotal();
    for(int objIdx = totalObjects-1; objIdx >= 0; objIdx--)
    {
        string objName = ObjectName(objIdx);
        if(StringFind(objName, "VLine_") == 0)
            ObjectDelete(objName);
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
        ArrayInitialize(CSLine1History, EMPTY_VALUE);
        ArrayInitialize(CSLine2History, EMPTY_VALUE);
    }

    int rv = Bars;
    // Use fixed level spacing so remaining timeframes compress without leaving large gaps
    double levelStep = 1.0;
    double currentLevel = 1.0;

    // Populate custom indicator history lines for the current chart timeframe
    // Always fetch up to BarsToLookBack (or available Bars) so history length matches input
    if(ShowCustomHistory)
    {
        int historyBars = MathMin(Bars, BarsToLookBack);
        for(int hi = historyBars - 1; hi >= 0; hi--)
        {
            double l1 = EMPTY_VALUE, l2 = EMPTY_VALUE;
            // Try primary name, fall back to subfolder if needed
            string name = IndicatorName;
            l1 = iCustom(Symbol(), Period(), name, Line1Buffer, hi);
            l2 = iCustom(Symbol(), Period(), name, Line2Buffer, hi);
            if((l1 == EMPTY_VALUE || l2 == EMPTY_VALUE) && StringLen(IndicatorSubfolder) > 0)
            {
                name = IndicatorSubfolder + IndicatorName;
                l1 = iCustom(Symbol(), Period(), name, Line1Buffer, hi);
                l2 = iCustom(Symbol(), Period(), name, Line2Buffer, hi);
            }

            CSLine1History[hi] = (l1 != EMPTY_VALUE) ? l1 : EMPTY_VALUE;
            CSLine2History[hi] = (l2 != EMPTY_VALUE) ? l2 : EMPTY_VALUE;
        }

        // Clear any remaining history slots above historyBars to avoid stale values
        for(int hi = historyBars; hi < Bars; hi++)
        {
            CSLine1History[hi] = EMPTY_VALUE;
            CSLine2History[hi] = EMPTY_VALUE;
        }
    }

    // Process each valid timeframe
    for(int tf_idx = 0; tf_idx < NumTimeframes; tf_idx++)
    {
        ENUM_TIMEFRAMES current_tf = Timeframes[tf_idx];

        for(int i = limit; i >= 0; i--)
        {
            double strengthValue = GetStrengthValue(i, current_tf, tf_idx);
            if(strengthValue != EMPTY_VALUE && strengthValue != 0.0)
            {
                if(strengthValue > 0)
                {
                    // Set the appropriate buffer based on timeframe index
                    switch(tf_idx)
                    {
                        case 0:
                            TF1UpBuffer[i] = currentLevel;
                            TF1DownBuffer[i] = EMPTY_VALUE;
                            break;
                        case 1:
                            TF2UpBuffer[i] = currentLevel;
                            TF2DownBuffer[i] = EMPTY_VALUE;
                            break;
                        case 2:
                            TF3UpBuffer[i] = currentLevel;
                            TF3DownBuffer[i] = EMPTY_VALUE;
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
                            TF1DownBuffer[i] = currentLevel;
                            break;
                        case 1:
                            TF2UpBuffer[i] = EMPTY_VALUE;
                            TF2DownBuffer[i] = currentLevel;
                            break;
                        case 2:
                            TF3UpBuffer[i] = EMPTY_VALUE;
                            TF3DownBuffer[i] = currentLevel;
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
                }
                rv = 0;
            }
        }

        currentLevel += levelStep; // Increment level for next timeframe
    }

    // Clear unused timeframe buffers completely - clear ALL bars, not just limit
    int totalBars = MathMin(Bars, BarsToLookBack);
    for(int i = totalBars - 1; i >= 0; i--)
    {
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

    // Create vertical lines at TF1 up/down zone STARTS (match Arrows' zone-start logic)
    if(ShowVerticalLines && NumTimeframes >= 1)
    {
        // Remove any existing VLine objects created by this indicator to avoid duplicates
        for(int objIdx2 = ObjectsTotal() - 1; objIdx2 >= 0; objIdx2--)
        {
            string objName2 = ObjectName(objIdx2);
            if(StringFind(objName2, "VLine_") == 0 || objName2 == "VLine_Start" || objName2 == "VLine_End")
                ObjectDelete(objName2);
        }

        int prevState = 0; // 0 = none, 1 = up, -1 = down
        // Scan from oldest to newest (totalBars-1 down to 0)
        for(int b = totalBars - 1; b >= 0; b--)
        {
            int state = 0;
            if(TF1UpBuffer[b] != EMPTY_VALUE) state = 1;
            else if(TF1DownBuffer[b] != EMPTY_VALUE) state = -1;

            // If we enter a zone (state becomes up or down) and previous state is different, mark zone start
            if(state != 0 && state != prevState)
            {
                string vname = "VLine_" + IntegerToString((int)Time[b]);
                color vcol = (state == 1) ? TF1UpColor : TF1DownColor;
                DrawVerticalLine(vname, Time[b], vcol, VerticalLineStyle, VerticalLineWidth);
            }

            if(state != 0) prevState = state;
        }
    }
    else
    {
        // Clear all vertical lines if disabled
        for(int objIdx = ObjectsTotal() - 1; objIdx >= 0; objIdx--)
        {
            string objName = ObjectName(objIdx);
            if(StringFind(objName, "VLine_") == 0 || objName == "VLine_Start")
                ObjectDelete(objName);
        }
    }

    // Draw timeframe labels on the right side
    if(ShowTags)
    {
        double labelLevel = 1.0;
        for(int i=0; i<NumTimeframes; i++)
        {
            string tfs = GetTimeframeString(Timeframes[i]);
            // Position labels at the same levels as histogram bars. Place slightly to the right of current bar
            DrawText("TF_"+IntegerToString(i+1), tfs, Time[0] + Period()*60, labelLevel, TagColor, TagFont, TagFontSize, false, ANCHOR_LEFT);
            labelLevel += levelStep;
        }

        // Clear unused labels (support up to 3 labels)
        for(int i=NumTimeframes+1; i<=3; i++)
        {
            ObjectDelete("TF_"+IntegerToString(i));
        }
    }

    // Generate alerts on new zone starts per timeframe (compare bar 0 vs bar 1)
    if(AlertsEnabled && Bars >= 2)
    {
        for(int tf_idx = 0; tf_idx < NumTimeframes; tf_idx++)
        {
            // Skip non-selected TFs when single-TF alerting is enabled
            if(AlertsOnlyOneTF && (tf_idx != (AlertTFIndex - 1)))
                continue;

            int state0 = 0;
            int state1 = 0;

            switch(tf_idx)
            {
                case 0:
                    if(TF1UpBuffer[0]   != EMPTY_VALUE) state0 = 1; else if(TF1DownBuffer[0] != EMPTY_VALUE) state0 = -1;
                    if(TF1UpBuffer[1]   != EMPTY_VALUE) state1 = 1; else if(TF1DownBuffer[1] != EMPTY_VALUE) state1 = -1;
                    break;
                case 1:
                    if(TF2UpBuffer[0]   != EMPTY_VALUE) state0 = 1; else if(TF2DownBuffer[0] != EMPTY_VALUE) state0 = -1;
                    if(TF2UpBuffer[1]   != EMPTY_VALUE) state1 = 1; else if(TF2DownBuffer[1] != EMPTY_VALUE) state1 = -1;
                    break;
                case 2:
                    if(TF3UpBuffer[0]   != EMPTY_VALUE) state0 = 1; else if(TF3DownBuffer[0] != EMPTY_VALUE) state0 = -1;
                    if(TF3UpBuffer[1]   != EMPTY_VALUE) state1 = 1; else if(TF3DownBuffer[1] != EMPTY_VALUE) state1 = -1;
                    break;
            }

            if(state0 != 0 && state0 != state1)
            {
                ENUM_TIMEFRAMES tf = Timeframes[tf_idx];
                int tf_bar = (tf == Period()) ? 0 : iBarShift(Symbol(), tf, Time[0], false);
                datetime evtTime = (tf_bar >= 0) ? iTime(Symbol(), tf, tf_bar) : Time[0];

                if(LastAlertBarTime[tf_idx] != evtTime || LastAlertState[tf_idx] != state0)
                {
                    if(DebugMode)
                        Print("ALERT tf_idx=", tf_idx, " tf=", GetTimeframeString(tf), " state=", state0, " evt=", TimeToString(evtTime, TIME_DATE|TIME_SECONDS));
                    TriggerAlert(tf_idx, tf, state0, evtTime);
                    LastAlertBarTime[tf_idx] = evtTime;
                    LastAlertState[tf_idx] = state0;
                }
            }
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
        ObjectSet(name, OBJPROP_FONTSIZE, fontSize);
        // Note: Font property cannot be changed after object creation in MQL4
        ObjectSet(name, OBJPROP_BACK, back);
        ObjectSet(name, OBJPROP_ANCHOR, anchor);
        ObjectMove(name, 0, time, price);
    }
}

//+------------------------------------------------------------------+
//| Draw vertical line on indicator subwindow                        |
//+------------------------------------------------------------------+
void DrawVerticalLine(string name, datetime time, color col, int style, int width)
{
    // Create a vertical line in the main chart window so it spans the chart (not just the indicator subwindow)
    if(ObjectFind(name) < 0)
    {
        ObjectCreate(name, OBJ_VLINE, 0, time, 0);
    }
    if(ObjectFind(name) >= 0)
    {
        ObjectSet(name, OBJPROP_COLOR, col);
        ObjectSet(name, OBJPROP_STYLE, style);
        ObjectSet(name, OBJPROP_WIDTH, width);
        ObjectSet(name, OBJPROP_BACK, true);
    }
}


//+------------------------------------------------------------------+
//| Alert helpers                                                     |
//+------------------------------------------------------------------+
string StateToString(int state)
{
    if(state > 0) return "UP";
    if(state < 0) return "DOWN";
    return "NEUTRAL";
}

void TriggerAlert(int tf_index, ENUM_TIMEFRAMES timeframe, int state, datetime eventTime)
{
    if(!AlertsEnabled) return;

    // If only one TF should alert, enforce selection
    if(AlertsOnlyOneTF && (tf_index != (AlertTFIndex - 1)))
        return;

    string tfStr = GetTimeframeString(timeframe);
    string direction = StateToString(state);
    string msg = StringFormat("CS Histogram %s %s %s @ %s", Symbol(), tfStr, direction, TimeToString(eventTime, TIME_DATE|TIME_SECONDS));

    if(AlertPopup)
        Alert(msg);
    if(AlertPush)
        SendNotification(msg);
    if(AlertSound && StringLen(AlertSoundFile) > 0)
        PlaySound(AlertSoundFile);
}

//+------------------------------------------------------------------+
//| Get Currency Strength Value for a specific bar and timeframe     |
//+------------------------------------------------------------------+
double GetStrengthValue(int bar, ENUM_TIMEFRAMES timeframe, int tf_index)
{
    string symbol = Symbol(); // Use current chart's symbol only
    // Determine which data source to use for this timeframe by tf_index
    int source = CUSTOM; // default
    switch(tf_index)
    {
        case 0: source = TF1Source; break;
        case 1: source = TF2Source; break;
        case 2: source = TF3Source; break;
        default: source = TF1Source; break;
    }

    // If using custom indicator source (iCustom)
    if(source == CUSTOM)
    {
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

    // If using 2-MA source: integrate the 2MA logic directly (no iCustom)
    if(source == MA2)
    {
        // Map current-bar to target timeframe bar index
        int tf_bar;
        if(timeframe == Period())
            tf_bar = bar;
        else
        {
            datetime barTime = Time[bar];
            tf_bar = iBarShift(symbol, timeframe, barTime, false);
        }
        if(tf_bar < 0)
            return EMPTY_VALUE;

        // Ensure we have enough bars on the target timeframe for i+1 access
        int tf_bars = iBars(symbol, timeframe);
        if(tf_bar + 1 >= tf_bars)
            return EMPTY_VALUE;

        // Current close and zone thresholds using i+1 bars (as in original 2MA)
        double c = iClose(symbol, timeframe, tf_bar);
        double mah1 = iMA(symbol, timeframe, MA_MA1_Periods, 0, MA1_Method, PRICE_HIGH, tf_bar + 1);
        double mah2 = iMA(symbol, timeframe, MA_MA2_Periods, 0, MA2_Method, PRICE_HIGH, tf_bar + 1);
        double mal1 = iMA(symbol, timeframe, MA_MA1_Periods, 0, MA1_Method, PRICE_LOW,  tf_bar + 1);
        double mal2 = iMA(symbol, timeframe, MA_MA2_Periods, 0, MA2_Method, PRICE_LOW,  tf_bar + 1);

        // Classification does NOT depend on sign(ma1 - ma2). Return +1/-1 only.
        if(c > mah1 && c > mah2)
            return 1.0;    // UP signal
        if(c < mal1 && c < mal2)
            return -1.0;   // DOWN signal

        // Neutral: continue last clear signal by scanning back on the TARGET timeframe
        for(int back = 1; tf_bar + back + 1 < tf_bars && back <= 50; back++)
        {
            int cb = tf_bar + back;
            double c_chk = iClose(symbol, timeframe, cb);
            double mah1_chk = iMA(symbol, timeframe, MA_MA1_Periods, 0, MA1_Method, PRICE_HIGH, cb + 1);
            double mah2_chk = iMA(symbol, timeframe, MA_MA2_Periods, 0, MA2_Method, PRICE_HIGH, cb + 1);
            double mal1_chk = iMA(symbol, timeframe, MA_MA1_Periods, 0, MA1_Method, PRICE_LOW,  cb + 1);
            double mal2_chk = iMA(symbol, timeframe, MA_MA2_Periods, 0, MA2_Method, PRICE_LOW,  cb + 1);

            if(c_chk > mah1_chk && c_chk > mah2_chk) return 1.0;   // continue UP
            if(c_chk < mal1_chk && c_chk < mal2_chk) return -1.0;  // continue DOWN
        }
        return EMPTY_VALUE;
    }

    // Optional debug print for comparison of sources (only once per bar=0 and when enabled)
    if(DebugMode && bar == 0)
    {
        // compute tf_bar for mapping
        datetime dbgTime = Time[bar];
        int dbg_tf_bar = (timeframe == Period()) ? bar : iBarShift(symbol, timeframe, dbgTime, false);
        if(dbg_tf_bar >= 0)
        {
            double dbg_c1 = iCustom(symbol, timeframe, IndicatorName, Line1Buffer, dbg_tf_bar);
            double dbg_c2 = iCustom(symbol, timeframe, IndicatorName, Line2Buffer, dbg_tf_bar);
            double dbg_ma1 = iMA(symbol, timeframe, MA_MA1_Periods, 0, MA1_Method, MA1_Price, dbg_tf_bar);
            double dbg_ma2 = iMA(symbol, timeframe, MA_MA2_Periods, 0, MA2_Method, MA2_Price, dbg_tf_bar);
            Print("DBG GetStrength tf_index=", tf_index, " tf=", GetTimeframeString(timeframe), " tf_bar=", dbg_tf_bar,
                  " custom=(", dbg_c1, ",", dbg_c2, ") ma=(", dbg_ma1, ",", dbg_ma2, ") source=", source);
        }
    }

    return EMPTY_VALUE; // fallback
}

//+------------------------------------------------------------------+
//| Fetch custom indicator line values with optional subfolder fallback
//+------------------------------------------------------------------+
bool FetchCustomCSLines(int bar, ENUM_TIMEFRAMES timeframe, double &line1, double &line2)
{
    string name = IndicatorName;
    line1 = iCustom(Symbol(), timeframe, name, Line1Buffer, bar);
    line2 = iCustom(Symbol(), timeframe, name, Line2Buffer, bar);
    if((line1 == EMPTY_VALUE || line2 == EMPTY_VALUE) && StringLen(IndicatorSubfolder) > 0)
    {
        name = IndicatorSubfolder + IndicatorName;
        line1 = iCustom(Symbol(), timeframe, name, Line1Buffer, bar);
        line2 = iCustom(Symbol(), timeframe, name, Line2Buffer, bar);
    }
    return !(line1 == EMPTY_VALUE || line2 == EMPTY_VALUE);
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
