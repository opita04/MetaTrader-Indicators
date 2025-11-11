/*
File: EA - 3LS Husky CS Trader.mq4
Author: AI Assistant
Source: Complete integration of opita-3LS-husky-cs.mq4 indicator logic + EA - Currency Strength Trader.mq4 structure
Description: Self-contained Expert Advisor with all indicator logic integrated - no external indicators required
Purpose: Automate trading when 3LS patterns occur with HuskyBands and Currency Strength confirmation.
         Features dynamic FIFO exits when blocked signals (X's) appear - closes oldest positions first.
Parameters: See trading, timeframe, indicator, alert, and exit settings near top of file
Version: 1.00
Last Modified: 2025.11.10
Compatibility: MetaTrader 4 (MT4)
*/
//+------------------------------------------------------------------+
#property copyright "AI Assistant"
#property version   "1.00"
#property strict

//--- Trading Parameters
extern string __TradingSettings = ""; // === TRADING SETTINGS ===
extern double LotSize = 0.01;                    // Lot Size
extern int StopLoss = 50;                        // Stop Loss in Pips
extern int TakeProfit = 100;                     // Take Profit in Pips
extern int MagicNumber = 54321;                  // Magic Number for Orders
extern int MaxOpenPositions = 1;                 // Maximum Open Positions

//--- Time Restrictions (uses BROKER TIME, not PC time)
extern string __TimeRestrictions = ""; // === TIME RESTRICTIONS ===
extern bool   UseTimeRestrictions = false;      // Enable Time-Based Trading Restrictions
extern int    TradingHourStart = 8;             // Trading Start Hour (0-23, Broker Time)
extern int    TradingHourEnd = 16;              // Trading End Hour (0-23, Broker Time)

//--- 3LS Husky CS Settings (Integrated - No External Indicator Needed)
extern string __IndicatorSettings = ""; // === 3LS HUSKY CS SETTINGS ===
extern int    BarsToLookBack = 500;             // Bars to Look Back for Historical Arrows

//--- Historical trade arrows settings
extern bool   ShowHistoricalTradeArrows = true; // Draw arrows where trades would have occurred historically
extern color  HistoricalBuyArrowColor = clrGreen;
extern color  HistoricalSellArrowColor = clrRed;
extern int    HistoricalBuyArrowCode = 233;
extern int    HistoricalSellArrowCode = 234;
extern color  HistoricalBlockedBuyColor = clrOrange;
extern color  HistoricalBlockedSellColor = clrAqua;
extern int    HistoricalBlockedArrowCode = 88; // X mark
extern int    HistoricalArrowOffsetPips = 5; // Distance from candle in pips

//--- Live arrows (draw on each new bar when signals occur)
extern bool   DrawLiveArrows = true;        // Draw live arrows/X on new signals

//--- Alert Settings
extern string __AlertSettings = ""; // === ALERT SETTINGS ===
extern bool   AlertOnTrade = true;        // Alert when trade is opened
extern bool   popupAlert = true;          // Show popup alerts
extern bool   pushAlert = false;          // Send push notifications
extern bool   emailAlert = false;         // Send email alerts
extern bool   AlertOnBlocked = true;     // Alert when signal is blocked by CS filter

//--- Exit Settings
extern string __ExitSettings = ""; // === EXIT SETTINGS ===
extern bool   ExitOnBlockedSignal = true; // Close trades when blocked signal (X) appears (FIFO: oldest position first)
extern bool   ExitOnOppositeSignal = true; // Close trades when an opposite arrow appears (FIFO: oldest position first)

//==============================================================================
// INTEGRATED INDICATOR CODE - Enums and Constants
//==============================================================================

// HuskyBands enums (copied from smLazyTMA HuskyBands_v2.1)
enum ENUM_BAND_TYPE
{
   Median_Band,
   HighLow_Bands
};

enum ENUM_THRESHOLD_BANDS
{
   Band1,
   Band2,
   Band3,
   Band4
};

enum TIMEFRAMES
  {
   tf_cu  = 0,                                            // Current time frame
   tf_m1  = PERIOD_M1,                                    // 1 minute
   tf_m5  = PERIOD_M5,                                    // 5 minutes
   tf_m15 = PERIOD_M15,                                   // 15 minutes
   tf_m30 = PERIOD_M30,                                   // 30 minutes
   tf_h1  = PERIOD_H1,                                    // 1 hour
   tf_h4  = PERIOD_H4,                                    // 4 hours
   tf_d1  = PERIOD_D1,                                    // Daily
   tf_w1  = PERIOD_W1,                                    // Weekly
   tf_mn1 = PERIOD_MN1,                                   // Monthly
   tf_n1  = -1,                                           // First higher time frame
   tf_n2  = -2,                                           // Second higher time frame
   tf_n3  = -3                                            // Third higher time frame
  };

//==============================================================================
// INTEGRATED INDICATOR CODE - Parameters (moved from extern to input)
//==============================================================================

// ======= 3LS Settings =======
input TIMEFRAMES ls_tf = 0;                                      // Time frame to use
input bool ls_show_bearish = true;                               // Show Bearish 3 Line Strike
input bool ls_show_bullish = true;                               // Show Bullish 3 Line Strike
input double ls_arrow_gap = 0.25;                                // Arrow gap
input bool ls_arrow_mtf = true;                                  // Arrow on first mtf bar

