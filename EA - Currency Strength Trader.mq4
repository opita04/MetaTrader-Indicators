/*
File: EA - Currency Strength Trader.mq4
Author: unknown
Source: unknown
Description: Expert Advisor that trades based on currency strength alignment and Opita04 trigger
Purpose: Automate trading when multiple timeframes align and an Opita04 trigger confirms the signal
Parameters: See trading, timeframe, and indicator settings near top of file
Version: 1.00
Last Modified: 2025.11.06
Compatibility: MetaTrader 4 (MT4)
*/
//+------------------------------------------------------------------+
#property copyright "Currency Strength Trader"
#property version   "1.00"
#property strict

//--- Trading Parameters
extern string __TradingSettings = ""; // === TRADING SETTINGS ===
extern double LotSize = 0.01;                    // Lot Size
extern int StopLoss = 50;                        // Stop Loss in Pips
extern int TakeProfit = 100;                     // Take Profit in Pips
extern int MagicNumber = 12345;                  // Magic Number for Orders
extern int MaxOpenPositions = 1;                 // Maximum Open Positions

//--- Time Restrictions (uses BROKER TIME, not PC time)
extern string __TimeRestrictions = ""; // === TIME RESTRICTIONS ===
extern bool   UseTimeRestrictions = false;      // Enable Time-Based Trading Restrictions
extern int    TradingHourStart = 8;             // Trading Start Hour (0-23, Broker Time)
extern int    TradingHourEnd = 16;              // Trading End Hour (0-23, Broker Time)

//--- Timeframe Settings (1-4 alignment timeframes)
extern string __TimeframeSettings = ""; // === ALIGNMENT TIMEFRAME SETTINGS ===
extern int    NumTimeframes = 2;              // Number of Alignment Timeframes (1-4)
extern ENUM_TIMEFRAMES Timeframe4 = PERIOD_H4;   // Alignment Timeframe 1
extern ENUM_TIMEFRAMES Timeframe3 = PERIOD_H1;   // Alignment Timeframe 2
extern ENUM_TIMEFRAMES Timeframe2 = PERIOD_H1;  // Alignment Timeframe 3
extern ENUM_TIMEFRAMES Timeframe1 = PERIOD_M5;   // Alignment Timeframe 4

//--- Opita04 Trigger Settings
extern string __OpitaSettings = ""; // === OPITA04 TRIGGER SETTINGS ===
extern bool   UseOpita04Trigger = true;        // Use Opita04 as Trigger Indicator
extern double OpitaArrowGap = 1.0;             // Arrow Gap for Opita Signals

//--- Indicator Settings
extern string __IndicatorName = ""; // === INDICATOR SETTINGS ===
extern string IndicatorName = "CurrencyStrengthWizard"; // Indicator Name (REQUIRED)
extern int    Line1Buffer = 0;             // Line 1 Buffer Number
extern int    Line2Buffer = 1;             // Line 2 Buffer Number
extern int    BarsToLookBack = 500;       // Bars to Look Back
//--- Historical trade arrows settings
extern bool   ShowHistoricalTradeArrows = True; // Draw arrows where trades would have occurred historically
extern color  HistoricalBuyArrowColor = clrGreen;
extern color  HistoricalSellArrowColor = clrRed;
extern int    HistoricalBuyArrowCode = 233;
extern int    HistoricalSellArrowCode = 234;
extern int    HistoricalArrowOffsetPips = 5; // Distance from candle in pips

//--- Alert Settings
extern string __AlertSettings = ""; // === ALERT SETTINGS ===
extern bool   AlertOnTrade = true;        // Alert when trade is opened
extern bool   popupAlert = true;          // Show popup alerts
extern bool   pushAlert = false;          // Send push notifications
extern bool   emailAlert = false;         // Send email alerts

