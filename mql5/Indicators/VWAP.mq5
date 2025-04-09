//+------------------------------------------------------------------+
//|                                                        VWAP.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   5

//--- plot VWAP
#property indicator_label1  "VWAP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- plot Zone1Upper
#property indicator_label2  "Zone1Upper"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- plot Zone1Lower
#property indicator_label3  "Zone1Lower"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrRed
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- plot Zone3Upper
#property indicator_label4  "Zone3Upper"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrGreen
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

//--- plot Zone3Lower
#property indicator_label5  "Zone3Lower"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrGreen
#property indicator_style5  STYLE_DOT
#property indicator_width5  1

//--- input parameters
input int      InpVwapPeriod=20;    // VWAP Period
input double   InpZone1Mult=1.0;    // Zone 1 Multiplier
input double   InpZone3Mult=2.0;    // Zone 3 Multiplier

//--- indicator buffers
double         VwapBuffer[];
double         Zone1UpperBuffer[];
double         Zone1LowerBuffer[];
double         Zone3UpperBuffer[];
double         Zone3LowerBuffer[];

//--- global variables
int            vwap_period;
double         zone1_mult;
double         zone3_mult;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator buffers
   SetIndexBuffer(0, VwapBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, Zone1UpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, Zone1LowerBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, Zone3UpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, Zone3LowerBuffer, INDICATOR_DATA);
   
   // Set indicator labels
   PlotIndexSetString(0, PLOT_LABEL, "VWAP (" + string(InpVwapPeriod) + ")");
   PlotIndexSetString(1, PLOT_LABEL, "Zone 1 Upper");
   PlotIndexSetString(2, PLOT_LABEL, "Zone 1 Lower");
   PlotIndexSetString(3, PLOT_LABEL, "Zone 3 Upper");
   PlotIndexSetString(4, PLOT_LABEL, "Zone 3 Lower");
   
   // Set global variables
   vwap_period = InpVwapPeriod;
   zone1_mult = InpZone1Mult;
   zone3_mult = InpZone3Mult;
   
   // Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "VWAP (" + string(vwap_period) + ")");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
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
   // Check for data
   if(rates_total < vwap_period)
      return(0);
   
   // Calculate VWAP
   int start;
   
   // First calculation or if number of bars was changed
   if(prev_calculated == 0)
   {
      start = vwap_period;
      
      // Initialize buffers with empty values
      for(int i = 0; i < start; i++)
      {
         VwapBuffer[i] = 0;
         Zone1UpperBuffer[i] = 0;
         Zone1LowerBuffer[i] = 0;
         Zone3UpperBuffer[i] = 0;
         Zone3LowerBuffer[i] = 0;
      }
   }
   else
      start = prev_calculated - 1;
   
   // Main calculation loop
   for(int i = start; i < rates_total; i++)
   {
      double sum_tp_vol = 0;
      double sum_vol = 0;
      double std_dev = 0;
      
      // Calculate VWAP over the period
      for(int j = 0; j < vwap_period && (i-j) >= 0; j++)
      {
         double typical_price = (high[i-j] + low[i-j] + close[i-j]) / 3;
         double vol = tick_volume[i-j];
         
         sum_tp_vol += typical_price * vol;
         sum_vol += vol;
      }
      
      // Calculate VWAP
      if(sum_vol > 0)
         VwapBuffer[i] = sum_tp_vol / sum_vol;
      else
         VwapBuffer[i] = close[i];
      
      // Calculate standard deviation
      for(int j = 0; j < vwap_period && (i-j) >= 0; j++)
      {
         double typical_price = (high[i-j] + low[i-j] + close[i-j]) / 3;
         double vol = tick_volume[i-j];
         
         std_dev += vol * MathPow(typical_price - VwapBuffer[i], 2);
      }
      
      if(sum_vol > 0)
         std_dev = MathSqrt(std_dev / sum_vol);
      else
         std_dev = 0;
      
      // Calculate zones
      Zone1UpperBuffer[i] = VwapBuffer[i] + std_dev * zone1_mult;
      Zone1LowerBuffer[i] = VwapBuffer[i] - std_dev * zone1_mult;
      Zone3UpperBuffer[i] = VwapBuffer[i] + std_dev * zone3_mult;
      Zone3LowerBuffer[i] = VwapBuffer[i] - std_dev * zone3_mult;
   }
   
   // Return value of prev_calculated for next call
   return(rates_total);
}
//+------------------------------------------------------------------+
