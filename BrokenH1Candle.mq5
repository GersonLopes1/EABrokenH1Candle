//+------------------------------------------------------------------+
//|                                               BrokenH1Candle.mq5 |
//|                                                     Gerson Lopes |
//|                         https://www.linkedin.com/in/gersonfilho/ |
//|                                                                  |
//|
//| EA to operate H1 break at Forex and Index instruments            |
//| Forex: Operates every H1 break                                   |
//| Index: Operates only the first H1 candle break                   |
//| SL: Iqual the last H1 candle -15 points                          |
//| TP: Calculate on the value of the last candle * set Risk Return  |
//| * Don't trade inside candles but keep orders.                    |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

MqlRates       mqlRates[];
MqlTick        mqlTick;
MqlDateTime    mqlDateTime;

ulong          codigoEA = 2001;//EA Code:

input uint     riscoRetorno = 1;// Risk Return:
input double   volumePos = 1;// Positions Valume:
input uint     pontosBE = 200;//Points to Break Even (0 to don't use BE):
input uint     pontosTS = 100;//Points to Trailing Stop (0 to don't use TS):
input bool     indexSymbol = false; //Index instrument:

uint           ptsDev = 10;

CTrade         cTrade;
datetime       ultimaOperacao;//control of last Op

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   cTrade.SetExpertMagicNumber(codigoEA);
   cTrade.SetDeviationInPoints(ptsDev);
   cTrade.SetTypeFilling(ORDER_FILLING_IOC);

   Print("EA H1 break initiated. Symbol: ", _Symbol);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("EA H1 break finished. Symbol: ", _Symbol);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//load array data
   CarregarArrays();

//check parameters to execute trade if don't exist pending orders or open position
   if(!ExisteOrdem() && !ExistePosicao() && ultimaOperacao != mqlRates[0].time)
     {
      Operacao(indexSymbol);
     }

//If Exist an Open position, manage it
   if(ExistePosicao())
     {
      GerenciarOrdens();
     }
  }

