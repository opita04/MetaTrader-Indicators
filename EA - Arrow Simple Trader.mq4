/*
File: EA - Arrow Simple Trader.mq4
Author: unknown
Source: derived from Currency Strength Trader and ArrowsSimple indicators
Description: Expert Advisor that trades based on ArrowsSimple crossover signals with multi-timeframe entry/exit management
Purpose: Automate trading by opening trades on entry timeframe arrows and closing on exit timeframe arrows with breakeven management
Parameters: Trading, arrow logic, time restriction, alert, and historical display settings
Version: 1.01
Last Modified: 2025.11.11 - Initial creation integrating ArrowsSimple logic
Compatibility: MetaTrader 4 (MT4)
*/
#property copyright "Currency Strength Arrow Trader"
#property version   "1.01"
#property strict

//--- General settings
extern string __GeneralSettings     = "";
extern string IndicatorName         = "CurrencyStrengthWizard";
input ENUM_TIMEFRAMES EntryTimeframe = PERIOD_M5;
input ENUM_TIMEFRAMES ExitTimeframe  = PERIOD_M1;
extern double LotSize               = 0.10;
extern int    StopLossPips          = 50;
extern int    TakeProfitPips        = 200;
extern int    MaxOpenPositions      = 1;
extern int    MagicNumber           = 45678;
extern int    Slippage              = 3;

//--- Breakeven settings
extern bool   UseBreakeven          = false;
extern int    BreakevenBufferPips   = 1;

//--- Arrow logic (ported from ArrowsSimple.mq4)
extern string __ArrowSettings       = "";
extern int    Line1Buffer           = 0;
extern int    Line2Buffer           = 1;
extern int    VolumeBuffer1         = 2;
extern int    VolumeBuffer2         = 4;
extern int    VolumeBuffer3         = 6;
extern double UpperThreshold        = 50.0;
extern double LowerThreshold        = -50.0;
extern double ArrowGapPercent       = 150.0;
extern double ExitMarkerGapPercent  = 150.0;

//--- Historical display
extern bool   ShowHistoricalArrows  = true;
extern int    HistoricalLookback    = 500;
extern color  HistoricalBuyColor    = clrLime;
extern color  HistoricalSellColor   = clrRed;
extern color  ExitMarkerColor       = clrOrange;
extern int    EntryArrowCodeUp      = 233;
extern int    EntryArrowCodeDown    = 234;
extern int    ExitMarkerCode        = 158;

//--- Trading hours
extern string __TimeSettings        = "";
extern bool   UseTimeRestrictions   = false;
extern int    TradingHourStart      = 8;
extern int    TradingHourEnd        = 16;

//--- Alert settings
extern string __AlertSettings       = "";
extern bool   AlertOnTrade          = true;
extern bool   popupAlert            = true;
extern bool   pushAlert             = false;
extern bool   emailAlert            = false;

//--- Internal state
string BotName = "Arrow Trader";

string IndicatorPrimaryPath;
string IndicatorFallbackPath;
bool   IndicatorUseFallback = false;

double EntryArrowUp[], EntryArrowDown[], EntryUpState[], EntryDownState[];
double ExitArrowUp[], ExitArrowDown[], ExitUpState[], ExitDownState[];

datetime EntryLastCalcBar = 0;
datetime ExitLastCalcBar  = 0;
datetime lastEntryBar     = 0;
datetime lastExitBar      = 0;

bool IsInitialized = false;

int EntryProcessingDepth = 600;
int ExitProcessingDepth  = 600;

