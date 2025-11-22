//+------------------------------------------------------------------+
//|                                        Apollo Signal List.mq4    |
//|                                                                  |
//|  Monitors Apollo Smart Level Trader signals and displays them  |
//|  in a list format with timestamps and alerts                     |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

//--- Input parameters
//=== Display Settings ===
input string s1 = "===== Display Settings =====";
input int    MaxSignalsToShow = 20;        // Maximum signals to display in list
input int    ListXPosition = 20;            // X position of list (pixels from left)
input int    ListYPosition = 50;            // Y position of list (pixels from top)
input int    FontSize = 9;                 // Font size for signal list
input color  BuyColor = clrAqua;            // Color for Buy signals
input color  SellColor = clrMagenta;        // Color for Sell signals
input color  OtherColor = clrYellow;        // Color for other signals
input color  BackgroundColor = clrBlack;    // Background color for list

//=== Alert Settings ===
input string s2 = "===== Alert Settings =====";
input bool   EnableAlerts = true;          // Enable alerts for new signals
input bool   EnableSound = false;           // Enable sound alerts
input bool   EnableEmail = false;          // Enable email alerts
input bool   EnablePush = false;           // Enable push notifications

//=== Arrow Settings ===
input string s3 = "===== Arrow Settings =====";
input bool   ShowArrows = true;            // Show arrows on chart for signals
input bool   ArrowsOnlyAfterBarClose = true; // Only create arrows after bar closes (prevents repainting)
input int    BuyArrowCode = 233;          // Arrow code for Buy signals (233=up arrow)
input int    SellArrowCode = 234;         // Arrow code for Sell signals (234=down arrow)
input int    OtherArrowCode = 159;        // Arrow code for other signals (159=diamond)
input int    ArrowSize = 2;               // Arrow size for Buy/Sell signals
input int    OtherArrowSize = 4;          // Arrow size for other signals (larger)
input double ArrowGap = 0.0001;           // Arrow gap from price (in points, not percentage)

//=== Repaint Detection ===
input string s4 = "===== Repaint Detection =====";
input bool   CheckRepaint = true;         // Check if signals repaint (disappear after bar closes)

//=== Copy to Other Chart ===
input string s5 = "===== Copy to Other Chart =====";
input bool   CopyArrowsToOtherChart = true; // Copy arrows to all charts with same symbol/timeframe
input string TargetSymbol = "";           // Target symbol (empty = same symbol as current chart)
input int    TargetTimeframe = 0;         // Target timeframe (0 = same timeframe, 1=M1, 5=M5, etc.)

//=== Apollo Line Refresher ===
input string s6 = "===== Apollo Line Refresher =====";
input bool   EnableLineRefresher = false;  // Enable Apollo line refreshing
input int    RefreshIntervalSeconds = 180;  // Refresh interval in seconds
input bool   EnableLogging = false;      // Enable debug logging for line refresher

//--- Signal structure
struct SignalInfo
{
   datetime time;
   string   signal;
   string   objectName;
   double   price;
   int      barIndex;        // Bar index when signal was detected
   bool     isRepainted;     // True if signal disappeared after bar closed
   bool     isConfirmed;     // True if signal still exists after bar closed
   bool     arrowCreated;    // True if arrow has been created (prevents deletion)
};

//--- Global variables
SignalInfo Signals[];
string      objPrefix = "ApolloSignalList_";
int         lastObjectCount = 0;
int         signalCount = 0;
datetime    lastBarTime = 0;
datetime    lastRefreshTime = 0;  // For Apollo Line Refresher

