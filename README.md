# EABrokenH1Candle
MQL5 EA. Trade Broken H1 Candle for index and Forex Instruments.

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
