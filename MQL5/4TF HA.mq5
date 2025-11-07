/*
File: 4TF HA.mq5
Author: Alex Pyrkov (original)
Source: unknown
Description: 4-timeframe Heikin Ashi indicator (MQL5) with alignment alerts and optional chart arrows
Purpose: Provide multi-timeframe HA alignment visualization and alerts across 4 configured timeframes
Parameters: See TimeFrames and HA settings near top of file
Version: 1.01
Last Modified: 2025.11.06
Compatibility: MetaTrader 5 (MT5)
*/
//+------------------------------------------------------------------+
#property copyright "Jaime Bohl"
#property version   "1.01"

//Owner Jaime Bohl
//version 1.00 by Alex Pyrkov May 30, 2024
//version 1.01 by Alex Pyrkov June 01, 2024

#include <Indicators\Trend.mqh>
const string PREFIX="TF4_HA_";

#property indicator_separate_window
#property indicator_minimum 0
#property indicator_maximum 5
#property indicator_buffers   8
#property indicator_plots   8

#property indicator_label1  "UP"
#property indicator_width1  2
#property indicator_color1  clrSkyBlue

#property indicator_label2  "DOWN"
#property indicator_width2  2
#property indicator_color2  clrTomato

#property indicator_label3  "UP"
#property indicator_width3  2
#property indicator_color3  clrSkyBlue

#property indicator_label4  "DOWN"
#property indicator_width4  2
#property indicator_color4  clrTomato

#property indicator_label5  "UP"
#property indicator_width5  2
#property indicator_color5  clrSkyBlue

#property indicator_label6  "DOWN"
#property indicator_width6  2
#property indicator_color6  clrTomato

#property indicator_label7  "UP"
#property indicator_width7  2
#property indicator_color7  clrSkyBlue

#property indicator_label8  "DOWN"
#property indicator_width8  2
#property indicator_color8  clrTomato




input int MaxBarsBack=1000;
input string          HeaderTF        = "=== TimeFrames ===";//-----         
input ENUM_TIMEFRAMES TF1=PERIOD_CURRENT;
input ENUM_TIMEFRAMES TF2=PERIOD_M15;
input ENUM_TIMEFRAMES TF3=PERIOD_M30;
input ENUM_TIMEFRAMES TF4=PERIOD_H1;
input string          HeaderHA        = "=== HA settings ===";//-----         
input ENUM_MA_METHOD  inpMaMethod1    = MODE_SMA; // MA 1 method
input int             inpMaPeriod1    = 1;        // MA 1 period
input ENUM_MA_METHOD  inpMaMethod2    = MODE_SMA; // MA 2 method
input int             inpMaPeriod2    = 1;        // MA 2 period
input bool            inpUseHAHighLow = true;     // Use high/low for trends?
input string AlertsHeader="=== Alerts ===";//-----
input bool FirstArrowInTrendOnly=false;
input bool LiveAlert=false;//Alert on current developing bar
input bool popupAlert=false;
input bool soundAlert=true;
input bool emailAlert=false;
input bool pushAlert=false;

input string HeaderArrows= "====   Arrows and visual  settings  ====";//-----
input int   ArrowCodeUp     = 110;              // Up code for histogram
input int   ArrowCodeDn     = 110;              // Down code for histogram
input bool ShowTags=true;
input string TagFont="Arial Black";
input int TagFontSize=8;
input color TagColor=clrBisque;
input bool ShowTFRectangles=true;
input color TFRColor=clrSlateGray;
input bool ShowChartArrows=true;
input int   ArrowChartCodeUp= 225;
input int   ArrowChartCodeDn= 226;
input color ArrowChartColorUp=clrSkyBlue;
input color ArrowChartColorDn=clrTomato;
input int ArrowChartWidth=1;



class apvHA
{
   protected:
   string m_symb;
   ENUM_TIMEFRAMES m_tf;
   bool m_calculated;
   double m_ha_open[];
   double m_ha_close[];
   double m_ha_u[];
   double m_ha_d[];
   CiMA m_ma_open;
   CiMA m_ma_high;
   CiMA m_ma_low;
   CiMA m_ma_close;
   datetime m_last;
   public:
   apvHA(){};
   virtual ~apvHA()
   {
      if(m_ma_open.Handle()!=INVALID_HANDLE) m_ma_open.FullRelease();
      if(m_ma_high.Handle()!=INVALID_HANDLE) m_ma_high.FullRelease();
      if(m_ma_low.Handle()!=INVALID_HANDLE) m_ma_low.FullRelease();
      if(m_ma_close.Handle()!=INVALID_HANDLE) m_ma_close.FullRelease();
   }
   
