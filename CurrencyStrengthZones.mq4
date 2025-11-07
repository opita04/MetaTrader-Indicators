/*
File: CurrencyStrengthZones.mq4
Author: unknown
Source: unknown
Description: Currency Strength Dashboard / Zones indicator wrapping dashboard features for charts
Purpose: Provide dashboard-like zone displays for currency strength signals on a chart
Parameters: See dashboard, pair selection and timeframe settings at the top of the file
Version: 1.00
Last Modified: 2025.11.06
Compatibility: MetaTrader 4 (MT4)
*/
//+------------------------------------------------------------------+
#property copyright "Currency Strength Dashboard"
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Dashboard Settings
extern string __DashboardSettings = ""; // Dashboard Settings
extern int    DashboardX = 20;              // Dashboard X Position
extern int    DashboardY = 20;              // Dashboard Y Position
extern bool   FullChartBackground = true;   // Background covers whole chart
extern string DashboardFont = "Arial Bold"; // Dashboard Font
extern int    DashboardTitleSize = 14;      // Title Font Size
extern int    DashboardFontSize = 9;        // Table Font Size
extern color  DashboardBgColor = C'255,228,181'; // Background Color (Moccasin)
extern color  HeaderBgColor = C'0,100,200'; // Header Background Color (Blue)
extern color  HeaderTextColor = clrWhite;   // Header Text Color
extern color  TableTextColor = clrBlack;     // Table Text Color
extern color  UpSignalColor = clrBlue;      // Up Signal Color
extern color  DownSignalColor = clrRed;     // Down Signal Color
extern color  NeutralColor = clrYellow;     // Neutral Color
extern bool   ShowGridLines = true;         // Show grid lines between cells
extern color  GridLineColor = clrBlack;      // Grid line color

//--- Pair Selection Settings
extern string __PairSettings = ""; // Pair Selection Settings
extern string PairSelectionMode = "MarketWatch"; // Mode: "CommaList" or "MarketWatch"
extern string PairsList = "EURUSD,GBPUSD,USDJPY"; // Comma-separated pairs (for CommaList mode)
extern int    MaxPairs = 5;                 // Maximum pairs to display
extern bool   ShowCurrentPair = true;       // Always show current chart pair

//--- Timeframe Settings (1-4 timeframes)
extern string __TimeframeSettings = ""; // Timeframe Settings
extern int    NumTimeframes = 3;              // Number of Timeframes (1-4)
extern ENUM_TIMEFRAMES Timeframe1 = PERIOD_D1;   // Timeframe 1
extern ENUM_TIMEFRAMES Timeframe2 = PERIOD_H1;   // Timeframe 2
extern ENUM_TIMEFRAMES Timeframe3 = PERIOD_M5;   // Timeframe 3
extern ENUM_TIMEFRAMES Timeframe4 = PERIOD_MN1;  // Timeframe 4

//--- Alert Settings (per timeframe)
extern string __AlertSettings = ""; // Alert Settings
extern bool   AlertTF1 = false;      // Alert on TF1 Direction Change
extern bool   AlertTF2 = false;      // Alert on TF2 Direction Change
extern bool   AlertTF3 = false;      // Alert on TF3 Direction Change
extern bool   AlertTF4 = false;      // Alert on TF4 Direction Change

//--- Indicator Settings
extern string __IndicatorName = ""; // Indicator Settings
extern string IndicatorName = "CurrencyStrengthWizard"; // Indicator Name (REQUIRED)
extern int    Line1Buffer = 0;             // Line 1 Buffer Number
extern int    Line2Buffer = 1;             // Line 2 Buffer Number
extern int    BarsToLookBack = 100;       // Bars to Look Back

//--- Global Variables
string DashboardPrefix = "ArrowsDash_";
string Pairs[];           // Array to store selected pairs
int TotalPairs = 0;       // Total number of pairs to display
ENUM_TIMEFRAMES Timeframes[4]; // Array of active timeframes
bool AlertEnabled[4];     // Alert enabled for each timeframe
int PreviousSignals[]; // Previous signals for each pair and timeframe [pair*4 + tf]

