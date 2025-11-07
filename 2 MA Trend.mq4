/*
File: 2 MA Trend.mq4
Author: Alex Pyrkov (original) / unknown (current)
Source: unknown
Description: Moving average based trend indicator with alerts and notifications
Purpose: Detect trend direction using MA comparisons and optionally notify the user
Parameters: See input section for MA settings, notification toggles and periods
Version: 1.00
Last Modified: 2025.11.06
Compatibility: MetaTrader 4 (MT4)
*/
//+------------------------------------------------------------------+
#property version   "1.00"
#property copyright "Jaime Bohl"
#property strict
//Owner Jaime Bohl
//version 1.00 by Alex Pyrkov Aug 09, 2022
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_color1  clrSlateGray
#property indicator_width1  5
#property indicator_color2  clrTurquoise
#property indicator_width2  2
#property indicator_color3  clrSalmon
#property indicator_width3  2

const string BotName="MA Trend";

input int ma_periods=9;
input ENUM_APPLIED_PRICE ma_price=PRICE_MEDIAN;
input ENUM_MA_METHOD ma_method=MODE_EMA;

input bool EnableNotifications=true;
input bool EnableSound=true;
input bool EnablePopup=true;
input bool EnablePush=true;

double buffUp[];
double buffDown[];
double buffLine[];

int lastTrendState=0; // 1=up, -1=down, 0=unknown
datetime lastNotificationTime=0; // Track last notification time to prevent duplicates

int OnInit()
{
   SetIndexBuffer(0,buffLine);
   SetIndexBuffer(1,buffUp);
   SetIndexBuffer(2,buffDown);
   
   SetIndexDrawBegin(0,MaxPeriod()+2);
   SetIndexDrawBegin(1,MaxPeriod()+2);
   SetIndexDrawBegin(2,MaxPeriod()+2);
   
   SetIndexStyle(0,DRAW_LINE);
   SetIndexStyle(1,DRAW_ARROW);
   SetIndexStyle(2,DRAW_ARROW);

   int code=159;
   SetIndexArrow(1,code);
   SetIndexArrow(2,code);
   
   SetIndexLabel(0,"MA TREND LINE");
   SetIndexLabel(1,"MA TREND UP");
   SetIndexLabel(2,"MA TREND DOWN");
   
   ArraySetAsSeries(buffUp,true);
   ArraySetAsSeries(buffDown,true);
   ArraySetAsSeries(buffLine,true);

   IndicatorDigits(Digits+1);
   IndicatorShortName("MA Trend");
   
   lastTrendState=0;
   lastNotificationTime=0;

   return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total<=MaxPeriod()) return 0;
   
   ArraySetAsSeries(time,true);
   ArraySetAsSeries(open,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);

   
   int limit=rates_total-prev_calculated+1;
   if(limit>(rates_total-MaxPeriod()-3)) limit=rates_total-MaxPeriod()-3;
   
   // Check for trend change only when a new bar forms
   bool newBarFormed = (prev_calculated < rates_total);
   
   for(int i=limit;i>=0;i--)
   {
      double ma=GetMA(i);
      double c=close[i];
      double mah=GetMA(i+1,PRICE_HIGH);
      double mal=GetMA(i+1,PRICE_LOW);

      double map=GetMA(i+1);
      
      double v=ma;
      int currentTrend=0;
      if(c>mah)
      {
         buffUp[i]=v;
         buffDown[i]=EMPTY_VALUE;
         currentTrend=1;
      }
      else if(c<mal)
      {
         buffUp[i]=EMPTY_VALUE;
         buffDown[i]=v;
         currentTrend=-1;
      }
      else
      {
         if(LegalValue(buffUp[i+1]))
         {
            buffUp[i]=v;
            buffDown[i]=EMPTY_VALUE;
            currentTrend=1;
         }
         else if(LegalValue(buffDown[i+1]))
         {
            buffUp[i]=EMPTY_VALUE;
            buffDown[i]=v;
            currentTrend=-1;
         }
      }
      buffLine[i]=v;
      
      // Check for trend change only on new bar formation (i=0) and when trend actually changes
      if(EnableNotifications && newBarFormed && i==0 && prev_calculated>0)
      {
         // Only check once per bar (use time to prevent duplicate notifications on same bar)
         if(time[0]!=lastNotificationTime)
         {
            // Get the trend from the completed previous bar (index 1)
            int prevTrend=0;
            if(LegalValue(buffUp[1]))
               prevTrend=1;
            else if(LegalValue(buffDown[1]))
               prevTrend=-1;

            // Debug output
            Print("DEBUG: currentTrend=", currentTrend, " prevTrend=", prevTrend, " lastTrendState=", lastTrendState);
            Print("DEBUG: buffUp[1]=", buffUp[1], " buffDown[1]=", buffDown[1], " buffUp[0]=", buffUp[0], " buffDown[0]=", buffDown[0]);
            Print("DEBUG: close[0]=", close[0], " mah=", GetMA(1,PRICE_HIGH), " mal=", GetMA(1,PRICE_LOW));

            // Only notify if trend actually changed from previous completed bar
            // Changed condition to also notify on trend establishment (prevTrend=0) or trend change
            if(currentTrend != 0 && currentTrend != lastTrendState)
            {
               string message="";
               if(currentTrend==1)
                  message="Trend changed to UP";
               else if(currentTrend==-1)
                  message="Trend changed to DOWN";

               Print("DEBUG: NOTIFICATION TRIGGERED - ", message);
               Alarm(message,EnableSound,EnablePopup,false,EnablePush);
               lastTrendState=currentTrend;
               lastNotificationTime=time[0];
            }
            else if(currentTrend!=0)
            {
               // Update state without notifying (trend unchanged or first time)
               lastTrendState=currentTrend;
               lastNotificationTime=time[0];
            }
         }
      }
   }
   
   return rates_total;
}