//--- Global Variables
string BotName = "Currency Strength Trader";
ENUM_TIMEFRAMES Timeframes[4]; // Array of alignment timeframes
int PreviousSignals[]; // Previous signals for each timeframe [timeframe_index]
int CurrentAlignmentDirection = 0; // Current alignment direction (0=unaligned, 1=up, -1=down)
bool HasTradedInAlignment = false; // Flag to track if we've traded in current alignment
bool IsInitialized = false;

//+------------------------------------------------------------------+
//| Helper function to get PreviousSignals index                     |
//+------------------------------------------------------------------+
int GetPreviousSignalIndex(int timeframeIndex)
{
    return timeframeIndex;
}

//+------------------------------------------------------------------+
//| Expert Advisor initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
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

    // Validate opita04 settings
    if(UseOpita04Trigger)
    {
        if(OpitaArrowGap <= 0) OpitaArrowGap = 1.0;
        Print("Opita04 trigger enabled with arrow gap: ", DoubleToString(OpitaArrowGap, 1));
    }
    else
    {
        Print("Opita04 trigger disabled - will trade on alignment only");
    }

    // Validate trading hours
    if(UseTimeRestrictions)
    {
        if(TradingHourStart < 0) TradingHourStart = 0;
        if(TradingHourStart > 23) TradingHourStart = 23;
        if(TradingHourEnd < 0) TradingHourEnd = 0;
        if(TradingHourEnd > 23) TradingHourEnd = 23;

        Print("Time restrictions enabled: Trading allowed from ", TradingHourStart, ":00 to ", TradingHourEnd, ":00 (Broker Time)");
    }

    // Initialize timeframes array
    Timeframes[0] = Timeframe1;
    Timeframes[1] = Timeframe2;
    Timeframes[2] = Timeframe3;
    Timeframes[3] = Timeframe4;

    // Initialize previous signals array
    ArrayResize(PreviousSignals, 4);
    for(int i = 0; i < 4; i++)
    {
        PreviousSignals[i] = 0; // Initialize to neutral
    }

    // Validate lot size
    if(LotSize <= 0) LotSize = 0.01;
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
    double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
    if(LotSize < minLot) LotSize = minLot;
    if(LotSize > maxLot) LotSize = maxLot;

    // Set EA name
    IndicatorShortName("Currency Strength Trader");

    Print("Currency Strength Trader initialized successfully");
    Print("Trading pair: ", Symbol());
    Print("Number of alignment timeframes: ", NumTimeframes);
    Print("Opita04 trigger: ", UseOpita04Trigger ? "ENABLED" : "DISABLED");
    Print("Using BROKER TIME for all time-based operations (not PC/local time)");

    IsInitialized = true;

    // Draw historical trade arrows if enabled
    if(ShowHistoricalTradeArrows)
    {
        DrawHistoricalTradeSignals(BarsToLookBack);
        PrintFormat("Drawn historical trade arrows for last %d bars", BarsToLookBack);
    }

    return(0);
}

//+------------------------------------------------------------------+
//| Expert Advisor deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("Currency Strength Trader deinitialized");
}

//+------------------------------------------------------------------+
//| Expert Advisor tick function                                     |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!IsInitialized) return;

    string currentSymbol = Symbol();
    static datetime lastTradeTime = 0;

    // Only trade if we have a new bar on the trigger timeframe
    if(Time[0] == lastTradeTime) return;
    lastTradeTime = Time[0];

    // Check for trading opportunities
    CheckForTradeSignal(currentSymbol);
}