void OnTrade(void)
  {
   ultimaOperacao = mqlRates[0].time;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Operacao(bool bIndexSymbol)
  {

//Are the last an inside candle?
//This rule don't valid for the first H1 Index Candle.
   bool     bInsideCandle = mqlRates[1].high > mqlRates[2].high || mqlRates[1].low < mqlRates[2].low ? false : true;

//Calc H1 candle points
   double   dPtsCandle = NormalizeDouble(mqlRates[1].high - mqlRates[1].low, _Digits);

   if(bIndexSymbol)
     {
      //No order pending and Open position and executed deal and are the First Candle of Session
      if(!OperacaoRealizada() && IndexPrimeiroCandle())
        {
         InserirOrdem(mqlRates[1].high, mqlRates[1].low, dPtsCandle);
        }
     }
   else
     {
      //No order pending and Open position and aren't a Inside Candle.
      if(!bInsideCandle)
        {
         InserirOrdem(mqlRates[1].high, mqlRates[1].low, dPtsCandle);
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void  InserirOrdem(double dPrcHigh, double dPrcLow, double dPtsCandle)
  {

//Insert pending buy Order
   if(!cTrade.BuyStop(volumePos, dPrcHigh, _Symbol, dPrcLow - 15* _Point, dPrcHigh + riscoRetorno * dPtsCandle))
     {
      PrintFormat("Erro: Insert Buy Stop Order. Result Retcode: %i, -Result Retcode Description: %s", cTrade.ResultRetcode(), cTrade.ResultRetcodeDescription());
      return;
     }

//Insert pending sell Order
   if(!cTrade.SellStop(volumePos, dPrcLow, _Symbol, dPrcHigh + 15* _Point, dPrcLow - riscoRetorno * dPtsCandle))
     {
      PrintFormat("Erro: Insert Sell Stop Order. Result Retcode: %i, -Result Retcode Description: %s", cTrade.ResultRetcode(), cTrade.ResultRetcodeDescription());
      return;
     }
  }

//+------------------------------------------------------------------+
//|Load Arrays Data                                                  |
//+------------------------------------------------------------------+
void CarregarArrays()
  {
   ArraySetAsSeries(mqlRates, true);

   if(CopyRates(_Symbol, PERIOD_H1, 0, 10, mqlRates) == 0)
     {
      Print("Error: Load Array Data mqlRates!");
      return;
     }
   if(!SymbolInfoTick(_Symbol, mqlTick))
     {
      Print("Error: Load Array Data mqlTick!");
      return;
     }
  }

//+------------------------------------------------------------------+
//| Check if exist open position to the Symbol and EA                |
//| and retuns a control bool value                                  |
//+------------------------------------------------------------------+
bool ExistePosicao()
  {

   bool existePosicao = false;

   if(PositionsTotal() > 0)
     {
      for(int i=0; i<PositionsTotal(); i++)
        {
         ulong positionTicket = PositionGetTicket(i);
         if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == codigoEA)
           {
            existePosicao = true;
            break;
           }
        }
     }
   return existePosicao;
  }


//+------------------------------------------------------------------+
//|Admin orders and positions after its creation                     |
//+------------------------------------------------------------------+
void GerenciarOrdens()
  {

// If a side has broken remove the other side pending order
   if(ExistePosicao() && ExisteOrdem())
     {
      for(int i=0; i < OrdersTotal(); i++)
        {
         ulong orderTicket = OrderGetTicket(i);
         if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == codigoEA)
           {
            if(!cTrade.OrderDelete(orderTicket))
              {
               PrintFormat("Error: Delete Order. Ticket: %i", orderTicket);
               return;
              }
           }
        }
     }

// Move BreakEven or Trailling Stop if user setup (input > 0) for use that and the set number of points is reached
   if(ExistePosicao())
     {

      if(pontosBE > 0)
        {
         BreakEven();
        }

      if(pontosTS > 0)
        {
         TrallingStop();
        }
     }
  }

//+------------------------------------------------------------------+
//| Move To Break even by user setup points                          |
//+------------------------------------------------------------------+
void BreakEven()
  {
   for(int i=0; i < PositionsTotal(); i++)
     {
      ulong positionTicket = PositionGetTicket(i);
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == codigoEA)
        {
         double prcEntrada = PositionGetDouble(POSITION_PRICE_OPEN),
                prcSL = PositionGetDouble(POSITION_SL),
                prcTP = PositionGetDouble(POSITION_TP);

         //Move to BreakEven
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && mqlTick.bid >= prcEntrada + pontosBE *_Point && prcSL < prcEntrada)
           {
            if(!cTrade.PositionModify(positionTicket,prcEntrada,prcTP))
              {
               PrintFormat("Error: Buy Position Modify to Break Even. Ticket: %i", positionTicket);
               return;
              }
           }
         else
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && mqlTick.ask <= prcEntrada - pontosBE *_Point && prcSL > prcEntrada)
              {
               if(!cTrade.PositionModify(positionTicket,prcEntrada,prcTP))
                 {
                  PrintFormat("Error: Sell Position Modify to Break Even. Ticket: %i", positionTicket);
                  return;
                 }
              }
        }
     }
  }

//+------------------------------------------------------------------+
//| Move Tralling stop by user setup points                          |
//+------------------------------------------------------------------+
void TrallingStop()
  {
   for(int i=0; i < PositionsTotal(); i++)
     {
      ulong positionTicket = PositionGetTicket(i);
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == codigoEA)
        {
         double prcEntrada = PositionGetDouble(POSITION_PRICE_OPEN),
                prcSL = PositionGetDouble(POSITION_SL),
                prcTP = PositionGetDouble(POSITION_TP);

         //Move TrailingStop
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && mqlTick.bid >= prcSL + pontosTS *_Point)
           {
            if(!cTrade.PositionModify(positionTicket, prcSL + pontosTS *_Point, prcTP))
              {
               PrintFormat("Error: Buy Position Modify trailling stop. Ticket: %i", positionTicket);
               return;
              }
           }
         else
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && mqlTick.ask <= prcSL - pontosTS *_Point)
              {
               if(!cTrade.PositionModify(positionTicket, prcSL - pontosTS *_Point, prcTP))
                 {
                  PrintFormat("Error: Buy Position Modify trailling stop. Ticket: %i", positionTicket);
                  return;
                 }
              }
        }
     }
  }

