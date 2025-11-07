/*
File: 2MA.mq4
Author: Alex Pyrkov (original) / unknown (current)
Source: unknown
Description: 2 Moving Average indicator (2MA) with histogram outputs and alerts
Purpose: Provide a 2-MA based signal/histogram for trend detection and optional alerts
Parameters: See input parameters at top of file for MA periods, methods and alert options
Version: 1.01
Last Modified: 2025.11.06
Compatibility: MetaTrader 4 (MT4)
*/
//+------------------------------------------------------------------+
#property version   "1.01"
#property copyright "OPitA"
#property strict
//Owner OPitA
//version 1.00 by Alex Pyrkov Aug 08, 2022
//version 1.01 by Alex Pyrkov Aug 09, 2022
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_color1  clrGreen
#property indicator_width1  3
#property indicator_color2  clrRed
#property indicator_width2  3
#property indicator_color3  clrWhiteSmoke
#property indicator_width3  3

const string BotName="2 MA";

input bool FirstSignalOnly=true;
input string MA1="=== MA 1 ===";//----
input int ma1_periods=34;
input ENUM_APPLIED_PRICE ma1_price=PRICE_CLOSE;
input ENUM_MA_METHOD ma1_method=MODE_EMA;

input string MA2="=== MA 2 ===";//----
input int ma2_periods=34;
input ENUM_APPLIED_PRICE ma2_price=PRICE_MEDIAN;
input ENUM_MA_METHOD ma2_method=MODE_EMA;
input string HeaderAlerts="=== Alerts ===";//-----
input bool soundAlert=true;
input bool popupAlert=true;
input bool emailAlert=false;
input bool pushAlert=true;



double buffUp[];
double buffDown[];
double buffNeutral[];
datetime m_lastAlert=0;

int init()
{
   SetIndexBuffer(0,buffUp);
   SetIndexBuffer(1,buffDown);
   SetIndexBuffer(2,buffNeutral);

   SetIndexDrawBegin(0,MaxPeriod()+2);
   SetIndexDrawBegin(1,MaxPeriod()+2);
   SetIndexDrawBegin(2,MaxPeriod()+2);

   SetIndexStyle(0,DRAW_HISTOGRAM);
   SetIndexStyle(1,DRAW_HISTOGRAM);
   SetIndexStyle(2,DRAW_HISTOGRAM);

   SetIndexLabel(0,"UP");
   SetIndexLabel(1,"DOWN");
   SetIndexLabel(2,"NEUTRAL");

   ArraySetAsSeries(buffUp,true);
   ArraySetAsSeries(buffDown,true);
   ArraySetAsSeries(buffNeutral,true);

   IndicatorDigits(Digits+1);
   IndicatorShortName("2 MA");


   return(0);
}

int start()
{
   if(Bars<=MaxPeriod()) return(0);

   int counted_bars = IndicatorCounted();
   int limit = Bars - counted_bars;

   // Initialize arrays as series (MQL4 style)
   ArraySetAsSeries(buffUp,true);
   ArraySetAsSeries(buffDown,true);
   ArraySetAsSeries(buffNeutral,true);

   if(limit>(Bars-MaxPeriod()-3)) limit=Bars-MaxPeriod()-3;
   
   for(int i=limit;i>=0;i--)
   {
      double ma1=GetMA1(i);
      double ma2=GetMA2(i);
      double c=close[i];
      double mah1=GetMA1(i+1,PRICE_HIGH);
      double mah2=GetMA2(i+1,PRICE_HIGH);
      double mal1=GetMA1(i+1,PRICE_LOW);
      double mal2=GetMA2(i+1,PRICE_LOW);

      double map1=GetMA1(i+1);
      double map2=GetMA2(i+1);
      
      double v=ma1-ma2;
      if(c>mah1 && c>mah2)
      {
         buffUp[i]=v;
         buffDown[i]=EMPTY_VALUE;
         buffNeutral[i]=EMPTY_VALUE;
      }
      else if(c<mal1 && c<mal2)
      {
         buffUp[i]=EMPTY_VALUE;
         buffDown[i]=v;
         buffNeutral[i]=EMPTY_VALUE;
      }
      else
      {
         if(FirstSignalOnly)
         {
            if(LegalValue(buffUp[i+1]))
            {
               buffUp[i]=v;
               buffDown[i]=EMPTY_VALUE;
               buffNeutral[i]=EMPTY_VALUE;
            }
            else if(LegalValue(buffDown[i+1]))
            {
               buffUp[i]=EMPTY_VALUE;
               buffDown[i]=v;
               buffNeutral[i]=EMPTY_VALUE;
            }
            else
            {
               buffUp[i]=EMPTY_VALUE;
               buffDown[i]=EMPTY_VALUE;
               buffNeutral[i]=v;            
            }
         }
         else
         {
            if(c>=mal1 && c>=mal2 && LegalValue(buffUp[i+1]))
            {
               buffUp[i]=v;
               buffDown[i]=EMPTY_VALUE;
               buffNeutral[i]=EMPTY_VALUE;
            }
            else if(c<=mah1 && c<=mah2  && LegalValue(buffDown[i+1]))
            {
               buffUp[i]=EMPTY_VALUE;
               buffDown[i]=v;
               buffNeutral[i]=EMPTY_VALUE;
            }
            else
            {
               buffUp[i]=EMPTY_VALUE;
               buffDown[i]=EMPTY_VALUE;
               buffNeutral[i]=v;
            }
         }
      }
   }

   // Alert logic - check for new signals on bar 1 (previous bar)
   int shift=1;
   if(Time[shift] != m_lastAlert)
   {
      if(!LegalValue(buffUp[shift+1]) && LegalValue(buffUp[shift]))
      {
         Alarm("Signal UP",soundAlert,popupAlert,emailAlert,pushAlert);
         m_lastAlert=Time[shift];
      }
      else if(!LegalValue(buffDown[shift+1]) && LegalValue(buffDown[shift]))
      {
         Alarm("Signal DOWN",soundAlert,popupAlert,emailAlert,pushAlert);
         m_lastAlert=Time[shift];
      }
   }
   return(0);
}

double GetMA1(int shift)
{
   return (iMA(Symbol(),PERIOD_CURRENT,ma1_periods,0,ma1_method,ma1_price,shift));
}

double GetMA2(int shift)
{
   return (iMA(Symbol(),PERIOD_CURRENT,ma2_periods,0,ma2_method,ma2_price,shift));
}

double GetMA1(int shift,ENUM_APPLIED_PRICE price)
{
   return (iMA(Symbol(),PERIOD_CURRENT,ma1_periods,0,ma1_method,price,shift));
}

double GetMA2(int shift,ENUM_APPLIED_PRICE price)
{
   return (iMA(Symbol(),PERIOD_CURRENT,ma2_periods,0,ma2_method,price,shift));
}

int MaxPeriod()
{
   int p=ma1_periods;
   if(ma2_periods>p) p=ma2_periods;
   return p;
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