   bool Create(string symb,ENUM_TIMEFRAMES tf)
   {
      m_symb=symb;
      m_tf=tf;
      if(!m_ma_open.Create(symb,tf,inpMaPeriod1,0,inpMaMethod1,PRICE_OPEN)) return false;
      if(!m_ma_high.Create(symb,tf,inpMaPeriod1,0,inpMaMethod1,PRICE_HIGH)) return false;
      if(!m_ma_low.Create(symb,tf,inpMaPeriod1,0,inpMaMethod1,PRICE_LOW)) return false;
      if(!m_ma_close.Create(symb,tf,inpMaPeriod1,0,inpMaMethod1,PRICE_CLOSE)) return false;
      
      int sz=MaxBarsBack+inpMaPeriod1+inpMaPeriod2+1;
      if(!m_ma_open.BufferResize(sz)) return false;
      if(!m_ma_high.BufferResize(sz)) return false;
      if(!m_ma_low.BufferResize(sz)) return false;
      if(!m_ma_close.BufferResize(sz)) return false;
      
      sz=MaxBarsBack+inpMaPeriod2+1;
      if(ArrayResize(m_ha_open,sz)<0) return false;
      if(ArrayResize(m_ha_close,sz)<0) return false;
      if(ArrayResize(m_ha_u,sz)<0) return false;
      if(ArrayResize(m_ha_d,sz)<0) return false;
      
      ArraySetAsSeries(m_ha_open,true);
      ArraySetAsSeries(m_ha_close,true);
      ArraySetAsSeries(m_ha_u,true);
      ArraySetAsSeries(m_ha_d,true);
      
      ArrayInitialize(m_ha_open,0.0);
      ArrayInitialize(m_ha_close,0.0);
      ArrayInitialize(m_ha_u,0.0);
      ArrayInitialize(m_ha_d,0.0);
      
      m_calculated=false;
      m_last=0;
      return true;
   }
   