//+------------------------------------------------------------------+
int PipMultiplier()
{
    return (Digits == 3 || Digits == 5) ? 10 : 1;
}
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
    if(!UseTimeRestrictions) return true;

    datetime nowTime = TimeCurrent();
    int hour = TimeHour(nowTime);

    bool within = false;
    if(TradingHourEnd > TradingHourStart)
        within = (hour >= TradingHourStart && hour < TradingHourEnd);
    else if(TradingHourEnd < TradingHourStart)
        within = (hour >= TradingHourStart || hour < TradingHourEnd);

    if(!within)
    {
        PrintFormat("[TimeCheck] Hour=%d outside trading window start=%d end=%d", hour, TradingHourStart, TradingHourEnd);
    }

    return within;
}
//+------------------------------------------------------------------+
bool ProbeIndicatorPath(string symbol, ENUM_TIMEFRAMES tf, const string &path)
{
    double v1 = iCustom(symbol, tf, path, Line1Buffer, 1);
    double v2 = iCustom(symbol, tf, path, Line2Buffer, 1);
    return !(v1 == EMPTY_VALUE && v2 == EMPTY_VALUE);
}
//+------------------------------------------------------------------+
double FetchIndicatorValue(string symbol, ENUM_TIMEFRAMES tf, int buffer, int shift)
{
    string path = IndicatorUseFallback ? IndicatorFallbackPath : IndicatorPrimaryPath;
    double value = iCustom(symbol, tf, path, buffer, shift);
    if(value == EMPTY_VALUE && !IndicatorUseFallback)
    {
        double alt = iCustom(symbol, tf, IndicatorFallbackPath, buffer, shift);
        if(alt != EMPTY_VALUE)
        {
            IndicatorUseFallback = true;
            value = alt;
        }
    }
    return value;
}
//+------------------------------------------------------------------+
bool PrepareArrowArrays(double &arrowUp[], double &arrowDown[],
                        double &stateUp[], double &stateDown[],
                        int size)
{
    if(size <= 0)
    {
        ArrayResize(arrowUp, 0);
        ArrayResize(arrowDown, 0);
        ArrayResize(stateUp, 0);
        ArrayResize(stateDown, 0);
        return false;
    }

    ArrayResize(arrowUp, size);
    ArrayResize(arrowDown, size);
    ArrayResize(stateUp, size);
    ArrayResize(stateDown, size);

    ArraySetAsSeries(arrowUp, true);
    ArraySetAsSeries(arrowDown, true);
    ArraySetAsSeries(stateUp, true);
    ArraySetAsSeries(stateDown, true);

    ArrayInitialize(arrowUp, EMPTY_VALUE);
    ArrayInitialize(arrowDown, EMPTY_VALUE);
    ArrayInitialize(stateUp, 0);
    ArrayInitialize(stateDown, 0);

    return true;
}
//+------------------------------------------------------------------+
void ComputeArrowSeries(string symbol, ENUM_TIMEFRAMES tf, int maxBars,
                        double arrowGapPercent,
                        double &arrowUp[], double &arrowDown[],
                        double &stateUp[], double &stateDown[])
{
    int barsAvailable = iBars(symbol, tf);
    if(barsAvailable <= 1) return;

    int barsToProcess = MathMin(maxBars, barsAvailable - 1);
    if(!PrepareArrowArrays(arrowUp, arrowDown, stateUp, stateDown, barsToProcess + 2))
        return;

    for(int i = barsToProcess; i >= 0; i--)
    {
        arrowUp[i] = EMPTY_VALUE;
        arrowDown[i] = EMPTY_VALUE;

        double line1_curr = FetchIndicatorValue(symbol, tf, Line1Buffer, i);
        double line1_prev = FetchIndicatorValue(symbol, tf, Line1Buffer, i + 1);
        double line2_curr = FetchIndicatorValue(symbol, tf, Line2Buffer, i);
        double line2_prev = FetchIndicatorValue(symbol, tf, Line2Buffer, i + 1);

        if(line1_curr == EMPTY_VALUE || line2_curr == EMPTY_VALUE ||
           line1_prev == EMPTY_VALUE || line2_prev == EMPTY_VALUE)
        {
            stateUp[i] = 0;
            stateDown[i] = 0;
            continue;
        }

        bool crossAbove = (line1_prev <= line2_prev) && (line1_curr > line2_curr);
        bool crossBelow = (line1_prev >= line2_prev) && (line1_curr < line2_curr);

        const double EPS = 1e-6;
        double vol_curr = 0.0;
        bool   has_curr = false;
        if(VolumeBuffer1 >= 0)
        {
            double v = FetchIndicatorValue(symbol, tf, VolumeBuffer1, i);
            if(v != EMPTY_VALUE && MathAbs(v) > EPS) { vol_curr = v; has_curr = true; }
        }
        if(!has_curr && VolumeBuffer2 >= 0)
        {
            double v = FetchIndicatorValue(symbol, tf, VolumeBuffer2, i);
            if(v != EMPTY_VALUE && MathAbs(v) > EPS) { vol_curr = v; has_curr = true; }
        }
        if(!has_curr && VolumeBuffer3 >= 0)
        {
            double v = FetchIndicatorValue(symbol, tf, VolumeBuffer3, i);
            if(v != EMPTY_VALUE && MathAbs(v) > EPS) { vol_curr = v; has_curr = true; }
        }

        double prevUpState = (i + 1 < ArraySize(stateUp)) ? stateUp[i + 1] : 0.0;
        double prevDownState = (i + 1 < ArraySize(stateDown)) ? stateDown[i + 1] : 0.0;

        stateUp[i] = prevUpState;
        stateDown[i] = prevDownState;

        if(crossAbove)
        {
            stateUp[i] = 1;
            stateDown[i] = 0;
        }
        if(crossBelow)
        {
            stateDown[i] = 1;
            stateUp[i] = 0;
        }

        if(stateUp[i] == 1 && has_curr && vol_curr <= LowerThreshold)
            stateUp[i] = 2;
        if(stateDown[i] == 1 && has_curr && vol_curr >= UpperThreshold)
            stateDown[i] = 2;

        if(has_curr)
        {
            double candleHigh = iHigh(symbol, tf, i);
            double candleLow  = iLow(symbol, tf, i);
            double candleHeight = candleHigh - candleLow;
            if(candleHeight <= 0) candleHeight = Point * 10;

            double gap = candleHeight * (arrowGapPercent / 100.0);

            if(stateUp[i] == 2 && vol_curr > 0.0)
            {
                stateUp[i] = 3;
                arrowUp[i] = candleLow - gap;
            }
            if(stateDown[i] == 2 && vol_curr < 0.0)
            {
                stateDown[i] = 3;
                arrowDown[i] = candleHigh + gap;
            }
        }

        if(i <= 2)
        {
            PrintFormat(
                "[ArrowDebug] symbol=%s tf=%d shift=%d l1_curr=%.5f l2_curr=%.5f l1_prev=%.5f l2_prev=%.5f crossAbove=%d crossBelow=%d hasVol=%d vol=%.5f stateUp=%s stateDown=%s arrowUp=%s arrowDown=%s",
                symbol,
                tf,
                i,
                line1_curr,
                line2_curr,
                line1_prev,
                line2_prev,
                crossAbove,
                crossBelow,
                has_curr,
                vol_curr,
                FormatStateValue(stateUp[i]),
                FormatStateValue(stateDown[i]),
                FormatArrowValue(arrowUp[i]),
                FormatArrowValue(arrowDown[i])
            );
        }
    }
}
//+------------------------------------------------------------------+
string FormatArrowValue(double value)
{
    if(value == EMPTY_VALUE) return "EMPTY";
    return DoubleToString(value, Digits);
}
//+------------------------------------------------------------------+
string FormatStateValue(double value)
{
    return StringFormat("%d", (int)MathRound(value));
}
//+------------------------------------------------------------------+
bool RefreshEntryArrowData()
{
    string symbol = Symbol();
    datetime latest = iTime(symbol, (ENUM_TIMEFRAMES)EntryTimeframe, 0);
    if(latest == 0) return false;
    if(latest == EntryLastCalcBar) return false;

    EntryLastCalcBar = latest;
    ComputeArrowSeries(symbol, (ENUM_TIMEFRAMES)EntryTimeframe, EntryProcessingDepth,
                       ArrowGapPercent,
                       EntryArrowUp, EntryArrowDown,
                       EntryUpState, EntryDownState);
    PrintFormat("[EntryCalc] Refreshed arrow buffers up to %d bars (tf=%d)",
                EntryProcessingDepth, EntryTimeframe);
    return true;
}
//+------------------------------------------------------------------+
bool RefreshExitArrowData()
{
    string symbol = Symbol();
    datetime latest = iTime(symbol, (ENUM_TIMEFRAMES)ExitTimeframe, 0);
    if(latest == 0) return false;
    if(latest == ExitLastCalcBar) return false;

    ExitLastCalcBar = latest;
    ComputeArrowSeries(symbol, (ENUM_TIMEFRAMES)ExitTimeframe, ExitProcessingDepth,
                       ArrowGapPercent,
                       ExitArrowUp, ExitArrowDown,
                       ExitUpState, ExitDownState);
    PrintFormat("[ExitCalc] Refreshed arrow buffers up to %d bars (tf=%d)",
                ExitProcessingDepth, ExitTimeframe);
    return true;
}
//+------------------------------------------------------------------+
int GetEntryArrowSignal(int shift)
{
    if(ArraySize(EntryArrowUp) <= shift || ArraySize(EntryArrowDown) <= shift)
        return 0;

    if(EntryArrowUp[shift] != EMPTY_VALUE)
        return 1;
    if(EntryArrowDown[shift] != EMPTY_VALUE)
        return -1;
    return 0;
}
//+------------------------------------------------------------------+
int GetExitArrowSignal(int shift)
{
    if(ArraySize(ExitArrowUp) <= shift || ArraySize(ExitArrowDown) <= shift)
        return 0;

    if(ExitArrowUp[shift] != EMPTY_VALUE)
        return 1;
    if(ExitArrowDown[shift] != EMPTY_VALUE)
        return -1;
    return 0;
}
//+------------------------------------------------------------------+
int GetCrossoverDirection(string symbol, ENUM_TIMEFRAMES tf, int shift)
{
    double line1_curr = FetchIndicatorValue(symbol, tf, Line1Buffer, shift);
    double line1_prev = FetchIndicatorValue(symbol, tf, Line1Buffer, shift + 1);
    double line2_curr = FetchIndicatorValue(symbol, tf, Line2Buffer, shift);
    double line2_prev = FetchIndicatorValue(symbol, tf, Line2Buffer, shift + 1);

    if(line1_curr == EMPTY_VALUE || line2_curr == EMPTY_VALUE ||
       line1_prev == EMPTY_VALUE || line2_prev == EMPTY_VALUE)
        return 0;

    if(line1_prev <= line2_prev && line1_curr > line2_curr)
        return 1;
    if(line1_prev >= line2_prev && line1_curr < line2_curr)
        return -1;
    return 0;
}
//+------------------------------------------------------------------+
void ClearHistoricalObjects()
{
    for(int i = ObjectsTotal() - 1; i >= 0; i--)
    {
        string name = ObjectName(i);
        if(StringFind(name, "HistEntry_") == 0 || StringFind(name, "HistExit_") == 0)
            ObjectDelete(name);
    }
}
//+------------------------------------------------------------------+
void DrawHistoricalMarkers()
{
    if(!ShowHistoricalArrows) return;

    ClearHistoricalObjects();

    string symbol = Symbol();
    int maxEntryShift = MathMin(HistoricalLookback, ArraySize(EntryArrowUp) - 1);
    for(int shift = 1; shift <= maxEntryShift; shift++)
    {
        int signal = 0;
        double price = 0.0;
        if(EntryArrowUp[shift] != EMPTY_VALUE)
        {
            signal = 1;
            price = EntryArrowUp[shift];
        }
        else if(EntryArrowDown[shift] != EMPTY_VALUE)
        {
            signal = -1;
            price = EntryArrowDown[shift];
        }

        if(signal == 0) continue;

        datetime when = iTime(symbol, (ENUM_TIMEFRAMES)EntryTimeframe, shift);
        if(when == 0) continue;

        string name = StringFormat("HistEntry_%s_%d_%d", symbol, signal, (int)when);
        if(ObjectFind(name) != -1) continue;

        if(ObjectCreate(name, OBJ_ARROW, 0, when, price))
        {
            ObjectSetInteger(0, name, OBJPROP_COLOR,
                             (signal == 1) ? HistoricalBuyColor : HistoricalSellColor);
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE,
                             (signal == 1) ? EntryArrowCodeUp : EntryArrowCodeDown);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        }
    }

    int maxExitShift = MathMin(HistoricalLookback, ArraySize(ExitArrowUp) - 1);
    for(int shift = 1; shift <= maxExitShift; shift++)
    {
        int signal = 0;
        if(ExitArrowUp[shift] != EMPTY_VALUE) signal = 1;
        else if(ExitArrowDown[shift] != EMPTY_VALUE) signal = -1;

        if(signal == 0) continue;

        datetime when = iTime(symbol, (ENUM_TIMEFRAMES)ExitTimeframe, shift);
        if(when == 0) continue;

        double candleHigh = iHigh(symbol, (ENUM_TIMEFRAMES)ExitTimeframe, shift);
        double candleLow  = iLow(symbol, (ENUM_TIMEFRAMES)ExitTimeframe, shift);
        double candleHeight = candleHigh - candleLow;
        if(candleHeight <= 0) candleHeight = Point * 10;

        double gap = candleHeight * (ExitMarkerGapPercent / 100.0);
        double price = (signal == 1) ? (candleHigh + gap) : (candleLow - gap);

        string name = StringFormat("HistExit_%s_%d_%d", symbol, signal, (int)when);
        if(ObjectFind(name) != -1) continue;

        if(ObjectCreate(name, OBJ_ARROW, 0, when, price))
        {
            ObjectSetInteger(0, name, OBJPROP_COLOR, ExitMarkerColor);
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, ExitMarkerCode);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        }
    }

    PrintFormat("[Historical] Redrawn up to %d bars", HistoricalLookback);
}
//+------------------------------------------------------------------+
bool CanOpenPosition(string symbol)
{
    int openPositions = 0;
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
        if(OrderSymbol() == symbol && OrderMagicNumber() == MagicNumber)
            openPositions++;
    }
    return (openPositions < MaxOpenPositions);
}
//+------------------------------------------------------------------+
void Alarm(string body)
{
    string shortName = BotName + " ";
    if(popupAlert) Alert(shortName, body);
    if(emailAlert) SendMail("From " + shortName, shortName + body);
    if(pushAlert)  SendNotification(shortName + body);
}
//+------------------------------------------------------------------+
bool PlaceOrder(int orderType)
{
    string symbol = Symbol();
    if(!CanOpenPosition(symbol))
    {
        Print("[OrderSend] Skipped - max open positions reached");
        return false;
    }

    int pipMult = PipMultiplier();
    double price = (orderType == OP_BUY) ? Ask : Bid;
    double sl = 0.0;
    double tp = 0.0;

    if(orderType == OP_BUY)
    {
        sl = price - StopLossPips * Point * pipMult;
        tp = price + TakeProfitPips * Point * pipMult;
    }
    else
    {
        sl = price + StopLossPips * Point * pipMult;
        tp = price - TakeProfitPips * Point * pipMult;
    }

    sl = NormalizeDouble(sl, Digits);
    tp = NormalizeDouble(tp, Digits);

    double lots = NormalizeDouble(LotSize, 2);

    PrintFormat("[OrderSend] type=%s price=%.5f SL=%.5f TP=%.5f lots=%.2f",
                (orderType == OP_BUY) ? "BUY" : "SELL", price, sl, tp, lots);

    int ticket = OrderSend(symbol, orderType, lots, price, Slippage, sl, tp, BotName, MagicNumber, 0, clrDodgerBlue);
    if(ticket < 0)
    {
        PrintFormat("[OrderSend][Error] %d", GetLastError());
        return false;
    }

    string direction = (orderType == OP_BUY) ? "BUY" : "SELL";
    string message = StringFormat("%s %s at %.5f (SL %.5f TP %.5f)",
                                  symbol, direction, price, sl, tp);
    Print("[OrderSend][Success] ", message);
    if(AlertOnTrade) Alarm("TRADE OPENED: " + message);

    return true;
}
//+------------------------------------------------------------------+
void CloseTrades(int orderTypeToClose)
{
    string symbol = Symbol();
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
        if(OrderMagicNumber() != MagicNumber || OrderSymbol() != symbol)
            continue;
        if(OrderType() != orderTypeToClose)
            continue;

        double closePrice = (OrderType() == OP_BUY) ? Bid : Ask;
        bool result = OrderClose(OrderTicket(), OrderLots(), closePrice, Slippage, clrOrangeRed);
        PrintFormat("[OrderClose] ticket=%d dir=%s result=%d",
                    OrderTicket(),
                    (OrderType() == OP_BUY) ? "BUY" : "SELL",
                    result);
        if(!result)
            PrintFormat("[OrderClose][Error] %d", GetLastError());
    }
}
//+------------------------------------------------------------------+
void MoveTradesToBreakeven(int crossoverDirection)
{
    if(!UseBreakeven) return;

    string symbol = Symbol();
    int pipMult = PipMultiplier();
    double bufferPoints = BreakevenBufferPips * Point * pipMult;

    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
        if(OrderMagicNumber() != MagicNumber || OrderSymbol() != symbol)
            continue;

        bool isBuy = (OrderType() == OP_BUY);

        if(isBuy && crossoverDirection != -1) continue;
        if(!isBuy && crossoverDirection != 1) continue;

        double newSL = OrderOpenPrice();
        if(isBuy)
        {
            newSL += bufferPoints;
            newSL = NormalizeDouble(newSL, Digits);
            if(Bid <= newSL) continue;
            if(OrderStopLoss() != 0 && OrderStopLoss() >= newSL - Point * pipMult / 2.0) continue;
        }
        else
        {
            newSL -= bufferPoints;
            newSL = NormalizeDouble(newSL, Digits);
            if(Ask >= newSL) continue;
            if(OrderStopLoss() != 0 && OrderStopLoss() <= newSL + Point * pipMult / 2.0) continue;
        }

        bool modified = OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), OrderExpiration(), clrAqua);
        PrintFormat("[Breakeven] ticket=%d dir=%s newSL=%.5f result=%d",
                    OrderTicket(), isBuy ? "BUY" : "SELL", newSL, modified);
        if(!modified)
            PrintFormat("[Breakeven][Error] %d", GetLastError());
    }
}
//+------------------------------------------------------------------+
int OnInit()
{
    PrintFormat("[Init] Symbol=%s EntryTF=%d ExitTF=%d Indicator=%s",
                Symbol(), EntryTimeframe, ExitTimeframe, IndicatorName);

    IndicatorPrimaryPath  = IndicatorName;
    IndicatorFallbackPath = "Millionaire Maker\\" + IndicatorName;

    bool baseEntryOk = ProbeIndicatorPath(Symbol(), (ENUM_TIMEFRAMES)EntryTimeframe, IndicatorPrimaryPath);
    bool baseExitOk  = ProbeIndicatorPath(Symbol(), (ENUM_TIMEFRAMES)ExitTimeframe, IndicatorPrimaryPath);

    if(!baseEntryOk || !baseExitOk)
    {
        bool fallbackEntryOk = ProbeIndicatorPath(Symbol(), (ENUM_TIMEFRAMES)EntryTimeframe, IndicatorFallbackPath);
        bool fallbackExitOk  = ProbeIndicatorPath(Symbol(), (ENUM_TIMEFRAMES)ExitTimeframe, IndicatorFallbackPath);

        if(fallbackEntryOk || fallbackExitOk)
        {
            IndicatorUseFallback = true;
            Print("[Init] Using fallback indicator path: ", IndicatorFallbackPath);
        }
        else
        {
            Print("[Init][Fail] Indicator buffers unavailable on configured timeframes.");
            return(INIT_FAILED);
        }
    }

    if(LotSize <= 0.0) LotSize = 0.01;
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
    double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
    if(minLot > 0 && LotSize < minLot) LotSize = minLot;
    if(maxLot > 0 && LotSize > maxLot) LotSize = maxLot;

    EntryProcessingDepth = MathMax(HistoricalLookback + 10, 300);
    ExitProcessingDepth  = MathMax(HistoricalLookback + 10, 300);

    RefreshEntryArrowData();
    RefreshExitArrowData();
    DrawHistoricalMarkers();

    Print("[Init] Initialization complete.");
    IsInitialized = true;
    return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    PrintFormat("[Deinit] reason=%d", reason);
    ClearHistoricalObjects();
    IsInitialized = false;
}
//+------------------------------------------------------------------+
void OnTick()
{
    if(!IsInitialized) return;

    string symbol = Symbol();

    bool entryUpdated = RefreshEntryArrowData();
    bool exitUpdated  = RefreshExitArrowData();

    if((entryUpdated || exitUpdated) && ShowHistoricalArrows)
        DrawHistoricalMarkers();

    datetime entryBarTime = iTime(symbol, (ENUM_TIMEFRAMES)EntryTimeframe, 0);
    if(entryBarTime != 0 && entryBarTime != lastEntryBar)
    {
        lastEntryBar = entryBarTime;

        int entrySignal = GetEntryArrowSignal(1);
        PrintFormat("[EntryCheck] %s tf=%d signal=%d", TimeToString(entryBarTime), EntryTimeframe, entrySignal);

        if(entrySignal != 0 && IsWithinTradingHours())
        {
            if(entrySignal == 1) PlaceOrder(OP_BUY);
            else if(entrySignal == -1) PlaceOrder(OP_SELL);
        }
        else if(entrySignal != 0)
        {
            Print("[EntryCheck] Signal blocked by time restrictions.");
        }
        else
        {
            double upVal = (ArraySize(EntryArrowUp) > 1) ? EntryArrowUp[1] : EMPTY_VALUE;
            double downVal = (ArraySize(EntryArrowDown) > 1) ? EntryArrowDown[1] : EMPTY_VALUE;
            double upState = (ArraySize(EntryUpState) > 1) ? EntryUpState[1] : 0;
            double downState = (ArraySize(EntryDownState) > 1) ? EntryDownState[1] : 0;
            PrintFormat("[EntryCheck][Buffers] shift=1 up=%s down=%s stateUp=%s stateDown=%s",
                        FormatArrowValue(upVal),
                        FormatArrowValue(downVal),
                        FormatStateValue(upState),
                        FormatStateValue(downState));
        }
    }

    datetime exitBarTime = iTime(symbol, (ENUM_TIMEFRAMES)ExitTimeframe, 0);
    if(exitBarTime != 0 && exitBarTime != lastExitBar)
    {
        lastExitBar = exitBarTime;

        int exitSignal = GetExitArrowSignal(1);
        PrintFormat("[ExitCheck] %s tf=%d signal=%d", TimeToString(exitBarTime), ExitTimeframe, exitSignal);

        if(exitSignal == 1) CloseTrades(OP_SELL);
        else if(exitSignal == -1) CloseTrades(OP_BUY);

        int crossoverDir = GetCrossoverDirection(symbol, (ENUM_TIMEFRAMES)ExitTimeframe, 1);
        if(crossoverDir != 0)
        {
            PrintFormat("[Crossover] dir=%d detected on exit timeframe", crossoverDir);
            MoveTradesToBreakeven(crossoverDir);
        }
        else
        {
            double upVal = (ArraySize(ExitArrowUp) > 1) ? ExitArrowUp[1] : EMPTY_VALUE;
            double downVal = (ArraySize(ExitArrowDown) > 1) ? ExitArrowDown[1] : EMPTY_VALUE;
            double upState = (ArraySize(ExitUpState) > 1) ? ExitUpState[1] : 0;
            double downState = (ArraySize(ExitDownState) > 1) ? ExitDownState[1] : 0;
            PrintFormat("[ExitCheck][Buffers] shift=1 up=%s down=%s stateUp=%s stateDown=%s",
                        FormatArrowValue(upVal),
                        FormatArrowValue(downVal),
                        FormatStateValue(upState),
                        FormatStateValue(downState));
        }
    }
}
