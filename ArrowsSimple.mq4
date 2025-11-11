#property copyright "Line Crossover Arrows (Simple)"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

// Arrow plots
#property indicator_label1  "Cross Arrow Up"
#property indicator_type1   DRAW_ARROW
#property indicator_label2  "Cross Arrow Down"
#property indicator_type2   DRAW_ARROW

//--- Indicator Parameters
extern string IndicatorName = "CurrencyStrengthWizard"; // Indicator Name (REQUIRED)
int    Line1Buffer = 0;            // Line 1 Buffer Number
int    Line2Buffer = 1;            // Line 2 Buffer Number
extern int    BarsToLookBack = 1000;      // Bars to Look Back
extern bool   ShowArrows = true;          // Show Arrows
extern int    ArrowCodeUp = 233;          // Arrow Code Up (233 = up arrow)
extern int    ArrowCodeDown = 234;        // Arrow Code Down (234 = down arrow)
extern color  ArrowUpColor = clrLightGreen; // Arrow Up Color
extern color  ArrowDnColor = clrRed;      // Arrow Down Color
extern int    ArrowWidth = 2;             // Arrow Width
extern double ArrowGapPercent = 150.0;     // Arrow Gap (% of candle height)

// Volume/Strength buffer settings (for state machine logic)
int    VolumeBuffer1 = 2;          // Additional buffer index to read (green/positive)
int    VolumeBuffer2 = 4;          // Additional buffer index to read (red/negative)
int    VolumeBuffer3 = 6;          // Additional buffer index to read (alt/dup)
double UpperThreshold = 50.0;      // Upper threshold
double LowerThreshold = -50.0;     // Lower threshold

// Buffers
double CrossArrowUp[];
double CrossArrowDown[];

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
    SetIndexBuffer(2, CrossUpState);
    SetIndexBuffer(3, CrossDnState);

    SetIndexStyle(0, DRAW_ARROW, EMPTY, ArrowWidth, ArrowUpColor);
    SetIndexArrow(0, ArrowCodeUp);
    SetIndexEmptyValue(0, EMPTY_VALUE);

    SetIndexStyle(1, DRAW_ARROW, EMPTY, ArrowWidth, ArrowDnColor);
    SetIndexArrow(1, ArrowCodeDown);
    SetIndexEmptyValue(1, EMPTY_VALUE);

    // State buffers are not drawn
    SetIndexStyle(2, DRAW_NONE);
    SetIndexStyle(3, DRAW_NONE);

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
        ArrayInitialize(CrossUpState, 0);
        ArrayInitialize(CrossDnState, 0);
    }

    for(int j = maxBarsToProcess; j < Bars; j++)
    {
        CrossArrowUp[j] = EMPTY_VALUE;
        CrossArrowDown[j] = EMPTY_VALUE;
        CrossUpState[j] = 0;
        CrossDnState[j] = 0;
    }

    // Process from oldest to newest (right to left on chart)
    for(int i = limit; i >= 0; i--)
    {
        CrossArrowUp[i] = EMPTY_VALUE;
        CrossArrowDown[i] = EMPTY_VALUE;

        double line1_current = iCustom(Symbol(), Period(), IndicatorName, Line1Buffer, i);
        double line1_previous = iCustom(Symbol(), Period(), IndicatorName, Line1Buffer, i + 1);
        double line2_current = iCustom(Symbol(), Period(), IndicatorName, Line2Buffer, i);
        double line2_previous = iCustom(Symbol(), Period(), IndicatorName, Line2Buffer, i + 1);

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
        const double EPS = 1e-6;
        {
            double v_pos = (VolumeBuffer1 >= 0) ? iCustom(Symbol(), Period(), IndicatorName, VolumeBuffer1, i) : EMPTY_VALUE;
            double v_neg = (VolumeBuffer2 >= 0) ? iCustom(Symbol(), Period(), IndicatorName, VolumeBuffer2, i) : EMPTY_VALUE;
            double v_dup = (VolumeBuffer3 >= 0) ? iCustom(Symbol(), Period(), IndicatorName, VolumeBuffer3, i) : EMPTY_VALUE;
            if(v_pos != EMPTY_VALUE && MathAbs(v_pos) > EPS) { vol_curr = v_pos; has_curr = true; }
            else if(v_neg != EMPTY_VALUE && MathAbs(v_neg) > EPS) { vol_curr = v_neg; has_curr = true; }
            else if(v_dup != EMPTY_VALUE && MathAbs(v_dup) > EPS) { vol_curr = v_dup; has_curr = true; }
        }

        // ===== FORWARD-LOOKING STATE MACHINE =====
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
        }
        if(crossBelow)
        {
            CrossDnState[i] = 1; // State 1: crossover detected
            CrossUpState[i] = 0; // Cancel any up sequence
        }

        // 2. Check for threshold progression (state 1 -> state 2)
        // Only transition from state 1 to state 2 when threshold is first hit
        if(CrossUpState[i] == 1 && has_curr && vol_curr <= LowerThreshold)
        {
            CrossUpState[i] = 2; // State 2: threshold hit
        }
        if(CrossDnState[i] == 1 && has_curr && vol_curr >= UpperThreshold)
        {
            CrossDnState[i] = 2; // State 2: threshold hit
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
            }
            
            if(CrossDnState[i] == 2 && vol_curr < 0.0)
            {
                CrossDnState[i] = 3; // State 3: arrow drawn
                CrossArrowDown[i] = High[i] + gap;
            }
        }
    }

    return(0);
}

//+------------------------------------------------------------------+