//+------------------------------------------------------------------+
//| Get Opita04 signal from current chart                             |
//+------------------------------------------------------------------+
int GetOpita04Signal()
{
    if(!UseOpita04Trigger) return 0;

    string symbol = Symbol();
    int timeframe = Period();

    // Attempt to read Opita indicator buffers
    double signalBuy = iCustom(symbol, timeframe, "opita04 3LS with BB - 2", 0, 0, 1); // Buy buffer at index 1 (current bar)
    double signalSell = iCustom(symbol, timeframe, "opita04 3LS with BB - 2", 0, 1, 1); // Sell buffer at index 1 (current bar)

    double lowerBand = GetOpitaLowerBand();
    double upperBand = GetOpitaUpperBand();

    // Debug: print raw opita values and bands
    PrintFormat("Opita raw for %s tf=%d -> signalBuy=%g signalSell=%g lowerBand=%g upperBand=%g", symbol, timeframe, signalBuy, signalSell, lowerBand, upperBand);

    // Check for BUY signal - signal from 3LS AND candle touches lower band
    if(signalBuy != 0 && signalBuy != EMPTY_VALUE)
    {
        if(Low[1] <= lowerBand) // Previous completed bar touches lower band
        {
            Print("Opita BUY condition met");
            return 1; // BUY signal
        }
    }

    // Check for SELL signal - signal from 3LS AND candle touches upper band
    if(signalSell != 0 && signalSell != EMPTY_VALUE)
    {
        if(High[1] >= upperBand) // Previous completed bar touches upper band
        {
            Print("Opita SELL condition met");
            return -1; // SELL signal
        }
    }

    return 0; // No signal
}

//+------------------------------------------------------------------+
//| Get Opita04 upper band value                                     |
//+------------------------------------------------------------------+
double GetOpitaUpperBand()
{
    return iCustom(Symbol(), Period(), "low-pass-bands-sync-filters-mtf",
                   "current time frame", 30, PRICE_CLOSE, 0, 0.01, false,
                   5, 8, 2.0, 2.0, true, true, 1.0, false, false, false, false, false, false, 1, 1);
}

//+------------------------------------------------------------------+
//| Get Opita04 lower band value                                     |
//+------------------------------------------------------------------+
double GetOpitaLowerBand()
{
    return iCustom(Symbol(), Period(), "low-pass-bands-sync-filters-mtf",
                   "current time frame", 30, PRICE_CLOSE, 0, 0.01, false,
                   5, 8, 2.0, 2.0, true, true, 1.0, false, false, false, false, false, false, 2, 1);
}

//+------------------------------------------------------------------+
//| Check if current time is within trading hours                    |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
    if(!UseTimeRestrictions) return true;

    datetime currentTime = TimeCurrent(); // Broker server time
    int currentHour = TimeHour(currentTime);

    // Handle cases where end hour is less than start hour (overnight trading)
    if(TradingHourEnd > TradingHourStart)
    {
        // Normal case: e.g., 8:00 to 16:00
        return (currentHour >= TradingHourStart && currentHour < TradingHourEnd);
    }
    else if(TradingHourEnd < TradingHourStart)
    {
        // Overnight case: e.g., 20:00 to 06:00
        return (currentHour >= TradingHourStart || currentHour < TradingHourEnd);
    }
    else
    {
        // Same hour means no trading
        return false;
    }
}

