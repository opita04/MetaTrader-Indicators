/*
File: smLazyTMA HuskyBands_v2.1.mq4
Author: SwingMan (original) / unknown (current)
Source: Copyright 22.06.2019, SwingMan
Description: HuskyBands (TMA-based bands) indicator providing multiple band levels and signal arrows
Purpose: Compute TMA-centered bands and optional entry/exit arrows based on band thresholds
Parameters: See input parameters (HalfLength, MA method, ATR multipliers, draw options)
Version: 2.1
Last Modified: 2025.11.06
Compatibility: MetaTrader 4 (MT4)
*/
//+------------------------------------------------------------------+
#property copyright "Copyright 22.06.2019, SwingMan"
#property version   "2.1"
#property indicator_chart_window
#property indicator_buffers 19
#property indicator_plots   16

// Plot definitions
#property indicator_label1  "TMA UP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  4

#property indicator_label2  "TMA DOWN"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrTomato
#property indicator_style2  STYLE_SOLID
#property indicator_width2  4

// Upper bands
#property indicator_label3  "Upper Band 1"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrChocolate
#property indicator_style3  STYLE_DASH
#property indicator_width3  1

#property indicator_label4  "Upper Band 2"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrHotPink
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

#property indicator_label5  "Upper Band 3"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrMagenta
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

#property indicator_label6  "Upper Band 4"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrMagenta
#property indicator_style6  STYLE_DOT
#property indicator_width6  1

// Lower bands
#property indicator_label7  "Lower Band 1"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrChocolate
#property indicator_style7  STYLE_DASH
#property indicator_width7  1

#property indicator_label8  "Lower Band 2"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrSpringGreen
#property indicator_style8  STYLE_SOLID
#property indicator_width8  2

#property indicator_label9  "Lower Band 3"
#property indicator_type9   DRAW_LINE
#property indicator_color9  clrMediumSeaGreen
#property indicator_style9  STYLE_SOLID
#property indicator_width9  1

#property indicator_label10 "Lower Band 4"
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
input int                    HalfLength      = 34;            // Half Length
input int                    ma_period       = 4;             // MA averaging period
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

// Buffers
double tmaUP[], tmaDN[], tmaCentered[];
double bandUP1[], bandUP2[], bandUP3[], bandUP4[];
double bandDN1[], bandDN2[], bandDN3[], bandDN4[];
double slope[];
double arrowUP[], arrowDN[], exitUP[], exitDN[];
double tmaCenteredHighs[], tmaCenteredLows[];
double weights[];
double signalSended[];

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