//--- Apollo signal descriptions to monitor
string ApolloSignals[] = {"Buy", "Sell", "Shooting Star", "Downtrend", 
                          "Reversal", "Downward", "Close all long", "UP-Trend"};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Apollo Signal List initialized");
   ArrayResize(Signals, 0);
   lastObjectCount = ObjectsTotal();
   lastRefreshTime = TimeCurrent();
   
   // Set up timer for line refresher if enabled
   if(EnableLineRefresher)
   {
      EventSetTimer(RefreshIntervalSeconds);
      Print("Apollo Line Refresher enabled. Refresh interval: ", RefreshIntervalSeconds, " seconds");
   }
   
   // Create background panel
   CreateBackgroundPanel();
   
   // Scan for existing signals
   ScanForApolloSignals();
   UpdateDisplay();
   
   // Draw arrows for existing signals if enabled
   // Only create arrows for confirmed signals (or all if ArrowsOnlyAfterBarClose is false)
   if(ShowArrows)
   {
      for(int i = 0; i < ArraySize(Signals); i++)
      {
         // Only create arrow if:
         // 1. ArrowsOnlyAfterBarClose is false (create immediately), OR
         // 2. Signal is confirmed (bar closed and signal still exists)
         if(!ArrowsOnlyAfterBarClose || Signals[i].isConfirmed)
         {
            DrawArrow(Signals[i].signal, Signals[i].time, Signals[i].price);
            Signals[i].arrowCreated = true;
         }
      }
      
      // Copy all arrows to other chart if enabled
      if(CopyArrowsToOtherChart)
         CopyAllArrowsToOtherChart();
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Kill timer if it was set
   EventKillTimer();
   
   // Delete all objects created by this indicator
   ObjectsDeleteAll(0, objPrefix);
   Print("Apollo Signal List deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar (bar closed)
   datetime currentBarTime = iTime(Symbol(), Period(), 0);
   if(currentBarTime != lastBarTime && lastBarTime != 0)
   {
      // New bar formed - check for repaints
      if(CheckRepaint)
         CheckForRepaints();
      lastBarTime = currentBarTime;
   }
   else if(lastBarTime == 0)
   {
      lastBarTime = currentBarTime;
   }
   
   // Check for new signals frequently to catch them before deletion
   int currentObjectCount = ObjectsTotal();
   
   // Check if object count changed (new objects appeared)
   if(currentObjectCount != lastObjectCount)
   {
      ScanForApolloSignals();
      lastObjectCount = currentObjectCount;
   }
   // Also check periodically (every 100ms equivalent - every 10 ticks on fast markets)
   static int tickCounter = 0;
   tickCounter++;
   if(tickCounter >= 10)
   {
      ScanForApolloSignals();
      tickCounter = 0;
   }
   
   // Check if it's time to refresh Apollo lines
   if(EnableLineRefresher)
   {
      datetime currentTime = TimeCurrent();
      if(currentTime - lastRefreshTime >= RefreshIntervalSeconds)
      {
         RefreshApolloLines();
         lastRefreshTime = currentTime;
      }
   }
}

//+------------------------------------------------------------------+
//| Check for repaints - signals that disappeared after bar closed  |
//+------------------------------------------------------------------+
void CheckForRepaints()
{
   for(int i = 0; i < ArraySize(Signals); i++)
   {
      // Only check signals that haven't been confirmed or marked as repainted yet
      if(!Signals[i].isConfirmed && !Signals[i].isRepainted)
      {
         // Check if the bar has closed (bar index is now > 0, meaning it's historical)
         int currentBarIndex = iBarShift(Symbol(), Period(), Signals[i].time);
         
         // If bar is now historical (index > 0), check if signal object still exists
         if(currentBarIndex > 0)
         {
            // Try to find the original object
            bool objectExists = false;
            int totalObjects = ObjectsTotal();
            
            for(int j = 0; j < totalObjects; j++)
            {
               string objName = ObjectName(0, j);
               if(objName == Signals[i].objectName)
               {
                  // Check if it still has the same signal text
                  string currentText = ObjectGetString(0, objName, OBJPROP_TEXT);
                  if(currentText == Signals[i].signal)
                  {
                     objectExists = true;
                     break;
                  }
               }
            }
            
            // If object doesn't exist anymore, it repainted
            if(!objectExists)
            {
               Signals[i].isRepainted = true;
               Print("REPAINT DETECTED: Signal '", Signals[i].signal, "' at ", 
                     TimeToString(Signals[i].time), " disappeared after bar closed!");
               
               // Don't create arrow for repainted signals if ArrowsOnlyAfterBarClose is true
               // But if arrow was already created, keep it (just mark as repainted)
               if(ShowArrows)
               {
                  if(Signals[i].arrowCreated)
                  {
                     // Arrow already exists - just update its appearance
                     UpdateArrowForRepaint(Signals[i].time, Signals[i].price, true);
                  }
                  // If arrow wasn't created yet and ArrowsOnlyAfterBarClose is true, don't create it
               }
               
               // Update display
               UpdateDisplay();
            }
            else
            {
               // Signal still exists - it's confirmed
               Signals[i].isConfirmed = true;
               Print("Signal CONFIRMED: '", Signals[i].signal, "' at ", 
                     TimeToString(Signals[i].time), " still exists after bar closed.");
               
               // Create arrow now if it wasn't created yet and ArrowsOnlyAfterBarClose is true
               if(ShowArrows && !Signals[i].arrowCreated)
               {
                  if(ArrowsOnlyAfterBarClose)
                  {
                     // Create arrow after bar confirmation (prevents repainting)
                     DrawArrow(Signals[i].signal, Signals[i].time, Signals[i].price);
                     Signals[i].arrowCreated = true;
                     
                     // Copy arrow to other chart if enabled
                     if(CopyArrowsToOtherChart)
                        CopyArrowToOtherChart(Signals[i].signal, Signals[i].time, Signals[i].price);
                  }
                  else
                  {
                     // Should have been created already, but create it now just in case
                     DrawArrow(Signals[i].signal, Signals[i].time, Signals[i].price);
                     Signals[i].arrowCreated = true;
                  }
               }
               else if(ShowArrows && Signals[i].arrowCreated)
               {
                  // Arrow already exists - just update its appearance
                  UpdateArrowForRepaint(Signals[i].time, Signals[i].price, false);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update arrow appearance for repaint status                       |
//+------------------------------------------------------------------+
void UpdateArrowForRepaint(datetime signalTime, double price, bool isRepainted)
{
   string arrowName = objPrefix + "Arrow_" + TimeToString(signalTime, TIME_DATE|TIME_SECONDS) + "_" + DoubleToString(price, Digits);
   
   if(ObjectFind(0, arrowName) >= 0)
   {
      if(isRepainted)
      {
         // Change arrow to gray/dimmed color to indicate repaint
         ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrGray);
         ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 1); // Make it smaller
      }
      else
      {
         // Keep original color but maybe make it brighter
         // The color was already set when arrow was created
      }
   }
}

//+------------------------------------------------------------------+
//| Check if text object has Apollo description                      |
//+------------------------------------------------------------------+
bool IsApolloTextObject(string objName)
{
   string description = ObjectGetString(0, objName, OBJPROP_TEXT);
   
   for(int i = 0; i < ArraySize(ApolloSignals); i++)
   {
      if(description == ApolloSignals[i])
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if signal already exists in our list                       |
//+------------------------------------------------------------------+
bool SignalExists(string signalText, datetime signalTime, double price)
{
   // Check by signal text + time + price (more reliable than object name)
   for(int i = 0; i < ArraySize(Signals); i++)
   {
      if(Signals[i].signal == signalText && 
         Signals[i].time == signalTime &&
         MathAbs(Signals[i].price - price) < Point * 10)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Scan chart for Apollo text objects                              |
//+------------------------------------------------------------------+
void ScanForApolloSignals()
{
   int totalObjects = ObjectsTotal();
   bool newSignalFound = false;
   
   // Scan backwards to catch newest objects first
   for(int i = totalObjects - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i);
      
      // Skip our own objects
      if(StringFind(objName, objPrefix) == 0)
         continue;
      
      int objType = (int)ObjectGetInteger(0, objName, OBJPROP_TYPE);
      
      // Check if it's a text object with Apollo description
      if(objType == OBJ_TEXT)
      {
         string signalText = ObjectGetString(0, objName, OBJPROP_TEXT);
         
         if(IsApolloTextObject(objName))
         {
            // Get signal time (use object's time or current bar time)
            datetime signalTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
            if(signalTime == 0)
               signalTime = iTime(Symbol(), Period(), 0);
            
            // Get price level
            double price = ObjectGetDouble(0, objName, OBJPROP_PRICE, 0);
            if(price == 0)
               price = iClose(Symbol(), Period(), 0);
            
            // Check if this is a new signal (by text + time + price, not object name)
            if(!SignalExists(signalText, signalTime, price))
            {
               // Add to signals array immediately
               int newSize = ArraySize(Signals) + 1;
               ArrayResize(Signals, newSize);
               
               Signals[newSize - 1].time = signalTime;
               Signals[newSize - 1].signal = signalText;
               Signals[newSize - 1].objectName = objName;
               Signals[newSize - 1].price = price;
               Signals[newSize - 1].barIndex = iBarShift(Symbol(), Period(), signalTime);
               Signals[newSize - 1].isRepainted = false;
               Signals[newSize - 1].isConfirmed = false;
               Signals[newSize - 1].arrowCreated = false;
               
               signalCount++;
               newSignalFound = true;
               
               // Send alert immediately
               if(EnableAlerts)
                  SendAlert(signalText, signalTime);
               
               // Draw arrow on chart if enabled
               // Only create arrow immediately if ArrowsOnlyAfterBarClose is false
               if(ShowArrows && !ArrowsOnlyAfterBarClose)
               {
                  DrawArrow(signalText, signalTime, price);
                  Signals[newSize - 1].arrowCreated = true;
                  
                  // Copy arrow to other chart if enabled
                  if(CopyArrowsToOtherChart)
                     CopyArrowToOtherChart(signalText, signalTime, price);
               }
               
               Print("New Apollo signal detected: ", signalText, " at ", TimeToString(signalTime), " Price: ", DoubleToString(price, Digits));
               
               // Update display immediately for this signal
               SortSignalsByTime();
               UpdateDisplay();
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Sort signals by time (newest first)                             |
//+------------------------------------------------------------------+
void SortSignalsByTime()
{
   int size = ArraySize(Signals);
   for(int i = 0; i < size - 1; i++)
   {
      for(int j = i + 1; j < size; j++)
      {
         if(Signals[i].time < Signals[j].time)
         {
            SignalInfo temp = Signals[i];
            Signals[i] = Signals[j];
            Signals[j] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Send alert for new signal                                       |
//+------------------------------------------------------------------+
void SendAlert(string signal, datetime signalTime)
{
   string message = StringConcatenate("Apollo Signal: ", signal, " at ", TimeToString(signalTime));
   
   if(EnableSound)
      Alert(message);
   else
      Print(message);
   
   if(EnableEmail)
      SendMail("Apollo Signal Alert", message);
   
   if(EnablePush)
      SendNotification(message);
}

//+------------------------------------------------------------------+
//| Draw arrow on chart for signal                                  |
//+------------------------------------------------------------------+
void DrawArrow(string signalText, datetime signalTime, double price)
{
   // Determine arrow code, color, and size based on signal type
   int arrowCode = OtherArrowCode;
   color arrowColor = OtherColor;
   int arrowSize = OtherArrowSize;
   double arrowPrice = price;
   
   if(signalText == "Buy" || signalText == "UP-Trend")
   {
      arrowCode = BuyArrowCode;
      arrowColor = BuyColor;
      arrowSize = ArrowSize;
      // Up arrow - add gap above price
      arrowPrice = price + ArrowGap;
   }
   else if(signalText == "Sell" || signalText == "Downtrend" || 
           signalText == "Downward" || signalText == "Close all long")
   {
      arrowCode = SellArrowCode;
      arrowColor = SellColor;
      arrowSize = ArrowSize;
      // Down arrow - subtract gap below price
      arrowPrice = price - ArrowGap;
   }
   else
   {
      // Other signals - use center price (no gap adjustment)
      arrowPrice = price;
   }
   
   // Create unique arrow object name
   string arrowName = objPrefix + "Arrow_" + TimeToString(signalTime, TIME_DATE|TIME_SECONDS) + "_" + DoubleToString(price, Digits);
   
   // Check if arrow already exists
   if(ObjectFind(0, arrowName) >= 0)
      return;
   
   // Create arrow object
   if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, signalTime, arrowPrice))
   {
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, arrowColor);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, arrowSize);
      ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
      ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, arrowName, OBJPROP_TEXT, signalText);
   }
}

//+------------------------------------------------------------------+
//| Copy arrow to all charts with matching symbol and timeframe      |
//+------------------------------------------------------------------+
void CopyArrowToOtherChart(string signalText, datetime signalTime, double price)
{
   if(!CopyArrowsToOtherChart)
      return;
   
   // Source arrow name
   string sourceArrowName = objPrefix + "Arrow_" + TimeToString(signalTime, TIME_DATE|TIME_SECONDS) + "_" + DoubleToString(price, Digits);
   
   // Check if source arrow exists - if not, try to create it first or use signal data directly
   bool arrowExists = (ObjectFind(0, sourceArrowName) >= 0);
   
   // Determine target symbol and timeframe
   string targetSym = (TargetSymbol == "") ? Symbol() : TargetSymbol;
   int targetTF = (TargetTimeframe == 0) ? (int)Period() : TargetTimeframe;
   
   // Get source arrow properties (or determine from signal if arrow doesn't exist yet)
   int sourceArrowCode = OtherArrowCode;
   color sourceArrowColor = OtherColor;
   int sourceArrowWidth = OtherArrowSize;
   double arrowPrice = price;
   
   if(signalText == "Buy" || signalText == "UP-Trend")
   {
      sourceArrowCode = BuyArrowCode;
      sourceArrowColor = BuyColor;
      sourceArrowWidth = ArrowSize;
      arrowPrice = price + ArrowGap;
   }
   else if(signalText == "Sell" || signalText == "Downtrend" || 
           signalText == "Downward" || signalText == "Close all long")
   {
      sourceArrowCode = SellArrowCode;
      sourceArrowColor = SellColor;
      sourceArrowWidth = ArrowSize;
      arrowPrice = price - ArrowGap;
   }
   
   datetime sourceTime = signalTime;
   double sourcePrice = arrowPrice;
   string sourceText = signalText;
   
   // If arrow exists, get its actual properties
   if(arrowExists)
   {
      sourceArrowCode = (int)ObjectGetInteger(0, sourceArrowName, OBJPROP_ARROWCODE);
      sourceArrowColor = (color)ObjectGetInteger(0, sourceArrowName, OBJPROP_COLOR);
      sourceArrowWidth = (int)ObjectGetInteger(0, sourceArrowName, OBJPROP_WIDTH);
      sourceTime = (datetime)ObjectGetInteger(0, sourceArrowName, OBJPROP_TIME, 0);
      sourcePrice = ObjectGetDouble(0, sourceArrowName, OBJPROP_PRICE, 0);
      sourceText = ObjectGetString(0, sourceArrowName, OBJPROP_TEXT);
   }
   
   // Find all charts with matching symbol and timeframe
   long chartId = ChartFirst();
   int copiedCount = 0;
   int skippedCount = 0;
   int checkedCount = 0;
   long currentChartId = ChartID();
   
   Print("CopyArrowToOtherChart: Looking for charts with ", targetSym, " ", targetTF);
   Print("Current chart ID: ", currentChartId, " Symbol: ", Symbol(), " Period: ", Period());
   
   if(chartId < 0)
   {
      Print("ERROR: ChartFirst() returned invalid chart ID. No charts found.");
      return;
   }
   
   do
   {
      checkedCount++;
      
      // Skip current chart (arrow already exists there)
      if(chartId == currentChartId)
      {
         chartId = ChartNext(chartId);
         if(chartId < 0) break;
         continue;
      }
      
      // Check if chart matches target symbol and timeframe
      string chartSymbol = ChartSymbol(chartId);
      int chartPeriod = (int)ChartPeriod(chartId);
      
      Print("Checking chart ID: ", chartId, " Symbol: ", chartSymbol, " Period: ", chartPeriod);
      
      if(chartSymbol == targetSym && chartPeriod == targetTF)
      {
         // Create unique arrow name for this chart
         string targetArrowName = objPrefix + "Copy_" + IntegerToString(chartId) + "_" + 
                                 TimeToString(signalTime, TIME_DATE|TIME_SECONDS) + "_" + DoubleToString(price, Digits);
         
         // Check if arrow already exists on this chart
         if(ObjectFind(chartId, targetArrowName) < 0)
         {
            // Create arrow on this chart
            if(ObjectCreate(chartId, targetArrowName, OBJ_ARROW, 0, sourceTime, sourcePrice))
            {
               ObjectSetInteger(chartId, targetArrowName, OBJPROP_ARROWCODE, sourceArrowCode);
               ObjectSetInteger(chartId, targetArrowName, OBJPROP_COLOR, sourceArrowColor);
               ObjectSetInteger(chartId, targetArrowName, OBJPROP_WIDTH, sourceArrowWidth);
               ObjectSetInteger(chartId, targetArrowName, OBJPROP_BACK, false);
               ObjectSetInteger(chartId, targetArrowName, OBJPROP_SELECTABLE, false);
               ObjectSetString(chartId, targetArrowName, OBJPROP_TEXT, sourceText);
               ObjectSetString(chartId, targetArrowName, OBJPROP_SYMBOL, targetSym);
               ObjectSetInteger(chartId, targetArrowName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
               copiedCount++;
               Print("SUCCESS: Copied arrow to chart ID: ", chartId, " (", chartSymbol, " ", chartPeriod, ")");
            }
            else
            {
               int error = GetLastError();
               Print("ERROR: Failed to create arrow on chart ID: ", chartId, " Error code: ", error);
               ResetLastError();
            }
         }
         else
         {
            skippedCount++;
            Print("Arrow already exists on chart ID: ", chartId, " - skipping");
         }
      }
      
      chartId = ChartNext(chartId);
      
      // Safety limit
      if(checkedCount > 100) 
      {
         Print("WARNING: Reached safety limit of 100 charts");
         break;
      }
   }
   while(chartId >= 0);
   
   if(copiedCount > 0)
      Print("Successfully copied arrow to ", copiedCount, " chart(s) with ", targetSym, " ", targetTF);
   else if(checkedCount == 0)
      Print("WARNING: No charts found. Make sure you have other charts open.");
   else
      Print("No matching charts found for ", targetSym, " ", targetTF, " (checked ", checkedCount, " charts)");
}

//+------------------------------------------------------------------+
//| Copy all existing arrows to another chart                       |
//+------------------------------------------------------------------+
void CopyAllArrowsToOtherChart()
{
   if(!CopyArrowsToOtherChart)
      return;
   
   Print("Copying all arrows to other chart...");
   int copiedCount = 0;
   
   for(int i = 0; i < ArraySize(Signals); i++)
   {
      CopyArrowToOtherChart(Signals[i].signal, Signals[i].time, Signals[i].price);
      copiedCount++;
   }
   
   Print("Copied ", copiedCount, " arrows to other chart");
}

//+------------------------------------------------------------------+
//| Create background panel for signal list                         |
//+------------------------------------------------------------------+
void CreateBackgroundPanel()
{
   string bgName = objPrefix + "Background";
   
   if(ObjectFind(0, bgName) < 0)
   {
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, ListXPosition);
      ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, ListYPosition);
      ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 300);
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, (MaxSignalsToShow + 2) * (FontSize + 4));
      ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, BackgroundColor);
      ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
      ObjectSetInteger(0, bgName, OBJPROP_ZORDER, 0);
      ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, bgName, OBJPROP_SELECTED, false);
   }
}

//+------------------------------------------------------------------+
//| Update the signal list display                                  |
//+------------------------------------------------------------------+
void UpdateDisplay()
{
   // Delete existing display objects
   for(int i = 0; i < MaxSignalsToShow + 5; i++)
   {
      string objName = objPrefix + "Signal_" + IntegerToString(i);
      ObjectDelete(0, objName);
   }
   
   // Create header
   string headerName = objPrefix + "Header";
   ObjectCreate(0, headerName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, headerName, OBJPROP_XDISTANCE, ListXPosition + 5);
   ObjectSetInteger(0, headerName, OBJPROP_YDISTANCE, ListYPosition + 5);
   ObjectSetString(0, headerName, OBJPROP_TEXT, "Apollo Signals:");
   ObjectSetInteger(0, headerName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, headerName, OBJPROP_FONTSIZE, FontSize);
      ObjectSetString(0, headerName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, headerName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, headerName, OBJPROP_BACK, false);
      ObjectSetInteger(0, headerName, OBJPROP_ZORDER, 1);
      ObjectSetInteger(0, headerName, OBJPROP_SELECTABLE, false);
   
   // Display signals (limit to MaxSignalsToShow)
   int signalsToShow = MathMin(ArraySize(Signals), MaxSignalsToShow);
   int lineHeight = FontSize + 4;
   
   for(int i = 0; i < signalsToShow; i++)
   {
      string objName = objPrefix + "Signal_" + IntegerToString(i);
      
      // Format signal text with time and repaint status
      string timeStr = TimeToString(Signals[i].time, TIME_DATE|TIME_MINUTES);
      string statusStr = "";
      if(Signals[i].isRepainted)
         statusStr = " [REPAINT]";
      else if(Signals[i].isConfirmed)
         statusStr = " [CONFIRMED]";
      else
         statusStr = " [PENDING]";
      
      string displayText = StringConcatenate(timeStr, " - ", Signals[i].signal, statusStr);
      
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, ListXPosition + 5);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, ListYPosition + 25 + (i * lineHeight));
      ObjectSetString(0, objName, OBJPROP_TEXT, displayText);
      
      // Set color based on signal type and repaint status
      color signalColor = OtherColor;
      if(Signals[i].isRepainted)
      {
         // Repainted signals shown in gray
         signalColor = clrGray;
      }
      else if(Signals[i].signal == "Buy" || Signals[i].signal == "UP-Trend")
         signalColor = BuyColor;
      else if(Signals[i].signal == "Sell" || Signals[i].signal == "Downtrend" || 
              Signals[i].signal == "Downward" || Signals[i].signal == "Close all long")
         signalColor = SellColor;
      
      ObjectSetInteger(0, objName, OBJPROP_COLOR, signalColor);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, FontSize);
      ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objName, OBJPROP_ZORDER, 1);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   }
   
   // Update background panel size
   string bgName = objPrefix + "Background";
   if(ObjectFind(0, bgName) >= 0)
   {
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 25 + (signalsToShow * lineHeight) + 5);
   }
}

//+------------------------------------------------------------------+
//| Apollo Line Refresher Functions                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if object name matches Apollo pattern                      |
//| Pattern: optional +/- followed by digits (e.g., "-45", "+13")   |
//+------------------------------------------------------------------+
bool IsApolloLineName(string objName)
{
   // Skip our own objects
   if(StringFind(objName, objPrefix) == 0)
      return false;
   
   // Remove leading +/- if present
   string name = objName;
   if(StringLen(name) > 0)
   {
      ushort firstChar = StringGetCharacter(name, 0);
      if(firstChar == '+' || firstChar == '-')
         name = StringSubstr(name, 1);
   }
   
   // Check if remaining string is all digits
   int len = StringLen(name);
   if(len == 0) return false;
   
   for(int i = 0; i < len; i++)
   {
      ushort ch = StringGetCharacter(name, i);
      if(ch < '0' || ch > '9')
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Remove all Apollo trendlines that have become diagonal and      |
//| text objects with Apollo descriptions                             |
//+------------------------------------------------------------------+
void RefreshApolloLines()
{
   int deletedCount = 0;
   int totalObjects = ObjectsTotal();
   
   for(int i = totalObjects - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i);
      
      // Skip our own objects (signal list, arrows, background, etc.)
      // This protects all objects created by this EA (arrows, labels, background panel)
      if(StringFind(objName, objPrefix) == 0)
         continue;
      
      int objType = (int)ObjectGetInteger(0, objName, OBJPROP_TYPE);
      
      // NEVER delete arrow objects - they are permanent once created
      // Extra safety check: even if arrow doesn't have our prefix, don't delete it
      // (in case of edge cases or future changes)
      if(objType == OBJ_ARROW)
         continue;
      
      // Check if it's a trendline with Apollo naming pattern
      if(objType == OBJ_TREND)
      {
         if(IsApolloLineName(objName))
         {
            // Get current coordinates to check if line is diagonal
            datetime time1 = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
            double price1 = ObjectGetDouble(0, objName, OBJPROP_PRICE, 0);
            datetime time2 = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 1);
            double price2 = ObjectGetDouble(0, objName, OBJPROP_PRICE, 1);
            
            // Check if line is not horizontal (prices differ)
            if(MathAbs(price1 - price2) > Point * 0.1)
            {
               // Delete the diagonal line to force indicator to redraw it
               bool deleted = ObjectDelete(0, objName);
               
               if(deleted)
               {
                  deletedCount++;
                  
                  if(EnableLogging)
                     Print("Deleted diagonal line: ", objName);
               }
            }
         }
      }
      // Check if it's a text object with Apollo description
      else if(objType == OBJ_TEXT)
      {
         if(IsApolloTextObject(objName))
         {
            // Delete the text object to force indicator to redraw it
            bool deleted = ObjectDelete(0, objName);
            
            if(deleted)
            {
               deletedCount++;
               
               if(EnableLogging)
                  Print("Deleted text object: ", objName);
            }
         }
      }
   }
   
   if(deletedCount > 0)
      Print("Apollo Line Refresher: Deleted ", deletedCount, " object(s)");
}

//+------------------------------------------------------------------+
//| Timer function (backup method if OnTick doesn't fire)            |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(EnableLineRefresher)
      RefreshApolloLines();
}

//+------------------------------------------------------------------+