   void Refresh()
   {
      m_ma_open.Refresh();
      m_ma_high.Refresh();
      m_ma_low.Refresh();
      m_ma_close.Refresh();
      
      if(m_last!=iTime(m_symb,m_tf,0) || SymbolInfoInteger(m_symb,SYMBOL_CUSTOM))
      {
         m_calculated=false;
      }
      int limit=m_calculated ? 2 : MaxBarsBack+inpMaPeriod2;
      for(int i=limit;i>=0;i--)
      {
         //if(!m_calculated) Print("Full recalculation "+HumanCompressionShort(m_tf));
         if(m_ma_open.BarsCalculated()<(i+1) || m_ma_high.BarsCalculated()<(i+1) || m_ma_low.BarsCalculated()<(i+1) || m_ma_close.BarsCalculated()<(i+1))
         {
            m_calculated=false;
            //Print("NOT CALCULATED");
            break;
         }
         else 
         {
            m_calculated=true;
            m_last=iTime(m_symb,m_tf,0);
         }
         
         if((i+1)>=ArraySize(m_ha_open))
         {
            m_ha_open[i]=(m_ma_close.Main(i)+m_ma_open.Main(i))/2.0;
         }
         else m_ha_open[i]=(m_ha_open[i+1]+m_ha_close[i+1])/2.0;
         
         m_ha_close[i]=(m_ma_open.Main(i)+m_ma_high.Main(i)+m_ma_low.Main(i)+m_ma_close.Main(i))/4.0;
         
         double haLow=MathMin(m_ma_low.Main(i),MathMin(m_ha_open[i],m_ha_close[i]));
         double haHigh=MathMax(m_ma_high.Main(i),MathMax(m_ha_open[i],m_ha_close[i]));
         
         if(m_ha_close[i]>m_ha_open[i])
         {
            m_ha_u[i]= haLow;
            m_ha_d[i]= haHigh;
         }
         else
         {
            m_ha_u[i]= haHigh;
            m_ha_d[i]= haLow;
         }
      }
   }
   //returns 0.0 if no signal
   int GetSignal(datetime dt)
   {
      if(!m_calculated) 
      {
         //Print("m_calculated = false");
         return 0.0;
      }
      int shift=iBarShift(m_symb,m_tf,dt);
      if(shift>=0)
      {
         if(inpUseHAHighLow)
         {
            if(iMAOnArray(m_ha_u,inpMaPeriod2,0,inpMaMethod2,shift)<iMAOnArray(m_ha_d,inpMaPeriod2,0,inpMaMethod2,shift)) return 1;
            else return -1;
         }
         else
         {
            if(iMAOnArray(m_ha_open,inpMaPeriod2,0,inpMaMethod2,shift)<iMAOnArray(m_ha_close,inpMaPeriod2,0,inpMaMethod2,shift)) return 1;
            else return -1;
         }
         
      }
      //else Print("WRONG BARSHIFT for "+TimeToString(dt,TIME_DATE|TIME_SECONDS)+" "+m_symb+" Timeframe "+HumanCompressionShort(m_tf));
      return 0.0;
   }
   //returns 0.0 if no signal
   int GetSignalByIndex(int i)
   {
      if(!m_calculated) return 0.0;
      int shift=i;
      if(shift>=0)
      {
         if(inpUseHAHighLow)
         {
            if(iMAOnArray(m_ha_u,inpMaPeriod2,0,inpMaMethod2,shift)<iMAOnArray(m_ha_d,inpMaPeriod2,0,inpMaMethod2,shift)) return 1;
            else return -1;
         }
         else
         {
            if(iMAOnArray(m_ha_open,inpMaPeriod2,0,inpMaMethod2,shift)<iMAOnArray(m_ha_close,inpMaPeriod2,0,inpMaMethod2,shift)) return 1;
            else return -1;
         }
         
      }
      return 0.0;
   }
   string GetSymbol() const
   {
      return m_symb;
   }
   ENUM_TIMEFRAMES GetPeriod() const
   {
      return m_tf;
   }
};


double buffHTF1Up[];
double buffHTF1Down[];
double buffHTF2Up[];
double buffHTF2Down[];
double buffHTF3Up[];
double buffHTF3Down[];
double buffHTF4Up[];
double buffHTF4Down[];

apvHA* g_ha1;
apvHA* g_ha2;
apvHA* g_ha3;
apvHA* g_ha4;
datetime g_last_alert=0;
int g_trend=0;
int g_old_sig=0;