//+------------------------------------------------------------------+
//| Check for Trade Signals                                          |
//+------------------------------------------------------------------+
void CheckForTradeSignal(string symbol)
{
    static bool timeRestrictionLogged = false;

    // Check if we're within trading hours
    if(!IsWithinTradingHours())
    {
        if(!timeRestrictionLogged)
        {
            Print("TRADING RESTRICTED: Current time ", TimeToString(TimeCurrent()), " (Broker Time) is outside trading hours ",
                  TradingHourStart, ":00 - ", TradingHourEnd, ":00");
            timeRestrictionLogged = true;
        }
        return;
    }

    // Reset the logging flag when we enter trading hours
    if(timeRestrictionLogged)
    {
        Print("TRADING RESUMED: Current time ", TimeToString(TimeCurrent()), " (Broker Time) is within trading hours ",
              TradingHourStart, ":00 - ", TradingHourEnd, ":00");
        timeRestrictionLogged = false;
    }

    // Get signals for all timeframes
    int currentSignals[4];
    ArrayInitialize(currentSignals, 0); // Initialize array to 0
    bool signalsValid = true;

    for(int tf = 0; tf < NumTimeframes; tf++)
    {
        currentSignals[tf] = GetCrossoverSignal(symbol, Timeframes[tf]);
        if(currentSignals[tf] == 0) // Neutral signal means invalid
        {
            signalsValid = false;
            break;
        }
    }

    // Debug: print currentSignals values for diagnosis
    string sigs = "";
    for(int s = 0; s < NumTimeframes; s++)
    {
        sigs += IntegerToString(currentSignals[s]);
        if(s < NumTimeframes-1) sigs += ",";
    }
    PrintFormat("Current signals by timeframe (%s): %s", Symbol(), sigs);

    // Determine current alignment direction
    int currentAlignment = 0;
    if(signalsValid)
    {
        // Check if all timeframes are aligned (same direction)
        bool allAligned = true;
        int alignmentDirection = currentSignals[0]; // Use first timeframe as reference

        for(int tf = 1; tf < NumTimeframes; tf++)
        {
            if(currentSignals[tf] != alignmentDirection)
            {
                allAligned = false;
                break;
            }
        }

        if(allAligned)
        {
            currentAlignment = alignmentDirection;
        }
    }

    // Check for alignment state change
    if(currentAlignment != CurrentAlignmentDirection)
    {
        // Alignment changed - reset trade flag
        HasTradedInAlignment = false;

        string oldDirection = GetDirectionString(CurrentAlignmentDirection);
        string newDirection = GetDirectionString(currentAlignment);

        Print("ALIGNMENT CHANGE: ", oldDirection, " → ", newDirection, " (New trade opportunity available)");

        CurrentAlignmentDirection = currentAlignment;

        // Update previous signals
        for(int tf = 0; tf < NumTimeframes; tf++)
        {
            PreviousSignals[tf] = currentSignals[tf];
        }
        return; // Don't trade on alignment change, wait for opita signal
    }

    // If not aligned, just update signals and return
    if(currentAlignment == 0)
    {
        for(int tf = 0; tf < NumTimeframes; tf++)
        {
            PreviousSignals[tf] = currentSignals[tf];
        }
        return;
    }

    // We have alignment - check for opita04 trigger
    if(!HasTradedInAlignment)
    {
        int opitaSignal = GetOpita04Signal();
        PrintFormat("Opita signal for %s = %d, currentAlignment = %d", Symbol(), opitaSignal, currentAlignment);

        if(opitaSignal == currentAlignment) // Opita signal matches alignment direction
        {
            // Check if we can open a position
            bool canOpen = CanOpenPosition(symbol);
            PrintFormat("CanOpenPosition(%s) = %d (open < max %d)", symbol, canOpen, MaxOpenPositions);

            if(canOpen)
            {
                int orderType = (currentAlignment == 1) ? OP_BUY : OP_SELL;

                // Debug: show price/SL/TP before opening
                double debugPrice = (orderType == OP_BUY) ? Ask : Bid;
                int pipMultiplier = (Digits == 3 || Digits == 5) ? 10 : 1;
                double debugSL = (orderType == OP_BUY) ? debugPrice - (StopLoss * Point * pipMultiplier) : debugPrice + (StopLoss * Point * pipMultiplier);
                double debugTP = (orderType == OP_BUY) ? debugPrice + (TakeProfit * Point * pipMultiplier) : debugPrice - (TakeProfit * Point * pipMultiplier);
                PrintFormat("Attempting OrderSend: symbol=%s type=%d price=%.5f SL=%.5f TP=%.5f LotSize=%.2f Magic=%d", symbol, orderType, debugPrice, debugSL, debugTP, LotSize, MagicNumber);

                OpenPosition(symbol, orderType);
                HasTradedInAlignment = true; // Mark that we've traded in this alignment

                string direction = (currentAlignment == 1) ? "BUY" : "SELL";
                Print("TRADE EXECUTED: ", direction, " signal from Opita04 during ", GetDirectionString(currentAlignment), " alignment");
            }
        }
    }
    else
    {
        // We've already traded in this alignment, ignore subsequent opita signals
        int opitaSignal = GetOpita04Signal();
        if(opitaSignal == currentAlignment)
        {
            Print("IGNORING OPITA SIGNAL: Already traded in current ", GetDirectionString(currentAlignment), " alignment");
        }
    }

    // Update previous signals
    for(int tf = 0; tf < NumTimeframes; tf++)
    {
        PreviousSignals[tf] = currentSignals[tf];
    }
}

