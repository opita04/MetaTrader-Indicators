/*
File: EA - Currency Strength Dashboard.mq4
Author: unknown
Source: unknown
Description: Dashboard EA showing currency strength across multiple pairs and timeframes with clickable arrows
Purpose: Provide a visual dashboard for monitoring currency strength alignment and quick chart opening
Parameters: See dashboard, timeframe, pair selection, and alert settings at the top of the file
Version: 2.00
Last Modified: 2025.11.06
Compatibility: MetaTrader 4 (MT4)
*/
//+------------------------------------------------------------------+
#property copyright "Currency Strength Dashboard"
#property version   "2.00"

// Import Windows API functions for chart opening
#import "user32.dll"
   int PostMessageA(int hWnd, int Msg, int wParam, int lParam);
   int FindWindowA(string lpClassName, string lpWindowName);
#import "shell32.dll"
   int ShellExecuteA(int hwnd, string lpOperation, string lpFile, string lpParameters, string lpDirectory, int nShowCmd);
#import

//--- Pair Selection Mode Enum
enum ENUM_PAIR_SELECTION_MODE
{
   MODE_MARKET_WATCH,    // Use pairs from Market Watch
   MODE_COMMA_LIST       // Use custom comma-separated list
};

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
extern ENUM_PAIR_SELECTION_MODE PairSelectionMode = MODE_MARKET_WATCH; // Select pair source
extern string PairsList = "EURUSD,GBPUSD,USDJPY"; // Comma-separated pairs (for MODE_COMMA_LIST)
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

//--- Template Settings
extern string __TemplateSettings = ""; // Template Settings
extern string TemplateName = "";       // Template to apply when opening charts (leave empty for no template)

//--- Alert Settings (general)
extern string __GeneralAlertSettings = ""; // General Alert Settings
extern bool   popupAlert = true;       // Show popup alerts
extern bool   pushAlert = false;       // Send push notifications
extern bool   emailAlert = false;      // Send email alerts

//--- Global Variables
string DashboardPrefix = "ArrowsDash_";
string Pairs[];           // Array to store selected pairs
int TotalPairs = 0;       // Total number of pairs to display
ENUM_TIMEFRAMES Timeframes[4]; // Array of active timeframes
bool AlertEnabled[4];     // Alert enabled for each timeframe
int PreviousSignals[]; // Previous signals for each pair and timeframe [pair*4 + tf]
datetime PreviousSignalTime[]; // Timestamp of last signal change for each pair/timeframe [pair*4 + tf]
string BotName = "Currency Strength Dashboard"; // Bot name for alerts

//+------------------------------------------------------------------+
//| Helper function to get PreviousSignals index                        |
//+------------------------------------------------------------------+
int GetPreviousSignalIndex(int pairIndex, int timeframeIndex)
{
    return pairIndex * 4 + timeframeIndex;
}

//+------------------------------------------------------------------+
//| Expert Advisor initialization function                           |
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
    // Initialize previous signal times array
    ArrayResize(PreviousSignalTime, TotalPairs * 4);
    for(int ti = 0; ti < TotalPairs * 4; ti++)
    {
        PreviousSignalTime[ti] = 0; // No timestamp yet
    }

    // Set indicator name
    IndicatorShortName("Currency Strength Dashboard");

    // Create dashboard on init
    CreateDashboard();

    return(0);
}

//+------------------------------------------------------------------+
//| Expert Advisor deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Delete all dashboard objects
    for(int obj=ObjectsTotal()-1; obj>=0; obj--)
    {
        string objName = ObjectName(obj);
        if(StringFind(objName, DashboardPrefix)==0) ObjectDelete(objName);
    }
}

