//+------------------------------------------------------------------+
//|                         CurrencyStrengthHistogram_StateMachine.mq4 |
//|                  CS Multi-Timeframe Histogram with State Machine   |
//+------------------------------------------------------------------+
#property copyright "Currency Strength Histogram with State Machine"
#property version   "1.00"
#property strict
#property indicator_separate_window
#property indicator_buffers 16
#property indicator_plots   16
#property indicator_minimum 0
#property indicator_maximum 5

//--- plot TF1 UP/DOWN/NEUTRAL
#property indicator_label1  "TF1 UP"
#property indicator_type1   DRAW_ARROW
#property indicator_label2  "TF1 DOWN"
#property indicator_type2   DRAW_ARROW
#property indicator_label3  "TF1 NEUTRAL BULL"
#property indicator_type3   DRAW_ARROW
#property indicator_label4  "TF1 NEUTRAL BEAR"
#property indicator_type4   DRAW_ARROW

//--- plot TF2 UP/DOWN/NEUTRAL
#property indicator_label5  "TF2 UP"
#property indicator_type5   DRAW_ARROW
#property indicator_label6  "TF2 DOWN"
#property indicator_type6   DRAW_ARROW
#property indicator_label7  "TF2 NEUTRAL BULL"
#property indicator_type7   DRAW_ARROW
#property indicator_label8  "TF2 NEUTRAL BEAR"
#property indicator_type8   DRAW_ARROW

//--- plot TF3 UP/DOWN/NEUTRAL
#property indicator_label9  "TF3 UP"
#property indicator_type9   DRAW_ARROW
#property indicator_label10  "TF3 DOWN"
#property indicator_type10   DRAW_ARROW
#property indicator_label11  "TF3 NEUTRAL BULL"
#property indicator_type11   DRAW_ARROW
#property indicator_label12  "TF3 NEUTRAL BEAR"
#property indicator_type12   DRAW_ARROW

//--- plot TF4 UP/DOWN/NEUTRAL
#property indicator_label13  "TF4 UP"
#property indicator_type13   DRAW_ARROW
#property indicator_label14  "TF4 DOWN"
#property indicator_type14   DRAW_ARROW
#property indicator_label15  "TF4 NEUTRAL BULL"
#property indicator_type15   DRAW_ARROW
#property indicator_label16  "TF4 NEUTRAL BEAR"
#property indicator_type16   DRAW_ARROW

//--- ==================== GENERAL SETTINGS ====================
extern string s1 = "===== General Settings ====="; // ────────────────────
extern string IndicatorName = "CurrencyStrengthWizard"; // Source Indicator Name (REQUIRED)
int    Line1Buffer = 0;             // Line 1 Buffer Number
int    Line2Buffer = 1;             // Line 2 Buffer Number

extern int    NumTimeframes = 2;            // Number of Timeframes to Display (1-4)
extern ENUM_TIMEFRAMES Timeframe4 = PERIOD_D1;   // Timeframe 4
extern ENUM_TIMEFRAMES Timeframe3 = PERIOD_H1;   // Timeframe 3
extern ENUM_TIMEFRAMES Timeframe2 = PERIOD_M5;  // Timeframe 2
extern ENUM_TIMEFRAMES Timeframe1 = PERIOD_M1;   // Timeframe 1

extern int    BarsToLookBack = 1000;         // Bars to Look Back for Data
extern bool   EnableDebugLogs = false;       // Enable verbose debugging logs

//--- State Machine Parameters (internal)
int    VolumeBuffer1 = 2;            // Volume/Strength Buffer 1 (green/positive)
int    VolumeBuffer2 = 4;            // Volume/Strength Buffer 2 (red/negative)
int    VolumeBuffer3 = 6;            // Volume/Strength Buffer 3 (alt/dup)
double UpperThreshold = 50.0;        // Upper Threshold
double LowerThreshold = -50.0;       // Lower Threshold

//--- ==================== LABEL SETTINGS ====================
extern string s2 = "===== Label Settings ====="; // ────────────────────
extern bool   ShowTags = true;              // Show timeframe labels on the right
extern string TagFont = "Arial Black";      // Font for timeframe labels
extern int    TagFontSize = 8;              // Font size for timeframe labels
extern color  TagColor = clrBisque;         // Color for timeframe labels

//--- ==================== HISTOGRAM COLORS ====================
extern string s3 = "===== Histogram Colors ====="; // ────────────────────
extern color TF1UpColor          = clrRoyalBlue;     // TF1 up color
extern color TF1DownColor        = clrSaddleBrown;   // TF1 down color
extern color TF1NeutralBullColor = clrLightBlue;     // TF1 bullish neutral color
extern color TF1NeutralBearColor = clrLightPink;     // TF1 bearish neutral color

extern color TF2UpColor          = clrRoyalBlue;     // TF2 up color
extern color TF2DownColor        = clrSaddleBrown;   // TF2 down color
extern color TF2NeutralBullColor = clrLightBlue;     // TF2 bullish neutral color
extern color TF2NeutralBearColor = clrLightPink;     // TF2 bearish neutral color

extern color TF3UpColor          = clrRoyalBlue;     // TF3 up color
extern color TF3DownColor        = clrSaddleBrown;   // TF3 down color
extern color TF3NeutralBullColor = clrLightBlue;     // TF3 bullish neutral color
extern color TF3NeutralBearColor = clrLightPink;     // TF3 bearish neutral color

extern color TF4UpColor          = clrRoyalBlue;     // TF4 up color
extern color TF4DownColor        = clrSaddleBrown;   // TF4 down color
extern color TF4NeutralBullColor = clrLightBlue;     // TF4 bullish neutral color
extern color TF4NeutralBearColor = clrLightPink;     // TF4 bearish neutral color

//--- ==================== ARROW SETTINGS ====================
extern string s4 = "===== Arrow Settings ====="; // ────────────────────
extern bool   ShowTF1Arrows = true;          // Show TF1 Arrows
extern int    TF1ArrowCodeUp = 233;          // TF1 Arrow Code Up
extern int    TF1ArrowCodeDown = 234;        // TF1 Arrow Code Down
extern int    TF1ArrowSize = 1;              // TF1 Arrow Size