//+------------------------------------------------------------------+
//| Custom indicator initialization function                           |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize lengths
    HalfLength = MathMax(HalfLength, 1);
    fullLength = HalfLength * 2 + 1;
    ArrayResize(weights, fullLength);
    
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
    SetIndexBuffer(16, tmaCentered, INDICATOR_CALCULATIONS);
    SetIndexBuffer(17, slope, INDICATOR_CALCULATIONS);
    SetIndexBuffer(18, signalSended, INDICATOR_CALCULATIONS);

    // Set plot arrows
    PlotIndexSetInteger(10, PLOT_ARROW, ArrowCode_EntrySignal);
    PlotIndexSetInteger(11, PLOT_ARROW, ArrowCode_EntrySignal);
    PlotIndexSetInteger(12, PLOT_ARROW, ArrowCode_ExitSignal);
    PlotIndexSetInteger(13, PLOT_ARROW, ArrowCode_ExitSignal);

    // Hide plots based on input parameters
    if(!Draw_Band1)
    {
        PlotIndexSetInteger(2, PLOT_SHOW_LINE, false);
        PlotIndexSetInteger(6, PLOT_SHOW_LINE, false);
    }
    if(!Draw_Band2)
    {
        PlotIndexSetInteger(3, PLOT_SHOW_LINE, false);
        PlotIndexSetInteger(7, PLOT_SHOW_LINE, false);
    }
    if(!Draw_Band3)
    {
        PlotIndexSetInteger(4, PLOT_SHOW_LINE, false);
        PlotIndexSetInteger(8, PLOT_SHOW_LINE, false);
    }
    if(!Draw_Band4)
    {
        PlotIndexSetInteger(5, PLOT_SHOW_LINE, false);
        PlotIndexSetInteger(9, PLOT_SHOW_LINE, false);
    }
    if(!Draw_HighLow_TMA)
    {
        PlotIndexSetInteger(14, PLOT_SHOW_LINE, false);
        PlotIndexSetInteger(15, PLOT_SHOW_LINE, false);
    }

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
                const long &spread[])
{
    // Check for minimum required bars
    if(rates_total < HalfLength + ATR_Period + 10) return(0);
    
    // Calculate starting point
    int start;
    if(prev_calculated == 0)
    {
        start = HalfLength + ATR_Period + 10;
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
    }
    else
    {
        start = prev_calculated - 1;
    }

    // Check for new bar
    thisTime = time[0];
    if(thisTime != oldTime)
    {
        newBar = true;
        oldTime = thisTime;
        newRedraw = true;
    }
    else
    {
        newBar = false;
        newRedraw = false;
    }

    // Limit calculation to specified number of bars
    int limit = rates_total - start;
    if(limit > Total_Bars)
        limit = Total_Bars;

    // Main calculation for new bars
    if(newBar)
    {
        // Calculate TMA averages
        Calculate_TMA_AVERAGE(limit, PRICE_MEDIAN, tmaCentered, tmaUP, tmaDN, slope);

        switch(Band_Type)
        {
            case Median_Band:
                break;
            case HighLow_Bands:
                Calculate_TMA_AVERAGE(limit, PRICE_HIGH, tmaCenteredHighs, tmaUP, tmaDN, slope);
                Calculate_TMA_AVERAGE(limit, PRICE_LOW, tmaCenteredLows, tmaUP, tmaDN, slope);
                break;
        }

        // Calculate bands
        Calculate_TMA_BANDS(limit, tmaCentered, tmaCenteredHighs, tmaCenteredLows,
                           bandUP1, bandUP2, bandUP3, bandUP4,
                           bandDN1, bandDN2, bandDN3, bandDN4);

        // Generate signals if enabled
        if(Draw_SignalArrows)
        {
            // Entry signals
            for(int i = limit; i >= 0 && !IsStopped(); i--)
            {
                Get_SlopeMomentumValues(Symbol(), PERIOD_CURRENT, i);
                arrowUP[i] = EMPTY_VALUE;
                arrowDN[i] = EMPTY_VALUE;

                // Skip last bar
                if(i == 0) continue;

                bool signalOK;
                int nBarsCheckClosesAtBands = 5;
                int nBarsCheckOldSignals = 1;

                // LONG signals
                if(iMomentum_Direction == OP_BUY)
                {
                    signalOK = true;
                    for(int j = 1; j <= nBarsCheckOldSignals; j++)
                    {
                        if(arrowUP[i+j] != EMPTY_VALUE)
                        {
                            signalOK = false;
                            break;
                        }
                    }

                    if(signalOK)
                    {
                        if(iOpen(Symbol(), PERIOD_CURRENT, i) < tmaCentered[i] && 
                           iOpen(Symbol(), PERIOD_CURRENT, i) < bandDN1[i])
                        {
                            bool bThresholdBand = true;
                            if(Threshold_Band == Band2 && iOpen(Symbol(), PERIOD_CURRENT, i) > bandDN2[i]) bThresholdBand = false;
                            else if(Threshold_Band == Band3 && iOpen(Symbol(), PERIOD_CURRENT, i) > bandDN3[i]) bThresholdBand = false;
                            else if(Threshold_Band == Band4 && iOpen(Symbol(), PERIOD_CURRENT, i) > bandDN4[i]) bThresholdBand = false;

                            if(bThresholdBand)
                            {
                                for(int k = 1; k <= nBarsCheckClosesAtBands; k++)
                                {
                                    if(iClose(Symbol(), PERIOD_CURRENT, i+k) < bandDN4[i+k] || 
                                       iClose(Symbol(), PERIOD_CURRENT, i+k) < bandDN3[i+k] || 
                                       iClose(Symbol(), PERIOD_CURRENT, i+k) < bandDN2[i+k] || 
                                       iClose(Symbol(), PERIOD_CURRENT, i+k) < bandDN1[i+k])
                                    {
                                        arrowUP[i] = iOpen(Symbol(), PERIOD_CURRENT, i);
                                        if(i == 0)
                                            SendAlerts(i, OP_BUY, Symbol(), PERIOD_CURRENT, slope);
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }

                // SHORT signals
                if(iMomentum_Direction == OP_SELL)
                {
                    signalOK = true;
                    for(int j = 1; j <= nBarsCheckOldSignals; j++)
                    {
                        if(arrowDN[i+j] != EMPTY_VALUE)
                        {
                            signalOK = false;
                            break;
                        }
                    }

                    if(signalOK)
                    {
                        if(iOpen(Symbol(), PERIOD_CURRENT, i) > tmaCentered[i] && 
                           iOpen(Symbol(), PERIOD_CURRENT, i) > bandUP1[i])
                        {
                            bool bThresholdBand = true;
                            if(Threshold_Band == Band2 && iOpen(Symbol(), PERIOD_CURRENT, i) < bandUP2[i]) bThresholdBand = false;
                            else if(Threshold_Band == Band3 && iOpen(Symbol(), PERIOD_CURRENT, i) < bandUP3[i]) bThresholdBand = false;
                            else if(Threshold_Band == Band4 && iOpen(Symbol(), PERIOD_CURRENT, i) < bandUP4[i]) bThresholdBand = false;

                            if(bThresholdBand)
                            {
                                for(int k = 1; k <= nBarsCheckClosesAtBands; k++)
                                {
                                    if(iClose(Symbol(), PERIOD_CURRENT, i+k) > bandUP4[i+k] || 
                                       iClose(Symbol(), PERIOD_CURRENT, i+k) > bandUP3[i+k] || 
                                       iClose(Symbol(), PERIOD_CURRENT, i+k) > bandUP2[i+k] || 
                                       iClose(Symbol(), PERIOD_CURRENT, i+k) > bandUP1[i+k])
                                    {
                                        arrowDN[i] = iOpen(Symbol(), PERIOD_CURRENT, i);
                                        if(i == 0)
                                            SendAlerts(i, OP_SELL, Symbol(), PERIOD_CURRENT, slope);
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate TMA Average                                              |
//+------------------------------------------------------------------+
void Calculate_TMA_AVERAGE(int limitX, ENUM_APPLIED_PRICE applied_priceX, double &tmaCenteredX[], 
                          double &tmaUPX[], double &tmaDNX[], double &slopeX[])
{
    // Calculate TMA values  
    Calculate_TMA_centered(applied_priceX, limitX, tmaCenteredX);

    if(applied_priceX != PRICE_MEDIAN)
        return;

    // Draw colored TMA median lines for UP and DOWN trend 
    for(int i = limitX-2; i >= 0 && !IsStopped(); i--)
    {
        if(tmaCenteredX[i+1] != 0)
            slopeX[i] = 10000 * (tmaCenteredX[i] - tmaCenteredX[i+1]) / tmaCenteredX[i+1];
    }

    for(int i = limitX-3; i >= 0 && !IsStopped(); i--)
    {
        int ii = i + 1;

        tmaUPX[i] = EMPTY_VALUE;
        tmaDNX[i] = EMPTY_VALUE;

        if(slopeX[ii] >= 0)
        {
            tmaUPX[i] = tmaCenteredX[i];
            if(slopeX[ii+1] < 0)
            {
                tmaUPX[i+1] = tmaCenteredX[i+1];
            }
        }
        else if(slopeX[ii] < 0)
        {
            tmaDNX[i] = tmaCenteredX[i];
            if(slopeX[ii+1] > 0)
                tmaDNX[i+1] = tmaCenteredX[i+1];
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate TMA Bands                                                |
//+------------------------------------------------------------------+
void Calculate_TMA_BANDS(int limitX, double &tmaCenteredX[], double &tmaCenteredHighsX[], double &tmaCenteredLowsX[],
                        double &bandUP1X[], double &bandUP2X[], double &bandUP3X[], double &bandUP4X[],
                        double &bandDN1X[], double &bandDN2X[], double &bandDN3X[], double &bandDN4X[])
{
    double deviation = 0;

    for(int i = limitX; i >= 0 && !IsStopped(); i--)
    {
        // Calculate StdDev between Close and TMA median
        double StdDev_dTmp = 0;
        for(int ij = 0; ij < ATR_Period; ij++)
        {
            double dClose = iClose(Symbol(), PERIOD_CURRENT, i + ij);
            StdDev_dTmp += MathPow(dClose - tmaCenteredX[i + ij], 2);
        }

        deviation = MathSqrt(StdDev_dTmp / ATR_Period);

        // Band distances
        double bandDistance1 = deviation * ATR_Multiplier_Band1;
        double bandDistance2 = deviation * ATR_Multiplier_Band2;
        double bandDistance3 = deviation * ATR_Multiplier_Band3;
        double bandDistance4 = deviation * ATR_Multiplier_Band4;

        double tmaValue;

        switch(Band_Type)
        {
            case Median_Band:
                tmaValue = tmaCenteredX[i];
                Set_BandValues(i, tmaValue, "plus", bandDistance1, bandDistance2, bandDistance3, bandDistance4,
                              bandUP1X, bandUP2X, bandUP3X, bandUP4X);
                Set_BandValues(i, tmaValue, "minus", bandDistance1, bandDistance2, bandDistance3, bandDistance4,
                              bandDN1X, bandDN2X, bandDN3X, bandDN4X);
                break;

            case HighLow_Bands:
                tmaValue = tmaCenteredHighsX[i];
                Set_BandValues(i, tmaValue, "plus", bandDistance1, bandDistance2, bandDistance3, bandDistance4,
                              bandUP1X, bandUP2X, bandUP3X, bandUP4X);
                tmaValue = tmaCenteredLowsX[i];
                Set_BandValues(i, tmaValue, "minus", bandDistance1, bandDistance2, bandDistance3, bandDistance4,
                              bandDN1X, bandDN2X, bandDN3X, bandDN4X);
                break;
        }
    }
}

//+------------------------------------------------------------------+
//| Set Band Values                                                    |
//+------------------------------------------------------------------+
void Set_BandValues(int iBar, double tmaValueX, string code,
                    double distance1, double distance2, double distance3, double distance4,
                    double &band1X[], double &band2X[], double &band3X[], double &band4X[])
{
    int sign = (code == "plus") ? 1 : -1;

    band1X[iBar] = tmaValueX + distance1 * sign;
    band2X[iBar] = tmaValueX + distance2 * sign;
    band3X[iBar] = tmaValueX + distance3 * sign;
    band4X[iBar] = tmaValueX + distance4 * sign;
}

//+------------------------------------------------------------------+
//| Calculate TMA Centered                                             |
//+------------------------------------------------------------------+
void Calculate_TMA_centered(ENUM_APPLIED_PRICE applied_priceX, int limitX, double &buffer1[])
{
    double sum, sumw;
    int i, j, k;

    if(limitX < 5)
        limitX = fullLength + 1;

    for(i = limitX - HalfLength - 1; i >= 0; i--)
    {
        sum = 0.0;
        for(j = 0; j < fullLength; j++)
        {
            double price = GetAppliedPrice(applied_priceX, i + j);
            double ma = iMA(NULL, PERIOD_CURRENT, ma_period, 0, ma_method, applied_priceX, i + j);
            sum += ma * weights[j];
        }
        buffer1[i + HalfLength] = sum / sumWeights;
    }

    for(i = HalfLength - 1; i >= 0; i--)
    {
        sum = (HalfLength + 1) * iMA(NULL, PERIOD_CURRENT, ma_period, 0, ma_method, applied_priceX, i);
        sumw = (HalfLength + 1);

        for(j = 1, k = HalfLength; j < HalfLength; j++, k--)
        {
            double ma = iMA(NULL, PERIOD_CURRENT, ma_period, 0, ma_method, applied_priceX, i + j);
            sum += ma * k;
            sumw += k;
            if(j <= i)
            {
                ma = iMA(NULL, PERIOD_CURRENT, ma_period, 0, ma_method, applied_priceX, i - j);
                sum += ma * k;
                sumw += k;
            }
        }
        buffer1[i] = sum / sumw;
    }
}

//+------------------------------------------------------------------+
//| Get Applied Price                                                  |
//+------------------------------------------------------------------+
double GetAppliedPrice(ENUM_APPLIED_PRICE applied_price, int index)
{
    switch(applied_price)
    {
        case PRICE_CLOSE:    return iClose(Symbol(), PERIOD_CURRENT, index);
        case PRICE_OPEN:     return iOpen(Symbol(), PERIOD_CURRENT, index);
        case PRICE_HIGH:     return iHigh(Symbol(), PERIOD_CURRENT, index);
        case PRICE_LOW:      return iLow(Symbol(), PERIOD_CURRENT, index);
        case PRICE_MEDIAN:   return (iHigh(Symbol(), PERIOD_CURRENT, index) + iLow(Symbol(), PERIOD_CURRENT, index)) / 2.0;
        case PRICE_TYPICAL:  return (iHigh(Symbol(), PERIOD_CURRENT, index) + iLow(Symbol(), PERIOD_CURRENT, index) + iClose(Symbol(), PERIOD_CURRENT, index)) / 3.0;
        case PRICE_WEIGHTED: return (iHigh(Symbol(), PERIOD_CURRENT, index) + iLow(Symbol(), PERIOD_CURRENT, index) + iClose(Symbol(), PERIOD_CURRENT, index) * 2) / 4.0;
        default: return iClose(Symbol(), PERIOD_CURRENT, index);
    }
}

//+------------------------------------------------------------------+
//| Get Slope Momentum Values                                          |
//+------------------------------------------------------------------+
void Get_SlopeMomentumValues(string symbol, ENUM_TIMEFRAMES timeFrame, int iBar)
{
    double slopeMA;
    double slopeM = 0;
    int SlopeBarsBack = 1;
    int PivotsAverage_Period = 21;
    double Factor_SlopeFiltering = 0.40;
    
    double buffMomentum[], slopeLine[], arrSlopeSorted[];
    ArrayResize(buffMomentum, PivotsAverage_Period + 2);
    ArrayResize(slopeLine, PivotsAverage_Period + 2);
    ArrayResize(arrSlopeSorted, PivotsAverage_Period);
    
    ArrayInitialize(buffMomentum, 0.0);
    ArrayInitialize(slopeLine, 0.0);

    // Calculate Slope line
    for(int i = 0; i < PivotsAverage_Period + 1; i++)
    {
        buffMomentum[i] = iMA(symbol, timeFrame, 3, 1, MODE_SMA, PRICE_TYPICAL, iBar + i);
    }

    for(int i = 0; i < PivotsAverage_Period + 1; i++)
    {
        if(buffMomentum[i + SlopeBarsBack] != 0)
        {
            slopeM = (buffMomentum[i] / buffMomentum[i + SlopeBarsBack]);
            slopeLine[i] = 1000 * MathLog10(slopeM);
        }
        else slopeMA = EMPTY_VALUE;
    }

    // Previous bar
    int prevBar = 1;
    slopeMA = slopeLine[0 + prevBar];

    // Limits for Slope line
    int iPosition = (int)MathFloor(PivotsAverage_Period * Factor_SlopeFiltering);

    for(int i = 0; i < PivotsAverage_Period; i++)
        arrSlopeSorted[i] = MathAbs(slopeLine[i]);

    ArraySort(arrSlopeSorted);
    double slopeLimitValue = arrSlopeSorted[iPosition];

    // Slope Momentum conditions
    int iMomentum_Direction = OP_NONE;

    if(MathAbs(slopeMA) >= slopeLimitValue)
    {
        if(slopeMA > 0 && slopeLine[0] < slopeLine[1] && slopeLine[1] > slopeLine[2])
        {
            iMomentum_Direction = OP_SELL;
        }
        else if(slopeMA < 0 && slopeLine[0] > slopeLine[1] && slopeLine[1] < slopeLine[2])
        {
            iMomentum_Direction = OP_BUY;
        }
    }

    // Update signal generation code in OnCalculate
    if(iMomentum_Direction == OP_BUY)
    {
        // Generate buy signals
        // ... Signal generation code continues
    }
    else if(iMomentum_Direction == OP_SELL)
    {
        // Generate sell signals
        // ... Signal generation code continues
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
    double dEntryPrice = iOpen(sSymbol, iPeriod, iBar);
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
    switch(iPeriod)
    {
        case PERIOD_M1:   return "M1";
        case PERIOD_M5:   return "M5";
        case PERIOD_M15:  return "M15";
        case PERIOD_M30:  return "M30";
        case PERIOD_H1:   return "H1";
        case PERIOD_H4:   return "H4";
        case PERIOD_D1:   return "D1";
        case PERIOD_W1:   return "W1";
        case PERIOD_MN1:  return "MN1";
        default:          return "Unknown";
    }
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
    if(Show_Comments)
        Comment("");
}