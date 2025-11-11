#property copyright "Line Crossover Arrows (Simple)"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   4

// Arrow plots
#property indicator_label1  "Cross Arrow Up"
#property indicator_type1   DRAW_ARROW
#property indicator_label2  "Cross Arrow Down"
#property indicator_type2   DRAW_ARROW
// Dot plots for threshold hits
#property indicator_label3  "Threshold Dot Upper"
#property indicator_type3   DRAW_ARROW
#property indicator_label4  "Threshold Dot Lower"
#property indicator_type4   DRAW_ARROW

//--- Indicator Parameters
extern string __IndicatorName = ""; // Indicator Settings
extern string IndicatorName = "CurrencyStrengthWizard"; // Indicator Name (REQUIRED)
extern int    Line1Buffer = 0;            // Line 1 Buffer Number
extern int    Line2Buffer = 1;            // Line 2 Buffer Number
extern int    BarsToLookBack = 1000;      // Bars to Look Back

extern string __ArrowSettings = ""; // Arrow Settings
extern bool   ShowArrows = true;          // Show Arrows
extern int    ArrowCodeUp = 233;          // Arrow Code Up (233 = up arrow)
extern int    ArrowCodeDown = 234;        // Arrow Code Down (234 = down arrow)
extern color  ArrowUpColor = clrLightGreen; // Arrow Up Color
extern color  ArrowDnColor = clrRed;      // Arrow Down Color
extern int    ArrowWidth = 2;             // Arrow Width
extern double ArrowGapPercent = 10.0;     // Arrow Gap (% of candle height)

extern string __DotSettings = ""; // Dot Settings
extern bool   ShowDots = true;            // Show threshold dots
extern int    DotCode = 159;              // Wingdings small dot
extern color  DotUpColor = clrLime;       // Dot color for upper threshold hit
extern color  DotDnColor = clrRed;        // Dot color for lower threshold hit
extern int    DotWidth = 1;               // Dot width
double DotGapPercent = 6.0;        // Dot gap (% of candle height)
int    VolumeBuffer = -1;          // Optional single buffer index (-1 to ignore)
int    VolumeBuffer1 = 2;          // Additional buffer index to read (green/positive)
int    VolumeBuffer2 = 4;          // Additional buffer index to read (red/negative)
int    VolumeBuffer3 = 6;          // Additional buffer index to read (alt/dup)
double UpperThreshold = 50.0;      // Upper threshold
double LowerThreshold = -50.0;     // Lower threshold
extern int    ThresholdLookbackBars = 8;  // Look back N bars for opposite-side threshold before flip
string __DebugSettings = "";       // Debug Settings
bool   EnableDebug = false;        // Enable debug logging
bool   DebugLogOnEveryBar = false; // Log even when no threshold hit
bool   ProbeAllBuffers = false;    // Scan a range of buffers and log values
int    ProbeStartIndex = 0;        // Start index (inclusive) for probe
int    ProbeEndIndex = 15;         // End index (inclusive) for probe

// Buffers
double CrossArrowUp[];
double CrossArrowDown[];
double ThresholdDotUp[];
double ThresholdDotDn[];