input bool       cs_filter_enabled      = true;                 // Enable Currency Strength filter
input string     cs_indicator_name      = "CurrencyStrengthWizard"; // Indicator Name
input string     cs_indicator_subfolder = "Millionaire Maker\\";   // Optional subfolder
input ENUM_TIMEFRAMES cs_timeframe      = PERIOD_M1;             // Strength timeframe
input int        cs_line1_buffer        = 0;                     // Line 1 buffer
input int        cs_line2_buffer        = 1;                     // Line 2 buffer
bool       cs_require_cross       = false;                 // Require fresh crossover
bool       cs_filter_debug_logs   = false;                 // Debug logging
bool       cs_swap_lines          = false;                 // Swap L1/L2 after read (use if buffers are reversed)
input bool       cs_use_closed_htf_bar  = true;                  // When CS TF > chart TF, use CLOSED higher-TF bar (shift+1)

// ===== HuskyBands Settings =====
input bool useHuskyBands      = true;                            // Use HuskyBands?
input bool Show_HuskyBands    = false;                            // Show HuskyBands on chart
input ENUM_BAND_TYPE Band_Type = Median_Band;                 // Band Type (Median_Band or HighLow_Bands)
input int HalfLength_input   = 34;                             // Half Length
input int ma_period          = 4;                              // MA averaging period
input int ma_method = MODE_LWMA;                    // MA averaging method
input int ATR_Period         = 144;                            // ATR Period
input int Total_Bars         = 500;                           // Total Bars
input double ATR_Multiplier_Band1 = 1.0;                      // ATR Multiplier for Band 1

//==============================================================================
// INTEGRATED INDICATOR CODE - Global Variables
//==============================================================================

string indicatorName = "Opita 3LSH Signals";
string dir = "";
double sumWeights;
double weights[];    // TMA weights (initialized in OnInit)
int fullLength;      // full length = HalfLength_input * 2 + 1
double tmaCache[];   // precomputed TMA values for performance

//--- Global Variables
string BotName = "3LS Husky CS Trader";
bool IsInitialized = false;
datetime LastSignalTime = 0;

//+------------------------------------------------------------------+
//| Expert Advisor initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{

    // Validate trading hours
    if(UseTimeRestrictions)
    {
        if(TradingHourStart < 0) TradingHourStart = 0;
        if(TradingHourStart > 23) TradingHourStart = 23;
        if(TradingHourEnd < 0) TradingHourEnd = 0;
        if(TradingHourEnd > 23) TradingHourEnd = 23;

        Print("Time restrictions enabled: Trading allowed from ", TradingHourStart, ":00 to ", TradingHourEnd, ":00 (Broker Time)");
    }

    // Validate lot size
    if(LotSize <= 0) LotSize = 0.01;
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
    double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
    if(LotSize < minLot) LotSize = minLot;
    if(LotSize > maxLot) LotSize = maxLot;

    // Set EA name
    IndicatorShortName(BotName);

    // Initialize TMA weights (match smLazyTMA HuskyBands logic)
    int halfLengthLocal = HalfLength_input;
    if(halfLengthLocal < 1) halfLengthLocal = 1;
    fullLength = halfLengthLocal * 2 + 1;
    ArrayResize(weights, fullLength);
    sumWeights = halfLengthLocal + 1;
    weights[halfLengthLocal] = halfLengthLocal + 1;
    for(int wi = 0; wi < halfLengthLocal; wi++)
      {
       weights[wi] = wi + 1;
       weights[fullLength - wi - 1] = wi + 1;
       sumWeights += (wi + 1) * 2;
      }

    // Diagnostic: print currency-strength timeframe resolution and bar counts
    if(cs_filter_debug_logs)
      {
       int resolvedTf = resolveTimeframePeriod(cs_timeframe);
       int barsM1 = iBars(Symbol(), PERIOD_M1);
       int shiftM1 = iBarShift(Symbol(), PERIOD_M1, Time[1], true);
       Print("3LSH CS Init: cs_timeframe=", cs_timeframe,
             " resolved=", resolvedTf,
             " Bars_current=", Bars,
             " Bars_M1=", barsM1,
             " iBarShift(M1)=", shiftM1);
      }

    Print(BotName + " initialized successfully");
    Print("Trading pair: ", Symbol());
    Print("All indicator logic integrated - no external indicators required");
    PrintFormat("Dynamic exits - blocked: %s, opposite: %s (FIFO)",
                ExitOnBlockedSignal ? "ENABLED" : "DISABLED",
                ExitOnOppositeSignal ? "ENABLED" : "DISABLED");
    Print("Using BROKER TIME for all time-based operations (not PC/local time)");

    // Draw historical trade arrows if enabled
    if(ShowHistoricalTradeArrows)
    {
        DrawHistoricalTradeSignals(BarsToLookBack);
        PrintFormat("Drawn historical trade arrows for last %d bars", BarsToLookBack);
    }

    IsInitialized = true;

    return(0);
}

//+------------------------------------------------------------------+
//| Expert Advisor deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up all historical trade objects when EA is removed
    ClearHistoricalTradeObjects();
    Print(BotName + " deinitialized - cleaned up all historical trade objects");
}

