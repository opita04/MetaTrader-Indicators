//+------------------------------------------------------------------+
//|                                    Apollo Line Refresher.mq4     |
//|                                                                  |
//|  Removes Apollo Smart Level Trader trendlines that have become  |
//|  diagonal and text objects with specific descriptions to force  |
//|  the indicator to redraw them                                    |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

input int RefreshIntervalSeconds = 180;  // Refresh interval in seconds
input bool EnableLogging = false;      // Enable debug logging

datetime lastRefreshTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Apollo Line Refresher initialized. Refresh interval: ", RefreshIntervalSeconds, " seconds");
   lastRefreshTime = TimeCurrent();
   
   // Set up timer as backup
   EventSetTimer(RefreshIntervalSeconds);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   Print("Apollo Line Refresher deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime currentTime = TimeCurrent();
   
   // Check if it's time to refresh
   if(currentTime - lastRefreshTime >= RefreshIntervalSeconds)
   {
      RefreshApolloLines();
      lastRefreshTime = currentTime;
   }
}

//+------------------------------------------------------------------+
//| Check if object name matches Apollo pattern                      |
//| Pattern: optional +/- followed by digits (e.g., "-45", "+13")   |
//+------------------------------------------------------------------+
bool IsApolloLineName(string objName)
{
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
//| Check if text object has Apollo description                      |
//| Descriptions: "Buy", "Sell", "Shooting Star", "Downtrend", "Reversal", "Close all long", "UP-Trend" |
//+------------------------------------------------------------------+
bool IsApolloTextObject(string objName)
{
   // Get the text/description of the object
   string description = ObjectGetString(0, objName, OBJPROP_TEXT);
   
   // Check if description matches Apollo patterns
   if(description == "Buy" || description == "Sell" || 
      description == "Shooting Star" || description == "Downtrend" || 
      description == "Reversal" || description == "Downward" ||
      description == "Close all long" || description == "UP-Trend")
   {
      return true;
   }
   
   return false;
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
      int objType = (int)ObjectGetInteger(0, objName, OBJPROP_TYPE);
      
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
   RefreshApolloLines();
}