extern bool   ShowTF2Arrows = true;          // Show TF2 Arrows
extern int    TF2ArrowCodeUp = 233;          // TF2 Arrow Code Up
extern int    TF2ArrowCodeDown = 234;        // TF2 Arrow Code Down
extern int    TF2ArrowSize = 2;              // TF2 Arrow Size

extern bool   ShowTF3Arrows = true;          // Show TF3 Arrows
extern int    TF3ArrowCodeUp = 233;          // TF3 Arrow Code Up
extern int    TF3ArrowCodeDown = 234;        // TF3 Arrow Code Down
extern int    TF3ArrowSize = 3;              // TF3 Arrow Size

extern bool   ShowTF4Arrows = true;          // Show TF4 Arrows
extern int    TF4ArrowCodeUp = 233;          // TF4 Arrow Code Up
extern int    TF4ArrowCodeDown = 234;        // TF4 Arrow Code Down
extern int    TF4ArrowSize = 4;              // TF4 Arrow Size

extern double ArrowGapMultiplier = 1.0;      // Arrow Gap Multiplier (global adjustment)

//--- ==================== VERTICAL LINE SETTINGS ====================
extern string s5 = "===== Vertical Line Settings ====="; // ────────────────────
extern bool   ShowVerticalLines = true;     // Show vertical lines at confirmed zones
extern int    VerticalLineStyle = STYLE_SOLID; // Style for vertical lines
extern int    VerticalLineWidth = 3;        // Width for vertical lines

//--- ==================== ALERT SETTINGS ====================
extern string s6 = "===== Alert Settings ====="; // ────────────────────
extern bool   EnableTF1Alerts = true;       // Enable TF1 Alerts
extern bool   EnableTF2Alerts = true;       // Enable TF2 Alerts
extern bool   AlertPopup = true;            // Show Popup Alerts
extern bool   AlertPush = true;             // Send Push Notifications
extern bool   AlertSound = true;           // Play Sound Alerts
extern string SoundFile = "alert.wav";      // Sound File Name (must be in Sounds folder)

//--- Indicator Buffers (4 per timeframe: Up, Down, NeutralBull, NeutralBear)
double TF1UpBuffer[];
double TF1DownBuffer[];
double TF1NeutralBullBuffer[];
double TF1NeutralBearBuffer[];
double TF2UpBuffer[];
double TF2DownBuffer[];
double TF2NeutralBullBuffer[];
double TF2NeutralBearBuffer[];
double TF3UpBuffer[];
double TF3DownBuffer[];
double TF3NeutralBullBuffer[];
double TF3NeutralBearBuffer[];
double TF4UpBuffer[];
double TF4DownBuffer[];
double TF4NeutralBullBuffer[];
double TF4NeutralBearBuffer[];

//--- State tracking arrays (not indicator buffers)
int TF1State[];
int TF2State[];
int TF3State[];
int TF4State[];

//--- Global Variables
ENUM_TIMEFRAMES Timeframes[4];

//--- Alert tracking variables
static int prevTF1State = 0;
static int prevTF2State = 0;

