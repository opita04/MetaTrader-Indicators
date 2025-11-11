//+------------------------------------------------------------------+
//|                                                  Turtle Soup.mq4 |
//| Programmed by Alex Pyrkov (email me pyrkov.programmer@gmail.com) |   
//+------------------------------------------------------------------+
#property copyright "Jaime Bohl"
#property version   "1.21"
#property strict
const int account_number = 0;//When 0, all accounts are enabled. If you set real account, the EA will be locked to this account
const int days_to_expire=0;//0 = unlimited

//Owner Jaime Bohl
//version 1.00 by Alex Pyrkov May 04, 2022
//version 1.01 by Alex Pyrkov May 05, 2022
//version 1.10 by Alex Pyrkov May 09, 2022
//version 1.11 by Alex Pyrkov May 11, 2022
//version 1.20 by Alex Pyrkov May 19, 2022
//version 1.21 by Alex Pyrkov May 19, 2022


const string prefix="JBTS_";
const string BotName="TURTLE SOUP";
const ENUM_BASE_CORNER cgiCorner=CORNER_LEFT_UPPER;
const bool MarketWatchSymbolsOnly=true;
const int ALERT_DELAY=60;

enum enRsiTypes
{
   rsi_rsi,  // Regular RSI
   rsi_wil,  // Wilders' RSI
   rsi_rap,  // Rapid RSI
   rsi_har,  // Harris RSI
   rsi_rsx,  // RSX
   rsi_cut   // Cuttlers RSI
};

enum enPrices
{
   pr_close,      // Close
   pr_open,       // Open
   pr_high,       // High
   pr_low,        // Low
   pr_median,     // Median
   pr_typical,    // Typical
   pr_weighted,   // Weighted
   pr_average,    // Average (high+low+open+close)/4
   pr_medianb,    // Average median body (open+close)/2
   pr_tbiased,    // Trend biased price
   pr_tbiased2,   // Trend biased (extreme) price
   pr_haclose,    // Heiken ashi close
   pr_haopen ,    // Heiken ashi open
   pr_hahigh,     // Heiken ashi high
   pr_halow,      // Heiken ashi low
   pr_hamedian,   // Heiken ashi median
   pr_hatypical,  // Heiken ashi typical
   pr_haweighted, // Heiken ashi weighted
   pr_haaverage,  // Heiken ashi average
   pr_hamedianb,  // Heiken ashi median body
   pr_hatbiased,  // Heiken ashi trend biased price
   pr_hatbiased2, // Heiken ashi trend biased (extreme) price
   pr_habclose,   // Heiken ashi (better formula) close
   pr_habopen ,   // Heiken ashi (better formula) open
   pr_habhigh,    // Heiken ashi (better formula) high
   pr_hablow,     // Heiken ashi (better formula) low
   pr_habmedian,  // Heiken ashi (better formula) median
   pr_habtypical, // Heiken ashi (better formula) typical
   pr_habweighted,// Heiken ashi (better formula) weighted
   pr_habaverage, // Heiken ashi (better formula) average
   pr_habmedianb, // Heiken ashi (better formula) median body
   pr_habtbiased, // Heiken ashi (better formula) trend biased price
   pr_habtbiased2 // Heiken ashi (better formula) trend biased (extreme) price
};

enum enMaTypes
{
   ma_sma,    // Simple moving average
   ma_ema,    // Exponential moving average
   ma_smma,   // Smoothed MA
   ma_lwma,   // Linear weighted MA
   ma_tema    // Tripple exponential moving average
};

enum enSignal
{
   sigRSIcrossMA,//Signal on RSI cross MA
   sigRSISlope,//Signal on RSI slope 
};

enum enArrowOn
{
   cc_onRSIcrosslevel,   // Color on RSI cross level
   cc_RSIcrossMA,  // Color on RSI cross MA 
   cc_onSLOPE,   // Color on RSI slope
  
};

enum enTimeFrames
{
   tf_cu  = PERIOD_CURRENT, // Current time frame
   tf_m1  = PERIOD_M1,      // 1 minute
   tf_m5  = PERIOD_M5,      // 5 minutes
   tf_m15 = PERIOD_M15,     // 15 minutes
   tf_m30 = PERIOD_M30,     // 30 minutes
   tf_h1  = PERIOD_H1,      // 1 hour
   tf_h4  = PERIOD_H4,      // 4 hours
   tf_d1  = PERIOD_D1,      // Daily
   tf_w1  = PERIOD_W1,      // Weekly
   tf_mn1 = PERIOD_MN1,     // Monthly
   tf_n1  = -1,             // First higher time frame
   tf_n2  = -2,             // Second higher time frame
   tf_n3  = -3              // Third higher time frame
};



input string SignalHeader="=== Signal's settings ===";
input int BackFrom=3;
input int BackTo=4;
input int ForwardFrom=8;
input int ForwardTo=60;
input int SL_Addition_Points=40;
input int MaxConfirmationBars=15;
input string MaskSymbols="AUDCAD,AUDCHF,AUDJPY,AUDNZD,AUDUSD,CADCHF,CADJPY,CHFJPY,EURAUD,EURCAD,EURCHF,EURGBP,EURJPY,EURNZD,EURUSD,GBPAUD,GBPCAD,GBPCHF,GBPJPY,GBPNZD,GBPUSD,NZDCAD,NZDCHF,NZDJPY,NZDUSD,USDCAD,USDCHF,USDJPY,US30,UK100,US2000,DE40D";//Symbols filter, empty=all symbols
input double RRTP1=100.0;//Reward to risk for TP1, percent
input int ScanEvery=5;//Scan every, sec




input string RSIFilterHeader="=== RSI Filter settings ===";
input bool UseRSIFilterForBOB=true;
input bool UseRSIFilterForLiveSignal=true;
input bool UseRSIFilterForSignal=true;
input ENUM_TIMEFRAMES rsiChartTF=PERIOD_H1;
input enTimeFrames rsiRSI_TF=tf_h4;
input int             rsiRsiPeriod      = 2;             // RSI period
input enRsiTypes      rsiRsiType            = rsi_rap;
input enPrices        rsiRsiPrice        = pr_close;       // Price to use
input int                rsiAveragePeriod      = 2;             // Average period
input enMaTypes          rsiAverageType        = ma_ema;         // Average type for RSI signal line
input bool   rsiInterpolate      = true;
input enSignal rsiSignal=sigRSISlope;
input int rsiBar=0;//RSI bar, 0 = current(live),1 = just closed etc

input string TimeFilterHeader="=== Time Filter settings ===";
input bool UseTimeFilter=true;
input string OFF_Hours1="20:00-23:59";
input string OFF_Hours2="00:00-00:00";
input string OFF_Hours3="00:00-00:00";
input string OFF_Hours4="00:00-00:00";

input string TimeframesHeader="=== Timeframes's settings ===";
input bool Use_M1=false;
input bool Use_M5=true;
input bool Use_M15=true;
input bool Use_M30=true;
input bool Use_H1=true;
input bool Use_H4=true;
input bool Use_D1=true;
input bool Use_W1=true;
input bool Use_MN1=true;
input string AlertsHeader="=== Alerts ===";
input bool AlertForBOB=true;
input bool AlertLive=true;
input bool soundAlert=true;
input bool popupAlert=true;
input bool emailAlert=false;
input bool pushAlert=true;

input string VisualizationHeader="=== Visualization ===";
input int XIndent=20;
input int YIndent=20;
ENUM_BASE_CORNER BaseCorner=CORNER_LEFT_UPPER;
input color ColorBackground=clrOldLace;
input ENUM_BORDER_TYPE BorderType=BORDER_FLAT;
input string TitleHeader="=== Title ===";
input int TitleHeight=40;
input string TitleFont="Copperplate Gothic Bold";
input int TitleFontSize=16;
input color TitleColor=clrBlack;
input int TitleBorderWidth=1;
input color TitleBrdClr=clrOldLace;
input color TitleBG=clrOldLace;

input int SubTitleHeight=30;
input string SubTitleFont="Copperplate Gothic Bold";
input int SubTitleFontSize=12;
input color SubTitleFG=clrNavy;
input int SubTitleBorderWidth=1;
input color SubTitleBrdClr=C'38,38,38';
input color SubTitleBG=clrLightSteelBlue;


input string TableHeader="=== Table ===";
input int Width=80;
input int Height=15;
input string TableFont="Verdana";
input int TableFontSize=8;
input color TableFG=clrBlack;
input color TableFGBuy=clrDarkGreen;
input color TableFGSell=clrRed;
input color TableFGRSINotConfirmed=clrSilver;
input color TableBGActive=clrAliceBlue;
input color TableBGOffTime=clrGainsboro;
input int TableBorderWidth=1;
input color TableBorderColor=C'38,38,38';

input color ColorPairDefault=clrBlack;
input string BasePair0="AUD";
input color ColorPair0=clrTeal;
input string BasePair1="CAD";
input color ColorPair1=clrSienna;
input string BasePair2="CHF";
input color ColorPair2=clrChocolate;
input string BasePair3="EUR";
input color ColorPair3=clrMediumBlue;
input string BasePair4="GBP";
input color ColorPair4=clrOliveDrab;
input string BasePair5="NZD";
input color ColorPair5=C'0,146,240';
input string BasePair6="USD";
input color ColorPair6=clrRed;