//+------------------------------------------------------------------+
//| Expert Advisor tick function                                     |
//+------------------------------------------------------------------+
void OnTick()
{
    UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Open Chart with Template Application                             |
//+------------------------------------------------------------------+
void OpenChartWindow(string symbol, ENUM_TIMEFRAMES timeframe)
{
    Print("Opening chart for ", symbol, " on ", GetTimeframeString(timeframe));

    // Try to open chart using ChartOpen function
    long chartId = ChartOpen(symbol, timeframe);

    if(chartId > 0)
    {
        Print("Chart opened successfully: " + symbol + " " + GetTimeframeString(timeframe));

        // Apply template if specified
        if(StringLen(TemplateName) > 0)
        {
            if(ChartApplyTemplate(chartId, TemplateName))
            {
                Print("Template applied successfully: " + TemplateName);
            }
            else
            {
                Print("Failed to apply template: " + TemplateName + " (Error: " + IntegerToString(GetLastError()) + ")");
            }
        }

        // Bring the chart to front
        ChartSetInteger(chartId, CHART_BRING_TO_TOP, true);
    }
    else
    {
        Print("Failed to open chart: " + symbol + " " + GetTimeframeString(timeframe) + " (Error: " + IntegerToString(GetLastError()) + ")");

        // Fallback: Show instructions for manual opening
        string message = "Please manually open chart: " + symbol + " " + GetTimeframeString(timeframe);
        Alarm(message);
    }
}


//+------------------------------------------------------------------+
//| Convert Timeframe Enum to Period Integer                        |
//+------------------------------------------------------------------+
int GetTimeframePeriod(ENUM_TIMEFRAMES timeframe)
{
    switch(timeframe)
    {
        case PERIOD_M1: return 1;
        case PERIOD_M5: return 5;
        case PERIOD_M15: return 15;
        case PERIOD_M30: return 30;
        case PERIOD_H1: return 60;
        case PERIOD_H4: return 240;
        case PERIOD_D1: return 1440;
        case PERIOD_W1: return 10080;
        case PERIOD_MN1: return 43200;
        default: return 1440; // Default to D1
    }
}

//+------------------------------------------------------------------+
//| Chart Event Handler - Handle Arrow Clicks                       |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    // Debug: Log all chart events
    Print("ChartEvent: id=", id, " lparam=", lparam, " dparam=", dparam, " sparam=", sparam);

    // Handle object click events
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        Print("Object clicked: ", sparam);

        // Check if clicked object is an arrow
        if(StringFind(sparam, DashboardPrefix + "Pair_") == 0 && StringFind(sparam, "_TF") > 0)
        {
            Print("Arrow clicked: ", sparam);

            // Extract pair index and timeframe index from object name
            // Format: "ArrowsDash_Pair_0_TF1"
            string tempName = StringSubstr(sparam, StringLen(DashboardPrefix + "Pair_"));
            int underscorePos = StringFind(tempName, "_TF");

            if(underscorePos > 0)
            {
                string pairIndexStr = StringSubstr(tempName, 0, underscorePos);
                string tfIndexStr = StringSubstr(tempName, underscorePos + 3);

                int pairIndex = StrToInteger(pairIndexStr);
                int tfIndex = StrToInteger(tfIndexStr);

                Print("Extracted indices: pair=", pairIndex, " tf=", tfIndex);

                // Validate indices
                if(pairIndex >= 0 && pairIndex < TotalPairs && tfIndex >= 0 && tfIndex < NumTimeframes)
                {
                    string symbol = Pairs[pairIndex];
                    ENUM_TIMEFRAMES timeframe = Timeframes[tfIndex];

                    Print("Opening chart for: ", symbol, " timeframe: ", GetTimeframeString(timeframe));

                    // Open new chart window
                    OpenChartWindow(symbol, timeframe);
                }
                else
                {
                    Print("Invalid indices: pair=", pairIndex, " (max ", TotalPairs-1, ") tf=", tfIndex, " (max ", NumTimeframes-1, ")");
                }
            }
            else
            {
                Print("Could not parse object name: ", tempName);
            }
        }
        else
        {
            Print("Object is not an arrow: ", sparam);
        }
    }
}