//+------------------------------------------------------------------+
//| Get direction string for logging                                 |
//+------------------------------------------------------------------+
string GetDirectionString(int direction)
{
    switch(direction)
    {
        case 1: return "UP";
        case -1: return "DOWN";
        case 0: return "UNALIGNED";
        default: return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Check if we can open a new position                              |
//+------------------------------------------------------------------+
bool CanOpenPosition(string symbol)
{
    int openPositions = 0;

    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == symbol && OrderMagicNumber() == MagicNumber)
            {
                openPositions++;
            }
        }
    }

    return (openPositions < MaxOpenPositions);
}

//+------------------------------------------------------------------+
//| Open a new position with SL/TP                                   |
//+------------------------------------------------------------------+
void OpenPosition(string symbol, int orderType)
{
    double price = (orderType == OP_BUY) ? Ask : Bid;
    double sl = 0;
    double tp = 0;

    int pipMultiplier = 1;
    if(Digits == 3 || Digits == 5) pipMultiplier = 10;

    if(orderType == OP_BUY)
    {
        sl = price - (StopLoss * Point * pipMultiplier);
        tp = price + (TakeProfit * Point * pipMultiplier);
    }
    else // OP_SELL
    {
        sl = price + (StopLoss * Point * pipMultiplier);
        tp = price - (TakeProfit * Point * pipMultiplier);
    }

    // Normalize prices
    sl = NormalizeDouble(sl, Digits);
    tp = NormalizeDouble(tp, Digits);

    int ticket = OrderSend(symbol, orderType, LotSize, price, 3, sl, tp,
                          BotName, MagicNumber, 0, clrBlue);

    if(ticket > 0)
    {
        string direction = (orderType == OP_BUY) ? "BUY" : "SELL";
        string message = StringFormat("TRADE OPENED: %s %s at %.5f (SL: %.5f, TP: %.5f)",
                                    symbol, direction, price, sl, tp);

        Print(message);

        if(AlertOnTrade)
        {
            Alarm(message);
        }
    }
    else
    {
        int error = GetLastError();
        Print("Failed to open position. Error: ", error);
    }
}


//+------------------------------------------------------------------+
//| Get Crossover Signal for Specified Symbol and Timeframe         |
//+------------------------------------------------------------------+
int GetCrossoverSignal(string symbol, ENUM_TIMEFRAMES timeframe)
{
    double line1_current, line1_previous, line2_current, line2_previous;
    string indicatorPath;

    // First try standard location
    indicatorPath = IndicatorName;
    line1_current = iCustom(symbol, timeframe, indicatorPath, Line1Buffer, 0);
    line1_previous = iCustom(symbol, timeframe, indicatorPath, Line1Buffer, 1);
    line2_current = iCustom(symbol, timeframe, indicatorPath, Line2Buffer, 0);
    line2_previous = iCustom(symbol, timeframe, indicatorPath, Line2Buffer, 1);

    // If not found (all values are EMPTY_VALUE), try subfolder
    if(line1_current == EMPTY_VALUE && line2_current == EMPTY_VALUE &&
       line1_previous == EMPTY_VALUE && line2_previous == EMPTY_VALUE)
    {
        indicatorPath = "Millionaire Maker\\" + IndicatorName;
        line1_current = iCustom(symbol, timeframe, indicatorPath, Line1Buffer, 0);
        line1_previous = iCustom(symbol, timeframe, indicatorPath, Line1Buffer, 1);
        line2_current = iCustom(symbol, timeframe, indicatorPath, Line2Buffer, 0);
        line2_previous = iCustom(symbol, timeframe, indicatorPath, Line2Buffer, 1);
    }

    // If still not found, return neutral
    if(line1_current == EMPTY_VALUE || line2_current == EMPTY_VALUE ||
       line1_previous == EMPTY_VALUE || line2_previous == EMPTY_VALUE)
    {
        return 0; // Neutral
    }

    // Return current position relative to each other
    if(line1_current > line2_current)
        return 1;  // Above
    else if(line1_current < line2_current)
        return -1; // Below
    else
        return 0;  // Neutral
}