input string HeaderVPatternBuy="= V Pattern BUY =";//---
input color ColorVBuy=clrSteelBlue;
input int WidthVBuy=2;
input ENUM_LINE_STYLE StyleVBuy=STYLE_SOLID;
input string HeaderVPatternSell="= V Pattern SELL =";//---
input color ColorVSell=clrOrangeRed;
input int WidthVSell=2;
input ENUM_LINE_STYLE StyleVSell=STYLE_SOLID;

input string HeaderConfirmationRectangle="= Confirmation Rectangle =";//---
input color ColorCR=clrYellow;
input int WidthCR=2;
input ENUM_LINE_STYLE StyleCR=STYLE_SOLID;
input bool FilledCR=true;//Confirmation rectangle is filled

input string HeaderSLRectangle="= SL Rectangle =";//---
input color ColorSL=clrPink;
input int WidthSL=2;
input ENUM_LINE_STYLE StyleSL=STYLE_SOLID;
input bool FilledSL=true;//SL rectangle is filled

input string HeaderTPRectangle="= TP Rectangle =";//---
input color ColorTP2=clrChartreuse;
input int WidthTP2=2;
input ENUM_LINE_STYLE StyleTP2=STYLE_SOLID;
input bool FilledTP2=true;//TP rectangle is filled

input string HeaderTP1Line="= TP1 line =";//---
input color ColorTP1=clrBlack;
input int WidthTP1=1;
input ENUM_LINE_STYLE StyleTP1=STYLE_DASH;

input string TemplateName="turtle soup";//Template to apply to chart






string m_symbols[];
ENUM_TIMEFRAMES m_timeframes[];
datetime m_init_time=0;
datetime m_lastUpdate=0;

class TimeSpan
{
   public:
   int minutes_from;
   int minutes_to;
   int hours_from;
   int hours_to;
   TimeSpan();
   bool Init(string s);//string format "00:00-00:00"
   bool TimeWithin();
   int TimeCompare(int h1,int m1,int h2,int m2);
};

TimeSpan::TimeSpan(void)
{
   minutes_from=0;
   minutes_to=0;
   hours_from=0;
   hours_to=0;
}

bool TimeSpan::Init(string s)
{
   string ft[];
   int res=StringSplit(s,StringGetCharacter("-",0),ft);
   if(res!=2)
   {
      res=StringSplit(s,StringGetCharacter("_",0),ft);
      if(res!=2) return false;
   }
   string from[];
   res=StringSplit(ft[0],StringGetCharacter(":",0),from);
   if(res!=2) return false;
   string to[];
   res=StringSplit(ft[1],StringGetCharacter(":",0),to);
   if(res!=2) return false;
   
   string shf=from[0];
   string smf=from[1];
   string sht=to[0];
   string smt=to[1];
   if(StringLen(shf)==0 || StringLen(smf)==0 || StringLen(sht)==0 || StringLen(smt)==0) return false;
   minutes_from=(int)StringToInteger(smf);
   minutes_to=(int)StringToInteger(smt);
   hours_from=(int)StringToInteger(shf);
   hours_to=(int)StringToInteger(sht);
   //Print(hours_from,":",minutes_from," ",hours_to,":",minutes_to);
   return true;
}

bool TimeSpan::TimeWithin()
{
   datetime now=TimeCurrent();
   if(TimeCompare(hours_from,minutes_from,hours_to,minutes_to)<=0)
   {
      return ((TimeCompare(TimeHour(now),TimeMinute(now),hours_from,minutes_from)>=0) &&
       (TimeCompare(TimeHour(now),TimeMinute(now),hours_to,minutes_to)<0));
   }
   else
   {
      return ((TimeCompare(TimeHour(now),TimeMinute(now),hours_from,minutes_from)>=0) ||
       (TimeCompare(TimeHour(now),TimeMinute(now),hours_to,minutes_to)<0));
   }
}

int TimeSpan::TimeCompare(int h1,int m1,int h2,int m2)
{
   if(h1>h2) return (1);
   if(h1<h2) return (-1);
   if(m1>m2) return (1);
   if(m1<m2) return (-1);
   return (0);
}

class TimeSpans 
{
   protected:
   TimeSpan* m_items[];
   int m_number;
   public:
   TimeSpans();
   ~TimeSpans();
   bool AddSpan(string s);
   bool TimeWithin();//within at least one timespan
};

TimeSpans::TimeSpans(void)
{
   m_number=0;
}

TimeSpans::~TimeSpans(void)
{
   for(int i=0;i<m_number;i++)
   {
      if(CheckPointer(m_items[i])==POINTER_DYNAMIC) delete m_items[i];
   }
   m_number=0;
}

bool TimeSpans::AddSpan(string s)
{
   if(ArrayResize(m_items,m_number+1)<0) return false;
   m_items[m_number]=new TimeSpan;
   bool res=m_items[m_number].Init(s);
   m_number++;
   return res;
}

bool TimeSpans::TimeWithin(void)
{
   for(int i=0;i<m_number;i++)
   {
      if(m_items[i].TimeWithin()) return true;
   }
   return false;
}

class FilterSymbols
{
   private:   
      string m_items[];
   public:
      FilterSymbols(){Reset();};
      virtual ~FilterSymbols(){};
      bool Init(string mask)
      {
         if(StringLen(mask)<1)
         {
            //empty, all allowed
            Reset();
            return true;
         }
         ushort u_sep=StringGetCharacter(",",0);
         int res=StringSplit(mask,u_sep,m_items);
         return res>=0;
      }
      void Reset()
      {
         ArrayResize(m_items,0);
      }
      bool Valid(string symb) const
      {
         int sz=ArraySize(m_items);
         if(sz==0) return true;
         for(int i=0;i<sz;i++)
         {
            if(m_items[i]==symb) return true;
         }
         return false;
      }
};

class CellContent
{
   public:
   string m_txt;
   string m_tooltip;
   color m_bg;
   color m_fg;
   CellContent()
   {
      Reset();
   }
   CellContent(const CellContent& x)
   {
      m_txt=x.m_txt;
      m_tooltip=x.m_tooltip;
      m_bg=x.m_bg;
      m_fg=x.m_fg;
   }
   virtual ~CellContent(){};
   CellContent operator=(const CellContent& x)
   {
      m_txt=x.m_txt;
      m_tooltip=x.m_tooltip;
      m_bg=x.m_bg;
      m_fg=x.m_fg;
      return this;
   }
   
   void Reset()
   {
      m_txt="";
      m_tooltip="\n";
      m_bg=clrNONE;
      m_fg=clrNONE;
   }
};

class CellStyle
{
   public:
   int W;
   int H;
   string Font;
   int FontSize;
   int brdWidth;
   ENUM_BORDER_TYPE brdType;
   color txtColor;
   color bkColor;
   color brdColor;
   ENUM_BASE_CORNER corner;
   
   
   CellStyle()
   {
      
   }
   CellStyle(int iW,int iH,string iFont,int iFontSize,int ibrdWidth,color itxtColor,color ibkColor,color ibrdColor,ENUM_BASE_CORNER icorner,ENUM_BORDER_TYPE ibrdType=BORDER_FLAT)
   {
      W=iW;
      H=iH;
      Font=iFont;
      FontSize=iFontSize;
      brdWidth=ibrdWidth;
      txtColor=itxtColor;
      bkColor=ibkColor;
      brdColor=ibrdColor;
      brdType=ibrdType;
      corner=icorner;
   }
   virtual ~CellStyle()
   {
   }
   
   CellStyle* operator=(const CellStyle& ss)
   {
      this.W=ss.W;
      this.H=ss.H;
      this.Font=ss.Font;
      this.FontSize=ss.FontSize;
      this.brdWidth=ss.brdWidth;
      this.brdType=ss.brdType;
      this.txtColor=ss.txtColor;
      this.bkColor=ss.bkColor;
      this.brdColor=ss.brdColor;
      this.corner=ss.corner;
      
      return GetPointer(this);
   }
};

class Cell
{
   public:
   string nmbase;
   string txt;
   string ToolTip;
   int X;
   int Y;
   CellStyle style;
   
   Cell()
   {
      ToolTip="\n";
   }
   Cell(string inmbase,int iX,int iY,string itxt,const CellStyle& istyle,string iToolTip="\n")
   {
      nmbase=inmbase;
      X=iX;
      Y=iY;
      txt=itxt;
      style=istyle;
      ToolTip=iToolTip;
   }
   virtual ~Cell()
   {
      ObjectDelete(0,nmbase+"_text");
      ObjectDelete(0,nmbase+"_background");
   }
   
