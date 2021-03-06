//+------------------------------------------------------------------+
//|                                            Breakdown_min_max.mq5 |
//|                                                       Konstantin |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Konstantin"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

// TEST1
// TEST2

input ENUM_TIMEFRAMES      Period = 15;     //Период
input int      Lot=1;                       //Размер открываемой позиции
input int      MinMaxPeriod = 60;           //Ширина окна поиска min and max
input int      Ma_Period = 200;             //Период быстрой МА
input int      MinMaxPeriodStop = 20;       //Ширина окна поиска min and max для стопа

//-------Глобальные переменные
int MinMaxHandle,MaHandle,MinMaxStopHandle;                          // хэндл индикатора
string short_name;                 // имя индикатора на графике
double MinPeriod[],MaxPeriod[],MA[],MinPeriodStop[],MaxPeriodStop[];

CTrade m_Trade;
CPositionInfo     m_Position;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---Получим хэндл индикатора
   MaHandle = iMA(_Symbol,Period,Ma_Period,0,MODE_EMA,PRICE_OPEN);
   MinMaxHandle = iCustom(_Symbol,Period,"MaxMinOfThePreviousBar",MinMaxPeriod);
   MinMaxStopHandle = iCustom(_Symbol,Period,"MaxMinOfThePreviousBar",MinMaxPeriod);

   if(MinMaxHandle<0 || MaHandle<0 || MinMaxStopHandle<0)
     {
      Alert("Ошибка при создании индикаторов - номер ошибки: ",GetLastError(),"!!");
      return(-1);
     }
   ChartIndicatorAdd(ChartID(),0,MaHandle);
   ChartIndicatorAdd(ChartID(),0,MinMaxHandle);
   short_name=StringFormat("MaxMinOfThePreviousBar(%s/%s, %G)",_Symbol,EnumToString(Period),MinMaxPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME,short_name);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(!ChartIndicatorDelete(ChartID(),0,short_name))
     {
      PrintFormat("Не удалось удалить индикатор %s с окна #%d. Код ошибки %d",short_name,0,GetLastError());
     }
//--- Освобождаем хэндлы индикаторов
   IndicatorRelease(MinMaxHandle);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Достаточно ли количество баров для работы
   if(Bars(_Symbol,Period)<MinMaxPeriod)
     {
      PrintFormat("На графике меньше %G баров, советник не будет работать!!",MinMaxPeriod);
      return;
     }

   static datetime Old_Time;
   datetime New_Time[1];
   bool IsNewBar=false;

// копируем время текущего бара в элемент New_Time[0]
   int copied=CopyTime(_Symbol,Period,0,1,New_Time);
   if(copied>0)
     {
      if(Old_Time!=New_Time[0])
        {
         IsNewBar=true;
         if(MQL5InfoInteger(MQL5_DEBUGGING))
            PrintFormat("Новый бар ",New_Time[0]," старый бар ",Old_Time);
         Old_Time=New_Time[0];
        }
     }
   else
     {
      PrintFormat("Ошибка копирования времени, номер ошибки =",GetLastError());
      ResetLastError();
      return;
     }

//--- советник должен проверять условия совершения новой торговой операции только при новом баре
   if(IsNewBar==false)
     {
      return;
     }

   MqlRates mrate[];                  // Будет содержать цены, объемы и спред для каждого бара
   ArraySetAsSeries(mrate,true);
   ArraySetAsSeries(MinPeriod,true);
   ArraySetAsSeries(MaxPeriod,true);
   ArraySetAsSeries(MA,true);
   ArraySetAsSeries(MinPeriodStop,true);
   ArraySetAsSeries(MaxPeriodStop,true);

   if(CopyRates(_Symbol,Period,0,3,mrate)<0)
     {
      PrintFormat("Ошибка копирования исторических данных - ошибка:",GetLastError(),"!!");
      return;
     }

   if(CopyBuffer(MinMaxHandle,1,0,3,MinPeriod)<0)      // Значения минимума лежат в 1.
     {
      PrintFormat("Ошибка копирования буферов индикатора MaxMinOfThePreviousBar - номер ошибки:",GetLastError());
      return;
     }

   if(CopyBuffer(MinMaxHandle,0,0,3,MaxPeriod)<0)      // Значения максимума лежат в 0.
     {
      PrintFormat("Ошибка копирования буферов индикатора MaxMinOfThePreviousBar - номер ошибки:",GetLastError());
      return;
     }

   if(CopyBuffer(MinMaxStopHandle,1,0,3,MinPeriodStop)<0)      // Значения минимума лежат в 1.
     {
      PrintFormat("Ошибка копирования буферов индикатора MaxMinOfThePreviousBar - номер ошибки:",GetLastError());
      return;
     }

   if(CopyBuffer(MinMaxStopHandle,0,0,3,MaxPeriodStop)<0)      // Значения максимума лежат в 0.
     {
      PrintFormat("Ошибка копирования буферов индикатора MaxMinOfThePreviousBar - номер ошибки:",GetLastError());
      return;
     }

   if(CopyBuffer(MaHandle,0,0,3,MA)<0)
     {
      Alert("Ошибка копирования буферов индикатора Moving Average - номер ошибки:",GetLastError(),"!!");
      return;
     }
   string symbol = _Symbol;                                      // укажем символ, на котором выставляется ордер
   int    digits = (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS); // количество знаков после запятой
   double point = SymbolInfoDouble(symbol,SYMBOL_POINT);         // пункт

//   1. Проверка условий для покупки :
   if(MA[0] < mrate[0].open && mrate[0].close > MaxPeriod[1]) //&& mrate[0].close > MaxPeriod[1]
     {
      if(m_Position.Select(_Symbol))                             //если уже существует позиция по этому символу
        {
         if(m_Position.PositionType()==POSITION_TYPE_SELL)
           {
            m_Trade.PositionClose(symbol);
           }
         if(m_Position.PositionType()==POSITION_TYPE_BUY)
           {
            return;
           }
        }
      double price_stop = NormalizeDouble(MinPeriodStop[0],digits);
      m_Trade.Buy(Lot,_Symbol,0.0,price_stop,0.0);

     }

//   2. Проверка условий на продажу :
   if(MA[1] > mrate[1].open && mrate[0].close < MinPeriod[1])
     {
      if(m_Position.Select(_Symbol))                             //если уже существует позиция по этому символу
        {
         if(m_Position.PositionType()==POSITION_TYPE_SELL)
           {
            return;
           }
         if(m_Position.PositionType()==POSITION_TYPE_BUY)
           {
            m_Trade.PositionClose(symbol);
           }
        }
      double price_stop  = NormalizeDouble(MaxPeriodStop[0],digits);
      m_Trade.Sell(Lot,_Symbol,0.0,price_stop,0.0);
     }

// 3. Трейлинг Стоп:
   if(m_Position.Select(_Symbol))
     {
      if(m_Position.PositionType()==POSITION_TYPE_BUY)
        {
         if(m_Position.StopLoss()< MinPeriodStop[0])
           {
            double price_stop = NormalizeDouble(MinPeriodStop[0],digits);

            m_Trade.PositionModify(symbol,price_stop,0.0);
           }
        }
      if(m_Position.PositionType()==POSITION_TYPE_SELL)
        {
         if(m_Position.StopLoss()> MaxPeriodStop[0])
           {
            double price_stop = NormalizeDouble(MaxPeriodStop[0],digits);

            m_Trade.PositionModify(symbol,price_stop,0.0);
           }
        }
     }

  }
//+------------------------------------------------------------------+