// State tracking for crossover sequences
// Each element tracks: 0=no crossover, 1=crossover detected, 2=threshold hit, 3=arrow drawn
double CrossUpState[];
double CrossDnState[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                        |
//+------------------------------------------------------------------+
int init()
{
    if(StringLen(IndicatorName) == 0)
    {
        Alert("ERROR: Indicator name is required! Please specify the IndicatorName parameter.");
        Print("ERROR: Indicator name is required! Please specify the IndicatorName parameter.");
        return(INIT_FAILED);
    }

    SetIndexBuffer(0, CrossArrowUp);
    SetIndexBuffer(1, CrossArrowDown);
    SetIndexBuffer(2, ThresholdDotUp);
    SetIndexBuffer(3, ThresholdDotDn);
    SetIndexBuffer(4, CrossUpState);
    SetIndexBuffer(5, CrossDnState);

    SetIndexStyle(0, DRAW_ARROW, EMPTY, ArrowWidth, ArrowUpColor);
    SetIndexArrow(0, ArrowCodeUp);
    SetIndexEmptyValue(0, EMPTY_VALUE);

    SetIndexStyle(1, DRAW_ARROW, EMPTY, ArrowWidth, ArrowDnColor);
    SetIndexArrow(1, ArrowCodeDown);
    SetIndexEmptyValue(1, EMPTY_VALUE);

    SetIndexStyle(2, DRAW_ARROW, EMPTY, DotWidth, DotUpColor);
    SetIndexArrow(2, DotCode);
    SetIndexEmptyValue(2, EMPTY_VALUE);

    SetIndexStyle(3, DRAW_ARROW, EMPTY, DotWidth, DotDnColor);
    SetIndexArrow(3, DotCode);
    SetIndexEmptyValue(3, EMPTY_VALUE);
    
    // State buffers are not drawn
    SetIndexStyle(4, DRAW_NONE);
    SetIndexStyle(5, DRAW_NONE);

    IndicatorShortName("Cross Arrows (Simple)");
    return(0);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                             |
//+------------------------------------------------------------------+
int start()
{
    if(Bars < 2)
        return(0);

    int counted_bars = IndicatorCounted();
    int maxBarsToProcess = MathMin(Bars, BarsToLookBack);
    int limit = maxBarsToProcess - 1;

    if(counted_bars == 0)
    {
        ArrayInitialize(CrossArrowUp, EMPTY_VALUE);
        ArrayInitialize(CrossArrowDown, EMPTY_VALUE);
        ArrayInitialize(ThresholdDotUp, EMPTY_VALUE);
        ArrayInitialize(ThresholdDotDn, EMPTY_VALUE);
        ArrayInitialize(CrossUpState, 0);
        ArrayInitialize(CrossDnState, 0);
    }

    for(int j = maxBarsToProcess; j < Bars; j++)
    {
        CrossArrowUp[j] = EMPTY_VALUE;
        CrossArrowDown[j] = EMPTY_VALUE;
        ThresholdDotUp[j] = EMPTY_VALUE;
        ThresholdDotDn[j] = EMPTY_VALUE;
        CrossUpState[j] = 0;
        CrossDnState[j] = 0;
    }

    // Process from oldest to newest (right to left on chart)
    for(int i = limit; i >= 0; i--)
    {
        CrossArrowUp[i] = EMPTY_VALUE;
        CrossArrowDown[i] = EMPTY_VALUE;
        ThresholdDotUp[i] = EMPTY_VALUE;
        ThresholdDotDn[i] = EMPTY_VALUE;

        double line1_current = iCustom(Symbol(), Period(), IndicatorName, Line1Buffer, i);
        double line1_previous = iCustom(Symbol(), Period(), IndicatorName, Line1Buffer, i + 1);
        double line2_current = iCustom(Symbol(), Period(), IndicatorName, Line2Buffer, i);
        double line2_previous = iCustom(Symbol(), Period(), IndicatorName, Line2Buffer, i + 1);
        
        // Threshold dot tracking
        bool upperHit = false;
        bool lowerHit = false;
        int buffersToCheck[4];
        buffersToCheck[0] = VolumeBuffer;
        buffersToCheck[1] = VolumeBuffer1;
        buffersToCheck[2] = VolumeBuffer2;
        buffersToCheck[3] = VolumeBuffer3;
        double bufValues[4];
        bool   bufHasValue[4];
        for(int k = 0; k < 4; k++){ bufValues[k] = 0.0; bufHasValue[k] = false; }
        string upperBy = "";
        string lowerBy = "";
        for(int b = 0; b < 4; b++)
        {
            int idx = buffersToCheck[b];
            if(idx < 0) continue;
            double v = iCustom(Symbol(), Period(), IndicatorName, idx, i);
            if(v == EMPTY_VALUE) continue;
            bufValues[b] = v;
            bufHasValue[b] = true;
            if(v >= UpperThreshold)
            {
                upperHit = true;
                if(StringLen(upperBy) > 0) upperBy += ",";
                upperBy += StringFormat("%d", idx);
            }
            if(v <= LowerThreshold)
            {
                lowerHit = true;
                if(StringLen(lowerBy) > 0) lowerBy += ",";
                lowerBy += StringFormat("%d", idx);
            }
        }

        if(line1_current == EMPTY_VALUE || line2_current == EMPTY_VALUE ||
           line1_previous == EMPTY_VALUE || line2_previous == EMPTY_VALUE)
        {
            continue;
        }

        bool crossAbove = (line1_previous <= line2_previous) && (line1_current > line2_current);
        bool crossBelow = (line1_previous >= line2_previous) && (line1_current < line2_current);

        // Get current volume/strength value
        double vol_curr = 0.0;
        bool   has_curr = false;
        int    vol_curr_idx = -1;
        const double EPS = 1e-6;
        {
            double v_pos = (VolumeBuffer1 >= 0) ? iCustom(Symbol(), Period(), IndicatorName, VolumeBuffer1, i) : EMPTY_VALUE;
            double v_neg = (VolumeBuffer2 >= 0) ? iCustom(Symbol(), Period(), IndicatorName, VolumeBuffer2, i) : EMPTY_VALUE;
            double v_dup = (VolumeBuffer3 >= 0) ? iCustom(Symbol(), Period(), IndicatorName, VolumeBuffer3, i) : EMPTY_VALUE;
            if(v_pos != EMPTY_VALUE && MathAbs(v_pos) > EPS) { vol_curr = v_pos; has_curr = true; vol_curr_idx = VolumeBuffer1; }
            else if(v_neg != EMPTY_VALUE && MathAbs(v_neg) > EPS) { vol_curr = v_neg; has_curr = true; vol_curr_idx = VolumeBuffer2; }
            else if(v_dup != EMPTY_VALUE && MathAbs(v_dup) > EPS) { vol_curr = v_dup; has_curr = true; vol_curr_idx = VolumeBuffer3; }
        }

        // ===== NEW FORWARD-LOOKING LOGIC =====
        // State machine for crossover -> threshold -> sign confirmation
        
        // Inherit state from next bar (i+1 is the bar before current bar i in time)
        double prevUpState = (i + 1 < Bars) ? CrossUpState[i + 1] : 0;
        double prevDnState = (i + 1 < Bars) ? CrossDnState[i + 1] : 0;
        
        // Initialize current state to previous state
        CrossUpState[i] = prevUpState;
        CrossDnState[i] = prevDnState;

        // 1. Detect new crossovers and reset state
        if(crossAbove)
        {
            CrossUpState[i] = 1; // State 1: crossover detected
            CrossDnState[i] = 0; // Cancel any down sequence
            if(EnableDebug)
                Print(StringFormat("UP CROSS %s %s -> State=1", Symbol(), TimeToStr(Time[i], TIME_DATE|TIME_MINUTES)));
        }
        if(crossBelow)
        {
            CrossDnState[i] = 1; // State 1: crossover detected
            CrossUpState[i] = 0; // Cancel any up sequence
            if(EnableDebug)
                Print(StringFormat("DN CROSS %s %s -> State=1", Symbol(), TimeToStr(Time[i], TIME_DATE|TIME_MINUTES)));
        }

        // 2. Check for threshold progression (state 1 -> state 2)
        // Only transition from state 1 to state 2 when threshold is first hit
        if(CrossUpState[i] == 1 && has_curr && vol_curr <= LowerThreshold)
        {
            CrossUpState[i] = 2; // State 2: threshold hit
            if(EnableDebug)
                Print(StringFormat("UP THRESH %s %s vol=%s -> State=2", Symbol(), TimeToStr(Time[i], TIME_DATE|TIME_MINUTES), DoubleToString(vol_curr, 5)));
        }
        if(CrossDnState[i] == 1 && has_curr && vol_curr >= UpperThreshold)
        {
            CrossDnState[i] = 2; // State 2: threshold hit
            if(EnableDebug)
                Print(StringFormat("DN THRESH %s %s vol=%s -> State=2", Symbol(), TimeToStr(Time[i], TIME_DATE|TIME_MINUTES), DoubleToString(vol_curr, 5)));
        }

        // 3. Check for sign confirmation and draw arrow (state 2 -> state 3)
        if(ShowArrows && (CrossUpState[i] == 2 || CrossDnState[i] == 2) && has_curr)
        {
            double candleHeight = High[i] - Low[i];
            if(candleHeight == 0) candleHeight = Point * 10;
            double gap = candleHeight * (ArrowGapPercent / 100.0);
            
            if(CrossUpState[i] == 2 && vol_curr > 0.0)
            {
                CrossUpState[i] = 3; // State 3: arrow drawn
                CrossArrowUp[i] = Low[i] - gap;
                if(EnableDebug)
                    Print(StringFormat("UP ARROW DRAWN %s %s vol=%s -> State=3", Symbol(), TimeToStr(Time[i], TIME_DATE|TIME_MINUTES), DoubleToString(vol_curr, 5)));
            }
            
            if(CrossDnState[i] == 2 && vol_curr < 0.0)
            {
                CrossDnState[i] = 3; // State 3: arrow drawn
                CrossArrowDown[i] = High[i] + gap;
                if(EnableDebug)
                    Print(StringFormat("DN ARROW DRAWN %s %s vol=%s -> State=3", Symbol(), TimeToStr(Time[i], TIME_DATE|TIME_MINUTES), DoubleToString(vol_curr, 5)));
            }
        }

        // Threshold dots
        if(ShowDots && (upperHit || lowerHit))
        {
            double candleHeightDots = High[i] - Low[i];
            if(candleHeightDots == 0)
                candleHeightDots = Point * 10;
            double dotGap = candleHeightDots * (DotGapPercent / 100.0);

            if(upperHit)
            {
                ThresholdDotUp[i] = High[i] + dotGap;
            }
            if(lowerHit)
            {
                ThresholdDotDn[i] = Low[i] - dotGap;
            }
        }

        // Debug logs
        if(EnableDebug && (DebugLogOnEveryBar || upperHit || lowerHit))
        {
            string ts = TimeToStr(Time[i], TIME_DATE|TIME_MINUTES);
            string vals = "";
            for(int bb = 0; bb < 4; bb++)
            {
                int idb = buffersToCheck[bb];
                if(bb > 0) vals += " ";
                if(idb < 0)
                    vals += StringFormat("b%d(idx=-1)=n/a", bb+1);
                else if(!bufHasValue[bb])
                    vals += StringFormat("b%d(idx=%d)=EMPTY", bb+1, idb);
                else
                    vals += StringFormat("b%d(idx=%d)=%s", bb+1, idb, DoubleToString(bufValues[bb], 5));
            }
            Print(StringFormat("ArrowsSimple DEBUG %s %s upperHit=%s by[%s] lowerHit=%s by[%s] %s",
                               Symbol(), ts,
                               upperHit ? "true" : "false", upperBy,
                               lowerHit ? "true" : "false", lowerBy,
                               vals));

            if(ProbeAllBuffers && ProbeEndIndex >= ProbeStartIndex)
            {
                string scan = "";
                int s = MathMax(0, ProbeStartIndex);
                int e = MathMax(s, ProbeEndIndex);
                for(int pi = s; pi <= e; pi++)
                {
                    double pv = iCustom(Symbol(), Period(), IndicatorName, pi, i);
                    if(pi > s) scan += " ";
                    if(pv == EMPTY_VALUE)
                        scan += StringFormat("[%d]=EMPTY", pi);
                    else
                        scan += StringFormat("[%d]=%s", pi, DoubleToString(pv, 5));
                }
                Print(StringFormat("ArrowsSimple PROBE %s %s idx %d..%d => %s",
                                   Symbol(), ts, s, e, scan));
            }
        }
    }

    return(0);
}

//+------------------------------------------------------------------+