   void Rotate()
   {
      string nm=nmbase+"_text";
      if(ObjectFind(0,nm)<0)
      {
         ObjectCreate(0,nm,OBJ_LABEL,0,X,Y);
      }
      if(ObjectFind(0,nm)>=0)
      {
         ObjectSetDouble(0,nm,OBJPROP_ANGLE,270);
      }   
   }
   void Apply(const CellContent& x)
   {
      txt=x.m_txt;
      ToolTip=x.m_tooltip;
      style.bkColor=x.m_bg;
      style.txtColor=x.m_fg;
   }   
   void Draw()
   {
      string nm=nmbase+"_background";
      if(ObjectFind(0,nm)<0)
      {
         ObjectCreate(0,nm,OBJ_RECTANGLE_LABEL,0,X,Y);
      }
      if(ObjectFind(0,nm)>=0)
      {
         ObjectSetInteger(0,nm,OBJPROP_COLOR,style.brdColor); 
         ObjectSetInteger(0,nm,OBJPROP_STYLE,STYLE_SOLID); 
         ObjectSetInteger(0,nm,OBJPROP_WIDTH,style.brdWidth); 
         ObjectSetInteger(0,nm,OBJPROP_BACK,false); 
         ObjectSetString(0,nm,OBJPROP_TOOLTIP,ToolTip);          
         ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false); 
         ObjectSetInteger(0,nm,OBJPROP_SELECTED,false); 
         ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);
         ObjectSetInteger(0,nm,OBJPROP_CORNER,style.corner);
         ObjectSetInteger(0,nm,OBJPROP_XDISTANCE,X); 
         ObjectSetInteger(0,nm,OBJPROP_YDISTANCE,Y); 
      //--- set label size 
         ObjectSetInteger(0,nm,OBJPROP_XSIZE,style.W); 
         ObjectSetInteger(0,nm,OBJPROP_YSIZE,style.H); 
      //--- set background color 
         ObjectSetInteger(0,nm,OBJPROP_BGCOLOR,style.bkColor); 
         ObjectSetInteger(0,nm,OBJPROP_BORDER_TYPE,style.brdType);           
      }
      nm=nmbase+"_text";
      if(ObjectFind(0,nm)<0)
      {
         ObjectCreate(0,nm,OBJ_LABEL,0,X,Y);
      }
      if(ObjectFind(0,nm)>=0)
      {
         ObjectSetInteger(0,nm,OBJPROP_COLOR,style.txtColor);
         ObjectSetString(0,nm,OBJPROP_FONT,style.Font);
         ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,style.FontSize); 
         ObjectSetString(0,nm,OBJPROP_TEXT,txt);    
         ObjectSetString(0,nm,OBJPROP_TOOLTIP,ToolTip);    
         ObjectSetInteger(0,nm,OBJPROP_BACK,false); 
         ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false); 
         ObjectSetInteger(0,nm,OBJPROP_SELECTED,false); 
         ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);
         ObjectSetInteger(0,nm,OBJPROP_CORNER,style.corner);
         ObjectSetInteger(0,nm,OBJPROP_ANCHOR,ANCHOR_CENTER);
         int x_dist=X+style.W/2;
         if(cgiCorner==CORNER_RIGHT_UPPER || cgiCorner==CORNER_RIGHT_LOWER)
         {
            x_dist=X-style.W/2;
         }   
         int y_dist=Y+style.H/2;
         if(cgiCorner==CORNER_LEFT_LOWER || cgiCorner==CORNER_RIGHT_LOWER)
         {
            y_dist=Y-style.H/2;
         }   

         ObjectSetInteger(0,nm,OBJPROP_XDISTANCE,x_dist); 
         ObjectSetInteger(0,nm,OBJPROP_YDISTANCE,y_dist); 
      }   
   }   
};

class ModelItem;
//!!! 
class ViewTable
{
   Cell* m_cellH1;
   Cell* m_cellH2[];
   Cell* m_cellTable[];
   ModelItem m_items[];
   public:
   ViewTable()
   {
   };
   virtual ~ViewTable()
   {
      if(CheckPointer(m_cellH1)==POINTER_DYNAMIC) delete m_cellH1;
      for(int i=0;i<ArrayRange(m_cellH2,0);i++)
      {
         if(CheckPointer(m_cellH2[i])==POINTER_DYNAMIC) delete m_cellH2[i];
      } 
      for(int i=0;i<ArrayRange(m_cellTable,0);i++)
      {
         if(CheckPointer(m_cellTable[i])==POINTER_DYNAMIC) delete m_cellTable[i];
      }
   }
   bool Init()
   {
      bool res=true;
      CellStyle th1(NumberOfCol()*(Width-1),TitleHeight,TitleFont,TitleFontSize,TitleBorderWidth,TitleColor,TitleBG,TitleBrdClr,cgiCorner);
      m_cellH1=new Cell(Prefix()+"_H1_",XIndent,YIndent,BotName,th1);
      CellStyle th2(Width,SubTitleHeight,SubTitleFont,SubTitleFontSize,SubTitleBorderWidth,SubTitleFG,SubTitleBG,SubTitleBrdClr,cgiCorner);
      if(ArrayResize(m_cellH2,NumberOfCol())>0)
      {
         for(int i=0;i<NumberOfCol();i++)
         {
            m_cellH2[i]=new Cell(Prefix()+"_H2_"+IntegerToString(i),XIndent+i*(Width-1),YIndent+TitleHeight-1,"",th2);
            if(i==0) m_cellH2[i].txt="PAIR";
            else m_cellH2[i].txt=HumanCompressionShort(m_timeframes[i-1]);
         }
      }
      else res=false;
      int total=ArraySize(m_symbols);
      if(ArrayResize(m_cellTable,total*NumberOfCol())>=0)
      {
         CellStyle tt(Width,Height,TableFont,TableFontSize,TableBorderWidth,TableFG,TableBGActive,TableBorderColor,cgiCorner);
         for(int i=0;i<total;i++)
         {
            for(int j=0;j<NumberOfCol();j++)
            {
               m_cellTable[i*NumberOfCol()+j]=new Cell(PrefixTable()+IntegerToString(i)+"_"+IntegerToString(j),XIndent+j*(Width-1),YIndent+TitleHeight+SubTitleHeight-2+i*(Height-1)," ",tt); 
            }
         }         
      }
      else res=false;
      if(ArrayResize(m_items,total)>=0)
      {
         for(int i=0;i<total;i++)
         {
            m_items[i].Reset();
            m_items[i].m_pair=m_symbols[i];
         }      
      }
      else res=false;
      
            
      return res;
   }
   bool Update()
   {
      bool res=false;
      VM vm[];
      if(ArrayResize(vm,ArrayRange(m_items,0))>0)
      {
         res=true;
         for(int i=0;i<ArrayRange(m_items,0);i++)
         {
            if(IsStopped()) return false;
            if(!m_items[i].Update(vm[i])) res=false;
         }
         if(res)
         {
            //simple bubble sort
            for(int i = 0; i < (ArraySize(vm)-1); i++)
            {      
               for(int j = i+1; j < ArraySize(vm); j++)
               {
                  if(vm[j]>vm[i])
                  {
                     VM tmp=vm[i];
                     vm[i]=vm[j];
                     vm[j]=tmp;
                  }      
               }
            }
         }
         if(CheckPointer(m_cellH1)==POINTER_DYNAMIC) m_cellH1.Draw();
         for(int i=0;i<ArrayRange(m_cellH2,0);i++)
         {
            if(CheckPointer(m_cellH2[i])==POINTER_DYNAMIC) m_cellH2[i].Draw();
         }
         
         for(int i=0;i<ArrayRange(m_symbols,0);i++)
         {
            for(int j=0;j<NumberOfCol();j++)
            {
               if(CheckPointer(m_cellTable[i*NumberOfCol()+j])==POINTER_DYNAMIC)
               {
                  m_cellTable[i*NumberOfCol()+j].Apply(vm[i].cc[j]);
                  m_cellTable[i*NumberOfCol()+j].Draw();
               }
            }
         }
      }         
      return res;
   }
   string Prefix() const
   {
      return prefix+"ViewTable_";
   }
   string PrefixTable() const
   {
      return Prefix()+"Table_";
   }
   void OnClick(string obj_name,int X,int Y)
   {
      //Print(obj_name);
      if(StringFind(obj_name,PrefixTable())>=0)
      {
         StringReplace(obj_name,PrefixTable(),"");
         string s[];
         string sep="_";                
         ushort u_sep=StringGetCharacter(sep,0);
         //Print(obj_name);
         int res=StringSplit(obj_name,u_sep,s);
         if(res==3)
         {
            int i=(int)StringToInteger(s[0]);
            int j=(int)StringToInteger(s[1]);
            //Print("i="+IntegerToString(i)+" j="+IntegerToString(j));
            if(j>0)
            {
               long cid=ChartOpen(m_symbols[i],m_timeframes[j-1]);
               if(StringLen(TemplateName)>0)
               {
                  ChartApplyTemplate(cid,TemplateName);
               }
            }
         }
      }
   }      
};

//!!! VM to draw a row
class VM 
{
   public:
   CellContent cc[];
   VM()
   {
      ArrayResize(cc,NumberOfCol());
      Reset();
   }
   VM(const VM& x)
   {
      ArrayResize(cc,ArraySize(x.cc));
      for(int i=0;i<ArraySize(cc);i++)
      {
         cc[i]=x.cc[i];
      }
   }
   virtual ~VM(){};
   VM operator=(const VM& x)
   {
      ArrayResize(cc,ArraySize(x.cc));
      for(int i=0;i<ArraySize(cc);i++)
      {
         cc[i]=x.cc[i];
      }
      return this;
   }
   bool operator>(const VM& x) const
   {
      return StringCompare(cc[0].m_txt,x.cc[0].m_txt,false)<0;
   }         
   void Reset()
   {
      for(int i=0;i<ArraySize(cc);i++)
      {
         cc[i].Reset();
      }
   }
};


//!!! 
class ModelItem
{
   public:
   string m_pair;
   datetime m_lastAlert[];
   datetime m_lastAlertLive[];
   datetime m_bob[];
   datetime m_extreme[];
   //-1,+1 = bob -2,+2 = confirmed
   int m_signal[];
   double m_entry[];
   double m_sl[];
   double m_tp1[];
   double m_tp2[];
   int m_back;
   int m_forward;
   