int OnInit()
{
   ArraySetAsSeries(buffHTF1Up,true);
   ArraySetAsSeries(buffHTF1Down,true);
   ArraySetAsSeries(buffHTF2Up,true);
   ArraySetAsSeries(buffHTF2Down,true);
   ArraySetAsSeries(buffHTF3Up,true);
   ArraySetAsSeries(buffHTF3Down,true);
   ArraySetAsSeries(buffHTF4Up,true);
   ArraySetAsSeries(buffHTF4Down,true);
   
   ArrayInitialize(buffHTF1Up,0.0);
   ArrayInitialize(buffHTF1Down,0.0);
   ArrayInitialize(buffHTF2Up,0.0);
   ArrayInitialize(buffHTF2Down,0.0);
   ArrayInitialize(buffHTF3Up,0.0);
   ArrayInitialize(buffHTF3Down,0.0);
   ArrayInitialize(buffHTF4Up,0.0);
   ArrayInitialize(buffHTF4Down,0.0);

   int i=0;
   SetIndexBuffer(i++,buffHTF1Up,INDICATOR_DATA);
   SetIndexBuffer(i++,buffHTF1Down,INDICATOR_DATA);
   SetIndexBuffer(i++,buffHTF2Up,INDICATOR_DATA);
   SetIndexBuffer(i++,buffHTF2Down,INDICATOR_DATA);
   SetIndexBuffer(i++,buffHTF3Up,INDICATOR_DATA);
   SetIndexBuffer(i++,buffHTF3Down,INDICATOR_DATA);
   SetIndexBuffer(i++,buffHTF4Up,INDICATOR_DATA);
   SetIndexBuffer(i++,buffHTF4Down,INDICATOR_DATA);

   PlotIndexSetInteger(0,PLOT_DRAW_TYPE,DRAW_ARROW);   
   PlotIndexSetInteger(0,PLOT_ARROW,ArrowCodeUp);   
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);

   PlotIndexSetInteger(1,PLOT_DRAW_TYPE,DRAW_ARROW);   
   PlotIndexSetInteger(1,PLOT_ARROW,ArrowCodeDn);   
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,0.0);

   PlotIndexSetInteger(2,PLOT_DRAW_TYPE,DRAW_ARROW);   
   PlotIndexSetInteger(2,PLOT_ARROW,ArrowCodeUp);   
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,0.0);

   PlotIndexSetInteger(3,PLOT_DRAW_TYPE,DRAW_ARROW);   
   PlotIndexSetInteger(3,PLOT_ARROW,ArrowCodeDn);   
   PlotIndexSetDouble(3,PLOT_EMPTY_VALUE,0.0);

   PlotIndexSetInteger(4,PLOT_DRAW_TYPE,DRAW_ARROW);   
   PlotIndexSetInteger(4,PLOT_ARROW,ArrowCodeUp);   
   PlotIndexSetDouble(4,PLOT_EMPTY_VALUE,0.0);

   PlotIndexSetInteger(5,PLOT_DRAW_TYPE,DRAW_ARROW);   
   PlotIndexSetInteger(5,PLOT_ARROW,ArrowCodeDn);   
   PlotIndexSetDouble(5,PLOT_EMPTY_VALUE,0.0);

   PlotIndexSetInteger(6,PLOT_DRAW_TYPE,DRAW_ARROW);   
   PlotIndexSetInteger(6,PLOT_ARROW,ArrowCodeUp);   
   PlotIndexSetDouble(6,PLOT_EMPTY_VALUE,0.0);

   PlotIndexSetInteger(7,PLOT_DRAW_TYPE,DRAW_ARROW);   
   PlotIndexSetInteger(7,PLOT_ARROW,ArrowCodeDn);   
   PlotIndexSetDouble(7,PLOT_EMPTY_VALUE,0.0);

   string symb_htf=Symbol();
   bool found=false;
   int total=SymbolsTotal(true);
   for(int i=0;i<total;i++)
   {
      string s=SymbolName(i,true);
      if(!SymbolInfoInteger(s,SYMBOL_CUSTOM))
      {
         if(s==Symbol()) 
         {
            symb_htf=s;
            found=true;
            break;
         }
      }
   }
   if(!found)
   {
      for(int i=0;i<total;i++)
      {
         string s=SymbolName(i,true);
         if(!SymbolInfoInteger(s,SYMBOL_CUSTOM))
         {
            if(StringFind(Symbol(),s)>=0) 
            {
               symb_htf=s;
               //Print(g_symbol_htf);
               found=true;
               break;
            }
         }
      }
   }

   g_ha1=new apvHA();
   g_ha2=new apvHA();
   g_ha3=new apvHA();
   g_ha4=new apvHA();
   
   if(!g_ha1.Create(TF1==PERIOD_CURRENT ? Symbol() : symb_htf,TF1))
   {
      Alert("Cannot create TF1 indicator. Please, restart");
      return INIT_FAILED;
   }
   if(!g_ha2.Create(TF2==PERIOD_CURRENT ? Symbol() : symb_htf,TF2))
   {
      Alert("Cannot create TF2 indicator. Please, restart");
      return INIT_FAILED;
   }
   if(!g_ha3.Create(TF3==PERIOD_CURRENT ? Symbol() : symb_htf,TF3))
   {
      Alert("Cannot create TF3 indicator. Please, restart");
      return INIT_FAILED;
   }
   if(!g_ha4.Create(TF4==PERIOD_CURRENT ? Symbol() : symb_htf,TF4))
   {
      Alert("Cannot create TF4 indicator. Please, restart");
      return INIT_FAILED;
   }
   g_trend=0;
   g_old_sig=0;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int  reason)
{
   if(CheckPointer(g_ha1)==POINTER_DYNAMIC) delete g_ha1;
   if(CheckPointer(g_ha2)==POINTER_DYNAMIC) delete g_ha2;
   if(CheckPointer(g_ha3)==POINTER_DYNAMIC) delete g_ha3;
   if(CheckPointer(g_ha4)==POINTER_DYNAMIC) delete g_ha4;
   for(int i=1;i<=4;i++)
   {
      ObjectDelete(0,PREFIX+IntegerToString(i));
   }
   ObjectsDeleteAll(0,PREFIX);
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
   ArraySetAsSeries(open,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);   
   ArraySetAsSeries(close,true);
   ArraySetAsSeries(time,true);

   g_ha1.Refresh();
   g_ha2.Refresh();
   g_ha3.Refresh();
   g_ha4.Refresh();
   
   int limit=rates_total-prev_calculated+1;
   int lim_tf=iBarShift(Symbol(),PERIOD_CURRENT,iTime(g_ha1.GetSymbol(),g_ha1.GetPeriod(),1));
   if(lim_tf>=0)
   {
      //lim_tf+=1;
      if(lim_tf>limit) limit=lim_tf;
   }
   if(limit>MaxBarsBack) limit=MaxBarsBack;
   if(limit>(rates_total-2)) limit=rates_total-2;
   
   int rv=rates_total;
   int k=1;
   //TF1
   for(int i=0;i<=limit;i++)
   {
      int sig=TF1==PERIOD_CURRENT ? g_ha1.GetSignalByIndex(i) : g_ha1.GetSignal(time[i]);
      if(sig>0) 
      {
         buffHTF1Up[i]=k;
         buffHTF1Down[i]=0.0;
      }
      else if(sig<0)
      {
         buffHTF1Up[i]=0.0;
         buffHTF1Down[i]=k;
      }
      else 
      {
         buffHTF1Up[i]=0.0;
         buffHTF1Down[i]=0.0;
         rv=0;
         //Print("TF1 caused reload");
      }
   }
   
   k++;
   //TF2
   limit=rates_total-prev_calculated+1;
   lim_tf=iBarShift(Symbol(),PERIOD_CURRENT,iTime(g_ha2.GetSymbol(),g_ha2.GetPeriod(),1));
   if(lim_tf>=0)
   {
      //lim_tf+=1;
      if(lim_tf>limit) limit=lim_tf;
   }
   if(limit>MaxBarsBack) limit=MaxBarsBack;
   if(limit>(rates_total-2)) limit=rates_total-2;
   
   for(int i=0;i<=limit;i++)
   {
      int sig=TF2==PERIOD_CURRENT ? g_ha2.GetSignalByIndex(i) : g_ha2.GetSignal(time[i]);
      if(sig>0) 
      {
         buffHTF2Up[i]=k;
         buffHTF2Down[i]=0.0;
      }
      else if(sig<0)
      {
         buffHTF2Up[i]=0.0;
         buffHTF2Down[i]=k;
      }
      else 
      {
         buffHTF2Up[i]=0.0;
         buffHTF2Down[i]=0.0;
         rv=0;
         //Print("TF2 caused reload");         
      }
   }      
   k++;
   //TF3
   limit=rates_total-prev_calculated+1;
   lim_tf=iBarShift(Symbol(),PERIOD_CURRENT,iTime(g_ha3.GetSymbol(),g_ha3.GetPeriod(),1));
   if(lim_tf>=0)
   {
      //lim_tf+=1;
      if(lim_tf>limit) limit=lim_tf;
   }
   if(limit>MaxBarsBack) limit=MaxBarsBack;
   if(limit>(rates_total-2)) limit=rates_total-2;
      
   for(int i=0;i<=limit;i++)
   {
      int sig=TF3==PERIOD_CURRENT ? g_ha3.GetSignalByIndex(i) : g_ha3.GetSignal(time[i]);
      if(sig>0) 
      {
         buffHTF3Up[i]=k;
         buffHTF3Down[i]=0.0;
      }
      else if(sig<0)
      {
         buffHTF3Up[i]=0.0;
         buffHTF3Down[i]=k;
      }
      else 
      {
         buffHTF3Up[i]=0.0;
         buffHTF3Down[i]=0.0;
         rv=0;
         //Print("TF3 caused reload");                  
      }
   }      
   k++;
   //TF4
   limit=rates_total-prev_calculated+1;
   lim_tf=iBarShift(Symbol(),PERIOD_CURRENT,iTime(g_ha4.GetSymbol(),g_ha4.GetPeriod(),1));
   if(lim_tf>=0)
   {
      //lim_tf+=1;
      if(lim_tf>limit) limit=lim_tf;
   }
   if(limit>MaxBarsBack) limit=MaxBarsBack;
   if(limit>(rates_total-2)) limit=rates_total-2;
   
   for(int i=0;i<=limit;i++)
   {
      int sig=TF4==PERIOD_CURRENT ? g_ha4.GetSignalByIndex(i) : g_ha4.GetSignal(time[i]);
      if(sig>0) 
      {
         buffHTF4Up[i]=k;
         buffHTF4Down[i]=0.0;
      }
      else if(sig<0)
      {
         buffHTF4Up[i]=0.0;
         buffHTF4Down[i]=k;
      }
      else 
      {
         buffHTF4Up[i]=0.0;
         buffHTF4Down[i]=0.0;
         rv=0;
      }
   }
   //tags
   if(ShowTags)
   {
      for(int i=1;i<=4;i++)
      {
         string tfs=HumanCompressionShort(TF1);
         if(i==2) tfs=HumanCompressionShort(TF2);
         if(i==3) tfs=HumanCompressionShort(TF3);
         if(i==4) tfs=HumanCompressionShort(TF4);
         DrawText(0,PREFIX+IntegerToString(i),tfs,time[0]+PeriodSeconds(),i,TagColor,TagFont,TagFontSize,false,ANCHOR_LEFT);
      }
   }
   //TF Rectangles
   if(ShowTFRectangles)
   {
      for(int i=1;i<=4;i++)
      {
         datetime dt1=iTime(g_ha1.GetSymbol(),g_ha1.GetPeriod(),0);
         datetime delta=SymbolInfoInteger(Symbol(),SYMBOL_CUSTOM) ? 0 : PeriodSeconds(PERIOD_CURRENT); 
         datetime dt2=dt1+PeriodSeconds(TF1)-delta;
         if(i==2) 
         {
            dt1=iTime(g_ha2.GetSymbol(),g_ha2.GetPeriod(),0);
            dt2=dt1+PeriodSeconds(TF2)-delta;
         }
         if(i==3) 
         {
            dt1=iTime(g_ha3.GetSymbol(),g_ha3.GetPeriod(),0);
            dt2=dt1+PeriodSeconds(TF3)-delta;
         }
         if(i==4) 
         {
            dt1=iTime(g_ha4.GetSymbol(),g_ha4.GetPeriod(),0);
            dt2=dt1+PeriodSeconds(TF4)-delta;
         }
         DrawRectangle(0,PREFIX+"TF_"+IntegerToString(i),dt1,i-0.5,dt2,i+0.5,TFRColor,true);
      }
   }
   if(rv>0)
   { 
      //alert/arrow
      if(g_last_alert!=time[0])
      {
         int shift=LiveAlert ? 0 : 1;
         int sig=GetSignal(4,shift);
         if(g_trend==0)
         {
            g_trend=GetLastSignal(4,shift+1,rates_total-2);
         }
         string nm=PREFIX+"ARROW_"+TimeToString(time[shift]);
         if(sig>0 && (FirstArrowInTrendOnly ? g_trend<0 : g_old_sig<=0)) 
         {
            if(ShowChartArrows) DrawArrow(0,nm,time[shift],low[shift],ArrowChartColorUp,ArrowChartWidth,ArrowChartCodeUp,ANCHOR_TOP);
            Alarm("all TFs are aligned UP");
            g_last_alert=time[0];
            g_trend=1;
         }
         else if(sig<0 && (FirstArrowInTrendOnly ? g_trend>0 : g_old_sig>=0))
         {
            Alarm("all TFs are aligned DOWN");
            if(ShowChartArrows) DrawArrow(0,nm,time[shift],high[shift],ArrowChartColorDn,ArrowChartWidth,ArrowChartCodeDn,ANCHOR_BOTTOM);
            g_last_alert=time[0];
            g_trend=-1;
         }
         g_old_sig=sig;
      }
   }
   //if(rv==0) Print("RELOAD");
   return rv;
}