//+------------------------------------------------------------------+
//| Initialize Pairs Array                                           |
//+------------------------------------------------------------------+
void InitializePairs()
{
    string tempPairs[];

    if(PairSelectionMode == MODE_MARKET_WATCH)
    {
        GetPairsFromMarketWatch(tempPairs);
    }
    else if(PairSelectionMode == MODE_COMMA_LIST)
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
    // Left-pad header text within the PAIR column for consistent alignment
    ObjectSet(objName, OBJPROP_XDISTANCE, DashboardX + 6);
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
        // Left-pad pair name within the PAIR column for consistent alignment
        ObjectSet(objName, OBJPROP_XDISTANCE, DashboardX + 6);
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
            ObjectSet(objName, OBJPROP_YDISTANCE, yPos + (rowHeight/4));
            ObjectSet(objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetText(objName, CharToString(232), DashboardFontSize + 2, "Wingdings", NeutralColor);
            ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSet(objName, OBJPROP_SELECTABLE, true); // Make clickable
            ObjectSet(objName, OBJPROP_SELECTED, false);
            // Create an age square centered below the arrow inside the same TF cell
            int ageWidth = MathMin(30, colWidth - 10);
            int ageHeight = 12;
            int ageLeft = xPos - (ageWidth / 2);
            int ageTop = yPos + rowHeight - ageHeight - 4;

            string objNameAgeBg = DashboardPrefix + "Pair_" + i + "_TF" + (string)t + "_AgeBg";
            ObjectCreate(objNameAgeBg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
            ObjectSet(objNameAgeBg, OBJPROP_BACK, false);
            ObjectSet(objNameAgeBg, OBJPROP_XDISTANCE, ageLeft);
            ObjectSet(objNameAgeBg, OBJPROP_YDISTANCE, ageTop);
            ObjectSet(objNameAgeBg, OBJPROP_XSIZE, ageWidth);
            ObjectSet(objNameAgeBg, OBJPROP_YSIZE, ageHeight);
            ObjectSet(objNameAgeBg, OBJPROP_BGCOLOR, DashboardBgColor);
            ObjectSet(objNameAgeBg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
            ObjectSet(objNameAgeBg, OBJPROP_CORNER, CORNER_LEFT_UPPER);

            string objNameAge = DashboardPrefix + "Pair_" + i + "_TF" + (string)t + "_Age";
            ObjectCreate(objNameAge, OBJ_LABEL, 0, 0, 0);
            ObjectSet(objNameAge, OBJPROP_BACK, false);
            ObjectSet(objNameAge, OBJPROP_XDISTANCE, xPos);
            ObjectSet(objNameAge, OBJPROP_YDISTANCE, ageTop + (ageHeight/2));
            ObjectSet(objNameAge, OBJPROP_ANCHOR, ANCHOR_CENTER);
            // Smaller font for the age text; initial empty
            ObjectSetText(objNameAge, "", MathMax(6, DashboardFontSize - 1), DashboardFont, TableTextColor);
            ObjectSet(objNameAge, OBJPROP_CORNER, CORNER_LEFT_UPPER);
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
                    Alarm("Direction Change: " + Pairs[i] + " " + GetTimeframeString(Timeframes[tf]) + " changed from DOWN to UP");
                }
                else if(currentSignal == -1 && PreviousSignals[signalIndex] == 1)
                {
                    Alarm("Direction Change: " + Pairs[i] + " " + GetTimeframeString(Timeframes[tf]) + " changed from UP to DOWN");
                }
            }

            // Update previous signal
            // If the signal changed, record the timestamp of the change
            int oldSignal = PreviousSignals[signalIndex];
            if(oldSignal != currentSignal)
            {
                PreviousSignalTime[signalIndex] = TimeCurrent();
            }
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
            // Update the age label for this timeframe
            string objNameAge = DashboardPrefix + "Pair_" + i + "_TF" + (string)tf + "_Age";
            string ageText = "";
            if(currentSignal != 0 && PreviousSignalTime[signalIndex] > 0)
            {
                ageText = FormatSignalAge(PreviousSignalTime[signalIndex]);
            }
            else if(currentSignal != 0 && PreviousSignalTime[signalIndex] == 0)
            {
                // If we have a non-zero signal but no recorded time, use a placeholder
                ageText = "<1m";
            }
            ObjectSetText(objNameAge, ageText, MathMax(6, DashboardFontSize - 1), DashboardFont, TableTextColor);
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
//| Format signal age (e.g. "5m", "2h30m")                           |
//+------------------------------------------------------------------+
string FormatSignalAge(datetime when)
{
    int secs = (int)(TimeCurrent() - when);
    if(secs < 60) return "<1m";
    int mins = secs / 60;
    if(mins < 60) return IntegerToString(mins) + "m";
    int hours = mins / 60;
    int remMins = mins % 60;
    if(remMins == 0) return IntegerToString(hours) + "h";
    return IntegerToString(hours) + "h" + IntegerToString(remMins) + "m";
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