   ModelItem()
   {
      Reset();
   }     
   ModelItem(string pair)
   {
      Reset();
      m_pair=pair;
   }     
   ModelItem(const ModelItem& x)
   {
      m_pair=x.m_pair;
      for(int i=0;i<ArraySize(m_lastAlert) && i<ArraySize(x.m_lastAlert);i++)
      {
         m_lastAlert[i]=x.m_lastAlert[i];
      }
      for(int i=0;i<ArraySize(m_lastAlertLive) && i<ArraySize(x.m_lastAlertLive);i++)
      {
         m_lastAlertLive[i]=x.m_lastAlertLive[i];
      }
      for(int i=0;i<ArraySize(m_bob) && i<ArraySize(x.m_bob);i++)
      {
         m_bob[i]=x.m_bob[i];
      }
      for(int i=0;i<ArraySize(m_extreme) && i<ArraySize(x.m_extreme);i++)
      {
         m_extreme[i]=x.m_extreme[i];
      }
      
      for(int i=0;i<ArraySize(m_signal) && i<ArraySize(x.m_signal);i++)
      {
         m_signal[i]=x.m_signal[i];
      }
      for(int i=0;i<ArraySize(m_entry) && i<ArraySize(x.m_entry);i++)
      {
         m_entry[i]=x.m_entry[i];
      }
      for(int i=0;i<ArraySize(m_sl) && i<ArraySize(x.m_sl);i++)
      {
         m_sl[i]=x.m_sl[i];
      }
      for(int i=0;i<ArraySize(m_tp1) && i<ArraySize(x.m_tp1);i++)
      {
         m_tp1[i]=x.m_tp1[i];
      }
      for(int i=0;i<ArraySize(m_tp2) && i<ArraySize(x.m_tp2);i++)
      {
         m_tp2[i]=x.m_tp2[i];
      }
      m_back=x.m_back;
      m_forward=x.m_forward;
   }
   virtual ~ModelItem(){};
   ModelItem operator=(const ModelItem& x)
   {
      m_pair=x.m_pair;
      for(int i=0;i<ArraySize(m_lastAlert) && i<ArraySize(x.m_lastAlert);i++)
      {
         m_lastAlert[i]=x.m_lastAlert[i];
      }
      for(int i=0;i<ArraySize(m_lastAlertLive) && i<ArraySize(x.m_lastAlertLive);i++)
      {
         m_lastAlertLive[i]=x.m_lastAlertLive[i];
      }      
      for(int i=0;i<ArraySize(m_bob) && i<ArraySize(x.m_bob);i++)
      {
         m_bob[i]=x.m_bob[i];
      }
      for(int i=0;i<ArraySize(m_extreme) && i<ArraySize(x.m_extreme);i++)
      {
         m_extreme[i]=x.m_extreme[i];
      }
      
      for(int i=0;i<ArraySize(m_signal) && i<ArraySize(x.m_signal);i++)
      {
         m_signal[i]=x.m_signal[i];
      }
      for(int i=0;i<ArraySize(m_entry) && i<ArraySize(x.m_entry);i++)
      {
         m_entry[i]=x.m_entry[i];
      }
      for(int i=0;i<ArraySize(m_sl) && i<ArraySize(x.m_sl);i++)
      {
         m_sl[i]=x.m_sl[i];
      }
      for(int i=0;i<ArraySize(m_tp1) && i<ArraySize(x.m_tp1);i++)
      {
         m_tp1[i]=x.m_tp1[i];
      }
      for(int i=0;i<ArraySize(m_tp2) && i<ArraySize(x.m_tp2);i++)
      {
         m_tp2[i]=x.m_tp2[i];
      }
      m_back=x.m_back;
      m_forward=x.m_forward;      
      return this;
   }
   
   void Reset()
   {
      m_pair="";
      ArrayResize(m_lastAlert,ArraySize(m_timeframes));
      ArrayInitialize(m_lastAlert,0);
      ArrayResize(m_lastAlertLive,ArraySize(m_timeframes));
      ArrayInitialize(m_lastAlertLive,0);
      ArrayResize(m_bob,ArraySize(m_timeframes));
      ArrayInitialize(m_bob,0);
      ArrayResize(m_extreme,ArraySize(m_timeframes));
      ArrayInitialize(m_extreme,0);
      ArrayResize(m_signal,ArraySize(m_timeframes));
      ArrayInitialize(m_signal,0);
      ArrayResize(m_entry,ArraySize(m_timeframes));
      ArrayInitialize(m_entry,0);
      ArrayResize(m_sl,ArraySize(m_timeframes));
      ArrayInitialize(m_sl,0);
      ArrayResize(m_tp1,ArraySize(m_timeframes));
      ArrayInitialize(m_tp1,0);
      ArrayResize(m_tp2,ArraySize(m_timeframes));
      ArrayInitialize(m_tp2,0);
      m_back=0;
      m_forward=0;
      
      ResetModel();
   }
   void ResetModel()
   {
      //!!!TODO
   }
   void ResetSignal()
   {
      ArrayInitialize(m_bob,0);
      ArrayInitialize(m_extreme,0);
      ArrayInitialize(m_signal,0);
      ArrayInitialize(m_entry,-1);
      ArrayInitialize(m_sl,-1);
      ArrayInitialize(m_tp1,-1);
      ArrayInitialize(m_tp2,-1);
      m_back=0;
      m_forward=0;
   }