double iMAOnArray(double& array[], int period, int ma_shift, ENUM_MA_METHOD ma_method, int shift)
{

   double buf[], arr[];
   int total = ArraySize(array);   

   if(total <= period)
      return 0;      

   if(shift > (total - period - ma_shift))
      return 0;     

   switch(ma_method) 
   {

   case MODE_SMA: {

      total = ArrayCopy(arr, array, 0, shift + ma_shift, period);
      if (ArrayResize(buf, total) < 0)
         return 0;

      double sum = 0;
      int i, pos = total-1;      

      for (i = 1; i < period; i++, pos--)

         sum += arr[pos];

      while (pos >= 0) {

         sum += arr[pos];

         buf[pos] = sum / period;

         sum -= arr[pos + period - 1];

         pos--;

      }

      return buf[0];

   }

      

   case MODE_EMA: {

      if (ArrayResize(buf, total) < 0)

         return 0;

      double pr = 2.0 / (period + 1);

      int pos = total - 2;

      

      while (pos >= 0) {

         if (pos == total - 2)

            buf[pos+1] = array[pos+1];

         buf[pos] = array[pos] * pr + buf[pos+1] * (1-pr);

         pos--;

      }

      return buf[shift+ma_shift];

   }

   

   case MODE_SMMA: {

      if (ArrayResize (buf, total) < 0)

         return(0);

      double sum = 0;

      int i, k, pos;

      

      pos = total - period;

      while (pos >= 0) {

         if (pos == total - period) {

            for (i = 0, k = pos; i < period; i++, k++) {

               sum += array[k];

               buf[k] = 0;

            }

         }

         else

            sum = buf[pos+1] * (period-1) + array[pos];

         buf[pos]=sum/period;

         pos--;

      }

      return buf[shift+ma_shift];

   }

   

   case MODE_LWMA: {

         if (ArrayResize (buf, total) < 0)

            return 0;

         double sum = 0.0, lsum = 0.0;

         double price;

         int i, weight = 0, pos = total-1;

         

         for(i = 1; i <= period; i++, pos--) {

            price = array[pos];

            sum += price * i;

            lsum += price;

            weight += i;

         }

         pos++;

         i = pos + period;

         while (pos >= 0) {

            buf[pos] = sum / weight;

            if (pos == 0)

               break;

            pos--;

            i--;

            price = array[pos];

            sum = sum - lsum + price * period;

            lsum -= array[i];

            lsum += price;

         }         

         return buf[shift+ma_shift];

      }

   }

   return 0;

}

