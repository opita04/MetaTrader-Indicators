//+------------------------------------------------------------------+
//|                                                   Median Bar.mq4 |
//| Programmed by Alex Pyrkov (email me pyrkov.programmer@gmail.com) |
//+------------------------------------------------------------------+
#property copyright "Jaime Bohl"
#property version   "1.02"
//Owner Jaime Bohl
//version 1.00 by Alex Pyrkov Sep 26, 2024
//version 1.01 by Alex Pyrkov Sep 27, 2024
//version 1.02 by Alex Pyrkov Sep 30, 2024

#define ROWS_COMMENT 5
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_color1 Black

const string BotName="Median Bar";
const string prefix="JBMB_";

enum RANGE
{
   raOpenClose,//Only body (open/close)
   raLowHigh,//Low to high
};

input RANGE CandleRange=raOpenClose;
input int Period1=10;
input int Period2=1000;
input double ThresholdExtreme=250;//Threshold extreme, percent
input double ThresholdFast=125;//Threshold fast, percent
input double ThresholdSlow=75;//Threshold slow, percent
input string VisualizationHeader="=== Visualization ===";
input int CornerMain=3; //0=CORNER_LEFT_UPPER, 1=CORNER_LEFT_LOWER, 2=CORNER_RIGHT_UPPER, 3=CORNER_RIGHT_LOWER
input int XIndent=20;
input int YIndent=20;
input int Width=360;
input int Height=30;
input string FontMain="Copperplate Gothic Bold";
input int FontSizeMain=16;

input color FGExtreme=Fuchsia;
input color FGFast=FireBrick;
input color FGNormal=SkyBlue;
input color FGSlow=OldLace;
input color BG=Black;

input int CornerComment=1; //0=CORNER_LEFT_UPPER, 1=CORNER_LEFT_LOWER, 2=CORNER_RIGHT_UPPER, 3=CORNER_RIGHT_LOWER
input int XIndentComment=20;
input int YIndentComment=20;
input int WidthComment=360;
input int HeightComment=20;
input string FontComment="Arial Bold";
input int FontSizeComment=11;
input color FGComment=Black;
input color BGComment=OldLace;

input bool LegendComment=true;
input bool LegendTooltip=true;


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
   ~CellContent(){};
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
      m_bg=CLR_NONE;
      m_fg=CLR_NONE;
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
   int brdType;
   color txtColor;
   color bkColor;
   color brdColor;
   int corner;


   CellStyle()
   {

   }
   CellStyle(int iW,int iH,string iFont,int iFontSize,int ibrdWidth,color itxtColor,color ibkColor,color ibrdColor,int icorner,int ibrdType=0)
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
   ~CellStyle()
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

      return &this;
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
   ~Cell()
   {
      ObjectDelete(nmbase+"_text");
      ObjectDelete(nmbase+"_background");
   }

   void Rotate()
   {
      string nm=nmbase+"_text";
      if(ObjectFind(nm)<0)
      {
         ObjectCreate(nm,OBJ_LABEL,0,X,Y);
      }
      if(ObjectFind(nm)>=0)
      {
         ObjectSet(nm,OBJPROP_ANGLE,270);
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
      if(ObjectFind(nm)<0)
      {
         ObjectCreate(nm,OBJ_RECTANGLE_LABEL,0,X,Y);
      }
      if(ObjectFind(nm)>=0)
      {
         ObjectSet(nm,OBJPROP_COLOR,style.brdColor);
         ObjectSet(nm,OBJPROP_STYLE,STYLE_SOLID);
         ObjectSet(nm,OBJPROP_WIDTH,style.brdWidth);
         ObjectSet(nm,OBJPROP_BACK,false);
         ObjectSetText(nm,"",0); // Clear text for background object
         ObjectSet(nm,OBJPROP_SELECTABLE,false);
         ObjectSet(nm,OBJPROP_SELECTED,false);
         ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);
         ObjectSet(nm,OBJPROP_CORNER,style.corner);
         int bg_x_dist=X;
         if(style.corner==2 || style.corner==3) // CORNER_RIGHT_UPPER or CORNER_RIGHT_LOWER
         {
            bg_x_dist=X+style.W;
         }
         int bg_y_dist=Y;
         if(style.corner==1 || style.corner==3) // CORNER_LEFT_LOWER or CORNER_RIGHT_LOWER
         {
            bg_y_dist=Y+style.H;
         }

         ObjectSet(nm,OBJPROP_XDISTANCE,bg_x_dist);
         ObjectSet(nm,OBJPROP_YDISTANCE,bg_y_dist);
      //--- set label size
         ObjectSet(nm,OBJPROP_XSIZE,style.W);
         ObjectSet(nm,OBJPROP_YSIZE,style.H);
      //--- set background color
         ObjectSet(nm,OBJPROP_BGCOLOR,style.bkColor);
         ObjectSet(nm,OBJPROP_BORDER_TYPE,style.brdType);
      }
      nm=nmbase+"_text";
      if(ObjectFind(nm)<0)
      {
         ObjectCreate(nm,OBJ_LABEL,0,X,Y);
      }
      if(ObjectFind(nm)>=0)
      {
         ObjectSet(nm,OBJPROP_COLOR,style.txtColor);
         ObjectSetText(nm,txt,style.FontSize,style.Font,style.txtColor);
         ObjectSet(nm,OBJPROP_BACK,false);
         ObjectSet(nm,OBJPROP_SELECTABLE,false);
         ObjectSet(nm,OBJPROP_SELECTED,false);
         ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);
         ObjectSet(nm,OBJPROP_CORNER,style.corner);
         ObjectSet(nm,OBJPROP_ANCHOR,ANCHOR_CENTER);
         int text_x_dist=X+style.W/2;
         int text_y_dist=Y+style.H/2;

         ObjectSet(nm,OBJPROP_XDISTANCE,text_x_dist);
         ObjectSet(nm,OBJPROP_YDISTANCE,text_y_dist);
      }
   }
};