   bool Update(VM& vm)
   {
      bool res=false;
      vm.Reset();
      bool off_time=(UseTimeFilter && m_off_ts.TimeWithin());

      vm.cc[0].m_tooltip="\n";
      vm.cc[0].m_txt=m_pair;
      vm.cc[0].m_fg=ColorPair(m_pair);
      vm.cc[0].m_bg=off_time ? TableBGOffTime : TableBGActive;
      
      for(int i=0;i<ArraySize(m_timeframes);i++)
      {
         if(IsStopped()) return false;
         vm.cc[i+1].m_tooltip="\n";
         vm.cc[i+1].m_txt=" ";
         vm.cc[i+1].m_fg=TableFG;
         vm.cc[i+1].m_bg=off_time ? TableBGOffTime : TableBGActive;;         

         
         int ind;
         datetime dt;
         double val;
         int digits=(int)SymbolInfoInteger(m_pair,SYMBOL_DIGITS);
         double pt=SymbolInfoDouble(m_pair,SYMBOL_POINT);
         bool live=false;
         if(m_signal[i]==1)
         {
            int ind_b=iBarShift(m_pair,m_timeframes[i],m_bob[i]);
            if(ind_b>MaxConfirmationBars) ResetSignal();
            else if(ind_b>=0)
            {
               int ind_l=iLowest(m_pair,m_timeframes[i],MODE_LOW,ind_b+1,0);
               if(ind_l>=0)
               {
                  m_sl[i]=iLow(m_pair,m_timeframes[i],ind_l)-pt*SL_Addition_Points;
               }
               if(AlertLive)
               {
                  if(ind_b>=1)
                  {
                     int ind_c=iHighest(m_pair,m_timeframes[i],MODE_CLOSE,ind_b,0);
                     if(ind_c>=0 && m_entry[i]>0 && m_sl[i]>0)
                     {
                        if(iClose(m_pair,m_timeframes[i],ind_c)>m_entry[i])
                        {
                           int ind_e=iBarShift(m_pair,m_timeframes[i],m_extreme[i]);
                           if(ind_e>=0)
                           {
                              int ind_v=iHighest(m_pair,m_timeframes[i],MODE_HIGH,ind_e-ind_b,ind_b);
                              if(ind_v>=0)
                              {
                                 //signal live buy
                                 bool rsi_ok=!UseRSIFilterForLiveSignal || GetRSISignal(m_pair,rsiChartTF,rsiRSI_TF)>0;
                                 m_tp1[i]=m_entry[i]+(m_entry[i]-m_sl[i])*RRTP1/100.0;
                                 m_tp2[i]=iHigh(m_pair,m_timeframes[i],ind_v);
                                 double pr=SymbolInfoDouble(m_pair,SYMBOL_ASK);
                                 if(m_tp2[i]>m_tp1[i] && pr<m_tp1[i])
                                 {
                                    datetime ladt=iTime(m_pair,m_timeframes[i],0);
                                    if(m_lastAlertLive[i]!=ladt  && rsi_ok)
                                    {
                                       m_lastAlertLive[i]=ladt;
                                       if(!off_time) Alarm(m_pair+" "+HumanCompressionShort(m_timeframes[i])+" LIVE BUY signal at "+DoubleToString(m_entry[i],digits));
                                    }
                                    vm.cc[i+1].m_txt="LIVE BUY";
                                    if(m_back>0 && m_forward>0) vm.cc[i+1].m_tooltip="Back="+IntegerToString(m_back)+" Forward="+IntegerToString(m_forward); 
                                    vm.cc[i+1].m_fg=rsi_ok ? TableFGBuy : TableFGRSINotConfirmed;
                                    vm.cc[i+1].m_bg=off_time ? TableBGOffTime : TableBGActive;
                                    live=true;
                                 }
                              }
                           }
                        }
                     }
                  }
               }
               if(ind_b>1)
               {
                  int ind_c=iHighest(m_pair,m_timeframes[i],MODE_CLOSE,ind_b-1,1);
                  if(ind_c>=0 && m_entry[i]>0 && m_sl[i]>0)
                  {
                     if(iClose(m_pair,m_timeframes[i],ind_c)>m_entry[i])
                     {
                        int ind_e=iBarShift(m_pair,m_timeframes[i],m_extreme[i]);
                        if(ind_e>=0)
                        {
                           int ind_v=iHighest(m_pair,m_timeframes[i],MODE_HIGH,ind_e-ind_b,ind_b);
                           if(ind_v>=0)
                           {
                              //signal buy
                              bool rsi_ok=!UseRSIFilterForSignal|| GetRSISignal(m_pair,rsiChartTF,rsiRSI_TF)>0;
                              m_tp1[i]=m_entry[i]+(m_entry[i]-m_sl[i])*RRTP1/100.0;
                              m_tp2[i]=iHigh(m_pair,m_timeframes[i],ind_v);
                              double pr=SymbolInfoDouble(m_pair,SYMBOL_ASK);
                              if(m_tp2[i]>m_tp1[i] && pr<m_tp1[i])
                              {
                                 datetime ladt=iTime(m_pair,m_timeframes[i],0);
                                 if(m_lastAlert[i]!=ladt  && rsi_ok)
                                 {
                                    m_lastAlert[i]=ladt;
                                    if(!off_time) Alarm(m_pair+" "+HumanCompressionShort(m_timeframes[i])+" BUY signal at "+DoubleToString(m_entry[i],digits));
                                 }
                                 m_signal[i]=2;
                              }
                              else ResetSignal();//TP is not good enough
                           }
                        }
                     }
                  }
               }
               if(!live)
               {
                  bool rsi_ok=!UseRSIFilterForBOB || GetRSISignal(m_pair,rsiChartTF,rsiRSI_TF)>0;
                  vm.cc[i+1].m_txt="BOB";
                  if(m_back>0 && m_forward>0) vm.cc[i+1].m_tooltip="Back="+IntegerToString(m_back)+" Forward="+IntegerToString(m_forward); 
                  vm.cc[i+1].m_fg=rsi_ok ? TableFGBuy : TableFGRSINotConfirmed;
                  vm.cc[i+1].m_bg=off_time ? TableBGOffTime : TableBGActive;
               }
            }
         }
         else if(m_signal[i]==-1)
         {
            int ind_b=iBarShift(m_pair,m_timeframes[i],m_bob[i]);
            if(ind_b>MaxConfirmationBars) ResetSignal();
            else if(ind_b>=0)
            {
               int ind_h=iHighest(m_pair,m_timeframes[i],MODE_HIGH,ind_b+1,0);
               if(ind_h>=0)
               {
                  m_sl[i]=iHigh(m_pair,m_timeframes[i],ind_h)+pt*SL_Addition_Points;
               }
               if(AlertLive)
               {
                  if(ind_b>=1)
                  {
                     int ind_c=iLowest(m_pair,m_timeframes[i],MODE_CLOSE,ind_b,0);
                     if(ind_c>=0 && m_entry[i]>0 && m_sl[i]>0)
                     {
                        if(iClose(m_pair,m_timeframes[i],ind_c)<m_entry[i])
                        {
                           int ind_e=iBarShift(m_pair,m_timeframes[i],m_extreme[i]);
                           if(ind_e>=0)
                           {
                              int ind_v=iLowest(m_pair,m_timeframes[i],MODE_LOW,ind_e-ind_b,ind_b);
                              if(ind_v>=0)
                              {
                                 //signal live sell
                                 bool rsi_ok=!UseRSIFilterForLiveSignal || GetRSISignal(m_pair,rsiChartTF,rsiRSI_TF)<0;                                 
                                 m_tp1[i]=m_entry[i]-(m_sl[i]-m_entry[i])*RRTP1/100.0;
                                 m_tp2[i]=iLow(m_pair,m_timeframes[i],ind_v);
                                 double pr=SymbolInfoDouble(m_pair,SYMBOL_BID);
                                 if(m_tp2[i]<m_tp1[i] && pr>m_tp1[i])
                                 {
                                    datetime ladt=iTime(m_pair,m_timeframes[i],0);
                                    if(m_lastAlertLive[i]!=ladt && rsi_ok)
                                    {
                                       m_lastAlertLive[i]=ladt;
                                       if(!off_time) Alarm(m_pair+" "+HumanCompressionShort(m_timeframes[i])+" LIVE SELL signal at "+DoubleToString(m_entry[i],digits));
                                    }
                                    vm.cc[i+1].m_txt="LIVE SELL";
                                    if(m_back>0 && m_forward>0) vm.cc[i+1].m_tooltip="Back="+IntegerToString(m_back)+" Forward="+IntegerToString(m_forward);                
                                    vm.cc[i+1].m_fg=rsi_ok ? TableFGSell : TableFGRSINotConfirmed;
                                    vm.cc[i+1].m_bg=off_time ? TableBGOffTime : TableBGActive;  
                                    live=true;             
                                 }
                              }
                           }
                        }
                     }
                  }               
               }               
               if(ind_b>1)
               {
                  int ind_c=iLowest(m_pair,m_timeframes[i],MODE_CLOSE,ind_b-1,1);
                  if(ind_c>=0 && m_entry[i]>0 && m_sl[i]>0)
                  {
                     if(iClose(m_pair,m_timeframes[i],ind_c)<m_entry[i])
                     {
                        int ind_e=iBarShift(m_pair,m_timeframes[i],m_extreme[i]);
                        if(ind_e>=0)
                        {
                           int ind_v=iLowest(m_pair,m_timeframes[i],MODE_LOW,ind_e-ind_b,ind_b);
                           if(ind_v>=0)
                           {
                              //signal sell
                              bool rsi_ok=!UseRSIFilterForSignal|| GetRSISignal(m_pair,rsiChartTF,rsiRSI_TF)<0;                              
                              m_tp1[i]=m_entry[i]-(m_sl[i]-m_entry[i])*RRTP1/100.0;
                              m_tp2[i]=iLow(m_pair,m_timeframes[i],ind_v);
                              double pr=SymbolInfoDouble(m_pair,SYMBOL_BID);
                              if(m_tp2[i]<m_tp1[i] && pr>m_tp1[i])
                              {
                                 datetime ladt=iTime(m_pair,m_timeframes[i],0);
                                 if(m_lastAlert[i]!=ladt  && rsi_ok)
                                 {
                                    m_lastAlert[i]=ladt;
                                    if(!off_time) Alarm(m_pair+" "+HumanCompressionShort(m_timeframes[i])+" SELL signal at "+DoubleToString(m_entry[i],digits));
                                 }
                                 m_signal[i]=-2;
                              }
                              else ResetSignal();//TP is not good enough
                           }
                        }
                     }
                  }
               }    
               if(!live)           
               {
                  bool rsi_ok=!UseRSIFilterForBOB || GetRSISignal(m_pair,rsiChartTF,rsiRSI_TF)<0;
                  vm.cc[i+1].m_txt="BOB";
                  if(m_back>0 && m_forward>0) vm.cc[i+1].m_tooltip="Back="+IntegerToString(m_back)+" Forward="+IntegerToString(m_forward);                
                  vm.cc[i+1].m_fg=rsi_ok ? TableFGSell : TableFGRSINotConfirmed;
                  vm.cc[i+1].m_bg=off_time ? TableBGOffTime : TableBGActive;               
               }
            }
         }
         else if(m_signal[i]==2)
         {
            bool rsi_ok=!UseRSIFilterForSignal|| GetRSISignal(m_pair,rsiChartTF,rsiRSI_TF)>0;
            vm.cc[i+1].m_txt="BUY";
            if(m_back>0 && m_forward>0) vm.cc[i+1].m_tooltip="Back="+IntegerToString(m_back)+" Forward="+IntegerToString(m_forward); 

            vm.cc[i+1].m_fg=rsi_ok ? TableFGBuy : TableFGRSINotConfirmed;
            vm.cc[i+1].m_bg=off_time ? TableBGOffTime : TableBGActive;
            double pr=SymbolInfoDouble(m_pair,SYMBOL_BID);
            if(pr>=m_tp2[i] || pr<=m_sl[i]) ResetSignal();               
         }
         else if(m_signal[i]==-2)
         {
            bool rsi_ok=!UseRSIFilterForSignal|| GetRSISignal(m_pair,rsiChartTF,rsiRSI_TF)<0;
            vm.cc[i+1].m_txt="SELL";
            if(m_back>0 && m_forward>0) vm.cc[i+1].m_tooltip="Back="+IntegerToString(m_back)+" Forward="+IntegerToString(m_forward); 
            vm.cc[i+1].m_fg=rsi_ok ? TableFGSell : TableFGRSINotConfirmed;
            vm.cc[i+1].m_bg=off_time ? TableBGOffTime : TableBGActive;
            double pr=SymbolInfoDouble(m_pair,SYMBOL_ASK);
            if(pr<=m_tp2[i] || pr>=m_sl[i]) ResetSignal();               
         }
         else
         {
            for(int j=BackFrom;j<=BackTo;j++)
            {
               if(m_signal[i]!=0) break;
               for(int k=ForwardFrom;k<=ForwardTo;k++)
               {
                  if(m_signal[i]!=0) break;
                  if(IsStopped()) return false;

                  int Forward=k;
                  int Back=j;
                  int start_ind=Forward+2;
                  //check buys
                  if(GetSwingLow(m_pair,m_timeframes[i],start_ind,Back,Forward,ind,dt,val))
                  {
                     if(ind==start_ind)
                     {
                        //found, check bob
                        if(iLow(m_pair,m_timeframes[i],1)<val)
                        {
                           //bob
                           bool rsi_ok=!UseRSIFilterForBOB || GetRSISignal(m_pair,rsiChartTF,rsiRSI_TF)>0;
                           m_back=Back;
                           m_forward=Forward;                           
                           m_signal[i]=1;
                           m_extreme[i]=dt;
                           m_bob[i]=iTime(m_pair,m_timeframes[i],1);
                           m_entry[i]=iHigh(m_pair,m_timeframes[i],1);
                           m_sl[i]=iLow(m_pair,m_timeframes[i],1)-pt*SL_Addition_Points;
                           vm.cc[i+1].m_txt="BOB";
                           vm.cc[i+1].m_tooltip="Back="+IntegerToString(Back)+" Forward="+IntegerToString(Forward);
                           vm.cc[i+1].m_fg=rsi_ok ? TableFGBuy : TableFGRSINotConfirmed;
                           vm.cc[i+1].m_bg=off_time ? TableBGOffTime : TableBGActive;
                           if(AlertForBOB)
                           {
                              double pr=SymbolInfoDouble(m_pair,SYMBOL_BID);
                              datetime ladt=iTime(m_pair,m_timeframes[i],0);
                              if(m_lastAlert[i]!=ladt  && rsi_ok)
                              {
                                 m_lastAlert[i]=ladt;
                                 if(!off_time) Alarm(m_pair+" "+HumanCompressionShort(m_timeframes[i])+" BOB (buy) is formed at "+DoubleToString(pr,digits)+
                                    " Back="+IntegerToString(Back)+" Forward="+IntegerToString(Forward));
                              }                     
                           }
                        }
                     }
                  }
                  //check sells
                  if(GetSwingHigh(m_pair,m_timeframes[i],start_ind,Back,Forward,ind,dt,val))
                  {
                     if(ind==start_ind)
                     {
                        //found, check bob
                        if(iHigh(m_pair,m_timeframes[i],1)>val)
                        {
                           //bob
                           bool rsi_ok=!UseRSIFilterForBOB || GetRSISignal(m_pair,rsiChartTF,rsiRSI_TF)<0;
                           m_back=Back;
                           m_forward=Forward;                                                      
                           m_signal[i]=-1;
                           m_extreme[i]=dt;                  
                           m_bob[i]=iTime(m_pair,m_timeframes[i],1); 
                           m_entry[i]=iLow(m_pair,m_timeframes[i],1);
                           m_sl[i]=iHigh(m_pair,m_timeframes[i],1)+pt*SL_Addition_Points;                                      
                           vm.cc[i+1].m_txt="BOB";
                           vm.cc[i+1].m_tooltip="Back="+IntegerToString(Back)+" Forward="+IntegerToString(Forward);
                           vm.cc[i+1].m_fg=rsi_ok ? TableFGSell : TableFGRSINotConfirmed;
                           vm.cc[i+1].m_bg=off_time ? TableBGOffTime : TableBGActive;
                           if(AlertForBOB)
                           {
                              double pr=SymbolInfoDouble(m_pair,SYMBOL_BID);
                              datetime ladt=iTime(m_pair,m_timeframes[i],0);
                              if(m_lastAlert[i]!=ladt  && rsi_ok)
                              {
                                 m_lastAlert[i]=ladt;
                                 if(!off_time) Alarm(m_pair+" "+HumanCompressionShort(m_timeframes[i])+" BOB (sell) is formed at "+DoubleToString(pr,digits)+
                                    " Back="+IntegerToString(Back)+" Forward="+IntegerToString(Forward));
                              }                     
                           }                     
                        }
                     }
                  }
               }
            }
         }
         //Draw
         if(IsStopped()) return false;
         long cids[];
         if(GetCharts(m_pair,m_timeframes[i],cids))
         {
            for(int j=0;j<ArraySize(cids);j++)
            {
               if(IsStopped()) return false;
               if(m_signal[i]!=0 && m_extreme[i]!=0 && m_bob[i]!=0)
               {
                  int ind_e=iBarShift(m_pair,m_timeframes[i],m_extreme[i]);
                  int ind_b=iBarShift(m_pair,m_timeframes[i],m_bob[i]);
                  if(m_signal[i]>0 && ind_e>=0 && ind_b>=0)
                  {
                     int ind_v=iHighest(m_pair,m_timeframes[i],MODE_HIGH,ind_e-ind_b,ind_b);
                     if(ind_v>=0)
                     {
                        DrawTL(cids[j],prefix+"LEG1",m_extreme[i],iLow(m_pair,m_timeframes[i],ind_e),
                           iTime(m_pair,m_timeframes[i],ind_v),iHigh(m_pair,m_timeframes[i],ind_v),ColorVBuy,WidthVBuy,StyleVBuy);
                        DrawTL(cids[j],prefix+"LEG2",iTime(m_pair,m_timeframes[i],ind_v),iHigh(m_pair,m_timeframes[i],ind_v),
                           iTime(m_pair,m_timeframes[i],ind_b),iLow(m_pair,m_timeframes[i],ind_e),ColorVBuy,WidthVBuy,StyleVBuy);
                     }
                     
                     if(m_signal[i]==1 && m_entry[i]>0 && m_sl[i]>0)
                     {
                        DrawRectangle(cids[j],prefix+"Confirmation",m_bob[i],m_entry[i],iTime(m_pair,m_timeframes[i],0),m_sl[i],ColorCR,WidthCR,StyleCR,FilledCR);
                     }
                     
                     if(m_signal[i]==2) ObjectDelete(cids[j],prefix+"Confirmation");
                     
                     if(m_signal[i]==2 && m_entry[i]>0 && m_sl[i]>0)
                     {
                        DrawRectangle(cids[j],prefix+"SL",m_bob[i],m_entry[i],iTime(m_pair,m_timeframes[i],0),m_sl[i],ColorSL,WidthSL,StyleSL,FilledSL);
                     }
                     if(m_signal[i]==2 && m_entry[i]>0 && m_tp2[i]>0)
                     {
                        DrawRectangle(cids[j],prefix+"TP2",m_bob[i],m_entry[i],iTime(m_pair,m_timeframes[i],0),m_tp2[i],ColorTP2,WidthTP2,StyleTP2,FilledTP2);
                     }
                     if(m_signal[i]==2 && m_tp1[i]>0)
                     {
                        DrawTL(cids[j],prefix+"TP1",m_bob[i],m_tp1[i],iTime(m_pair,m_timeframes[i],0),m_tp1[i],ColorTP1,WidthTP1,StyleTP1);                        
                     }
                  }

                  if(m_signal[i]<0 && ind_e>=0 && ind_b>=0)
                  {
                     int ind_v=iLowest(m_pair,m_timeframes[i],MODE_LOW,ind_e-ind_b,ind_b);
                     if(ind_v>=0)
                     {
                        DrawTL(cids[j],prefix+"LEG1",m_extreme[i],iHigh(m_pair,m_timeframes[i],ind_e),
                           iTime(m_pair,m_timeframes[i],ind_v),iLow(m_pair,m_timeframes[i],ind_v),ColorVSell,WidthVSell,StyleVSell);
                        DrawTL(cids[j],prefix+"LEG2",iTime(m_pair,m_timeframes[i],ind_v),iLow(m_pair,m_timeframes[i],ind_v),
                           iTime(m_pair,m_timeframes[i],ind_b),iHigh(m_pair,m_timeframes[i],ind_e),ColorVSell,WidthVSell,StyleVSell);

                     }
                     if(m_signal[i]==-1 && m_entry[i]>0 && m_sl[i]>0)
                     {
                        DrawRectangle(cids[j],prefix+"Confirmation",m_bob[i],m_entry[i],iTime(m_pair,m_timeframes[i],0),m_sl[i],ColorCR,WidthCR,StyleCR,FilledCR);
                     }

                     if(m_signal[i]==-2) ObjectDelete(cids[j],prefix+"Confirmation");
                     
                     if(m_signal[i]==-2 && m_entry[i]>0 && m_sl[i]>0)
                     {
                        DrawRectangle(cids[j],prefix+"SL",m_bob[i],m_entry[i],iTime(m_pair,m_timeframes[i],0),m_sl[i],ColorSL,WidthSL,StyleSL,FilledSL);
                     }
                     if(m_signal[i]==-2 && m_entry[i]>0 && m_tp2[i]>0)
                     {
                        DrawRectangle(cids[j],prefix+"TP2",m_bob[i],m_entry[i],iTime(m_pair,m_timeframes[i],0),m_tp2[i],ColorTP2,WidthTP2,StyleTP2,FilledTP2);
                     }
                     if(m_signal[i]==-2 && m_tp1[i]>0)
                     {
                        DrawTL(cids[j],prefix+"TP1",m_bob[i],m_tp1[i],iTime(m_pair,m_timeframes[i],0),m_tp1[i],ColorTP1,WidthTP1,StyleTP1);                        
                     }
                     
                  }

               }
               else
               {
                  //delete all
                  ObjectDelete(cids[j],prefix+"LEG1");
                  ObjectDelete(cids[j],prefix+"LEG2");
                  ObjectDelete(cids[j],prefix+"Confirmation");
                  ObjectDelete(cids[j],prefix+"SL");
                  ObjectDelete(cids[j],prefix+"TP1");
                  ObjectDelete(cids[j],prefix+"TP2");
               }
            }
         }         
      }
      
      return res;
   }
   bool operator>(const ModelItem& x) const
   {
      return StringCompare(m_pair,x.m_pair,false)<0;
   }      
};
 
  
long m_chartInitParams[14];
ViewTable* m_table;
//order repetition
int repeat=15;
int sleep_interval=1000;
int m_tzoffset=0;
datetime m_lastTime[];
TimeSpans* m_off_ts;