//+------------------------------------------------------------------+
//| Get crossover signal for a specific bar time                      |
//| Returns 1 (above), -1 (below), 0 (neutral/not available)         |
//+------------------------------------------------------------------+
int GetCrossoverSignalAtTime(string symbol, ENUM_TIMEFRAMES timeframe, datetime when)
{
    double line1_current, line2_current;
    string indicatorPath;

    // find the bar index on the target timeframe that matches 'when'
    int idx = iBarShift(symbol, timeframe, when, true);
    if(idx == -1) return 0; // no matching bar

    // First try standard location
    indicatorPath = IndicatorName;
    line1_current = iCustom(symbol, timeframe, indicatorPath, Line1Buffer, idx);
    line2_current = iCustom(symbol, timeframe, indicatorPath, Line2Buffer, idx);

    // If not found (both EMPTY_VALUE) try subfolder
    if(line1_current == EMPTY_VALUE && line2_current == EMPTY_VALUE)
    {
        indicatorPath = "Millionaire Maker\\" + IndicatorName;
        line1_current = iCustom(symbol, timeframe, indicatorPath, Line1Buffer, idx);
        line2_current = iCustom(symbol, timeframe, indicatorPath, Line2Buffer, idx);
    }

    if(line1_current == EMPTY_VALUE || line2_current == EMPTY_VALUE)
        return 0;

    if(line1_current > line2_current) return 1;
    else if(line1_current < line2_current) return -1;
    else return 0;
}

//+------------------------------------------------------------------+
//| Get Opita04 signal at a specific time on the chart timeframe      |
//+------------------------------------------------------------------+
int GetOpita04SignalAtTime(string symbol, datetime when)
{
    if(!UseOpita04Trigger) return 0;

    // find index on the current chart timeframe corresponding to 'when'
    int idx = iBarShift(symbol, Period(), when, true);
    if(idx == -1) return 0;

    double signalBuy = iCustom(symbol, Period(), "opita04 3LS with BB - 2", 0, 0, idx);
    double signalSell = iCustom(symbol, Period(), "opita04 3LS with BB - 2", 0, 1, idx);

    // For historical values, pass the historical shift (idx) as the final parameter
    double lowerBand = iCustom(symbol, Period(), "low-pass-bands-sync-filters-mtf",
                   "current time frame", 30, PRICE_CLOSE, 0, 0.01, false,
                   5, 8, 2.0, 2.0, true, true, 1.0, false, false, false, false, false, false, 2, idx);

    double upperBand = iCustom(symbol, Period(), "low-pass-bands-sync-filters-mtf",
                   "current time frame", 30, PRICE_CLOSE, 0, 0.01, false,
                   5, 8, 2.0, 2.0, true, true, 1.0, false, false, false, false, false, false, 1, idx);

    // Debug
    PrintFormat("(hist) Opita raw for %s tf=%d time=%s -> signalBuy=%g signalSell=%g lowerBand=%g upperBand=%g idx=%d",
                symbol, Period(), TimeToString(when), signalBuy, signalSell, lowerBand, upperBand, idx);

    if(signalBuy != 0 && signalBuy != EMPTY_VALUE)
    {
        // use the low of that bar
        int shift = idx;
        double barLow = iLow(symbol, Period(), shift);
        if(barLow <= lowerBand) return 1;
    }

    if(signalSell != 0 && signalSell != EMPTY_VALUE)
    {
        int shift = idx;
        double barHigh = iHigh(symbol, Period(), shift);
        if(barHigh >= upperBand) return -1;
    }

    return 0;
}