string HumanCompressionShort(ENUM_TIMEFRAMES tf)
{
   if(tf==PERIOD_CURRENT) return "CURRENT";
   int tf_min=PeriodSeconds(tf)/60;
   if(tf==PERIOD_MN1)
   {
      return "MN1";
   }
   else if(tf==PERIOD_W1)
   {
      return "W1";
   }
   else if(tf==PERIOD_D1)
   {
      return "D1";
   }
   else if(tf_min<1440 && tf_min>=60)
   {
      return "H"+IntegerToString(tf_min/60);
   }
   else  if(tf_min<60 && tf_min>=1)
   {
      return "M"+IntegerToString(tf_min);
   }
   else //seconds
   {
      return "Sec "+IntegerToString(PeriodSeconds(tf));
   }
}

void DrawText(long cid,string nm,string text,datetime dt,double price,color col,string font,int fontSize,bool prop_back,ENUM_ANCHOR_POINT anchor,string ToolTip="\n")
{
   if(ObjectFind(cid,nm)<0)
   {
      ObjectCreate(cid,nm,OBJ_TEXT,ChartWindowFind(),dt,price);
   }
   if(ObjectFind(cid,nm)>=0)
   {
      ObjectSetString(cid,nm,OBJPROP_TEXT,text);
      ObjectSetInteger(cid,nm,OBJPROP_COLOR,col);            
      ObjectSetString(cid,nm,OBJPROP_FONT,font);
      ObjectSetInteger(cid,nm,OBJPROP_FONTSIZE,fontSize);
      ObjectSetInteger(cid,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(cid,nm,OBJPROP_SELECTED,false);
      ObjectSetInteger(cid,nm,OBJPROP_BACK,prop_back);
      ObjectSetString(cid,nm,OBJPROP_TOOLTIP,ToolTip);          
      ObjectSetInteger(cid,nm,OBJPROP_HIDDEN,true);
      ObjectSetInteger(cid,nm,OBJPROP_ANCHOR,anchor);
      ObjectSetDouble(cid,nm,OBJPROP_ANGLE,0);
      ObjectMove(cid,nm,0,dt,price);                 
   }
}


void DrawRectangle(long cid,string nm,datetime dt1,double pr1,datetime dt2,double pr2,color col,bool fill)
{
   if(ObjectFind(cid,nm)<0)
   {
      ObjectCreate(cid,nm,OBJ_RECTANGLE,ChartWindowFind(),dt1,pr1,dt2,pr2);
   }
   if(ObjectFind(cid,nm)>=0)
   {
      ObjectSetInteger(cid,nm,OBJPROP_COLOR,col);            
      ObjectSetInteger(cid,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(cid,nm,OBJPROP_SELECTED,false);
      ObjectSetInteger(cid,nm,OBJPROP_BACK,true);
      ObjectSetInteger(cid,nm,OBJPROP_FILL,fill);
      ObjectMove(cid,nm,0,dt1,pr1);
      ObjectMove(cid,nm,1,dt2,pr2);
   }
}

void DrawArrow(long cid,string nm,datetime dt1,double pr1,color col,int width,int code,ENUM_ARROW_ANCHOR anchor)
{
   if(ObjectFind(cid,nm)<0)
   {
      ObjectCreate(cid,nm,OBJ_ARROW,0,dt1,pr1);
   }
   if(ObjectFind(cid,nm)>=0)
   {
      ObjectSetInteger(cid,nm,OBJPROP_COLOR,col);            
      ObjectSetInteger(cid,nm,OBJPROP_WIDTH,width);
      ObjectSetInteger(cid,nm,OBJPROP_ARROWCODE,code);
      ObjectSetInteger(cid,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(cid,nm,OBJPROP_SELECTED,false);
      ObjectSetInteger(cid,nm,OBJPROP_BACK,false);
      ObjectSetInteger(cid,nm,OBJPROP_ANCHOR,anchor); 
      ObjectMove(cid,nm,0,dt1,pr1);
   }
}

int GetSignal(int level,int shift)
{
   int up=0;
   if(buffHTF1Up[shift]>0.0) up++;
   if(buffHTF2Up[shift]>0.0) up++;
   if(buffHTF3Up[shift]>0.0) up++;
   if(buffHTF4Up[shift]>0.0) up++;

   int down=0;
   if(buffHTF1Down[shift]>0.0) down++;
   if(buffHTF2Down[shift]>0.0) down++;
   if(buffHTF3Down[shift]>0.0) down++;
   if(buffHTF4Down[shift]>0.0) down++;
   
   if(up>=level) return 1;
   else if(down>=level) return -1;
   return 0;
}

int GetLastSignal(int level,int shift,int total)
{
   for(int i=shift;i<(total-1);i++)
   {
      int up=0;
      if(buffHTF1Up[i]>0.0) up++;
      if(buffHTF2Up[i]>0.0) up++;
      if(buffHTF3Up[i]>0.0) up++;
      if(buffHTF4Up[i]>0.0) up++;
   
      int down=0;
      if(buffHTF1Down[i]>0.0) down++;
      if(buffHTF2Down[i]>0.0) down++;
      if(buffHTF3Down[i]>0.0) down++;
      if(buffHTF4Down[i]>0.0) down++;
      
      if(up>=level) return 1;
      else if(down>=level) return -1;
   }
   return 0;
}

void Alarm(string body)
{
   string shortName="4TF HA "+Symbol()+" ";
   if(soundAlert)
   {
      PlaySound("alert.wav");
   }
   if(popupAlert)
   {
      Alert(shortName,body);
   }
   if(emailAlert)
   {
      SendMail("From "+shortName,shortName+body);
   }
   if(pushAlert)
   {
      SendNotification(shortName+body);
   }
}

datetime RoundTime(datetime dt)
{
   MqlDateTime mdt;
   TimeToStruct(dt,mdt);
   mdt.sec=0;
   return StructToTime(mdt);
}