int OnInit()
{
	if(AccountNumber()!=account_number && account_number!=0)
	{
		Alert("Account is not allowed");
		return(INIT_FAILED);
	}
	if(TimeCurrent()>(__DATETIME__+days_to_expire*24*3600) && days_to_expire>0)
	{
		Alert("Dashboard is expired");
		return(INIT_FAILED);
	}
	else if(days_to_expire>0)
	{
	   Print("This version will expire "+TimeToString(__DATETIME__+days_to_expire*24*3600));
	}

   FilterSymbols filter;
   if(!filter.Init(MaskSymbols))
   {
      Alert("Cannot read Symbols Filter. Please, use comma as separator or leave blank to accept all symbols");
      return INIT_PARAMETERS_INCORRECT;
      
   }
   int symbolsCount = SymbolsTotal(MarketWatchSymbolsOnly);
   int sz=0;
   for(int i = 0; i < symbolsCount; i++)
   {      
      string symb=SymbolName(i, MarketWatchSymbolsOnly);
      if(filter.Valid(symb))
      {
         if(ArrayResize(m_symbols,sz+1)>0)
         {
            m_symbols[sz++] = symb; 
         }
         else
         {
            Alert("Memory allocation error. Please, restart the EA");
            return INIT_FAILED;         
         }
      }
   }
   
   Sort(m_symbols);   


   int counter=0;
   if(Use_M1) counter++;
   if(Use_M5) counter++;
   if(Use_M15) counter++;
   if(Use_M30) counter++;
   if(Use_H1) counter++;
   if(Use_H4) counter++;
   if(Use_D1) counter++;
   if(Use_W1) counter++;
   if(Use_MN1) counter++;
   
   ArrayResize(m_timeframes,counter);
   int i=0;
   if(Use_M1)
   {
      m_timeframes[i++]=PERIOD_M1;
   }
   if(Use_M5)
   {
      m_timeframes[i++]=PERIOD_M5;
   }
   if(Use_M15)
   {
      m_timeframes[i++]=PERIOD_M15;
   }
   if(Use_M30) m_timeframes[i++]=PERIOD_M30;
   if(Use_H1) m_timeframes[i++]=PERIOD_H1;
   if(Use_H4) m_timeframes[i++]=PERIOD_H4;
   if(Use_D1) m_timeframes[i++]=PERIOD_D1;
   if(Use_W1) m_timeframes[i++]=PERIOD_W1;
   if(Use_MN1) m_timeframes[i++]=PERIOD_MN1;

   m_table=new ViewTable();
   if(!m_table.Init())
   {
      Alert("ERROR: Insufficient memory");
      return INIT_FAILED;
   }
   if(ArrayResize(m_lastTime,ArraySize(m_symbols)*ArraySize(m_timeframes))<0)
   {
      Alert("ERROR: Insufficient memory");
      return INIT_FAILED;
   }
   ArrayInitialize(m_lastTime,0);
   m_off_ts=new TimeSpans;
   if(UseTimeFilter)
   {
      if(!m_off_ts.AddSpan(OFF_Hours1))
      {
         Alert(BotName +" error: Incorrect OFF_Hours1");
         return INIT_PARAMETERS_INCORRECT;
      }
      if(!m_off_ts.AddSpan(OFF_Hours2))
      {
         Alert(BotName +" error: Incorrect OFF_Hours2");
         return INIT_PARAMETERS_INCORRECT;
      }
      if(!m_off_ts.AddSpan(OFF_Hours3))
      {
         Alert(BotName +" error: Incorrect OFF_Hours3");
         return INIT_PARAMETERS_INCORRECT;
      }
      if(!m_off_ts.AddSpan(OFF_Hours4))
      {
         Alert(BotName +" error: Incorrect OFF_Hours4");
         return INIT_PARAMETERS_INCORRECT;
      }
   }
   
   //entire chart
   m_chartInitParams[0]=ChartGetInteger(0,CHART_COLOR_BACKGROUND);
   m_chartInitParams[1]=ChartGetInteger(0,CHART_COLOR_FOREGROUND);
   m_chartInitParams[2]=ChartGetInteger(0,CHART_COLOR_GRID);
   m_chartInitParams[3]=ChartGetInteger(0,CHART_COLOR_CHART_UP);
   m_chartInitParams[4]=ChartGetInteger(0,CHART_COLOR_CHART_DOWN);
   m_chartInitParams[5]=ChartGetInteger(0,CHART_COLOR_CHART_LINE);
   m_chartInitParams[6]=ChartGetInteger(0,CHART_COLOR_CANDLE_BULL);
   m_chartInitParams[7]=ChartGetInteger(0,CHART_COLOR_CANDLE_BEAR);
   m_chartInitParams[8]=ChartGetInteger(0,CHART_SHOW_DATE_SCALE);
   m_chartInitParams[9]=ChartGetInteger(0,CHART_SHOW_PRICE_SCALE);
   m_chartInitParams[10]=ChartGetInteger(0,CHART_SHOW_TRADE_LEVELS);
   m_chartInitParams[11]=ChartGetInteger(0,CHART_FOREGROUND);
   m_chartInitParams[12]=ChartGetInteger(0,CHART_SHOW_ASK_LINE);
   m_chartInitParams[13]=ChartGetInteger(0,CHART_SHOW_BID_LINE);
   
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,ColorBackground);
   ChartSetInteger(0,CHART_COLOR_FOREGROUND,ColorBackground);
   ChartSetInteger(0,CHART_COLOR_GRID,ColorBackground);
   ChartSetInteger(0,CHART_COLOR_CHART_UP,ColorBackground);
   ChartSetInteger(0,CHART_COLOR_CHART_DOWN,ColorBackground);
   ChartSetInteger(0,CHART_COLOR_CHART_LINE,ColorBackground);
   ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,ColorBackground);
   ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,ColorBackground);
   ChartSetInteger(0,CHART_SHOW_DATE_SCALE,false);
   ChartSetInteger(0,CHART_SHOW_PRICE_SCALE,false);
   ChartSetInteger(0,CHART_SHOW_TRADE_LEVELS,false);
   ChartSetInteger(0,CHART_FOREGROUND,false);
   ChartSetInteger(0,CHART_SHOW_ASK_LINE,false);
   ChartSetInteger(0,CHART_SHOW_BID_LINE,false);
   
   
   m_init_time=TimeCurrent();   
   EventSetTimer(ScanEvery);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(CheckPointer(m_off_ts)==POINTER_DYNAMIC) delete m_off_ts;   
   if(CheckPointer(m_table)==POINTER_DYNAMIC) delete m_table;
   if(reason!=REASON_INITFAILED)
   {
      ChartSetInteger(0,CHART_COLOR_BACKGROUND,m_chartInitParams[0]);
      ChartSetInteger(0,CHART_COLOR_FOREGROUND,m_chartInitParams[1]);
      ChartSetInteger(0,CHART_COLOR_GRID,m_chartInitParams[2]);
      ChartSetInteger(0,CHART_COLOR_CHART_UP,m_chartInitParams[3]);
      ChartSetInteger(0,CHART_COLOR_CHART_DOWN,m_chartInitParams[4]);
      ChartSetInteger(0,CHART_COLOR_CHART_LINE,m_chartInitParams[5]);
      ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,m_chartInitParams[6]);
      ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,m_chartInitParams[7]);
      ChartSetInteger(0,CHART_SHOW_DATE_SCALE,m_chartInitParams[8]);
      ChartSetInteger(0,CHART_SHOW_PRICE_SCALE,m_chartInitParams[9]);
      ChartSetInteger(0,CHART_SHOW_TRADE_LEVELS,m_chartInitParams[10]);
      ChartSetInteger(0,CHART_FOREGROUND,m_chartInitParams[11]);
      ChartSetInteger(0,CHART_SHOW_ASK_LINE,m_chartInitParams[12]);
      ChartSetInteger(0,CHART_SHOW_BID_LINE,m_chartInitParams[13]);
   }
   DeleteObjectsByPrefix(prefix);
   
   long cid=ChartFirst();
   do
   {
      if(cid>=0)
      {
         ObjectDelete(cid,prefix+"LEG1");
         ObjectDelete(cid,prefix+"LEG2");
         ObjectDelete(cid,prefix+"Confirmation");
         ObjectDelete(cid,prefix+"SL");
         ObjectDelete(cid,prefix+"TP1");
         ObjectDelete(cid,prefix+"TP2");
      }
      cid=ChartNext(cid);
   }
   while(cid>=0);   
}

