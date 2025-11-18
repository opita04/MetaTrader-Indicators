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
#property version   "3.20"

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
extern color  DashboardBgColor = clrOldLace; // Background Color (TurtleSoup-style)
extern color  HeaderBgColor = clrDeepSkyBlue; // Header Background Color (Blue)
extern color  HeaderTextColor = clrWhite;   // Header Text Color
extern color  TableTextColor = clrBlack;     // Table Text Color
extern color  TableCellBgColor = clrAliceBlue; // Table Cell Background Color
extern color  UpSignalColor = clrBlue;      // Up Signal Color (legacy - used if strength coloring disabled)
extern color  DownSignalColor = clrRed;     // Down Signal Color (legacy - used if strength coloring disabled)
extern color  NeutralColor = clrYellow;     // Neutral Color
extern bool   UseStrengthColoring = true;   // Use strength-based color coding
extern double StrengthHighThreshold = 5.0;  // High strength threshold (difference >= this)
extern double StrengthMediumThreshold = 2.0; // Medium strength threshold (difference >= this)
extern color  UpHighColor = clrGreen;       // Up arrow color for high strength (diff >= 5.0) - Green
extern color  UpMediumColor = clrLimeGreen; // Up arrow color for medium strength (2.0 <= diff < 5.0) - Light Green
extern color  UpLowColor = clrLightBlue;    // Up arrow color for low strength (0.01 <= diff < 2.0) - Light Blue
extern color  DownHighColor = clrRed;       // Down arrow color for high strength (diff >= 5.0)
extern color  DownMediumColor = C'255,165,0'; // Down arrow color for medium strength (2.0 <= diff < 5.0) - Orange
extern color  DownLowColor = C'255,182,193'; // Down arrow color for low strength (0.01 <= diff < 2.0) - Light Pink
extern color  GridLineColor = C'38,38,38';      // Grid line color
extern bool   ShowGridLines = true;         // Show grid lines between cells
extern bool   ShowAgeColumn = true;         // Show Age column for signal timestamps
extern bool   ShowValueColumns = true;      // Show currency strength value columns
extern int    ValueColumnWidth = 70;        // Currency value column width
extern int    RowHeight = 32;               // Grid row height (cell height)
extern int    HeaderHeight = 32;            // Grid header height
extern int    PairColumnWidth = 0;          // Pair column width (0 = auto-size based on content)
extern int    ArrowColumnWidth = 35;        // Arrow column width
extern int    AgeColumnWidth = 50;          // Age column width
extern int    CenterOffset = -4;            // Center position offset (negative = shift left, positive = shift right)

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
extern bool   AlertTF1TF2Alignment = false; // Alert when TF1 and TF2 align (both UP or both DOWN)

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
datetime LastBarTime[]; // Last bar time for each pair and timeframe [pair*4 + tf] - used for candle close detection
bool PreviousTF1TF2Alignment[]; // Previous alignment state for each pair (true = aligned, false = not aligned)
string BotName = "Currency Strength Dashboard"; // Bot name for alerts

//+------------------------------------------------------------------+
//| Helper function to get PreviousSignals index                        |
//+------------------------------------------------------------------+
int GetPreviousSignalIndex(int pairIndex, int timeframeIndex)
{
    return pairIndex * 4 + timeframeIndex;
}