Cell* g_cell=NULL;
Cell* g_comment[ROWS_COMMENT];

int init()
{
   if(Period1<1)
   {
      Alert("Period1 must be 1 or higher");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(Period2<1)
   {
      Alert("Period2 must be 1 or higher");
      return INIT_PARAMETERS_INCORRECT;
   }
   CellStyle cs(Width,Height,FontMain,FontSizeMain,1,FGNormal,BG,BG,CornerMain);
   g_cell=new Cell(prefix,XIndent,YIndent,"---",cs);

   if(LegendComment)
   {
      CellStyle ccs(WidthComment,HeightComment,FontComment,FontSizeComment,1,FGComment,BGComment,BGComment,CornerComment);
      for(int i=0;i<ROWS_COMMENT;i++)
      {
         g_comment[i]=new Cell(prefix+"cmt_"+IntegerToString(i),XIndentComment,YIndentComment+i*HeightComment,"---",ccs);
      }
   }
   IndicatorShortName(BotName);
   return(INIT_SUCCEEDED);
}

int deinit()
{
   if(g_cell != NULL) delete g_cell;
   for(int i=0;i<ROWS_COMMENT;i++)
   {
      if(g_comment[i] != NULL) delete g_comment[i];
   }
   return(0);
}

int start()
{
   int rates_total=Bars;
   int prev_calculated=0;

   if(rates_total<=(Period1+2) || rates_total<=(Period2+2)) return 0;

   double v1[];
   double v2[];
   if(ArrayResize(v1,Period1)>0 && ArrayResize(v2,Period2)>0)
   {
      ArrayInitialize(v1,0);
      ArrayInitialize(v2,0);
      for(int i=1;i<=Period1;i++)
      {
         v1[i-1]=CandleRange==raOpenClose ? MathAbs(Close[i]-Open[i]) : High[i]-Low[i];
      }
      double m1=GetMedian(v1);
      for(int j=1;j<=Period2;j++)
      {
         v2[j-1]=CandleRange==raOpenClose ? MathAbs(Close[j]-Open[j]) : High[j]-Low[j];
      }
      double m2=GetMedian(v2);
      if(m1>0 && m2>0)
      {
         double percent=m1/m2*100.0;
         string leg[ROWS_COMMENT];
         leg[0]="Median("+IntegerToString(Period2)+") "+DoubleToString(m2/Point,1)+" pts\r\n";
         leg[1]="Extreme("+DoubleToString(ThresholdExtreme,1)+"%) "+DoubleToString(m2*ThresholdExtreme/100.0/Point,1)+" pts\r\n";
         leg[2]="Fast("+DoubleToString(ThresholdFast,1)+"% to "+DoubleToString(ThresholdExtreme,1)+"%) "+DoubleToString(m2*ThresholdFast/100.0/Point,1)+" to " +DoubleToString(m2*ThresholdExtreme/100.0/Point,1)+" pts\r\n";
         leg[3]="Normal("+DoubleToString(ThresholdSlow,1)+"% to "+DoubleToString(ThresholdFast,1)+"%) "+DoubleToString(m2*ThresholdSlow/100.0/Point,1)+" to " +DoubleToString(m2*ThresholdFast/100.0/Point,1)+" pts\r\n";
         leg[4]="Slow("+DoubleToString(ThresholdSlow,1)+"%) "+DoubleToString(m2*ThresholdSlow/100.0/Point,1)+" pts\r\n";
         string legend=leg[0]+
            leg[1]+
            leg[2]+
            leg[3]+
            leg[4];

         string str=percent>=ThresholdFast ?  (percent<ThresholdExtreme ? "FAST" : "EXTREME") : (percent<ThresholdSlow ? "SLOW" : "NORMAL");
         CellContent cc;
         if(LegendComment)
         {
            cc.m_bg=BGComment;
            cc.m_fg=FGComment;
            cc.m_tooltip="\n";
            for(int k=0;k<ROWS_COMMENT;k++)
            {
               int m=k;
               if(CornerComment==1 || CornerComment==3) m=ROWS_COMMENT-k-1; // CORNER_LEFT_LOWER or CORNER_RIGHT_LOWER
               cc.m_txt=leg[m];
               g_comment[k].Apply(cc);
               g_comment[k].Draw();
            }
         }
         cc.m_bg=BG;
         cc.m_fg=percent>=ThresholdFast ? (percent<ThresholdExtreme ? FGFast : FGExtreme) : (percent<ThresholdSlow ? FGSlow : FGNormal);
         cc.m_tooltip=LegendTooltip ? legend : "\n";
         cc.m_txt=str +" bar "+DoubleToString(m1/Point,1)+" pts "+DoubleToString(percent,1)+"%";
         g_cell.Apply(cc);
         g_cell.Draw();
      }
   }
   return rates_total;
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

double GetMedian(double& v[])
{
   int sz=ArraySize(v);
   if(ArraySort(v))
   {
      if((sz&1)>0)
      {
         //odd
         //Print("Odd");
         return v[sz/2];
      }
      else
      {
         //even
         //Print("Even");
         int ind1=sz/2;
         int ind2=sz/2-1;
         return (v[ind1]+v[ind2])/2.0;
      }
   }
   return -1;
}