//+------------------------------------------------------------------+
//| Clear historical trade objects                                    |
//+------------------------------------------------------------------+
void ClearHistoricalTradeObjects()
{
    for(int i = ObjectsTotal() - 1; i >= 0; i--)
    {
        string nm = ObjectName(i);
        if(StringFind(nm, "HTrade_") == 0)
        {
            ObjectDelete(nm);
        }
    }
}

//+------------------------------------------------------------------+
//| Draw historical trade arrows based on alignment + opita trigger    |
//+------------------------------------------------------------------+
void DrawHistoricalTradeSignals(int lookBack)
{
    if(lookBack <= 0) return;

    ClearHistoricalTradeObjects();

    for(int i = 1; i <= lookBack && i < Bars; i++)
    {
        datetime when = Time[i];

        // collect signals across alignment timeframes for this time
        int sigs[4];
        bool valid = true;
        for(int tf = 0; tf < NumTimeframes; tf++)
        {
            sigs[tf] = GetCrossoverSignalAtTime(Symbol(), Timeframes[tf], when);
            if(sigs[tf] == 0) { valid = false; break; }
        }

        if(!valid) continue;

        // check all aligned
        int refDir = sigs[0];
        bool allAligned = true;
        for(int tf = 1; tf < NumTimeframes; tf++) if(sigs[tf] != refDir) { allAligned = false; break; }
        if(!allAligned) continue;

        // check opita trigger at this time
        int opita = GetOpita04SignalAtTime(Symbol(), when);
        if(opita != refDir) continue;

        // create arrow
        int pipMultiplier = (Digits == 3 || Digits == 5) ? 10 : 1;
        double offset = HistoricalArrowOffsetPips * Point * pipMultiplier;
        string name = "HTrade_" + ((refDir == 1) ? "BUY_" : "SELL_") + Symbol() + "_" + IntegerToString((int)when);

        double price = (refDir == 1) ? (Low[i] - offset) : (High[i] + offset);

        if(ObjectFind(name) == -1)
        {
            ObjectCreate(name, OBJ_ARROW, 0, when, price);
            // Try to set properties using both newer and older APIs for compatibility
            if(refDir == 1)
            {
                ObjectSetInteger(0, name, OBJPROP_COLOR, HistoricalBuyArrowColor);
                ObjectSetInteger(0, name, OBJPROP_ARROWCODE, HistoricalBuyArrowCode);
                ObjectSet(name, OBJPROP_COLOR, HistoricalBuyArrowColor);
                ObjectSet(name, OBJPROP_ARROWCODE, HistoricalBuyArrowCode);
            }
            else
            {
                ObjectSetInteger(0, name, OBJPROP_COLOR, HistoricalSellArrowColor);
                ObjectSetInteger(0, name, OBJPROP_ARROWCODE, HistoricalSellArrowCode);
                ObjectSet(name, OBJPROP_COLOR, HistoricalSellArrowColor);
                ObjectSet(name, OBJPROP_ARROWCODE, HistoricalSellArrowCode);
            }
        }
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
//| Alert Function with Multiple Notification Types                  |
//+------------------------------------------------------------------+
void Alarm(string body)
{
   string shortName = BotName + " ";
   if(popupAlert)
   {
      Alert(shortName, body);
   }
   if(emailAlert)
   {
      SendMail("From " + shortName, shortName + body);
   }
   if(pushAlert)
   {
      SendNotification(shortName + body);
   }
}

//+------------------------------------------------------------------+