//--- Debug helper
void DebugPrint(string message)
{
    if(!EnableDebugLogs) return;
    Print("CSHistSM DEBUG: " + message);
}

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
    int currentPeriod = Period();
    ENUM_TIMEFRAMES currentTF = (ENUM_TIMEFRAMES)currentPeriod;
    int validTimeframes = 0;
    ENUM_TIMEFRAMES validTFs[4];
    // Initialize array to avoid uninitialized variable warning
    for(int init_i = 0; init_i < 4; init_i++)
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
    for(int i = 0; i < 4; i++)
    {
        if(i < validTimeframes)
            Timeframes[i] = validTFs[i];
        else
            Timeframes[i] = currentTF; // Set to current TF to avoid issues
    }

    // Set up indicator buffers (16 total: 4 per timeframe)
    IndicatorBuffers(16);

    // Bind buffers
    int bufIdx = 0;
    SetIndexBuffer(bufIdx++, TF1UpBuffer, INDICATOR_DATA);
    SetIndexBuffer(bufIdx++, TF1DownBuffer, INDICATOR_DATA);
    SetIndexBuffer(bufIdx++, TF1NeutralBullBuffer, INDICATOR_DATA);
    SetIndexBuffer(bufIdx++, TF1NeutralBearBuffer, INDICATOR_DATA);
    SetIndexBuffer(bufIdx++, TF2UpBuffer, INDICATOR_DATA);
    SetIndexBuffer(bufIdx++, TF2DownBuffer, INDICATOR_DATA);
    SetIndexBuffer(bufIdx++, TF2NeutralBullBuffer, INDICATOR_DATA);
    SetIndexBuffer(bufIdx++, TF2NeutralBearBuffer, INDICATOR_DATA);
    SetIndexBuffer(bufIdx++, TF3UpBuffer, INDICATOR_DATA);
    SetIndexBuffer(bufIdx++, TF3DownBuffer, INDICATOR_DATA);
    SetIndexBuffer(bufIdx++, TF3NeutralBullBuffer, INDICATOR_DATA);
    SetIndexBuffer(bufIdx++, TF3NeutralBearBuffer, INDICATOR_DATA);
    SetIndexBuffer(bufIdx++, TF4UpBuffer, INDICATOR_DATA);
    SetIndexBuffer(bufIdx++, TF4DownBuffer, INDICATOR_DATA);
    SetIndexBuffer(bufIdx++, TF4NeutralBullBuffer, INDICATOR_DATA);
    SetIndexBuffer(bufIdx++, TF4NeutralBearBuffer, INDICATOR_DATA);

    // Set index styles for TF1
    SetIndexStyle(0, DRAW_ARROW, EMPTY, 2, TF1UpColor);
    SetIndexArrow(0, 110);
    SetIndexEmptyValue(0, EMPTY_VALUE);
    
    SetIndexStyle(1, DRAW_ARROW, EMPTY, 2, TF1DownColor);
    SetIndexArrow(1, 110);
    SetIndexEmptyValue(1, EMPTY_VALUE);
    
    SetIndexStyle(2, DRAW_ARROW, EMPTY, 2, TF1NeutralBullColor);
    SetIndexArrow(2, 110);
    SetIndexEmptyValue(2, EMPTY_VALUE);
    
    SetIndexStyle(3, DRAW_ARROW, EMPTY, 2, TF1NeutralBearColor);
    SetIndexArrow(3, 110);
    SetIndexEmptyValue(3, EMPTY_VALUE);

    // Set index styles for TF2
    SetIndexStyle(4, DRAW_ARROW, EMPTY, 2, TF2UpColor);
    SetIndexArrow(4, 110);
    SetIndexEmptyValue(4, EMPTY_VALUE);
    
    SetIndexStyle(5, DRAW_ARROW, EMPTY, 2, TF2DownColor);
    SetIndexArrow(5, 110);
    SetIndexEmptyValue(5, EMPTY_VALUE);
    
    SetIndexStyle(6, DRAW_ARROW, EMPTY, 2, TF2NeutralBullColor);
    SetIndexArrow(6, 110);
    SetIndexEmptyValue(6, EMPTY_VALUE);
    
    SetIndexStyle(7, DRAW_ARROW, EMPTY, 2, TF2NeutralBearColor);
    SetIndexArrow(7, 110);
    SetIndexEmptyValue(7, EMPTY_VALUE);

    // Set index styles for TF3
    SetIndexStyle(8, DRAW_ARROW, EMPTY, 2, TF3UpColor);
    SetIndexArrow(8, 110);
    SetIndexEmptyValue(8, EMPTY_VALUE);
    
    SetIndexStyle(9, DRAW_ARROW, EMPTY, 2, TF3DownColor);
    SetIndexArrow(9, 110);
    SetIndexEmptyValue(9, EMPTY_VALUE);
    
    SetIndexStyle(10, DRAW_ARROW, EMPTY, 2, TF3NeutralBullColor);
    SetIndexArrow(10, 110);
    SetIndexEmptyValue(10, EMPTY_VALUE);
    
    SetIndexStyle(11, DRAW_ARROW, EMPTY, 2, TF3NeutralBearColor);
    SetIndexArrow(11, 110);
    SetIndexEmptyValue(11, EMPTY_VALUE);

    // Set index styles for TF4
    SetIndexStyle(12, DRAW_ARROW, EMPTY, 2, TF4UpColor);
    SetIndexArrow(12, 110);
    SetIndexEmptyValue(12, EMPTY_VALUE);
    
    SetIndexStyle(13, DRAW_ARROW, EMPTY, 2, TF4DownColor);
    SetIndexArrow(13, 110);
    SetIndexEmptyValue(13, EMPTY_VALUE);
    
    SetIndexStyle(14, DRAW_ARROW, EMPTY, 2, TF4NeutralBullColor);
    SetIndexArrow(14, 110);
    SetIndexEmptyValue(14, EMPTY_VALUE);
    
    SetIndexStyle(15, DRAW_ARROW, EMPTY, 2, TF4NeutralBearColor);
    SetIndexArrow(15, 110);
    SetIndexEmptyValue(15, EMPTY_VALUE);

    // Set indicator name
    string tfString = GetTimeframeString(Timeframes[0]);
    for(int j = 1; j < NumTimeframes; j++)
    {
        tfString = tfString + "/" + GetTimeframeString(Timeframes[j]);
    }
    IndicatorShortName("CS Histogram SM (" + Symbol() + " - " + tfString + ")");

    // Initialize state arrays
    ArrayResize(TF1State, BarsToLookBack);
    ArrayResize(TF2State, BarsToLookBack);
    ArrayResize(TF3State, BarsToLookBack);
    ArrayResize(TF4State, BarsToLookBack);
    ArraySetAsSeries(TF1State, true);
    ArraySetAsSeries(TF2State, true);
    ArraySetAsSeries(TF3State, true);
    ArraySetAsSeries(TF4State, true);
    ArrayInitialize(TF1State, 0);
    ArrayInitialize(TF2State, 0);
    ArrayInitialize(TF3State, 0);
    ArrayInitialize(TF4State, 0);

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
    // Clean up vertical line objects and arrow objects
    int totalObjects = ObjectsTotal();
    for(int objIdx = totalObjects-1; objIdx >= 0; objIdx--)
    {
        string objName = ObjectName(objIdx);
        if(StringFind(objName, "VLine_SM_") == 0 || 
           StringFind(objName, "Arrow_TF") == 0)
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
    int totalBars = MathMin(Bars, BarsToLookBack);
    if(totalBars <= 0)
        return(0);

    static datetime lastCalcTime = 0;
    bool isNewBar = (Time[0] != lastCalcTime);
    if(isNewBar)
        lastCalcTime = Time[0];

    bool recalcAll = (counted_bars == 0) || isNewBar;
    int limit;

    if(recalcAll)
        limit = totalBars - 1;
    else
        limit = MathMin(Bars - counted_bars, totalBars - 1);

    if(limit < 0)
        limit = 0;

    // Initialize buffers
    if(recalcAll)
    {
        ArrayInitialize(TF1UpBuffer, EMPTY_VALUE);
        ArrayInitialize(TF1DownBuffer, EMPTY_VALUE);
        ArrayInitialize(TF1NeutralBullBuffer, EMPTY_VALUE);
        ArrayInitialize(TF1NeutralBearBuffer, EMPTY_VALUE);
        ArrayInitialize(TF2UpBuffer, EMPTY_VALUE);
        ArrayInitialize(TF2DownBuffer, EMPTY_VALUE);
        ArrayInitialize(TF2NeutralBullBuffer, EMPTY_VALUE);
        ArrayInitialize(TF2NeutralBearBuffer, EMPTY_VALUE);
        ArrayInitialize(TF3UpBuffer, EMPTY_VALUE);
        ArrayInitialize(TF3DownBuffer, EMPTY_VALUE);
        ArrayInitialize(TF3NeutralBullBuffer, EMPTY_VALUE);
        ArrayInitialize(TF3NeutralBearBuffer, EMPTY_VALUE);
        ArrayInitialize(TF4UpBuffer, EMPTY_VALUE);
        ArrayInitialize(TF4DownBuffer, EMPTY_VALUE);
        ArrayInitialize(TF4NeutralBullBuffer, EMPTY_VALUE);
        ArrayInitialize(TF4NeutralBearBuffer, EMPTY_VALUE);
        
        ArrayInitialize(TF1State, 0);
        ArrayInitialize(TF2State, 0);
        ArrayInitialize(TF3State, 0);
        ArrayInitialize(TF4State, 0);
    }

    // Ensure state arrays are large enough
    if(ArraySize(TF1State) < Bars)
    {
        ArrayResize(TF1State, Bars);
        ArraySetAsSeries(TF1State, true);
    }
    if(ArraySize(TF2State) < Bars)
    {
        ArrayResize(TF2State, Bars);
        ArraySetAsSeries(TF2State, true);
    }
    if(ArraySize(TF3State) < Bars)
    {
        ArrayResize(TF3State, Bars);
        ArraySetAsSeries(TF3State, true);
    }
    if(ArraySize(TF4State) < Bars)
    {
        ArrayResize(TF4State, Bars);
        ArraySetAsSeries(TF4State, true);
    }

    int rv = Bars;
    // Use fixed level spacing
    double levelStep = 1.0;
    double currentLevel = 1.0;

    // Process each valid timeframe
    for(int tf_idx = 0; tf_idx < NumTimeframes; tf_idx++)
    {
        ENUM_TIMEFRAMES current_tf = Timeframes[tf_idx];

        if(current_tf == Period())
        {
            // Same timeframe as chart: compute states per bar directly
            for(int i = limit; i >= 0; i--)
            {
                int state = CalculateBarState(i, current_tf, tf_idx);
                SetStateArray(tf_idx, i, state);
                ClearTimeframeBuffers(tf_idx, i);
                if(state == 1 || state == 2)
                    SetTimeframeBuffer(tf_idx, i, currentLevel, 2); // 2 = bullish neutral
                else if(state == -1 || state == -2)
                    SetTimeframeBuffer(tf_idx, i, currentLevel, -2); // -2 = bearish neutral
                else if(state == 3)
                    SetTimeframeBuffer(tf_idx, i, currentLevel, 1); // 1 = up
                else if(state == -3)
                    SetTimeframeBuffer(tf_idx, i, currentLevel, -1); // -1 = down
                else
                    rv = 0;
            }
        }
        else
        {
            // Higher timeframe: build state series on that timeframe, then map to chart bars
            int tfBars = iBars(Symbol(), current_tf);
            // Process enough bars on higher TF to cover the visual range + state persistence
            // Use min of available bars or a reasonable lookback (e.g., 200 bars on the higher TF)
            int tfLookback = MathMin(tfBars - 1, 200);
            int tfStart = tfLookback;
            
            int tfStatesSize = tfStart + 2;
            int tfStates[];
            ArrayResize(tfStates, tfStatesSize);
            ArrayInitialize(tfStates, 0);
            
            for(int tfb = tfStart; tfb >= 0; tfb--)
            {
                int prevIndex = tfb + 1;
                if(prevIndex >= tfBars) { tfStates[tfb] = 0; continue; }
                
                double l1c = iCustom(Symbol(), current_tf, IndicatorName, Line1Buffer, tfb);
                double l2c = iCustom(Symbol(), current_tf, IndicatorName, Line2Buffer, tfb);
                double l1p = iCustom(Symbol(), current_tf, IndicatorName, Line1Buffer, prevIndex);
                double l2p = iCustom(Symbol(), current_tf, IndicatorName, Line2Buffer, prevIndex);
                if(l1c == EMPTY_VALUE || l2c == EMPTY_VALUE || l1p == EMPTY_VALUE || l2p == EMPTY_VALUE)
                { tfStates[tfb] = 0; continue; }
                
                bool crossAbove = (l1p <= l2p) && (l1c > l2c);
                bool crossBelow = (l1p >= l2p) && (l1c < l2c);
                
                double vol = 0.0; bool has = false; const double EPS = 1e-6;
                double v_pos = (VolumeBuffer1 >= 0) ? iCustom(Symbol(), current_tf, IndicatorName, VolumeBuffer1, tfb) : EMPTY_VALUE;
                double v_neg = (VolumeBuffer2 >= 0) ? iCustom(Symbol(), current_tf, IndicatorName, VolumeBuffer2, tfb) : EMPTY_VALUE;
                double v_dup = (VolumeBuffer3 >= 0) ? iCustom(Symbol(), current_tf, IndicatorName, VolumeBuffer3, tfb) : EMPTY_VALUE;
                if(v_pos != EMPTY_VALUE && MathAbs(v_pos) > EPS) { vol = v_pos; has = true; }
                else if(v_neg != EMPTY_VALUE && MathAbs(v_neg) > EPS) { vol = v_neg; has = true; }
                else if(v_dup != EMPTY_VALUE && MathAbs(v_dup) > EPS) { vol = v_dup; has = true; }
                
                int prevState = tfStates[prevIndex];
                int curState = prevState;
                if(crossAbove) curState = 1;
                else if(crossBelow) curState = -1;
                
                if(curState == 1 && has && vol <= LowerThreshold) curState = 2;
                else if(curState == -1 && has && vol >= UpperThreshold) curState = -2;
                
                if(curState == 2 && has && vol > 0.0) curState = 3;
                else if(curState == -2 && has && vol < 0.0) curState = -3;
                
                tfStates[tfb] = curState;
            }
            
            // Map higher timeframe states onto chart bars
            for(int i = limit; i >= 0; i--)
            {
                int tf_bar_current = iBarShift(Symbol(), current_tf, Time[i], false);
                int state = 0;
                if(tf_bar_current >= 0 && tf_bar_current < ArraySize(tfStates))
                    state = tfStates[tf_bar_current];
                
                SetStateArray(tf_idx, i, state);
                ClearTimeframeBuffers(tf_idx, i);
                if(state == 1 || state == 2)
                    SetTimeframeBuffer(tf_idx, i, currentLevel, 2); // 2 = bullish neutral
                else if(state == -1 || state == -2)
                    SetTimeframeBuffer(tf_idx, i, currentLevel, -2); // -2 = bearish neutral
                else if(state == 3)
                    SetTimeframeBuffer(tf_idx, i, currentLevel, 1); // 1 = up
                else if(state == -3)
                    SetTimeframeBuffer(tf_idx, i, currentLevel, -1); // -1 = down
                else
                    rv = 0;
            }
        }

        currentLevel += levelStep; // Increment level for next timeframe
    }

    // Clear unused timeframe buffers completely
    for(int i = totalBars - 1; i >= 0; i--)
    {
        if(NumTimeframes < 4)
        {
            TF4UpBuffer[i] = EMPTY_VALUE;
            TF4DownBuffer[i] = EMPTY_VALUE;
            TF4NeutralBullBuffer[i] = EMPTY_VALUE;
            TF4NeutralBearBuffer[i] = EMPTY_VALUE;
        }
        if(NumTimeframes < 3)
        {
            TF3UpBuffer[i] = EMPTY_VALUE;
            TF3DownBuffer[i] = EMPTY_VALUE;
            TF3NeutralBullBuffer[i] = EMPTY_VALUE;
            TF3NeutralBearBuffer[i] = EMPTY_VALUE;
        }
        if(NumTimeframes < 2)
        {
            TF2UpBuffer[i] = EMPTY_VALUE;
            TF2DownBuffer[i] = EMPTY_VALUE;
            TF2NeutralBullBuffer[i] = EMPTY_VALUE;
            TF2NeutralBearBuffer[i] = EMPTY_VALUE;
        }
    }

    // Create vertical lines at confirmed zone starts (state 3 or -3)
    if(ShowVerticalLines && NumTimeframes >= 1)
    {
        // Remove existing VLine objects (except bar 0 which is drawn when alerts fire)
        for(int objIdx2 = ObjectsTotal() - 1; objIdx2 >= 0; objIdx2--)
        {
            string objName2 = ObjectName(objIdx2);
            if(StringFind(objName2, "VLine_SM_") == 0)
            {
                // Don't delete bar 0 lines (they're drawn when alerts fire)
                if(StringFind(objName2, "_" + IntegerToString((int)Time[0])) < 0)
                {
                    bool deleted = ObjectDelete(objName2);
                    if(deleted) DebugPrint("Deleted historical VLine object: " + objName2);
                }
            }
        }

        DrawTimeframeVerticalLines(0, "VLine_SM_TF1_", VerticalLineStyle, VerticalLineWidth, TF1UpColor, TF1DownColor, totalBars);

        if(NumTimeframes >= 2)
            DrawTimeframeVerticalLines(1, "VLine_SM_TF2_", STYLE_DASH, VerticalLineWidth, TF2UpColor, TF2DownColor, totalBars);
    }
    else
    {
        // Clear all vertical lines if disabled
        for(int objIdx = ObjectsTotal() - 1; objIdx >= 0; objIdx--)
        {
            string objName = ObjectName(objIdx);
            if(StringFind(objName, "VLine_SM_") == 0)
            {
                bool deleted = ObjectDelete(objName);
                if(deleted) DebugPrint("Deleted VLine object (ShowVerticalLines disabled): " + objName);
            }
        }
    }

    // Check for alerts on the most recent bar (bar 0) - only on new bars
    // Draw visual elements on bar 0 when alerts are triggered
    if(isNewBar)
    {
        // Check TF1 alerts
        if(EnableTF1Alerts && NumTimeframes >= 1)
        {
            int currentTF1State = GetStateArray(0, 0);
            if((currentTF1State == 3 || currentTF1State == -3) && currentTF1State != prevTF1State)
            {
                SendAlert(0, currentTF1State);
                // Remove any visual elements on bar 1 (the bar that just closed) to avoid duplicates
                if(Bars > 1)
                {
                    string vnameOld = "VLine_SM_TF1_" + IntegerToString((int)Time[1]);
                    if(ObjectDelete(vnameOld)) DebugPrint("Deleted previous TF1 VLine during alert: " + vnameOld);
                    string arrowNameOld = "Arrow_TF1_" + IntegerToString((int)Time[1]);
                    if(ObjectDelete(arrowNameOld)) DebugPrint("Deleted previous TF1 Arrow during alert: " + arrowNameOld);
                }
                DebugPrint("TF1 alert triggered. State=" + IntegerToString(currentTF1State) + " Time=" + TimeToString(Time[0], TIME_DATE|TIME_MINUTES|TIME_SECONDS));
                // Draw visual elements on bar 0 when alert is triggered
                if(ShowVerticalLines)
                {
                    string vname = "VLine_SM_TF1_" + IntegerToString((int)Time[0]);
                    color vcol = (currentTF1State == 3) ? TF1UpColor : TF1DownColor;
                    DrawVerticalLine(vname, Time[0], vcol, VerticalLineStyle, VerticalLineWidth);
                }
                if(ShowTF1Arrows)
                {
                    double gap = getArrowPoint() * ArrowGapMultiplier;
                    string arrowName = "Arrow_TF1_" + IntegerToString((int)Time[0]);
                    int arrowCode = (currentTF1State == 3) ? TF1ArrowCodeUp : TF1ArrowCodeDown;
                    color arrowColor = (currentTF1State == 3) ? TF1UpColor : TF1DownColor;
                    double arrowPrice = (currentTF1State == 3) ? (Low[0] - gap) : (High[0] + gap);
                    DrawArrow(arrowName, Time[0], arrowPrice, arrowCode, arrowColor, TF1ArrowSize);
                }
            }
            prevTF1State = currentTF1State;
        }
        
        // Check TF2 alerts
        if(EnableTF2Alerts && NumTimeframes >= 2)
        {
            int currentTF2State = GetStateArray(1, 0);
            if((currentTF2State == 3 || currentTF2State == -3) && currentTF2State != prevTF2State)
            {
                SendAlert(1, currentTF2State);
                // Remove any visual elements on bar 1 (the bar that just closed) to avoid duplicates
                if(Bars > 1)
                {
                    string vnameOld = "VLine_SM_TF2_" + IntegerToString((int)Time[1]);
                    if(ObjectDelete(vnameOld)) DebugPrint("Deleted previous TF2 VLine during alert: " + vnameOld);
                    string arrowNameOld = "Arrow_TF2_" + IntegerToString((int)Time[1]);
                    if(ObjectDelete(arrowNameOld)) DebugPrint("Deleted previous TF2 Arrow during alert: " + arrowNameOld);
                }
                DebugPrint("TF2 alert triggered. State=" + IntegerToString(currentTF2State) + " Time=" + TimeToString(Time[0], TIME_DATE|TIME_MINUTES|TIME_SECONDS));
                // Draw visual elements on bar 0 when alert is triggered
                if(ShowVerticalLines)
                {
                    string vname = "VLine_SM_TF2_" + IntegerToString((int)Time[0]);
                    color vcol = (currentTF2State == 3) ? TF2UpColor : TF2DownColor;
                    DrawVerticalLine(vname, Time[0], vcol, STYLE_DASH, VerticalLineWidth);
                }
                if(ShowTF2Arrows)
                {
                    double gap = getArrowPoint() * ArrowGapMultiplier;
                    string arrowName = "Arrow_TF2_" + IntegerToString((int)Time[0]);
                    int arrowCode = (currentTF2State == 3) ? TF2ArrowCodeUp : TF2ArrowCodeDown;
                    color arrowColor = (currentTF2State == 3) ? TF2UpColor : TF2DownColor;
                    double arrowPrice = (currentTF2State == 3) ? (Low[0] - gap) : (High[0] + gap);
                    DrawArrow(arrowName, Time[0], arrowPrice, arrowCode, arrowColor, TF2ArrowSize);
                }
            }
            prevTF2State = currentTF2State;
        }
    }

    // Draw arrows for confirmed zone starts per timeframe (historical bars only, skip bar 0 if alert was just triggered)
    DrawTimeframeArrows(0, TF1State, ShowTF1Arrows, TF1ArrowCodeUp, TF1ArrowCodeDown, TF1ArrowSize, TF1UpColor, TF1DownColor, totalBars);
    DrawTimeframeArrows(1, TF2State, ShowTF2Arrows, TF2ArrowCodeUp, TF2ArrowCodeDown, TF2ArrowSize, TF2UpColor, TF2DownColor, totalBars);
    DrawTimeframeArrows(2, TF3State, ShowTF3Arrows, TF3ArrowCodeUp, TF3ArrowCodeDown, TF3ArrowSize, TF3UpColor, TF3DownColor, totalBars);
    DrawTimeframeArrows(3, TF4State, ShowTF4Arrows, TF4ArrowCodeUp, TF4ArrowCodeDown, TF4ArrowSize, TF4UpColor, TF4DownColor, totalBars);

    // Draw timeframe labels on the right side
    if(ShowTags)
    {
        double labelLevel = 1.0;
        for(int i=0; i<NumTimeframes; i++)
        {
            string tfs = GetTimeframeString(Timeframes[i]);
            DrawText("TF_"+IntegerToString(i+1), tfs, Time[0] + Period()*150, labelLevel, TagColor, TagFont, TagFontSize, false, ANCHOR_LEFT);
            labelLevel += levelStep;
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
//| Calculate bar state using state machine logic                    |
//+------------------------------------------------------------------+
int CalculateBarState(int bar, ENUM_TIMEFRAMES timeframe, int tf_idx)
{
    string symbol = Symbol();
    
    // Get current and previous bar indices for the timeframe
    int tf_bar_current, tf_bar_previous;
    
    if(timeframe == Period())
    {
        tf_bar_current = bar;
        tf_bar_previous = bar + 1;
    }
    else
    {
        datetime barTime = Time[bar];
        tf_bar_current = iBarShift(symbol, timeframe, barTime, false);
        if(tf_bar_current < 0) return 0;
        tf_bar_previous = tf_bar_current + 1;
    }
    
    // Read line values
    double line1_current = iCustom(symbol, timeframe, IndicatorName, Line1Buffer, tf_bar_current);
    double line1_previous = iCustom(symbol, timeframe, IndicatorName, Line1Buffer, tf_bar_previous);
    double line2_current = iCustom(symbol, timeframe, IndicatorName, Line2Buffer, tf_bar_current);
    double line2_previous = iCustom(symbol, timeframe, IndicatorName, Line2Buffer, tf_bar_previous);
    
    if(line1_current == EMPTY_VALUE || line2_current == EMPTY_VALUE ||
       line1_previous == EMPTY_VALUE || line2_previous == EMPTY_VALUE)
    {
        return 0;
    }
    
    // Detect crossovers
    bool crossAbove = (line1_previous <= line2_previous) && (line1_current > line2_current);
    bool crossBelow = (line1_previous >= line2_previous) && (line1_current < line2_current);
    
    // Get volume/strength value
    double vol_curr = 0.0;
    bool has_curr = false;
    const double EPS = 1e-6;
    {
        double v_pos = (VolumeBuffer1 >= 0) ? iCustom(symbol, timeframe, IndicatorName, VolumeBuffer1, tf_bar_current) : EMPTY_VALUE;
        double v_neg = (VolumeBuffer2 >= 0) ? iCustom(symbol, timeframe, IndicatorName, VolumeBuffer2, tf_bar_current) : EMPTY_VALUE;
        double v_dup = (VolumeBuffer3 >= 0) ? iCustom(symbol, timeframe, IndicatorName, VolumeBuffer3, tf_bar_current) : EMPTY_VALUE;
        if(v_pos != EMPTY_VALUE && MathAbs(v_pos) > EPS) { vol_curr = v_pos; has_curr = true; }
        else if(v_neg != EMPTY_VALUE && MathAbs(v_neg) > EPS) { vol_curr = v_neg; has_curr = true; }
        else if(v_dup != EMPTY_VALUE && MathAbs(v_dup) > EPS) { vol_curr = v_dup; has_curr = true; }
    }
    
    // State machine logic - inherit state from previous bar on THIS timeframe
    int prevState = 0;
    
    // For higher timeframes, we need to find the previous bar on that timeframe
    if(timeframe == Period())
    {
        // Same timeframe, just use bar+1
        if(bar + 1 < Bars)
        {
            prevState = GetStateArray(tf_idx, bar + 1);
        }
    }
    else
    {
        // Higher timeframe - find the start of the previous higher TF bar
        datetime barTime = Time[bar];
        int tf_bar_current = iBarShift(Symbol(), timeframe, barTime, false);
        
        // Look for a chart bar that belongs to the previous higher TF bar
        for(int look_i = bar + 1; look_i < Bars && look_i < bar + 200; look_i++)
        {
            int tf_bar_check = iBarShift(Symbol(), timeframe, Time[look_i], false);
            if(tf_bar_check > tf_bar_current)
            {
                // This chart bar belongs to the previous higher TF bar
                prevState = GetStateArray(tf_idx, look_i);
                break;
            }
        }
    }
    
    int currentState = prevState;
    
    // 1. Detect new crossovers and reset state
    if(crossAbove)
    {
        currentState = 1; // State 1: crossover up detected
    }
    else if(crossBelow)
    {
        currentState = -1; // State -1: crossover down detected
    }
    
    // 2. Check for threshold progression (state 1/-1 -> state 2/-2)
    if(currentState == 1 && has_curr && vol_curr <= LowerThreshold)
    {
        currentState = 2; // State 2: threshold hit (up direction)
    }
    else if(currentState == -1 && has_curr && vol_curr >= UpperThreshold)
    {
        currentState = -2; // State -2: threshold hit (down direction)
    }
    
    // 3. Check for sign confirmation (state 2/-2 -> state 3/-3)
    if(currentState == 2 && has_curr && vol_curr > 0.0)
    {
        currentState = 3; // State 3: confirmed up
    }
    else if(currentState == -2 && has_curr && vol_curr < 0.0)
    {
        currentState = -3; // State -3: confirmed down
    }
    
    return currentState;
}

//+------------------------------------------------------------------+
//| Get state from state array                                       |
//+------------------------------------------------------------------+
int GetStateArray(int tf_idx, int bar)
{
    if(bar >= Bars || bar < 0) return 0;
    
    switch(tf_idx)
    {
        case 0: return TF1State[bar];
        case 1: return TF2State[bar];
        case 2: return TF3State[bar];
        case 3: return TF4State[bar];
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Set state in state array                                         |
//+------------------------------------------------------------------+
void SetStateArray(int tf_idx, int bar, int state)
{
    if(bar >= Bars || bar < 0) return;
    
    switch(tf_idx)
    {
        case 0: TF1State[bar] = state; break;
        case 1: TF2State[bar] = state; break;
        case 2: TF3State[bar] = state; break;
        case 3: TF4State[bar] = state; break;
    }
}

//+------------------------------------------------------------------+
//| Clear all buffers for a timeframe at a specific bar              |
//+------------------------------------------------------------------+
void ClearTimeframeBuffers(int tf_idx, int bar)
{
    switch(tf_idx)
    {
        case 0:
            TF1UpBuffer[bar] = EMPTY_VALUE;
            TF1DownBuffer[bar] = EMPTY_VALUE;
            TF1NeutralBullBuffer[bar] = EMPTY_VALUE;
            TF1NeutralBearBuffer[bar] = EMPTY_VALUE;
            break;
        case 1:
            TF2UpBuffer[bar] = EMPTY_VALUE;
            TF2DownBuffer[bar] = EMPTY_VALUE;
            TF2NeutralBullBuffer[bar] = EMPTY_VALUE;
            TF2NeutralBearBuffer[bar] = EMPTY_VALUE;
            break;
        case 2:
            TF3UpBuffer[bar] = EMPTY_VALUE;
            TF3DownBuffer[bar] = EMPTY_VALUE;
            TF3NeutralBullBuffer[bar] = EMPTY_VALUE;
            TF3NeutralBearBuffer[bar] = EMPTY_VALUE;
            break;
        case 3:
            TF4UpBuffer[bar] = EMPTY_VALUE;
            TF4DownBuffer[bar] = EMPTY_VALUE;
            TF4NeutralBullBuffer[bar] = EMPTY_VALUE;
            TF4NeutralBearBuffer[bar] = EMPTY_VALUE;
            break;
    }
}

//+------------------------------------------------------------------+
//| Set timeframe buffer based on direction                          |
//| direction: 1=up, -1=down, 2=bullish neutral, -2=bearish neutral  |
//+------------------------------------------------------------------+
void SetTimeframeBuffer(int tf_idx, int bar, double level, int direction)
{
    switch(tf_idx)
    {
        case 0:
            if(direction == 1) TF1UpBuffer[bar] = level;
            else if(direction == -1) TF1DownBuffer[bar] = level;
            else if(direction == 2) TF1NeutralBullBuffer[bar] = level;
            else if(direction == -2) TF1NeutralBearBuffer[bar] = level;
            break;
        case 1:
            if(direction == 1) TF2UpBuffer[bar] = level;
            else if(direction == -1) TF2DownBuffer[bar] = level;
            else if(direction == 2) TF2NeutralBullBuffer[bar] = level;
            else if(direction == -2) TF2NeutralBearBuffer[bar] = level;
            break;
        case 2:
            if(direction == 1) TF3UpBuffer[bar] = level;
            else if(direction == -1) TF3DownBuffer[bar] = level;
            else if(direction == 2) TF3NeutralBullBuffer[bar] = level;
            else if(direction == -2) TF3NeutralBearBuffer[bar] = level;
            break;
        case 3:
            if(direction == 1) TF4UpBuffer[bar] = level;
            else if(direction == -1) TF4DownBuffer[bar] = level;
            else if(direction == 2) TF4NeutralBullBuffer[bar] = level;
            else if(direction == -2) TF4NeutralBearBuffer[bar] = level;
            break;
    }
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
        ObjectSet(name, OBJPROP_BACK, back);
        ObjectSet(name, OBJPROP_ANCHOR, anchor);
        ObjectMove(name, 0, time, price);
    }
}

//+------------------------------------------------------------------+
//| Draw vertical line on chart                                      |
//+------------------------------------------------------------------+
void DrawVerticalLine(string name, datetime time, color col, int style, int width)
{
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
        DebugPrint(StringFormat("DrawVerticalLine -> name=%s time=%s color=%d style=%d width=%d", name, TimeToString(time, TIME_DATE|TIME_MINUTES|TIME_SECONDS), col, style, width));
    }
}

//+------------------------------------------------------------------+
//| Draw vertical lines for a timeframe                              |
//+------------------------------------------------------------------+
void DrawTimeframeVerticalLines(int tf_idx, string prefix, int lineStyle, int lineWidth,
                                color upColor, color downColor, int totalBars)
{
    int prevState = 0;

    // Start from totalBars - 1, skip bar 0 and bar 1 (bar 0 is drawn when alerts fire, bar 1 might be the alert bar)
    for(int b = totalBars - 1; b > 1; b--)
    {
        int state = GetStateArray(tf_idx, b);

        if((state == 3 || state == -3) && state != prevState)
        {
            string vname = prefix + IntegerToString((int)Time[b]);
            color vcol = (state == 3) ? upColor : downColor;
            DrawVerticalLine(vname, Time[b], vcol, lineStyle, lineWidth);
            DebugPrint(StringFormat("DrawTimeframeVerticalLines -> TF%d state=%d bar=%d time=%s", tf_idx+1, state, b, TimeToString(Time[b], TIME_DATE|TIME_MINUTES|TIME_SECONDS)));
        }

        if(state != 0)
            prevState = state;
    }
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
//| Draw arrows for timeframe zone starts                            |
//+------------------------------------------------------------------+
void DrawTimeframeArrows(int tf_idx, int &stateArray[], bool showArrows, int arrowCodeUp, int arrowCodeDown, 
                         int arrowSize, color upColor, color downColor, int totalBars)
{
    if(!showArrows || tf_idx >= NumTimeframes) return;
    
    // Clear existing arrows for this timeframe (except bar 0 which is drawn when alerts fire)
    for(int objIdx = ObjectsTotal() - 1; objIdx >= 0; objIdx--)
    {
        string objName = ObjectName(objIdx);
        if(StringFind(objName, "Arrow_TF" + IntegerToString(tf_idx + 1) + "_") == 0)
        {
            // Don't delete bar 0 arrows (they're drawn when alerts fire)
            if(StringFind(objName, "_" + IntegerToString((int)Time[0])) < 0)
            {
                bool deleted = ObjectDelete(objName);
                if(deleted) DebugPrint("Deleted historical Arrow object: " + objName);
            }
        }
    }
    
    int prevState = 0;
    
    // Scan from oldest to newest, skip bar 0 and bar 1 (bar 0 is drawn when alerts fire, bar 1 might be the alert bar)
    for(int b = totalBars - 1; b > 1; b--)
    {
        int state = stateArray[b];
        
        // Draw arrow when transitioning to confirmed state (3 or -3)
        if((state == 3 || state == -3) && state != prevState)
        {
            double gap = getArrowPoint() * ArrowGapMultiplier;
            
            string arrowName = "Arrow_TF" + IntegerToString(tf_idx + 1) + "_" + IntegerToString((int)Time[b]);
            int arrowCode = (state == 3) ? arrowCodeUp : arrowCodeDown;
            color arrowColor = (state == 3) ? upColor : downColor;
            double arrowPrice = (state == 3) ? (Low[b] - gap) : (High[b] + gap);
            
            DrawArrow(arrowName, Time[b], arrowPrice, arrowCode, arrowColor, arrowSize);
            DebugPrint(StringFormat("DrawTimeframeArrows -> TF%d state=%d bar=%d time=%s", tf_idx+1, state, b, TimeToString(Time[b], TIME_DATE|TIME_MINUTES|TIME_SECONDS)));
        }
        
        if(state != 0) prevState = state;
    }
}

//+------------------------------------------------------------------+
//| Draw arrow on chart                                              |
//+------------------------------------------------------------------+
void DrawArrow(string name, datetime time, double price, int arrowCode, color col, int width)
{
    if(ObjectFind(name) < 0)
    {
        ObjectCreate(name, OBJ_ARROW, 0, time, price);
    }
    if(ObjectFind(name) >= 0)
    {
        ObjectSet(name, OBJPROP_ARROWCODE, arrowCode);
        ObjectSet(name, OBJPROP_COLOR, col);
        ObjectSet(name, OBJPROP_WIDTH, width);
        ObjectMove(name, 0, time, price);
        DebugPrint(StringFormat("DrawArrow -> name=%s time=%s price=%G code=%d color=%d width=%d", name, TimeToString(time, TIME_DATE|TIME_MINUTES|TIME_SECONDS), price, arrowCode, col, width));
    }
}

//+------------------------------------------------------------------+
//| Send alert for confirmed zone start                              |
//+------------------------------------------------------------------+
void SendAlert(int tf_idx, int state)
{
    if(!AlertPopup && !AlertPush && !AlertSound) return;
    
    string tfName = "";
    string direction = "";
    
    if(tf_idx == 0)
    {
        tfName = "TF1 (" + GetTimeframeString(Timeframes[0]) + ")";
    }
    else if(tf_idx == 1)
    {
        tfName = "TF2 (" + GetTimeframeString(Timeframes[1]) + ")";
    }
    else
    {
        return; // Only TF1 and TF2 supported
    }
    
    if(state == 3)
    {
        direction = "UP";
    }
    else if(state == -3)
    {
        direction = "DOWN";
    }
    else
    {
        return; // Only alert on confirmed states
    }
    
    string alertMessage = Symbol() + " - " + tfName + " Confirmed Zone: " + direction;
    
    if(AlertPopup)
    {
        Alert(alertMessage);
    }
    
    if(AlertPush)
    {
        SendNotification(alertMessage);
    }
    
    if(AlertSound)
    {
        PlaySound(SoundFile);
    }
}

//+------------------------------------------------------------------+
//| Get arrow distance based on timeframe (from opita indicator)     |
//+------------------------------------------------------------------+
double getArrowPoint()
{
    int tf = Period();
    if(tf == 1)       return 5.0 * Point;
    if(tf == 5)       return 10.0 * Point;
    if(tf == 15)      return 22.0 * Point;
    if(tf == 30)      return 44.0 * Point;
    if(tf == 60)      return 80.0 * Point;
    if(tf == 240)     return 120.0 * Point;
    if(tf == 1440)    return 170.0 * Point;
    if(tf == 10080)   return 500.0 * Point;
    if(tf == 43200)   return 900.0 * Point;
    return 20.0 * Point;
}

//+------------------------------------------------------------------+