//+------------------------------------------------------------------+
//| Expert Advisor tick function                                     |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!IsInitialized) return;

    static datetime lastTradeTime = 0;

    // Only trade if we have a new bar
    if(Time[0] == lastTradeTime) return;
    lastTradeTime = Time[0];

    // Check for trading opportunities
    CheckForTradeSignal();
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
//| Check for Exit Signals (blocked signals in opposite direction)   |
//| Uses FIFO (First In, First Out) - closes oldest positions first  |
//+------------------------------------------------------------------+
void CheckForExitSignals()
{
    // Evaluate exit causes
    int blockedSignal  = ExitOnBlockedSignal  ? getIntegratedBlockedSignal() : 0;
    int oppositeSignal = ExitOnOppositeSignal ? getIntegratedSignal()        : 0;

    // Treat any blocked "X" signal as a generic opposite exit trigger
    bool hasBlockedAny = (blockedSignal != 0);

    // For opposite arrow exits, a BUY arrow means close SELL positions, and vice versa
    bool hasOppositeForBuy  = (oppositeSignal == -1); // close BUY when SELL arrow appears
    bool hasOppositeForSell = (oppositeSignal ==  1); // close SELL when BUY arrow appears

    if(!hasBlockedAny && oppositeSignal == 0) return; // No exit condition

    // Find the oldest position that should be closed (FIFO - First In, First Out)
    int oldestTicket = -1;
    datetime oldestOpenTime = D'2099.12.31 23:59:59'; // Initialize to far future date
    int exitOrderType = -1;
    string exitReason = "";

    // First pass: find the oldest position that should be closed
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
            {
                int orderType = OrderType();
                bool shouldCloseThis = false;
                string reasonLocal = "";

                // Priority 1: Blocked "X" exits (generic) -> close any position, oldest first
                if(hasBlockedAny)
                {
                    shouldCloseThis = true;
                    reasonLocal = "Blocked X signal appeared - exiting position (FIFO)";
                }
                // Priority 2: Opposite arrow exits (close positions opposite to the new arrow)
                else if(oppositeSignal != 0)
                {
                    if(orderType == OP_BUY && hasOppositeForBuy)
                    {
                        shouldCloseThis = true;
                        reasonLocal = "Opposite SELL arrow appeared - exiting BUY position (FIFO)";
                    }
                    else if(orderType == OP_SELL && hasOppositeForSell)
                    {
                        shouldCloseThis = true;
                        reasonLocal = "Opposite BUY arrow appeared - exiting SELL position (FIFO)";
                    }
                }

                if(shouldCloseThis)
                {
                    // Check if this is the oldest position we've found
                    if(OrderOpenTime() < oldestOpenTime)
                    {
                        oldestOpenTime = OrderOpenTime();
                        oldestTicket = OrderTicket();
                        exitOrderType = orderType;
                        exitReason = reasonLocal;
                    }
                }
            }
        }
    }

    // Second pass: close only the oldest position
    if(oldestTicket > 0)
    {
        // Select the oldest position again
        if(OrderSelect(oldestTicket, SELECT_BY_TICKET))
        {
            double closePrice = (exitOrderType == OP_BUY) ? Bid : Ask;
            bool closed = OrderClose(oldestTicket, OrderLots(), closePrice, 3, clrRed);

            if(closed)
            {
                string direction = (exitOrderType == OP_BUY) ? "BUY" : "SELL";

                string message = StringFormat("TRADE CLOSED: %s %s at %.5f - %s",
                                            Symbol(), direction, closePrice, exitReason);

                Print(message);

                if(AlertOnTrade)
                {
                    Alarm("Trade Closed - " + exitReason);
                }
            }
            else
            {
                int error = GetLastError();
                Print("Failed to close position. Error: ", error);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check for Trade Signals                                          |
//+------------------------------------------------------------------+
void CheckForTradeSignal()
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

    // Check for exit signals first (blocked signals or opposite arrow)
    if(ExitOnBlockedSignal || ExitOnOppositeSignal)
    {
        CheckForExitSignals();
    }

    // Get 3LS Husky CS signal using integrated functions
    int signal = getIntegratedSignal();

    // Draw live blocked X's regardless of position open status
    if(DrawLiveArrows)
    {
        int blockedLive = getIntegratedBlockedSignal();
        if(blockedLive != 0)
        {
            // Draw blocked X on the just-closed bar (index 1)
            DrawHistoricalArrow(Time[1], 1, blockedLive, true);
        }
    }

    if(signal == 0)
    {
        // No tradable signal but we may have drawn blocked X above
        return;
    }

    // Check if we can open a position
    bool canOpen = CanOpenPosition(Symbol());
    PrintFormat("CanOpenPosition(%s) = %s (open < max %d)", Symbol(), canOpen ? "true" : "false", MaxOpenPositions);

    if(canOpen)
    {
        int orderType = (signal > 0) ? OP_BUY : OP_SELL;
        string normalizedDirection = (signal > 0) ? "BUY" : (signal < 0 ? "SELL" : "NONE");
        PrintFormat("3LSH Debug EA: normalizedSignal=%d direction=%s orderType=%d (OP_BUY=%d OP_SELL=%d)",
                    signal, normalizedDirection, orderType, OP_BUY, OP_SELL);

        // Debug: show price/SL/TP before opening
        double debugPrice = (orderType == OP_BUY) ? Ask : Bid;
        int pipMultiplier = (Digits == 3 || Digits == 5) ? 10 : 1;
        double pipValue = Point * pipMultiplier;
        double debugSL = (orderType == OP_BUY) ?
                        debugPrice - (StopLoss * pipValue) :
                        debugPrice + (StopLoss * pipValue);
        double debugTP = (orderType == OP_BUY) ?
                        debugPrice + (TakeProfit * pipValue) :
                        debugPrice - (TakeProfit * pipValue);
        PrintFormat("Attempting OrderSend: symbol=%s type=%d price=%.5f SL=%.5f TP=%.5f LotSize=%.2f Magic=%d",
                    Symbol(), orderType, debugPrice, debugSL, debugTP, LotSize, MagicNumber);

        OpenPosition(Symbol(), orderType);

        string direction = (signal == 1) ? "BUY" : "SELL";
        Print("TRADE EXECUTED: ", direction, " signal from 3LS Husky CS indicator");

        LastSignalTime = Time[0];
    }

    // Draw live successful trade arrows even if we cannot open due to limits
    if(DrawLiveArrows && signal != 0)
    {
        // Draw arrow on the just-closed bar (index 1)
        DrawHistoricalArrow(Time[1], 1, signal, false);
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
//| Draw historical trade arrows based on 3LS Husky CS signals        |
//+------------------------------------------------------------------+
void DrawHistoricalTradeSignals(int lookBack)
{
    if(lookBack <= 0) return;

    ClearHistoricalTradeObjects();

    for(int i = 1; i <= lookBack && i < Bars; i++)
    {
        datetime when = Time[i];

        // Get 3LS Husky CS signal at this time using integrated functions
        int signal = getIntegratedSignalAtTime(when);
        int blockedSignal = getIntegratedBlockedSignalAtTime(when);

        // Draw successful trade arrows
        if(signal != 0)
        {
            DrawHistoricalArrow(when, i, signal, false);
        }

        // Draw blocked signal X's
        if(blockedSignal != 0)
        {
            DrawHistoricalArrow(when, i, blockedSignal, true);
        }
    }
}

//+------------------------------------------------------------------+
//| Draw a single historical arrow                                    |
//+------------------------------------------------------------------+
void DrawHistoricalArrow(datetime when, int barIndex, int signal, bool isBlocked)
{
    // Use a reasonable fixed offset for arrows (not pip-based like getPoint())
    // This provides good visibility without being too far from candles
    double offset = 15 * Point; // Fixed 15 points offset for all timeframes
    string signalType = isBlocked ? "BLOCKED_" : "";
    string direction = (signal == 1) ? "BUY" : "SELL";
    string name = "HTrade_" + signalType + direction + "_" + Symbol() + "_" + IntegerToString((int)when);

    // Position arrows/X marks above/below candles with offset for visibility
    double price = (signal == 1) ? (Low[barIndex] - offset) : (High[barIndex] + offset);

    if(ObjectFind(name) == -1)
    {
        ObjectCreate(name, OBJ_ARROW, 0, when, price);

        if(isBlocked)
        {
            // Draw X marks for blocked signals - make them more visible
            if(signal == 1)
            {
                ObjectSetInteger(0, name, OBJPROP_COLOR, HistoricalBlockedBuyColor);
                ObjectSetInteger(0, name, OBJPROP_ARROWCODE, HistoricalBlockedArrowCode);
                ObjectSetInteger(0, name, OBJPROP_WIDTH, 2); // Make thicker
                ObjectSet(name, OBJPROP_COLOR, HistoricalBlockedBuyColor);
                ObjectSet(name, OBJPROP_ARROWCODE, HistoricalBlockedArrowCode);
            }
            else
            {
                ObjectSetInteger(0, name, OBJPROP_COLOR, HistoricalBlockedSellColor);
                ObjectSetInteger(0, name, OBJPROP_ARROWCODE, HistoricalBlockedArrowCode);
                ObjectSetInteger(0, name, OBJPROP_WIDTH, 2); // Make thicker
                ObjectSet(name, OBJPROP_COLOR, HistoricalBlockedSellColor);
                ObjectSet(name, OBJPROP_ARROWCODE, HistoricalBlockedArrowCode);
            }
        }
        else
        {
            // Draw arrows for successful trades
            if(signal == 1)
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

//==============================================================================
// INTEGRATED INDICATOR CODE - Functions
//==============================================================================

//==============================================================================
// SECTION 4: 3LS PATTERN DETECTION (Integrated from ! 3LS indicator)
//==============================================================================

//+------------------------------------------------------------------+
//| Detect Three Line Strike pattern (from real 3LS indicator)        |
//+------------------------------------------------------------------+
int signalLS(int index)
  {
   // Check for Bullish 3 Line Strike-like setup and require current bar bullish
   if(ls_show_bullish && is3LSBull(index) && (Close[index] > Open[index]))
      return OP_BUY;

   // Check for Bearish 3 Line Strike-like setup and require current bar bearish
   if(ls_show_bearish && is3LSBear(index) && (Close[index] < Open[index]))
      return OP_SELL;

   return -1;
}

//+------------------------------------------------------------------+
//| Get candle color index (from real 3LS indicator)                 |
//+------------------------------------------------------------------+
int getCandleColorIndex(int pos)
  {
  // safety: guard against out-of-range access
  if(pos < 0 || pos >= Bars) return 0;
  return (Close[pos] > Open[pos]) ? 1 : (Close[pos] < Open[pos]) ? -1 : 0;
  }

//+------------------------------------------------------------------+
//| Check for Bullish 3LS (3 bearish candles) - from real indicator  |
//+------------------------------------------------------------------+
bool is3LSBull(int pos)
  {
  // Ensure there are 3 previous bars available (pos+3 must be within Bars)
  if(pos + 3 >= Bars) return false;

  // Check if 3 previous candles are all bearish (negative color index)
  bool is3LineSetup = ((getCandleColorIndex(pos+1) < 0) &&
                     (getCandleColorIndex(pos+2) < 0) &&
                     (getCandleColorIndex(pos+3) < 0));

  return is3LineSetup;
  }

//+------------------------------------------------------------------+
//| Check for Bearish 3LS (3 bullish candles) - from real indicator  |
//+------------------------------------------------------------------+
bool is3LSBear(int pos)
  {
  // Ensure there are 3 previous bars available (pos+3 must be within Bars)
  if(pos + 3 >= Bars) return false;

  // Check if 3 previous candles are all bullish (positive color index)
  bool is3LineSetup = ((getCandleColorIndex(pos+1) > 0) &&
                     (getCandleColorIndex(pos+2) > 0) &&
                     (getCandleColorIndex(pos+3) > 0));

  return is3LineSetup;
  }

//+------------------------------------------------------------------------+
//| Function to return True if the double has some value, false otherwise  |
//+------------------------------------------------------------------------+
bool hasValue(double val)
  {
   return (val != 0 && val != EMPTY_VALUE);
  }

string boolToString(bool flag)
  {
   return flag ? "true" : "false";
  }

//==============================================================================
// SECTION 5: HUSKYBANDS CALCULATION (Integrated ATR-based bands)
//==============================================================================

//+------------------------------------------------------------------+
//| Calculate TMA (Triangular Moving Average) - from smLazyTMA       |
//+------------------------------------------------------------------+
double calculateTMA(int shift, ENUM_APPLIED_PRICE applied_priceX)
  {
   // Use iMA-smoothed weighted TMA like smLazyTMA for exact matching
   int halfLength = HalfLength_input;
   if(halfLength < 1) halfLength = 1;

   int expectedFull = halfLength * 2 + 1;
   if(ArraySize(weights) != expectedFull)
     {
      // initialize weights if they aren't set (safety)
      ArrayResize(weights, expectedFull);
      sumWeights = halfLength + 1;
      weights[halfLength] = halfLength + 1;
      for(int wi = 0; wi < halfLength; wi++)
        {
         weights[wi] = wi + 1;
         weights[expectedFull - wi - 1] = wi + 1;
         sumWeights += (wi + 1) * 2;
        }
      fullLength = expectedFull;
     }

   double sum = 0.0;
   double usedWeightSum = 0.0;

   // Weighted sum of iMA values across window to produce centered TMA
   for(int j = 0; j < expectedFull; j++)
     {
      int index = shift + j - halfLength;
      if(index >= 0 && index < Bars)
        {
         double weight = weights[j];
         double maValue = iMA(NULL, Period(), ma_period, 0, ma_method, applied_priceX, index);
         sum += maValue * weight;
         usedWeightSum += weight;
        }
     }

   if(usedWeightSum == 0.0)
      return 0.0;

   return sum / usedWeightSum;
  }

//+------------------------------------------------------------------+
//| Calculate ATR-based deviation - from smLazyTMA                    |
//+------------------------------------------------------------------+
double calculateATRDeviation(int shift, int atrPeriod, double tmaValue)
  {
   // Compute standard deviation between Close and TMA over the ATR window,
   // using TMA values at each bar (matches smLazyTMA behavior).
   double StdDev_dTmp = 0.0;
   int count = 0;

   for(int ij = 0; ij < atrPeriod; ij++)
     {
      int idx = shift + ij;
      if(idx >= Bars) break;
      double tmaAtIdx = calculateTMA(idx, PRICE_MEDIAN);
      double dClose = Close[idx];
      StdDev_dTmp += MathPow(dClose - tmaAtIdx, 2);
      count++;
     }

   if(count == 0) return 0.0;
   return MathSqrt(StdDev_dTmp / count);
  }

//+------------------------------------------------------------------+
//| Get price value based on applied price type                      |
//+------------------------------------------------------------------+
double getPrice(int shift, ENUM_APPLIED_PRICE priceType)
  {
   switch(priceType)
     {
      case PRICE_CLOSE:
         return Close[shift];
      case PRICE_OPEN:
         return Open[shift];
      case PRICE_HIGH:
         return High[shift];
      case PRICE_LOW:
         return Low[shift];
      case PRICE_MEDIAN:
         return (High[shift] + Low[shift]) / 2;
      case PRICE_TYPICAL:
         return (High[shift] + Low[shift] + Close[shift]) / 3;
      case PRICE_WEIGHTED:
         return (High[shift] + Low[shift] + Close[shift] + Close[shift]) / 4;
      default:
         return Close[shift];
     }
  }

//==============================================================================
// SECTION 6: CURRENCY STRENGTH FILTER FUNCTIONS
//==============================================================================

// New: timeframe-parameterized CS filter
bool passesCurrencyStrengthFilterTf(int barIndex, int direction, int timeframe)
  {
   int strengthShift = resolveCurrencyStrengthShiftTf(barIndex, timeframe);
   if(strengthShift < 0)
     {
      if(cs_filter_debug_logs)
         Print("3LSH CS shift unresolved, bar ", barIndex, " tf=", timeframe);
      return(false);
     }

   double l1c, l1p, l2c, l2p;
   if(!loadCurrencyStrengthValues(timeframe, strengthShift, l1c, l1p, l2c, l2p))
     {
      if(cs_filter_debug_logs)
         Print("3LSH CS values missing for bar ", barIndex, " tf=", timeframe, " shift=", strengthShift, " - no fallback performed");
      return(false);
     }

   bool crossAbove = (l1p <= l2p) && (l1c > l2c);
   bool crossBelow = (l1p >= l2p) && (l1c < l2c);
   int signal = 0;
   if(crossAbove) signal = 1;
   else if(crossBelow) signal = -1;
   else if(l1c > l2c) signal = 1;
   else if(l1c < l2c) signal = -1;

   if(cs_filter_debug_logs)
      Print("3LSH CS bar=", barIndex, " tf=", timeframe, " shift=", strengthShift, " dir=", direction,
            " l1=", l1c, "/", l1p, " l2=", l2c, "/", l2p, " signal=", signal);

   if(cs_filter_debug_logs)
    {
     string side = (direction == OP_BUY) ? "BUY" : (direction == OP_SELL ? "SELL" : "UNKNOWN");
     string tsEval = (barIndex >= 0 && barIndex < Bars) ? TimeToString(Time[barIndex], TIME_DATE|TIME_SECONDS) : "n/a";
     PrintFormat("3LSH Debug: CS-eval side=%s bar=%d time=%s timeframe=%d shift=%d l1c=%.5f l1p=%.5f l2c=%.5f l2p=%.5f crossAbove=%s crossBelow=%s requireCross=%s signal=%d",
                 side, barIndex, tsEval, timeframe, strengthShift,
                 l1c, l1p, l2c, l2p,
                 boolToString(crossAbove), boolToString(crossBelow),
                 boolToString(cs_require_cross), signal);
    }

  bool result = false;
  if(direction == OP_BUY)
  {
     // Strict match to indicator: require bullish (signal==1) unless requireCross forces crossAbove
     result = cs_require_cross ? crossAbove : (signal == 1);
     if(cs_filter_debug_logs)
        PrintFormat("3LSH CS BUY check: cs_require_cross=%s, crossAbove=%s, signal==1 is %s, result=%s",
                    boolToString(cs_require_cross), boolToString(crossAbove), boolToString(signal == 1), boolToString(result));
  }
  else if(direction == OP_SELL)
  {
     // Strict match to indicator: require bearish (signal==-1) unless requireCross forces crossBelow
     result = cs_require_cross ? crossBelow : (signal == -1);
     if(cs_filter_debug_logs)
        PrintFormat("3LSH CS SELL check: cs_require_cross=%s, crossBelow=%s, signal==-1 is %s, result=%s",
                    boolToString(cs_require_cross), boolToString(crossBelow), boolToString(signal == -1), boolToString(result));
  }
   else
   {
      if(cs_filter_debug_logs)
         PrintFormat("3LSH CS UNKNOWN direction: %d", direction);
   }

   return result;
  }

int resolveCurrencyStrengthShiftTf(int barIndex, int timeframe)
  {
   if(timeframe == Period())
      return barIndex;
   int shift = iBarShift(Symbol(), timeframe, Time[barIndex], true);
   if(shift < 0)
      shift = iBarShift(Symbol(), timeframe, Time[barIndex], false);
   // If evaluating a higher timeframe than chart, optionally use the last CLOSED HTF bar
   if(cs_use_closed_htf_bar && timeframe > Period())
     {
      shift = shift + 1;
      if(shift >= iBars(Symbol(), timeframe))
         shift = iBars(Symbol(), timeframe) - 1;
      if(cs_filter_debug_logs)
         PrintFormat("3LSH CS using CLOSED HTF bar: timeframe=%d originalShift=%d adjustedShift=%d",
                     timeframe, shift - 1, shift);
     }
   return shift;
  }

bool loadCurrencyStrengthValues(int tf, int shift, double &l1c, double &l1p,
                                double &l2c, double &l2p)
  {
  string name = cs_indicator_name;
  // Try primary name first for requested timeframe
  l1c = iCustom(Symbol(), tf, name, cs_line1_buffer, shift);
  l1p = iCustom(Symbol(), tf, name, cs_line1_buffer, shift + 1);
  l2c = iCustom(Symbol(), tf, name, cs_line2_buffer, shift);
  l2p = iCustom(Symbol(), tf, name, cs_line2_buffer, shift + 1);

  // If missing, try optional subfolder-qualified name
  if(valuesMissing(l1c, l1p, l2c, l2p) && StringLen(cs_indicator_subfolder) > 0)
    {
     name = cs_indicator_subfolder + cs_indicator_name;
     l1c = iCustom(Symbol(), tf, name, cs_line1_buffer, shift);
     l1p = iCustom(Symbol(), tf, name, cs_line1_buffer, shift + 1);
     l2c = iCustom(Symbol(), tf, name, cs_line2_buffer, shift);
     l2p = iCustom(Symbol(), tf, name, cs_line2_buffer, shift + 1);
    }

  // Optional swap if indicator buffers are reversed relative to base/quote
  if(cs_swap_lines)
    {
     double t1 = l1c, t2 = l1p;
     l1c = l2c; l1p = l2p;
     l2c = t1;  l2p = t2;
     if(cs_filter_debug_logs)
        Print("3LSH CS note: swapped L1/L2 due to cs_swap_lines=true");
    }

  // If values exist, return early
  if(!valuesMissing(l1c, l1p, l2c, l2p))
     return true;

  // Debug info: show what was attempted
  if(cs_filter_debug_logs)
    Print("3LSH CS values missing initially; timeframe=", tf,
          " startShift=", shift, " name=", name);

  // Fallback: scan forward (increasing shift) up to a reasonable limit to
  // find the most recent non-empty values. This helps when indicator
  // instances only populate a limited history.
  int maxScan = 500; // configurable upper bound for scanning
  for(int s = shift; s < shift + maxScan && s < Bars - 2; s++)
    {
     double tl1c = iCustom(Symbol(), tf, name, cs_line1_buffer, s);
     double tl1p = iCustom(Symbol(), tf, name, cs_line1_buffer, s + 1);
     double tl2c = iCustom(Symbol(), tf, name, cs_line2_buffer, s);
     double tl2p = iCustom(Symbol(), tf, name, cs_line2_buffer, s + 1);

     if(!valuesMissing(tl1c, tl1p, tl2c, tl2p))
       {
        l1c = tl1c; l1p = tl1p; l2c = tl2c; l2p = tl2p;
        if(cs_filter_debug_logs)
           Print("3LSH CS found values at shift=", s, " timeframe=", tf);
        return true;
       }
    }

  // Nothing found within scan window
  if(cs_filter_debug_logs)
     Print("3LSH CS fallback scan failed for timeframe=", tf,
           " startShift=", shift, " (scanned up to ", MathMin(shift+maxScan, Bars-1), ")");

  return false;
  }

bool valuesMissing(double l1c, double l1p, double l2c, double l2p)
  {
   return (l1c == EMPTY_VALUE || l1p == EMPTY_VALUE ||
           l2c == EMPTY_VALUE || l2p == EMPTY_VALUE);
  }

int normalizeOrderTypeToSignal(int orderType)
  {
   if(orderType == OP_BUY)
      return 1;
   if(orderType == OP_SELL)
      return -1;
   return 0;
  }

//==============================================================================
// UTILITY FUNCTIONS
//==============================================================================

// Resolve a TIMEFRAMES option (including tf_n1/tf_n2/tf_n3) to
// an actual period constant (e.g. PERIOD_H1). If `tfOption` is
// `tf_cu` (0) the current chart period is returned.
int resolveTimeframePeriod(int tfOption)
  {
   // ordered list of standard periods used by the indicator
   int periods[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30,
                    PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};

   // current chart period -> find its index in the list
   int curIdx = -1;
   for(int i = 0; i < ArraySize(periods); i++)
     {
      if(Period() == periods[i]) { curIdx = i; break; }
     }

   // explicit period provided (non-negative and not tf_cu)
   if(tfOption >= 1)
     return tfOption;

   // tf_cu (0) -> return current chart period
   if(tfOption == tf_cu || tfOption == 0)
     return Period();

   // handle higher timeframe requests: tf_n1 == -1, tf_n2 == -2, tf_n3 == -3
   if(tfOption < 0 && curIdx >= 0)
     {
      int offset = -tfOption; // -(-1)=1 for tf_n1, etc.
      int desiredIdx = curIdx + offset;
      if(desiredIdx >= ArraySize(periods))
         desiredIdx = ArraySize(periods) - 1; // clamp to highest available
      return periods[desiredIdx];
     }

   // fallback: return current period
   return Period();
  }

int getMtfIndex(int tfOption)
  {
   int tf = resolveTimeframePeriod(tfOption);
   // if requested timeframe equals current, return shift 1 (first closed bar)
   if(tf == Period()) return 1;
   // otherwise return the bar shift for that higher timeframe
   return iBarShift(Symbol(), tf, Time[1]);
  }

//+------------------------------------------------------------------+
//| Period to String - from ! 3LS indicator                         |
//+------------------------------------------------------------------+
string TFName()
  {
   string sTfTable[] = {"M1","M5","M15","M30","H1","H4","D1","W1","MN"};
   int    iTfTable[] = {1,5,15,30,60,240,1440,10080,43200};

   for (int i=ArraySize(iTfTable)-1; i>=0; i--)
         if (Period()==iTfTable[i]) return(sTfTable[i]);
                              return("");
  }

//+------------------------------------------------------------------+
//| Function to return the distance of arrow from Candle             |
//+------------------------------------------------------------------+
double getPoint()
  {
   int tf = Period();
   if(tf == 1)
      return 5.0 * Point;
   if(tf == 5)
      return 10.0 * Point;
   if(tf == 15)
      return 22.0 * Point;
   if(tf == 30)
      return 44.0 * Point;
   if(tf == 60)
      return 80.0 * Point;
   if(tf == 240)
      return 120.0 * Point;
   if(tf == 1440)
      return 170.0 * Point;
   if(tf == 10080)
      return 500.0 * Point;
   if(tf == 43200)
      return 900.0 * Point;
   return 20.0 * Point;
  }

//==============================================================================
// EA SPECIFIC FUNCTIONS (replacing iCustom calls)
//==============================================================================

//+------------------------------------------------------------------+
//| Calculate HuskyBands for the current bar                         |
//+------------------------------------------------------------------+
void calculateHuskyBands(double &lowerBand, double &upperBand, int shift = 1)
{
   if(!useHuskyBands)
   {
      lowerBand = EMPTY_VALUE;
      upperBand = EMPTY_VALUE;
      return;
   }

   // Calculate TMA centered value
   double tmaValue = calculateTMA(shift, PRICE_MEDIAN);

   // Calculate ATR-based deviation
   double deviation = calculateATRDeviation(shift, ATR_Period, tmaValue);

   // Calculate band distance
   double bandDistance = deviation * ATR_Multiplier_Band1;

   // Set band values
   lowerBand = tmaValue - bandDistance;
   upperBand = tmaValue + bandDistance;
}

//+------------------------------------------------------------------+
//| Check for 3LS signal and apply all filters                        |
//+------------------------------------------------------------------+
int getIntegratedSignal()
{
   // Get 3LS signal
   int lsSignal = signalLS(1); // Check previous bar

   if(lsSignal == -1) return 0; // No 3LS signal

   int directionOrderType = lsSignal;

   // Get HuskyBands
   double lowerBand, upperBand;
   calculateHuskyBands(lowerBand, upperBand, 1);

   // Check band touch condition
   bool bandCondition = false;
   if(directionOrderType == OP_BUY && useHuskyBands)
      bandCondition = (Low[1] <= lowerBand);
   else if(directionOrderType == OP_SELL && useHuskyBands)
      bandCondition = (High[1] >= upperBand);

   // If HuskyBands are enabled but condition not met, no signal
   if(useHuskyBands && !bandCondition)
      return 0;

   // If HuskyBands disabled or condition met, check CS filter
   if(cs_filter_enabled)
   {
      bool csPass = passesCurrencyStrengthFilterTf(1, directionOrderType, cs_timeframe);
      if(!csPass)
         return 0; // CS filter blocks this signal
   }

   return normalizeOrderTypeToSignal(directionOrderType);
}

//+------------------------------------------------------------------+
//| Get blocked signal (for X marks)                                 |
//+------------------------------------------------------------------+
int getIntegratedBlockedSignal()
{
   // Get 3LS signal
   int lsSignal = signalLS(1); // Check previous bar

   if(lsSignal == -1) return 0; // No 3LS signal

   int directionOrderType = lsSignal;

   // Get HuskyBands
   double lowerBand, upperBand;
   calculateHuskyBands(lowerBand, upperBand, 1);

   // Check band touch condition
   bool bandCondition = false;
   if(directionOrderType == OP_BUY && useHuskyBands)
      bandCondition = (Low[1] <= lowerBand);
   else if(directionOrderType == OP_SELL && useHuskyBands)
      bandCondition = (High[1] >= upperBand);

   // If HuskyBands are enabled but condition not met, no signal
   if(useHuskyBands && !bandCondition)
      return 0;

   // If CS filter is enabled and blocks this signal, return blocked signal
   if(cs_filter_enabled)
   {
      bool csPass = passesCurrencyStrengthFilterTf(1, directionOrderType, cs_timeframe);
      if(!csPass)
         return normalizeOrderTypeToSignal(directionOrderType); // Return the blocked signal type
   }

   return 0; // No blocked signal
}

//+------------------------------------------------------------------+
//| Get blocked signal price for historical arrows                   |
//+------------------------------------------------------------------+
double getBlockedPrice(int direction, int barIndex = 1)
{
   if(direction == 1)
      return Low[barIndex] - getPoint() * ls_arrow_gap;
   else if(direction == -1)
      return High[barIndex] + getPoint() * ls_arrow_gap;

   return EMPTY_VALUE;
}

//+------------------------------------------------------------------+
//| Check for 3LS signal and apply all filters at specific time      |
//+------------------------------------------------------------------+
int getIntegratedSignalAtTime(datetime when)
{
   // find index on the current chart timeframe corresponding to 'when'
   int idx = iBarShift(Symbol(), Period(), when, true);
   if(idx == -1) return 0;

   // Get 3LS signal at this bar
   int lsSignal = signalLS(idx);

   if(lsSignal == -1) return 0; // No 3LS signal

   // Get HuskyBands at this bar
   double lowerBand, upperBand;
   calculateHuskyBandsAtTime(lowerBand, upperBand, when);

   // Check band touch condition
   bool bandCondition = false;
   int directionOrderType = lsSignal;
   if(directionOrderType == OP_BUY && useHuskyBands)
      bandCondition = (Low[idx] <= lowerBand);
   else if(directionOrderType == OP_SELL && useHuskyBands)
      bandCondition = (High[idx] >= upperBand);

   // If HuskyBands are enabled but condition not met, no signal
   if(useHuskyBands && !bandCondition)
      return 0;

   // If HuskyBands disabled or condition met, check CS filter
   if(cs_filter_enabled)
   {
      bool csPass = passesCurrencyStrengthFilterTf(idx, directionOrderType, cs_timeframe);
      if(!csPass)
         return 0; // CS filter blocks this signal
   }

   return normalizeOrderTypeToSignal(directionOrderType);
}

//+------------------------------------------------------------------+
//| Get blocked signal at specific time                              |
//+------------------------------------------------------------------+
int getIntegratedBlockedSignalAtTime(datetime when)
{
   // find index on the current chart timeframe corresponding to 'when'
   int idx = iBarShift(Symbol(), Period(), when, true);
   if(idx == -1) return 0;

   // Get 3LS signal at this bar
   int lsSignal = signalLS(idx);

   if(lsSignal == -1) return 0; // No 3LS signal

   // Get HuskyBands at this bar
   double lowerBand, upperBand;
   calculateHuskyBandsAtTime(lowerBand, upperBand, when);

   // Check band touch condition
   bool bandCondition = false;
   int directionOrderType = lsSignal;
   if(directionOrderType == OP_BUY && useHuskyBands)
      bandCondition = (Low[idx] <= lowerBand);
   else if(directionOrderType == OP_SELL && useHuskyBands)
      bandCondition = (High[idx] >= upperBand);

   // If HuskyBands are enabled but condition not met, no signal
   if(useHuskyBands && !bandCondition)
      return 0;

   // If CS filter is enabled and blocks this signal, return blocked signal
   if(cs_filter_enabled)
   {
      bool csPass = passesCurrencyStrengthFilterTf(idx, directionOrderType, cs_timeframe);
      if(!csPass)
         return normalizeOrderTypeToSignal(directionOrderType); // Return the blocked signal type
   }

   return 0; // No blocked signal
}

//+------------------------------------------------------------------+
//| Calculate HuskyBands at a specific time                          |
//+------------------------------------------------------------------+
void calculateHuskyBandsAtTime(double &lowerBand, double &upperBand, datetime when)
{
   if(!useHuskyBands)
   {
      lowerBand = EMPTY_VALUE;
      upperBand = EMPTY_VALUE;
      return;
   }

   // find index on the current chart timeframe corresponding to 'when'
   int idx = iBarShift(Symbol(), Period(), when, true);
   if(idx == -1)
   {
      lowerBand = EMPTY_VALUE;
      upperBand = EMPTY_VALUE;
      return;
   }

   // Calculate TMA centered value
   double tmaValue = calculateTMA(idx, PRICE_MEDIAN);

   // Calculate ATR-based deviation
   double deviation = calculateATRDeviation(idx, ATR_Period, tmaValue);

   // Calculate band distance
   double bandDistance = deviation * ATR_Multiplier_Band1;

   // Set band values
   lowerBand = tmaValue - bandDistance;
   upperBand = tmaValue + bandDistance;
}

//+------------------------------------------------------------------+