double GetMA(int shift)
{
   return (iMA(Symbol(),PERIOD_CURRENT,ma_periods,0,ma_method,ma_price,shift));
}


double GetMA(int shift,ENUM_APPLIED_PRICE price)
{
   return (iMA(Symbol(),PERIOD_CURRENT,ma_periods,0,ma_method,price,shift));
}


int MaxPeriod()
{
   return ma_periods;
}

bool LegalValue(double val)
{
   return !IsEqual(val,EMPTY_VALUE);
}

bool IsEqual(double val1, double val2,double acc=1.)
{
   return (MathAbs(val1-val2)<=(acc*Point));
}

bool NotEqual(double val1, double val2,double acc=1.)
{
   return !IsEqual(val1,val2,acc);
}

void Alarm(string body,bool soundA,bool popupA,bool emailA,bool pushA)
{
   string pair_com=Symbol()+" "+HumanCompressionShort(Period());
   if(soundA)
   {
      PlaySound("alert.wav");
   }
   if(popupA)
   {
      Alert(BotName+" ",pair_com," ",body);
   }
   if(emailA)
   {
      SendMail("From "+BotName+" "+pair_com,pair_com+" "+body);
   }
   if(pushA)
   {
      SendNotification("From "+BotName+" "+pair_com+" "+body);
   }
}

string HumanCompressionShort(int per)
{
   if(per==0) per=Period();
   switch(per)
   {
      case PERIOD_M1:
         return ("M1"); 
      case PERIOD_M5:
         return ("M5"); 
      case PERIOD_M15:
         return ("M15"); 
      case PERIOD_M30:
         return ("M30"); 
      case PERIOD_H1:
         return ("H1");
      case PERIOD_H4:
         return ("H4");
      case PERIOD_D1:
         return ("D1");
      case  PERIOD_W1:
         return ("W1");
      case PERIOD_MN1:
         return ("MN1"); 
   }
   return ("M"+IntegerToString(per));
}