//+------------------------------------------------------------------+
//| Helper function to get PreviousSignals index                        |
//+------------------------------------------------------------------+
int GetPreviousSignalIndex(int pairIndex, int timeframeIndex)
{
    return pairIndex * 4 + timeframeIndex;
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

    // Initialize alert settings
    AlertEnabled[0] = AlertTF1;
    AlertEnabled[1] = AlertTF2;
    AlertEnabled[2] = AlertTF3;
    AlertEnabled[3] = AlertTF4;

    // Initialize pairs array
    InitializePairs();

    // Initialize previous signals array
    ArrayResize(PreviousSignals, TotalPairs * 4);
    for(int i = 0; i < TotalPairs * 4; i++)
    {
        PreviousSignals[i] = 0; // Initialize to neutral
    }

    // Set indicator name
    IndicatorShortName("Currency Strength Dashboard");

    // Create dashboard on init
    CreateDashboard();

    return(0);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
int deinit()
{
    // Delete all dashboard objects
    for(int obj=ObjectsTotal()-1; obj>=0; obj--)
    {
        string objName = ObjectName(obj);
        if(StringFind(objName, DashboardPrefix)==0) ObjectDelete(objName);
    }
    return(0);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
{
    UpdateDashboard();
    return(0);
}

//+------------------------------------------------------------------+
//| Initialize Pairs Array                                           |
//+------------------------------------------------------------------+
void InitializePairs()
{
    string tempPairs[];

    if(PairSelectionMode == "MarketWatch")
    {
        GetPairsFromMarketWatch(tempPairs);
    }
    else if(PairSelectionMode == "CommaList")
    {
        GetPairsFromCommaList(tempPairs);
    }
    else
    {
        GetPairsFromMarketWatch(tempPairs);
    }

    // Add current pair if requested and not already in list
    if(ShowCurrentPair)
    {
        bool found = false;
        string currentPair = Symbol();
        for(int i = 0; i < ArraySize(tempPairs); i++)
        {
            if(tempPairs[i] == currentPair)
            {
                found = true;
                break;
            }
        }
        if(!found && TotalPairs < MaxPairs)
        {
            ArrayResize(tempPairs, ArraySize(tempPairs) + 1);
            tempPairs[ArraySize(tempPairs) - 1] = currentPair;
        }
    }

    // Limit to MaxPairs
    TotalPairs = MathMin(ArraySize(tempPairs), MaxPairs);
    ArrayResize(Pairs, TotalPairs);
    for(int k = 0; k < TotalPairs; k++)
    {
        Pairs[k] = tempPairs[k];
    }
}

//+------------------------------------------------------------------+
//| Get Pairs from Market Watch                                      |
//+------------------------------------------------------------------+
void GetPairsFromMarketWatch(string &pairs[])
{
    int count = 0;
    for(int i = 0; i < SymbolsTotal(true); i++)
    {
        string symbol = SymbolName(i, true);
        if(count >= MaxPairs) break;

        if(StringLen(symbol) >= 6 && StringLen(symbol) <= 7)
        {
            ArrayResize(pairs, count + 1);
            pairs[count] = symbol;
            count++;
        }
    }
    TotalPairs = count;
}

//+------------------------------------------------------------------+
//| Get Pairs from Comma-Separated List                              |
//+------------------------------------------------------------------+
void GetPairsFromCommaList(string &pairs[])
{
    string pairsString = PairsList;
    int count = 0;
    string sep = ",";

    StringReplace(pairsString, " ", "");

    int pos = StringFind(pairsString, sep);
    while(pos >= 0 && count < MaxPairs)
    {
        string pair = StringSubstr(pairsString, 0, pos);
        if(StringLen(pair) > 0)
        {
            ArrayResize(pairs, count + 1);
            pairs[count] = pair;
            count++;
        }
        pairsString = StringSubstr(pairsString, pos + 1);
        pos = StringFind(pairsString, sep);
    }

    if(StringLen(pairsString) > 0 && count < MaxPairs)
    {
        ArrayResize(pairs, count + 1);
        pairs[count] = pairsString;
        count++;
    }

    TotalPairs = count;
}

//+------------------------------------------------------------------+
//| Create Dashboard Objects                                         |
//+------------------------------------------------------------------+
void CreateDashboard()
{
    string objName;
    int xPos, yPos;
    int rowHeight = 22;
    int colWidth = 80;
    int pairColWidth = 70;
    
    // Calculate dashboard dimensions
    int dashboardWidth = pairColWidth + (NumTimeframes * colWidth) + 20;
    int dashboardHeight = 45 + (TotalPairs * rowHeight) + 25;

    // Main background
    objName = DashboardPrefix + "Background";
    ObjectCreate(objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);

    if(FullChartBackground)
    {
        // Cover whole chart area
        ObjectSet(objName, OBJPROP_XDISTANCE, 0);
        ObjectSet(objName, OBJPROP_YDISTANCE, 0);
        ObjectSet(objName, OBJPROP_XSIZE, 2000); // Large width to cover chart
        ObjectSet(objName, OBJPROP_YSIZE, 1500); // Large height to cover chart
    }
    else
    {
        // Standard dashboard background
        ObjectSet(objName, OBJPROP_XDISTANCE, DashboardX);
        ObjectSet(objName, OBJPROP_YDISTANCE, DashboardY);
        ObjectSet(objName, OBJPROP_XSIZE, dashboardWidth);
        ObjectSet(objName, OBJPROP_YSIZE, dashboardHeight);
    }
    ObjectSet(objName, OBJPROP_BGCOLOR, DashboardBgColor);
    ObjectSet(objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSet(objName, OBJPROP_BACK, false); // Bring to front to cover chart

    // Title
    yPos = DashboardY + 8;
    objName = DashboardPrefix + "Title";
    ObjectCreate(objName, OBJ_LABEL, 0, 0, 0);
    ObjectSet(objName, OBJPROP_BACK, false); // Bring to front
    ObjectSet(objName, OBJPROP_XDISTANCE, DashboardX + (dashboardWidth / 2));
    ObjectSet(objName, OBJPROP_YDISTANCE, yPos);
    ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSet(objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
    ObjectSetText(objName, "Currency Strength Dashboard", DashboardTitleSize, DashboardFont, TableTextColor);

    // Header row background
    yPos += 25;
    objName = DashboardPrefix + "HeaderBg";
    ObjectCreate(objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSet(objName, OBJPROP_XDISTANCE, DashboardX);
    ObjectSet(objName, OBJPROP_YDISTANCE, yPos);
    ObjectSet(objName, OBJPROP_XSIZE, dashboardWidth);
    ObjectSet(objName, OBJPROP_YSIZE, rowHeight);
    ObjectSet(objName, OBJPROP_BGCOLOR, HeaderBgColor);
    ObjectSet(objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSet(objName, OBJPROP_BACK, false);

    // Header labels
    objName = DashboardPrefix + "Header_Pair";
    ObjectCreate(objName, OBJ_LABEL, 0, 0, 0);
    ObjectSet(objName, OBJPROP_BACK, false); // Bring to front
    ObjectSet(objName, OBJPROP_XDISTANCE, DashboardX + (pairColWidth / 2) - 15);
    ObjectSet(objName, OBJPROP_YDISTANCE, yPos + 5);
    ObjectSet(objName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetText(objName, "PAIR", DashboardFontSize, DashboardFont, HeaderTextColor);
    ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);

    // Timeframe headers
    for(int tf = 0; tf < NumTimeframes; tf++)
    {
        xPos = DashboardX + pairColWidth + (tf * colWidth) + (colWidth / 2);
        objName = DashboardPrefix + "Header_TF" + (string)tf;
        ObjectCreate(objName, OBJ_LABEL, 0, 0, 0);
        ObjectSet(objName, OBJPROP_BACK, false); // Bring to front
        ObjectSet(objName, OBJPROP_XDISTANCE, xPos);
        ObjectSet(objName, OBJPROP_YDISTANCE, yPos + 5);
        ObjectSet(objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
        ObjectSetText(objName, GetTimeframeString(Timeframes[tf]), DashboardFontSize, DashboardFont, HeaderTextColor);
        ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    }

    // Create grid lines (if enabled)
    if(ShowGridLines)
    {
        int gridLineThickness = 1;
        int tableTop = yPos;
        int tableBottom = yPos + rowHeight + (TotalPairs * rowHeight);
        int tableRight = DashboardX + pairColWidth + (NumTimeframes * colWidth);

        // Top border
        objName = DashboardPrefix + "Grid_H_Top";
        ObjectCreate(objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSet(objName, OBJPROP_BACK, false);
        ObjectSet(objName, OBJPROP_XDISTANCE, DashboardX);
        ObjectSet(objName, OBJPROP_YDISTANCE, tableTop);
        ObjectSet(objName, OBJPROP_XSIZE, tableRight - DashboardX);
        ObjectSet(objName, OBJPROP_YSIZE, gridLineThickness);
        ObjectSet(objName, OBJPROP_BGCOLOR, GridLineColor);
        ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);

        // Horizontal line after header row
        objName = DashboardPrefix + "Grid_H_Header";
        ObjectCreate(objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSet(objName, OBJPROP_BACK, false);
        ObjectSet(objName, OBJPROP_XDISTANCE, DashboardX);
        ObjectSet(objName, OBJPROP_YDISTANCE, tableTop + rowHeight);
        ObjectSet(objName, OBJPROP_XSIZE, tableRight - DashboardX);
        ObjectSet(objName, OBJPROP_YSIZE, gridLineThickness);
        ObjectSet(objName, OBJPROP_BGCOLOR, GridLineColor);
        ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);

        // Left border
        objName = DashboardPrefix + "Grid_V_Left";
        ObjectCreate(objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSet(objName, OBJPROP_BACK, false);
        ObjectSet(objName, OBJPROP_XDISTANCE, DashboardX);
        ObjectSet(objName, OBJPROP_YDISTANCE, tableTop);
        ObjectSet(objName, OBJPROP_XSIZE, gridLineThickness);
        ObjectSet(objName, OBJPROP_YSIZE, tableBottom - tableTop);
        ObjectSet(objName, OBJPROP_BGCOLOR, GridLineColor);
        ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);

        // Vertical line after PAIR column
        objName = DashboardPrefix + "Grid_V_Pair";
        ObjectCreate(objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSet(objName, OBJPROP_BACK, false);
        ObjectSet(objName, OBJPROP_XDISTANCE, DashboardX + pairColWidth);
        ObjectSet(objName, OBJPROP_YDISTANCE, tableTop);
        ObjectSet(objName, OBJPROP_XSIZE, gridLineThickness);
        ObjectSet(objName, OBJPROP_YSIZE, tableBottom - tableTop);
        ObjectSet(objName, OBJPROP_BGCOLOR, GridLineColor);
        ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);

        // Vertical lines between timeframe columns (including right border)
        for(tf = 0; tf < NumTimeframes; tf++)
        {
            objName = DashboardPrefix + "Grid_V_TF" + (string)tf;
            ObjectCreate(objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
            ObjectSet(objName, OBJPROP_BACK, false);
            ObjectSet(objName, OBJPROP_XDISTANCE, DashboardX + pairColWidth + (tf + 1) * colWidth);
            ObjectSet(objName, OBJPROP_YDISTANCE, tableTop);
            ObjectSet(objName, OBJPROP_XSIZE, gridLineThickness);
            ObjectSet(objName, OBJPROP_YSIZE, tableBottom - tableTop);
            ObjectSet(objName, OBJPROP_BGCOLOR, GridLineColor);
            ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        }

        // Bottom border
        objName = DashboardPrefix + "Grid_H_Bottom";
        ObjectCreate(objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSet(objName, OBJPROP_BACK, false);
        ObjectSet(objName, OBJPROP_XDISTANCE, DashboardX);
        ObjectSet(objName, OBJPROP_YDISTANCE, tableBottom);
        ObjectSet(objName, OBJPROP_XSIZE, tableRight - DashboardX);
        ObjectSet(objName, OBJPROP_YSIZE, gridLineThickness);
        ObjectSet(objName, OBJPROP_BGCOLOR, GridLineColor);
        ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    }

    // Create pair rows
    yPos += rowHeight;
    for(int i = 0; i < TotalPairs; i++)
    {
        // Pair name
        objName = DashboardPrefix + "Pair_" + i + "_Name";
        ObjectCreate(objName, OBJ_LABEL, 0, 0, 0);
        ObjectSet(objName, OBJPROP_BACK, false); // Bring to front
        ObjectSet(objName, OBJPROP_XDISTANCE, DashboardX + (pairColWidth / 2) - 15);
        ObjectSet(objName, OBJPROP_YDISTANCE, yPos + 5);
        ObjectSet(objName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        ObjectSetText(objName, Pairs[i], DashboardFontSize, DashboardFont, TableTextColor);
        ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);

        // Timeframe signals
        for(int t = 0; t < NumTimeframes; t++)
        {
            xPos = DashboardX + pairColWidth + (t * colWidth) + (colWidth / 2);
            objName = DashboardPrefix + "Pair_" + i + "_TF" + (string)t;
            ObjectCreate(objName, OBJ_LABEL, 0, 0, 0);
            ObjectSet(objName, OBJPROP_BACK, false); // Bring to front
            ObjectSet(objName, OBJPROP_XDISTANCE, xPos);
            ObjectSet(objName, OBJPROP_YDISTANCE, yPos + 5);
            ObjectSet(objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetText(objName, CharToString(232), DashboardFontSize + 2, "Wingdings", NeutralColor);
            ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSet(objName, OBJPROP_SELECTABLE, true); // Make clickable
            ObjectSet(objName, OBJPROP_SELECTED, false);
        }

        // Horizontal grid line after this row (except for the last row)
        if(ShowGridLines && i < TotalPairs - 1)
        {
            objName = DashboardPrefix + "Grid_H_Row" + (string)i;
            ObjectCreate(objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
            ObjectSet(objName, OBJPROP_BACK, false);
            ObjectSet(objName, OBJPROP_XDISTANCE, DashboardX);
            ObjectSet(objName, OBJPROP_YDISTANCE, yPos + rowHeight);
            ObjectSet(objName, OBJPROP_XSIZE, dashboardWidth);
            ObjectSet(objName, OBJPROP_YSIZE, 1); // 1 pixel thickness
            ObjectSet(objName, OBJPROP_BGCOLOR, GridLineColor);
            ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        }

        yPos += rowHeight;
    }
}

//+------------------------------------------------------------------+
//| Update Dashboard with Current Signals                           |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
    string objName;
    string signalText;
    color signalColor;
    int currentSignal;

    // Update each pair's signals
    for(int i = 0; i < TotalPairs; i++)
    {
        // Update each timeframe
        for(int tf = 0; tf < NumTimeframes; tf++)
        {
            // Get current signal
            currentSignal = GetCrossoverSignal(Pairs[i], Timeframes[tf]);

            // Check for direction change and alert if enabled
            int signalIndex = GetPreviousSignalIndex(i, tf);
            if(AlertEnabled[tf] && PreviousSignals[signalIndex] != 0 && PreviousSignals[signalIndex] != currentSignal)
            {
                if(currentSignal == 1 && PreviousSignals[signalIndex] == -1)
                {
                    Alert("Direction Change: " + Pairs[i] + " " + GetTimeframeString(Timeframes[tf]) + " changed from DOWN to UP");
                }
                else if(currentSignal == -1 && PreviousSignals[signalIndex] == 1)
                {
                    Alert("Direction Change: " + Pairs[i] + " " + GetTimeframeString(Timeframes[tf]) + " changed from UP to DOWN");
                }
            }

            // Update previous signal
            PreviousSignals[signalIndex] = currentSignal;

            // Determine arrow and color
            if(currentSignal == 1)
            {
                signalText = CharToString(233); // Up arrow in Wingdings
                signalColor = UpSignalColor;
            }
            else if(currentSignal == -1)
            {
                signalText = CharToString(234); // Down arrow in Wingdings
                signalColor = DownSignalColor;
            }
            else
            {
                signalText = CharToString(232); // Right arrow in Wingdings (neutral)
                signalColor = NeutralColor;
            }

            // Update display
            objName = DashboardPrefix + "Pair_" + i + "_TF" + (string)tf;
            ObjectSetText(objName, signalText, DashboardFontSize + 2, "Wingdings", signalColor);
        }
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

    bool crossAbove = (line1_previous <= line2_previous) && (line1_current > line2_current);
    bool crossBelow = (line1_previous >= line2_previous) && (line1_current < line2_current);

    if(crossAbove)
        return 1;  // Up signal
    else if(crossBelow)
        return -1; // Down signal
    else
    {
        if(line1_current > line2_current)
            return 1;  // Currently above
        else if(line1_current < line2_current)
            return -1; // Currently below
        else
            return 0;  // Neutral
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