//+------------------------------------------------------------------+
//| Check if a new bar has formed (candle close detection)          |
//+------------------------------------------------------------------+
bool IsNewBar(string symbol, ENUM_TIMEFRAMES timeframe, int signalIndex)
{
    datetime currentBarTime = iTime(symbol, timeframe, 0);
    if(currentBarTime != LastBarTime[signalIndex])
    {
        LastBarTime[signalIndex] = currentBarTime;
        return true; // New bar formed
    }
    return false; // Same bar
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
    // Initialize last bar time array for candle close detection
    ArrayResize(LastBarTime, TotalPairs * 4);
    for(int bi = 0; bi < TotalPairs * 4; bi++)
    {
        LastBarTime[bi] = 0; // Initialize to 0
    }
    // Initialize previous TF1+TF2 alignment array
    ArrayResize(PreviousTF1TF2Alignment, TotalPairs);
    for(int ai = 0; ai < TotalPairs; ai++)
    {
        PreviousTF1TF2Alignment[ai] = false; // Initialize to not aligned
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
    int gridOverlap = 0;
    int tfIdx;

    // Calculate pair column width based on longest pair name (or use fixed width if specified)
    int pairColWidth;
    if(PairColumnWidth > 0)
    {
        pairColWidth = PairColumnWidth; // Use fixed width
    }
    else
    {
        pairColWidth = 60; // Minimum width for auto-sizing
        for(int p = 0; p < TotalPairs; p++)
        {
            int nameWidth = StringLen(Pairs[p]) * 8 + 12;
            if(nameWidth > pairColWidth) pairColWidth = nameWidth;
        }
        // Also check "PAIR" header text
        int pairHeaderWidth = StringLen("PAIR") * 8 + 12;
        if(pairHeaderWidth > pairColWidth) pairColWidth = pairHeaderWidth;
    }
    
    // Arrow column width (use parameter)
    int arrowColWidth = ArrowColumnWidth;
    
    // Age column width (use parameter if ShowAgeColumn is enabled)
    int ageColWidth = ShowAgeColumn ? AgeColumnWidth : 0;
    
    // Value column width (use parameter if ShowValueColumns is enabled)
    int valueColWidth = ShowValueColumns ? ValueColumnWidth : 0;

    // Calculate total columns: 1 (pair) + for each TF: arrow + (age if enabled) + (2 value columns if enabled)
    int columnsPerTF = 1; // Arrow
    if(ShowAgeColumn) columnsPerTF++;
    if(ShowValueColumns) columnsPerTF += 2; // Two value columns (currency1 and currency2)
    
    int totalColumns = 1 + NumTimeframes * columnsPerTF;
    int columnWidths[];
    ArrayResize(columnWidths, totalColumns);
    columnWidths[0] = pairColWidth;
    for(int tf = 0, col = 1; tf < NumTimeframes; tf++)
    {
        columnWidths[col++] = arrowColWidth;
        if(ShowAgeColumn)
        {
            columnWidths[col++] = ageColWidth;
        }
        if(ShowValueColumns)
        {
            columnWidths[col++] = valueColWidth; // Currency 1
            columnWidths[col++] = valueColWidth; // Currency 2
        }
    }

    int columnLeft[];
    ArrayResize(columnLeft, totalColumns);
    columnLeft[0] = DashboardX;
    for(int c = 1; c < totalColumns; c++)
    {
        columnLeft[c] = columnLeft[c - 1] + columnWidths[c - 1] - 1; // Border overlap like TurtleSoup
    }

    int tableWidth = columnLeft[totalColumns - 1] + columnWidths[totalColumns - 1] - DashboardX;
    int headerY = DashboardY + 40;
    int dataStartY = headerY + HeaderHeight - 1; // Border overlap
    int tableHeight = HeaderHeight + (TotalPairs > 0 ? (TotalPairs * (RowHeight - 1)) + 1 : 0);
    int dashboardHeight = (headerY - DashboardY) + tableHeight + 20;

    objName = DashboardPrefix + "Background";
    ObjectCreate(objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    if(FullChartBackground)
    {
        ObjectSet(objName, OBJPROP_XDISTANCE, 0);
        ObjectSet(objName, OBJPROP_YDISTANCE, 0);
        ObjectSet(objName, OBJPROP_XSIZE, 2000);
        ObjectSet(objName, OBJPROP_YSIZE, 1500);
    }
    else
    {
        ObjectSet(objName, OBJPROP_XDISTANCE, DashboardX);
        ObjectSet(objName, OBJPROP_YDISTANCE, DashboardY);
        ObjectSet(objName, OBJPROP_XSIZE, tableWidth);
        ObjectSet(objName, OBJPROP_YSIZE, dashboardHeight);
    }
    ObjectSet(objName, OBJPROP_BGCOLOR, DashboardBgColor);
    ObjectSet(objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSet(objName, OBJPROP_BACK, false);

    objName = DashboardPrefix + "Title";
    ObjectCreate(objName, OBJ_LABEL, 0, 0, 0);
    ObjectSet(objName, OBJPROP_BACK, false);
    ObjectSet(objName, OBJPROP_XDISTANCE, DashboardX + tableWidth / 2);
    ObjectSet(objName, OBJPROP_YDISTANCE, DashboardY + 10);
    ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSet(objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
    ObjectSetText(objName, "Currency Strength Dashboard", DashboardTitleSize, DashboardFont, TableTextColor);

    for(int headerCol = 0; headerCol < totalColumns; headerCol++)
    {
        int headerCellWidth = columnWidths[headerCol];
        int headerCellHeight = HeaderHeight;
        string headerCellBg = DashboardPrefix + "Header_Cell_" + (string)headerCol;
        ObjectCreate(headerCellBg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSet(headerCellBg, OBJPROP_BACK, false);
        ObjectSet(headerCellBg, OBJPROP_XDISTANCE, columnLeft[headerCol]);
        ObjectSet(headerCellBg, OBJPROP_YDISTANCE, headerY);
        ObjectSet(headerCellBg, OBJPROP_XSIZE, headerCellWidth);
        ObjectSet(headerCellBg, OBJPROP_YSIZE, headerCellHeight);
        ObjectSet(headerCellBg, OBJPROP_BGCOLOR, HeaderBgColor);
        ObjectSet(headerCellBg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSet(headerCellBg, OBJPROP_COLOR, GridLineColor);
        ObjectSet(headerCellBg, OBJPROP_WIDTH, 1);
        ObjectSet(headerCellBg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSet(headerCellBg, OBJPROP_SELECTABLE, false);
        ObjectSet(headerCellBg, OBJPROP_HIDDEN, true);

        // Calculate center position exactly like TurtleSoup: Y + H/2
        int headerCenterY = headerY + headerCellHeight / 2;
        if(headerCol == 0)
        {
            objName = DashboardPrefix + "Header_Pair";
            ObjectCreate(objName, OBJ_LABEL, 0, 0, 0);
            ObjectSet(objName, OBJPROP_BACK, false);
            ObjectSet(objName, OBJPROP_XDISTANCE, columnLeft[headerCol] + 6);
            ObjectSet(objName, OBJPROP_YDISTANCE, headerCenterY);
            ObjectSet(objName, OBJPROP_ANCHOR, ANCHOR_LEFT);
            ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetText(objName, "PAIR", DashboardFontSize, DashboardFont, HeaderTextColor);
        }
        else
        {
            // Calculate which timeframe and column type this is
            int colOffset = headerCol - 1; // Skip pair column
            tfIdx = 0;
            int colInTF = 0;
            int colsPerTF = 1; // Arrow
            if(ShowAgeColumn) colsPerTF++;
            if(ShowValueColumns) colsPerTF += 2;
            
            tfIdx = colOffset / colsPerTF;
            colInTF = colOffset % colsPerTF;
            
            if(tfIdx < NumTimeframes)
            {
                if(colInTF == 0)
                {
                    // Arrow column - show timeframe name
                    objName = DashboardPrefix + "Header_TF" + (string)tfIdx;
                    ObjectCreate(objName, OBJ_LABEL, 0, 0, 0);
                    ObjectSet(objName, OBJPROP_BACK, false);
                    ObjectSet(objName, OBJPROP_XDISTANCE, columnLeft[headerCol] + headerCellWidth / 2 + CenterOffset);
                    ObjectSet(objName, OBJPROP_YDISTANCE, headerCenterY);
                    ObjectSet(objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
                    ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
                    ObjectSetText(objName, GetTimeframeString(Timeframes[tfIdx]), DashboardFontSize, DashboardFont, HeaderTextColor);
                }
                else if(colInTF == 1 && ShowAgeColumn)
                {
                    // Age column
                    objName = DashboardPrefix + "Header_TF" + (string)tfIdx + "_Age";
                    ObjectCreate(objName, OBJ_LABEL, 0, 0, 0);
                    ObjectSet(objName, OBJPROP_BACK, false);
                    ObjectSet(objName, OBJPROP_XDISTANCE, columnLeft[headerCol] + headerCellWidth / 2 + CenterOffset);
                    ObjectSet(objName, OBJPROP_YDISTANCE, headerCenterY);
                    ObjectSet(objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
                    ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
                    ObjectSetText(objName, "Age", DashboardFontSize, DashboardFont, HeaderTextColor);
                }
                else if(ShowValueColumns)
                {
                    // Value columns
                    int headerValueColIdx = colInTF;
                    if(ShowAgeColumn) headerValueColIdx--; // Adjust for age column
                    headerValueColIdx -= 1; // Adjust for arrow column
                    
                    if(headerValueColIdx == 0)
                    {
                        // Currency 1 value column
                        objName = DashboardPrefix + "Header_TF" + (string)tfIdx + "_Val1";
                        ObjectCreate(objName, OBJ_LABEL, 0, 0, 0);
                        ObjectSet(objName, OBJPROP_BACK, false);
                        ObjectSet(objName, OBJPROP_XDISTANCE, columnLeft[headerCol] + headerCellWidth / 2 + CenterOffset);
                        ObjectSet(objName, OBJPROP_YDISTANCE, headerCenterY);
                        ObjectSet(objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
                        ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
                        ObjectSetText(objName, "C1", DashboardFontSize, DashboardFont, HeaderTextColor);
                    }
                    else if(headerValueColIdx == 1)
                    {
                        // Currency 2 value column
                        objName = DashboardPrefix + "Header_TF" + (string)tfIdx + "_Val2";
                        ObjectCreate(objName, OBJ_LABEL, 0, 0, 0);
                        ObjectSet(objName, OBJPROP_BACK, false);
                        ObjectSet(objName, OBJPROP_XDISTANCE, columnLeft[headerCol] + headerCellWidth / 2 + CenterOffset);
                        ObjectSet(objName, OBJPROP_YDISTANCE, headerCenterY);
                        ObjectSet(objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
                        ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
                        ObjectSetText(objName, "C2", DashboardFontSize, DashboardFont, HeaderTextColor);
                    }
                }
            }
        }
    }

    int rowY = dataStartY;
    for(int rowIndex = 0; rowIndex < TotalPairs; rowIndex++)
    {
        for(int dataCol = 0; dataCol < totalColumns; dataCol++)
        {
            int dataCellWidth = columnWidths[dataCol];
            int dataCellHeight = RowHeight;
            string dataCellBg = DashboardPrefix + "Cell_" + (string)rowIndex + "_" + (string)dataCol + "_Bg";
            ObjectCreate(dataCellBg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
            ObjectSet(dataCellBg, OBJPROP_BACK, false);
            ObjectSet(dataCellBg, OBJPROP_XDISTANCE, columnLeft[dataCol]);
            ObjectSet(dataCellBg, OBJPROP_YDISTANCE, rowY);
            ObjectSet(dataCellBg, OBJPROP_XSIZE, dataCellWidth);
            ObjectSet(dataCellBg, OBJPROP_YSIZE, dataCellHeight);
            ObjectSet(dataCellBg, OBJPROP_BGCOLOR, TableCellBgColor);
            ObjectSet(dataCellBg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
            ObjectSet(dataCellBg, OBJPROP_COLOR, GridLineColor);
            ObjectSet(dataCellBg, OBJPROP_WIDTH, 1);
            ObjectSet(dataCellBg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSet(dataCellBg, OBJPROP_SELECTABLE, false);
            ObjectSet(dataCellBg, OBJPROP_HIDDEN, true);

            // Calculate center position exactly like TurtleSoup: X + W/2
            int cellX = columnLeft[dataCol];
            int centerX = cellX + dataCellWidth / 2 + (dataCol > 0 ? CenterOffset : 0); // Apply offset only to centered columns (not pair column)
            int centerY = rowY + dataCellHeight / 2;
            if(dataCol == 0)
            {
                objName = DashboardPrefix + "Pair_" + (string)rowIndex + "_Name";
                ObjectCreate(objName, OBJ_LABEL, 0, 0, 0);
                ObjectSet(objName, OBJPROP_BACK, false);
                ObjectSet(objName, OBJPROP_XDISTANCE, columnLeft[dataCol] + 6);
                ObjectSet(objName, OBJPROP_YDISTANCE, centerY);
                ObjectSet(objName, OBJPROP_ANCHOR, ANCHOR_LEFT);
                ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
                ObjectSetText(objName, Pairs[rowIndex], DashboardFontSize, DashboardFont, TableTextColor);
            }
            else
            {
                // Calculate which timeframe and column type this is
                int dataColOffset = dataCol - 1; // Skip pair column
                int dataTfIdx = 0;
                int dataColInTF = 0;
                int dataColsPerTF = 1; // Arrow
                if(ShowAgeColumn) dataColsPerTF++;
                if(ShowValueColumns) dataColsPerTF += 2;
                
                dataTfIdx = dataColOffset / dataColsPerTF;
                dataColInTF = dataColOffset % dataColsPerTF;
                
                if(dataTfIdx < NumTimeframes)
                {
                    if(dataColInTF == 0)
                    {
                        // Arrow column
                        objName = DashboardPrefix + "Pair_" + (string)rowIndex + "_TF" + (string)dataTfIdx;
                        ObjectCreate(objName, OBJ_LABEL, 0, 0, 0);
                        ObjectSet(objName, OBJPROP_BACK, false);
                        ObjectSet(objName, OBJPROP_XDISTANCE, centerX);
                        ObjectSet(objName, OBJPROP_YDISTANCE, centerY);
                        ObjectSet(objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
                        ObjectSet(objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
                        ObjectSetText(objName, CharToString(232), DashboardFontSize + 2, "Wingdings", NeutralColor);
                        ObjectSet(objName, OBJPROP_SELECTABLE, true);
                        ObjectSet(objName, OBJPROP_SELECTED, false);
                    }
                    else if(dataColInTF == 1 && ShowAgeColumn)
                    {
                        // Age column
                        string ageName = DashboardPrefix + "Pair_" + (string)rowIndex + "_TF" + (string)dataTfIdx + "_Age";
                        ObjectCreate(ageName, OBJ_LABEL, 0, 0, 0);
                        ObjectSet(ageName, OBJPROP_BACK, false);
                        ObjectSet(ageName, OBJPROP_XDISTANCE, centerX);
                        ObjectSet(ageName, OBJPROP_YDISTANCE, centerY);
                        ObjectSet(ageName, OBJPROP_ANCHOR, ANCHOR_CENTER);
                        ObjectSet(ageName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
                        ObjectSet(ageName, OBJPROP_SELECTABLE, false);
                        ObjectSetText(ageName, "", MathMax(8, DashboardFontSize - 1), DashboardFont, TableTextColor);
                    }
                    else if(ShowValueColumns)
                    {
                        // Value columns
                        int dataValueColIdx = dataColInTF;
                        if(ShowAgeColumn) dataValueColIdx--; // Adjust for age column
                        dataValueColIdx -= 1; // Adjust for arrow column
                        
                        if(dataValueColIdx == 0)
                        {
                            // Currency 1 value column
                            string val1Name = DashboardPrefix + "Pair_" + (string)rowIndex + "_TF" + (string)dataTfIdx + "_Val1";
                            ObjectCreate(val1Name, OBJ_LABEL, 0, 0, 0);
                            ObjectSet(val1Name, OBJPROP_BACK, false);
                            ObjectSet(val1Name, OBJPROP_XDISTANCE, centerX);
                            ObjectSet(val1Name, OBJPROP_YDISTANCE, centerY);
                            ObjectSet(val1Name, OBJPROP_ANCHOR, ANCHOR_CENTER);
                            ObjectSet(val1Name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
                            ObjectSet(val1Name, OBJPROP_SELECTABLE, false);
                            ObjectSetText(val1Name, "", MathMax(8, DashboardFontSize - 1), DashboardFont, TableTextColor);
                        }
                        else if(dataValueColIdx == 1)
                        {
                            // Currency 2 value column
                            string val2Name = DashboardPrefix + "Pair_" + (string)rowIndex + "_TF" + (string)dataTfIdx + "_Val2";
                            ObjectCreate(val2Name, OBJ_LABEL, 0, 0, 0);
                            ObjectSet(val2Name, OBJPROP_BACK, false);
                            ObjectSet(val2Name, OBJPROP_XDISTANCE, centerX);
                            ObjectSet(val2Name, OBJPROP_YDISTANCE, centerY);
                            ObjectSet(val2Name, OBJPROP_ANCHOR, ANCHOR_CENTER);
                            ObjectSet(val2Name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
                            ObjectSet(val2Name, OBJPROP_SELECTABLE, false);
                            ObjectSetText(val2Name, "", MathMax(8, DashboardFontSize - 1), DashboardFont, TableTextColor);
                        }
                    }
                }
            }
        }
        rowY += RowHeight - 1; // Border overlap like TurtleSoup
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
        bool newBarTF1 = false;
        bool newBarTF2 = false;
        int signalTF1 = 0;
        int signalTF2 = 0;
        
        // Update each timeframe
        for(int tf = 0; tf < NumTimeframes; tf++)
        {
            // Get current signal
            currentSignal = GetCrossoverSignal(Pairs[i], Timeframes[tf]);
            
            // Get strength difference for color coding
            double strengthDiff = GetStrengthDifference(Pairs[i], Timeframes[tf]);

            // Get signal index for this pair/timeframe
            int signalIndex = GetPreviousSignalIndex(i, tf);
            
            // Check if a new bar has formed (candle close)
            bool newBar = IsNewBar(Pairs[i], Timeframes[tf], signalIndex);
            
            // Store new bar status and signals for TF1 and TF2 (for alignment check)
            if(tf == 0)
            {
                newBarTF1 = newBar;
                signalTF1 = currentSignal;
            }
            else if(tf == 1)
            {
                newBarTF2 = newBar;
                signalTF2 = currentSignal;
            }

            // Check for direction change and alert if enabled (only on candle close)
            if(newBar && AlertEnabled[tf] && PreviousSignals[signalIndex] != 0 && PreviousSignals[signalIndex] != currentSignal)
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

            // Determine arrow and color based on signal and strength difference
            if(currentSignal == 1)
            {
                signalText = CharToString(233); // Up arrow in Wingdings
                signalColor = GetSignalColor(currentSignal, strengthDiff);
            }
            else if(currentSignal == -1)
            {
                signalText = CharToString(234); // Down arrow in Wingdings
                signalColor = GetSignalColor(currentSignal, strengthDiff);
            }
            else
            {
                signalText = CharToString(232); // Right arrow in Wingdings (neutral)
                signalColor = GetSignalColor(currentSignal, strengthDiff);
            }

            // Update display - recalculate centerY and centerX to ensure consistent alignment
            int headerY = DashboardY + 40;
            int dataStartY = headerY + HeaderHeight - 1;
            int centerY = dataStartY + i * (RowHeight - 1) + RowHeight / 2;
            
            // Calculate arrow column position (matching CreateDashboard logic)
            int pairColWidth;
            if(PairColumnWidth > 0)
            {
                pairColWidth = PairColumnWidth;
            }
            else
            {
                pairColWidth = 60;
                for(int p = 0; p < TotalPairs; p++)
                {
                    int nameWidth = StringLen(Pairs[p]) * 8 + 12;
                    if(nameWidth > pairColWidth) pairColWidth = nameWidth;
                }
                int pairHeaderWidth = StringLen("PAIR") * 8 + 12;
                if(pairHeaderWidth > pairColWidth) pairColWidth = pairHeaderWidth;
            }
            
            // Calculate arrow column left position
            int arrowColLeft = DashboardX + pairColWidth - 1; // Start after pair column with border overlap
            for(int t = 0; t < tf; t++)
            {
                arrowColLeft += ArrowColumnWidth - 1; // Add arrow column width with border overlap
                if(ShowAgeColumn) arrowColLeft += AgeColumnWidth - 1; // Add age column width with border overlap
                if(ShowValueColumns) arrowColLeft += (ValueColumnWidth - 1) * 2; // Add two value column widths with border overlap
            }
            int arrowCenterX = arrowColLeft + ArrowColumnWidth / 2 + CenterOffset;
            
            objName = DashboardPrefix + "Pair_" + i + "_TF" + (string)tf;
            ObjectSet(objName, OBJPROP_XDISTANCE, arrowCenterX);
            ObjectSet(objName, OBJPROP_YDISTANCE, centerY);
			ObjectSetText(objName, signalText, DashboardFontSize + 2, "Wingdings", signalColor);
            // Update the age label for this timeframe (only if ShowAgeColumn is enabled)
            int currentColLeft = arrowColLeft + ArrowColumnWidth - 1;
            if(ShowAgeColumn)
            {
                int ageColLeft = currentColLeft;
                int ageCenterX = ageColLeft + AgeColumnWidth / 2 + CenterOffset;
                string objNameAge = DashboardPrefix + "Pair_" + i + "_TF" + (string)tf + "_Age";
                ObjectSet(objNameAge, OBJPROP_XDISTANCE, ageCenterX);
                ObjectSet(objNameAge, OBJPROP_YDISTANCE, centerY);
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
                ObjectSetText(objNameAge, ageText, MathMax(8, DashboardFontSize - 1), DashboardFont, TableTextColor);
                currentColLeft += AgeColumnWidth - 1; // Move to next column
            }
            
            // Update the currency value labels for this timeframe (only if ShowValueColumns is enabled)
            if(ShowValueColumns)
            {
                string objNameVal1 = DashboardPrefix + "Pair_" + i + "_TF" + (string)tf + "_Val1";
                string objNameVal2 = DashboardPrefix + "Pair_" + i + "_TF" + (string)tf + "_Val2";
                double value1, value2;
                if(GetCurrencyValues(Pairs[i], Timeframes[tf], value1, value2))
                {
                    // Parse pair name to get currency names
                    string currency1, currency2;
                    ParsePairName(Pairs[i], currency1, currency2);
                    
                    // Currency 1 value column
                    int val1ColLeft = currentColLeft;
                    int val1CenterX = val1ColLeft + ValueColumnWidth / 2 + CenterOffset;
                    ObjectSet(objNameVal1, OBJPROP_XDISTANCE, val1CenterX);
                    ObjectSet(objNameVal1, OBJPROP_YDISTANCE, centerY);
                    ObjectSet(objNameVal1, OBJPROP_ANCHOR, ANCHOR_CENTER);
                    string val1Text = currency1 + "=" + DoubleToString(value1, 2);
                    ObjectSetText(objNameVal1, val1Text, MathMax(8, DashboardFontSize - 1), DashboardFont, TableTextColor);
                    
                    // Currency 2 value column
                    int val2ColLeft = val1ColLeft + ValueColumnWidth - 1;
                    int val2CenterX = val2ColLeft + ValueColumnWidth / 2 + CenterOffset;
                    ObjectSet(objNameVal2, OBJPROP_XDISTANCE, val2CenterX);
                    ObjectSet(objNameVal2, OBJPROP_YDISTANCE, centerY);
                    ObjectSet(objNameVal2, OBJPROP_ANCHOR, ANCHOR_CENTER);
                    string val2Text = currency2 + "=" + DoubleToString(value2, 2);
                    ObjectSetText(objNameVal2, val2Text, MathMax(8, DashboardFontSize - 1), DashboardFont, TableTextColor);
                }
                else
                {
                    // No values available - clear the labels
                    ObjectSetText(objNameVal1, "", MathMax(8, DashboardFontSize - 1), DashboardFont, TableTextColor);
                    ObjectSetText(objNameVal2, "", MathMax(8, DashboardFontSize - 1), DashboardFont, TableTextColor);
                }
            }
        }

        // Check for TF1+TF2 alignment alert (only on candle close)
        if(AlertTF1TF2Alignment && NumTimeframes >= 2)
        {
            // Only check alignment on candle close (when either TF1 or TF2 has a new bar)
            if(newBarTF1 || newBarTF2)
            {
                // Check if TF1 and TF2 are aligned (both UP or both DOWN, and not neutral)
                bool isAligned = (signalTF1 == 1 && signalTF2 == 1) || (signalTF1 == -1 && signalTF2 == -1);

                // Alert when alignment occurs (transition from not aligned to aligned)
                if(isAligned && !PreviousTF1TF2Alignment[i])
                {
                    string direction = (signalTF1 == 1) ? "UP" : "DOWN";
                    Alarm("TF1+TF2 Alignment: " + Pairs[i] + " - " + GetTimeframeString(Timeframes[0]) + 
                          " and " + GetTimeframeString(Timeframes[1]) + " both aligned " + direction);
                }

                // Update previous alignment state
                PreviousTF1TF2Alignment[i] = isAligned;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get Currency Strength Values for Specified Symbol and Timeframe |
//+------------------------------------------------------------------+
bool GetCurrencyValues(string symbol, ENUM_TIMEFRAMES timeframe, double &value1, double &value2)
{
    string indicatorPath;
    
    // First try standard location
    indicatorPath = IndicatorName;
    value1 = iCustom(symbol, timeframe, indicatorPath, Line1Buffer, 0);
    value2 = iCustom(symbol, timeframe, indicatorPath, Line2Buffer, 0);

    // If not found (all values are EMPTY_VALUE), try subfolder
    if(value1 == EMPTY_VALUE && value2 == EMPTY_VALUE)
    {
        indicatorPath = "Millionaire Maker\\" + IndicatorName;
        value1 = iCustom(symbol, timeframe, indicatorPath, Line1Buffer, 0);
        value2 = iCustom(symbol, timeframe, indicatorPath, Line2Buffer, 0);
    }

    // If still not found, return false
    if(value1 == EMPTY_VALUE || value2 == EMPTY_VALUE)
    {
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Parse Pair Name to Extract Two Currencies                        |
//+------------------------------------------------------------------+
void ParsePairName(string pair, string &currency1, string &currency2)
{
    // For standard pairs like EURUSD, GBPUSD, USDJPY (6 characters)
    if(StringLen(pair) == 6)
    {
        currency1 = StringSubstr(pair, 0, 3);
        currency2 = StringSubstr(pair, 3, 3);
    }
    // For pairs with 7 characters (rare, but possible)
    else if(StringLen(pair) == 7)
    {
        // Try to find common 3-letter currencies
        string commonCurrencies[] = {"USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "NZD", "XAU", "XAG"};
        bool found = false;
        for(int i = 0; i < ArraySize(commonCurrencies); i++)
        {
            int pos = StringFind(pair, commonCurrencies[i]);
            if(pos == 0)
            {
                currency1 = commonCurrencies[i];
                currency2 = StringSubstr(pair, StringLen(commonCurrencies[i]));
                found = true;
                break;
            }
            else if(pos > 0 && pos + StringLen(commonCurrencies[i]) == StringLen(pair))
            {
                currency1 = StringSubstr(pair, 0, pos);
                currency2 = commonCurrencies[i];
                found = true;
                break;
            }
        }
        if(!found)
        {
            // Default: first 3 and last 3
            currency1 = StringSubstr(pair, 0, 3);
            currency2 = StringSubstr(pair, 4, 3);
        }
    }
    else
    {
        // Default: first 3 and last 3
        currency1 = StringSubstr(pair, 0, 3);
        currency2 = StringSubstr(pair, StringLen(pair) - 3, 3);
    }
}

//+------------------------------------------------------------------+
//| Get Strength Difference for Specified Symbol and Timeframe      |
//+------------------------------------------------------------------+
double GetStrengthDifference(string symbol, ENUM_TIMEFRAMES timeframe)
{
    double value1, value2;
    if(GetCurrencyValues(symbol, timeframe, value1, value2))
    {
        return MathAbs(value1 - value2);
    }
    return 0.0;
}

//+------------------------------------------------------------------+
//| Get Color Based on Signal Direction and Strength Difference     |
//+------------------------------------------------------------------+
color GetSignalColor(int signal, double strengthDiff)
{
    // If strength coloring is disabled, use legacy colors
    if(!UseStrengthColoring)
    {
        if(signal == 1)
            return UpSignalColor;
        else if(signal == -1)
            return DownSignalColor;
        else
            return NeutralColor;
    }

    // For neutral signals, always use neutral color
    if(signal == 0)
        return NeutralColor;

    // Determine color based on signal direction and strength difference
    if(signal == 1) // Up signal
    {
        if(strengthDiff >= StrengthHighThreshold)
            return UpHighColor;
        else if(strengthDiff >= StrengthMediumThreshold)
            return UpMediumColor;
        else if(strengthDiff >= 0.01)
            return UpLowColor;
        else
            return UpLowColor; // Very small difference, use low color
    }
    else // Down signal (signal == -1)
    {
        if(strengthDiff >= StrengthHighThreshold)
            return DownHighColor;
        else if(strengthDiff >= StrengthMediumThreshold)
            return DownMediumColor;
        else if(strengthDiff >= 0.01)
            return DownLowColor;
        else
            return DownLowColor; // Very small difference, use low color
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