void OnTick()
{
   //Print(DoubleToString(GetMACDHistogram(Symbol(),PERIOD_CURRENT,0),5));
   //Update();
}

void OnTimer()
{
   Update();
}

void Update()
{
   //Print(TimeToString(TimeCurrent(),TIME_SECONDS));
   if(!IsStopped())
   {
      if(CheckPointer(m_table)==POINTER_DYNAMIC)
      {
         m_table.Update();
      }
   }
}




bool NotEqual(string symb,double val1, double val2,double acc=1.)
{
   return !IsEqual(symb,val1,val2,acc);
}
bool IsEqual(string symb,double val1, double val2,double acc=1.)
{
   double pt=SymbolInfoDouble(symb,SYMBOL_POINT);
   return (MathAbs(val1-val2)<=(acc*pt));
}




void Sort(string& arr[])
{
   //simple bubble sort
   for(int i = 0; i < (ArraySize(arr)-1); i++)
   {      
      for(int j = i+1; j < ArraySize(arr); j++)
      {
         if(StringCompare(arr[i],arr[j],false)>0)
         {
            string tmp=arr[i];
            arr[i]=arr[j];
            arr[j]=tmp;
         }      
      }
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



void Alarm(string body)
{
   if(TimeCurrent()>(m_init_time+ALERT_DELAY))
   {
      string shortName=BotName+" ";
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
}

bool LegalValue(string symb,double val)
{
   return (!(IsEqual(symb,val,0) || IsEqual(symb,val,EMPTY_VALUE)));
}

int NumberOfCol()
{
   return ArraySize(m_timeframes)+1;
}


bool GetSwingLow(string symb,ENUM_TIMEFRAMES tf,int start_index,int back_period,int forward_period,int& ind,datetime& dt,double& val)
{
   ind=-1;
   dt=0;
   val=-1;
   int tot=iBars(symb,tf);
   if(tot<=(start_index+back_period)) return false;
   bool found=true;
   for(int i=start_index;i<tot;i++)
   {
      found=true;
      for(int j=i+1;((j<tot) && ((j-i)<=back_period));j++)
      {
         if(iLow(symb,tf,j)<iLow(symb,tf,i))
         {
            found=false;
            break;  
         }
      }
      if(found)
      {
         for(int j=i-1;(j>=0 && ((i-j)<=forward_period));j--)
         {
            if(iLow(symb,tf,j)<iLow(symb,tf,i))
            {
               found=false;
               break;  
            }
         }
      }
      if(found) 
      {
         ind=i;
         dt=iTime(symb,tf,i);
         val=iLow(symb,tf,i);
         return true;
      }
   }
   return false;
}

bool GetSwingHigh(string symb,ENUM_TIMEFRAMES tf,int start_index,int back_period,int forward_period,int& ind,datetime& dt,double& val)
{
   ind=-1;
   dt=0;
   val=-1;
   int tot=iBars(symb,tf);
   if(tot<=(start_index+back_period)) return false;
   bool found=true;
   for(int i=start_index;i<tot;i++)
   {
      found=true;
      for(int j=i+1;((j<tot) && ((j-i)<=back_period));j++)
      {
         if(iHigh(symb,tf,j)>iHigh(symb,tf,i))
         {
            found=false;
            break;  
         }
      }
      if(found)
      {
         for(int j=i-1;(j>=0 && ((i-j)<=forward_period));j--)
         {
            if(iHigh(symb,tf,j)>iHigh(symb,tf,i))
            {
               found=false;
               break;  
            }
         }
      }
      if(found)
      {
         ind=i;
         dt=iTime(symb,tf,i);
         val=iHigh(symb,tf,i);
         return true;
      }
   }
   return false;
}

int GetLastTimeIndex(string symb,ENUM_TIMEFRAMES tf)
{
   for(int i=0;i<ArraySize(m_symbols);i++)
   {
      if(m_symbols[i]==symb)
      {
         for(int j=0;j<ArraySize(m_timeframes);j++)
         {
            if(m_timeframes[j]==tf)
            {
               return i*ArraySize(m_timeframes)+j;
            }
         } 
      }
   }
   return -1;
}

color ColorPair(string symb)
{
   int res=StringFind(symb,BasePair0);
   if(res==0 || res==1) return ColorPair0;

   res=StringFind(symb,BasePair1);
   if(res==0 || res==1) return ColorPair1;

   res=StringFind(symb,BasePair2);
   if(res==0 || res==1) return ColorPair2;

   res=StringFind(symb,BasePair3);
   if(res==0 || res==1) return ColorPair3;

   res=StringFind(symb,BasePair4);
   if(res==0 || res==1) return ColorPair4;

   res=StringFind(symb,BasePair5);
   if(res==0 || res==1) return ColorPair5;
   
   res=StringFind(symb,BasePair6);
   if(res==0 || res==1) return ColorPair6;

   return ColorPairDefault;   
}

bool GetCharts(string pair,ENUM_TIMEFRAMES tf,long& cids[],bool ExcludeCurrent=true)
{
   ArrayResize(cids,0);
   long cid=ChartFirst();
   do
   {
      if(cid>=0 && (!ExcludeCurrent || cid!=ChartID()))
      {
         if(ChartSymbol(cid)==pair && ChartPeriod(cid)==tf)
         {
            int sz=ArraySize(cids);
            if(ArrayResize(cids,sz+1)>0)
            {
               cids[sz]=cid;
            }
            else return false;
         }
      }
      cid=ChartNext(cid);
   }
   while(cid>=0);
   return true;
}

void DeleteObjectsByPrefix(string pref)
{
   bool something_removed=true;
   while(something_removed)
   {
      something_removed=false;      
      int tot=ObjectsTotal();   
      for(int i=0;i<tot;i++)
      {
         string nm=ObjectName(i);
         if(StringFind(nm,pref)>=0) 
         {
            ObjectDelete(nm);
            something_removed=true;
            break;      
         }
      }
   }
}

void DrawTL(long cid,string nm,datetime dt1,double pr1,datetime dt2,double pr2,color col,int width,ENUM_LINE_STYLE style)
{
   if(ObjectFind(cid,nm)<0)
   {
      ObjectCreate(cid,nm,OBJ_TREND,0,dt1,pr1,dt2,pr2);
   }
   if(ObjectFind(cid,nm)>=0)
   {
      ObjectSetInteger(cid,nm,OBJPROP_COLOR,col);            
      ObjectSetInteger(cid,nm,OBJPROP_WIDTH,width);
      ObjectSetInteger(cid,nm,OBJPROP_STYLE,style);
      ObjectSetInteger(cid,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(cid,nm,OBJPROP_SELECTED,false);
      ObjectSetInteger(cid,nm,OBJPROP_RAY,false);
      ObjectSetInteger(cid,nm,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(cid,nm,OBJPROP_BACK,false);
      ObjectMove(cid,nm,0,dt1,pr1);
      ObjectMove(cid,nm,1,dt2,pr2);            
   }
}

void DrawRectangle(long cid,string nm,datetime dt1,double pr1,datetime dt2,double pr2,color col,int width,ENUM_LINE_STYLE style,bool back)
{
   if(ObjectFind(cid,nm)<0)
   {
      ObjectCreate(cid,nm,OBJ_RECTANGLE,0,dt1,pr1,dt2,pr2);
   }
   if(ObjectFind(cid,nm)>=0)
   {
      ObjectSetInteger(cid,nm,OBJPROP_COLOR,col);            
      ObjectSetInteger(cid,nm,OBJPROP_WIDTH,width);
      ObjectSetInteger(cid,nm,OBJPROP_STYLE,style);
      ObjectSetInteger(cid,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(cid,nm,OBJPROP_SELECTED,false);
      ObjectSetInteger(cid,nm,OBJPROP_BACK,back);
      ObjectMove(cid,nm,0,dt1,pr1);
      ObjectMove(cid,nm,1,dt2,pr2);            
   }
}


void  OnChartEvent( 
   const int       id,       // event ID  
   const long&     lparam,   // long type event parameter 
   const double&   dparam,   // double type event parameter 
   const string&   sparam    // string type event parameter 
   )
{
   if(id==CHARTEVENT_OBJECT_CLICK)
   {
      if(CheckPointer(m_table)==POINTER_DYNAMIC)
      {
         if(StringFind(sparam,m_table.Prefix())>=0)
         {
            m_table.OnClick(sparam,(int)lparam,(int)dparam);
         }
      }      
   }
}


double GetRSI(string symb,ENUM_TIMEFRAMES tf,enTimeFrames rtf,int mode,int shift)
{
   return iCustom(symb,tf,"RSI ma BT mod 1.1",
      rtf,rsiRsiPeriod,rsiRsiType,rsiRsiPrice,rsiAveragePeriod,rsiAverageType,true,false,clrNONE,60,40,
      clrNONE,clrNONE,2,cc_RSIcrossMA,rsiInterpolate,false,false,false,false,false,false," RSI X",
      false,2,0.5,clrNONE,clrNONE,159,159,2,2,"-",CORNER_LEFT_UPPER,
      "RSI  X","Arial",10,clrNONE,clrNONE,"RSI X OFF","RSI X ON",clrNONE,clrNONE,900,0,                                   
      85,20,"tick.wav","-",
      mode,shift);
}

int GetRSISignal(string symb,ENUM_TIMEFRAMES tf,enTimeFrames rtf)
{
   int shift=rsiBar;
   double main=GetRSI(symb,tf,rtf,0,shift);
   double ma=GetRSI(symb,tf,rtf,5,shift);

   if(rsiSignal==sigRSIcrossMA)
   {  
      if(main>ma)
      {
         return 1;
      }
      else if(main<ma)
      {
         return -1;
      }
   }
   else if(rsiSignal==sigRSISlope)
   {
      double main_p=GetRSI(symb,tf,rtf,0,shift+1);
      if(main>main_p)
      {
         return 1;
      }
      else if(main<main_p)
      {
         return -1;
      }
      else
      {
         int i=shift+1;
         while(i<(iBars(symb,tf)-2))
         {
            main=GetRSI(symb,tf,rtf,0,i);
            main_p=GetRSI(symb,tf,rtf,0,i+1);
            if(main>main_p)
            {
               return 1;
            }
            else if(main<main_p)
            {
               return -1;
            }
            i++;
         }
      }
   }
   return 0;
}