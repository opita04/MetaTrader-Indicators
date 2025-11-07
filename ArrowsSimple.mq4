#property copyright "Line Crossover Arrows (Simple)"
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

// Buffers
double CrossArrowUp[];
double CrossArrowDown[];

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

    SetIndexStyle(0, DRAW_ARROW, EMPTY, ArrowWidth, ArrowUpColor);
    SetIndexArrow(0, ArrowCodeUp);
    SetIndexEmptyValue(0, EMPTY_VALUE);

    SetIndexStyle(1, DRAW_ARROW, EMPTY, ArrowWidth, ArrowDnColor);
    SetIndexArrow(1, ArrowCodeDown);
    SetIndexEmptyValue(1, EMPTY_VALUE);

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
    }

    for(int j = maxBarsToProcess; j < Bars; j++)
    {
        CrossArrowUp[j] = EMPTY_VALUE;
        CrossArrowDown[j] = EMPTY_VALUE;
    }

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

        if(!ShowArrows)
            continue;

        if(crossAbove || crossBelow)
        {
            double candleHeight = High[i] - Low[i];
            if(candleHeight == 0)
                candleHeight = Point * 10;

            double gap = candleHeight * (ArrowGapPercent / 100.0);

            if(crossAbove)
            {
                CrossArrowUp[i] = Low[i] - gap;
            }
            else if(crossBelow)
            {
                CrossArrowDown[i] = High[i] + gap;
            }
        }
    }

    return(0);
}

//+------------------------------------------------------------------+