//+------------------------------------------------------------------+
//|Check if exists pending order to the Symbol and EA                |
//|returns a control bool value                                      |
//+------------------------------------------------------------------+
bool ExisteOrdem()
  {

   bool existeOrdem = false;

   if(OrdersTotal() > 0)
     {
      for(int i=0; i<OrdersTotal(); i++)
        {
         ulong orderTicket = OrderGetTicket(i);
         if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == codigoEA)
           {
            existeOrdem = true;
           }
        }
     }
   return existeOrdem;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|Check if index OP are realized                                    |
//|returns a control bool value                                      |
//+------------------------------------------------------------------+
bool OperacaoRealizada()
  {
   bool                 operacaoRealizada = false;
   datetime             inicioSessao, fimSessao;

//Identify the day of the week and then the Open and End market info
   ENUM_DAY_OF_WEEK     dayOfWeek = DiaDaSemana();
   SymbolInfoSessionTrade(_Symbol, dayOfWeek, 0, inicioSessao, fimSessao);

//Select History with Open and End Session datetime Info.
//Checks if something was done by the EA for the current Symbol
   HistorySelect(inicioSessao, fimSessao);

   if(HistoryDealsTotal() > 0)
     {
      for(int i=HistoryDealsTotal() -1; i <= 0; i--)
        {
         uint        dealTicket = HistoryDealGetTicket(i);
         string      dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
         ulong       dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);

         if(dealMagic == codigoEA && dealSymbol == _Symbol)
           {
            operacaoRealizada = true;
            break;
           }
        }
     }
   return operacaoRealizada;
  }


//+------------------------------------------------------------------+
//|Check if is the first H1 Index Candle                             |
//|returns a control bool value                                      |
//+------------------------------------------------------------------+
bool IndexPrimeiroCandle()
  {
   bool                 indexPrimeiroCandle = false;
   datetime             inicioSessao, fimSessao;

//Identify the day of the week and then the Open and End market info
   ENUM_DAY_OF_WEEK dayOfWeek = DiaDaSemana();
   SymbolInfoSessionTrade(_Symbol, dayOfWeek, 0, inicioSessao, fimSessao);

//check if the last candle closed are the first H1 candle of the Session.
   if(mqlRates[1].time == inicioSessao)
     {
      indexPrimeiroCandle = true;
     }

   return indexPrimeiroCandle;
  }

//+------------------------------------------------------------------+
//|Identify the day of the week and return that                      |
//+------------------------------------------------------------------+
ENUM_DAY_OF_WEEK  DiaDaSemana()
  {

   ENUM_DAY_OF_WEEK  diaDaSemana;

   TimeToStruct(TimeCurrent(), mqlDateTime);

   switch(mqlDateTime.day_of_week)
     {
      case  0:
         diaDaSemana = SUNDAY;
         break;

      case  1:
         diaDaSemana = MONDAY;
         break;

      case  2:
         diaDaSemana = TUESDAY;
         break;

      case  3:
         diaDaSemana = WEDNESDAY;
         break;

      case  4:
         diaDaSemana = THURSDAY;
         break;

      case  5:
         diaDaSemana = FRIDAY;
         break;

      case  6:
         diaDaSemana = SATURDAY;
         break;

      default:
         Print("Error: Session info data with wrong parameters.");
         break;
     }
   return  diaDaSemana;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
