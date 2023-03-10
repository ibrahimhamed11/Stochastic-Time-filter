//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2018, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property copyright     "Eng Ibrahim Hamed"
#property link          "https://t.me/ibrahimhamed112"
#property version       "1.00"
#property strict
//#property description  "ibrahim.hamed112@hotmail.com"

/*
ENTRY BUY: when the fast MA crosses the slow from the bottom, both MA are going up
ENTRY SELL: when the fast MA crosses the slow from the top, both MA are going down
EXIT: When Stop Loss or Take Profit are reached or, reaching the upper threshold for buy orders and reaching the lower threshold for sell orders
Only 1 order at a time*/

extern double  Time_Period=PERIOD_H1;   //Time Frame
extern double TPpercent=1.00;           //Tp by percent
extern bool fixedLote=false;
extern double Lot_fixed_Size=0.1;       //fixed lote size
extern double TakeProfit=100;           //Take profit in pips
extern double StopLoss=200;             //Stop loss in pips
int tpPrecent;
double lotSize;
//Position size
extern int Slippage=2;                 //Slippage in pips
extern bool TradeEnabled=true;         //Enable trade
extern int StochK=5;                   //Stochastic K Period, default 5
extern int StochD=3;                   //Stochastic D Period, default 3
extern int StochSlowing=3;              //Stochastic Slowing, default 3
extern int UpperThreshold=80;          //Upper Threshold, default 80
extern int LowerThreShold=20;          //Lower Threshold, default 20
//Functional variables
double ePoint;                         //Point normalized
bool CanOrder;                         //Check for risk management
bool CanOpenBuy;                       //Flag if there are buy orders open
bool CanOpenSell;                      //Flag if there are sell orders open
int OrderOpRetry=10;                   //Number of attempts to perform a trade operation
int SleepSecs=3;                       //Seconds to sleep if can't order
int MinBars=60;                        //Minimum bars in the graph to enable trading

//Functional variables to determine prices
double MinSL;
double MaxSL;
double TP;
double SL;
double Spread;
int Slip;


//Variable initialization function
void Initialize()
  {
   RefreshRates();
   ePoint=Point;
   Slip=Slippage;
   if(MathMod(Digits,2)==1)
     {
      ePoint*=10;
      Slip*=10;
     }
   TP=TakeProfit*ePoint;
   SL=StopLoss*ePoint;
   CanOrder=TradeEnabled;
   CanOpenBuy=true;
   CanOpenSell=true;
  }


//Check if orders can be submitted
void CheckCanOrder()
  {
   if(Bars<MinBars)
     {
      Print("INFO - Not enough Bars to trade");
      CanOrder=false;

     }
   OrdersOpen();
   return;
  }


//Check if there are open orders and what type
void OrdersOpen()
  {
   for(int i = 0 ; i < OrdersTotal() ; i++)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false)
        {
         Print("ERROR - Unable to select the order - ",GetLastError());
         break;
        }
      if(OrderSymbol()==Symbol() && OrderType() == OP_BUY)
         CanOpenBuy=false;
      if(OrderSymbol()==Symbol() && OrderType() == OP_SELL)
         CanOpenSell=false;
     }
   return;
  }


//Close all the orders of a specific type and current symbol
void CloseAll(int Command)
  {
   double ClosePrice=0;
   for(int i = 0 ; i < OrdersTotal() ; i++)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false)
        {
         Print("ERROR - Unable to select the order - ",GetLastError());
         break;
        }
      if(OrderSymbol()==Symbol() && OrderType()==Command)
        {
         if(Command==OP_BUY)
            ClosePrice=Bid;
         if(Command==OP_SELL)
            ClosePrice=Ask;
         double Lots=OrderLots();
         int Ticket=OrderTicket();
         for(int j=1; j<OrderOpRetry; j++)
           {
            bool res=OrderClose(Ticket,Lots,ClosePrice,Slip,Red);
            if(res)
              {
               Print("TRADE - CLOSE - Order ",Ticket," closed at price ",ClosePrice);
               break;
              }
            else
               Print("ERROR - CLOSE - error closing order ",Ticket," return error: ",GetLastError());
           }
        }
     }
   return;
  }


//Open new order of a given type
void OpenNew(int Command)
  {
   RefreshRates();
   double OpenPrice=0;
   double SLPrice = 0;
   double TPPrice = 0;



   if(Command==OP_BUY)
     {
      OpenPrice=Ask;
      SLPrice=OpenPrice-SL;
      TPPrice=OpenPrice+TP;
     }

   if(Command==OP_SELL)
     {
      OpenPrice=Bid;
      SLPrice=OpenPrice+SL;
      TPPrice=OpenPrice-TP;
     }


   for(int i=1; i<OrderOpRetry; i++)
     {
      int res=OrderSend(Symbol(),Command,lotSize,OpenPrice,Slip,NormalizeDouble(SLPrice,Digits),0,"",0,0,Green);
      if(res)
        {
         Print("TRADE - NEW - Order ",res," submitted: Command ",Command," Volume ",lotSize," Open ",OpenPrice," Slippage ",Slip," Stop ",SLPrice," Take ",TPPrice);
         break;
        }
      else
         Print("ERROR - NEW - error sending order, return error: ",GetLastError());
     }
   return;
  }


//Technical analysis of the indicators
bool CrossToOpenBuy=false;
bool CrossToOpenSell=false;
bool CrossToCloseBuy=false;
bool CrossToCloseSell=false;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckStochCross()
  {
//default value
   CrossToOpenBuy=false;
   CrossToOpenSell=false;
   CrossToCloseBuy=false;
   CrossToCloseSell=false;


   double StochPrev=iStochastic(Symbol(),0,StochK,StochD,StochSlowing,MODE_SMA,STO_LOWHIGH,MODE_BASE,1);
   double StochCurr=iStochastic(Symbol(),0,StochK,StochD,StochSlowing,MODE_SMA,STO_LOWHIGH,MODE_BASE,0);
   if(StochCurr<LowerThreShold&&StochPrev<LowerThreShold)
     {
      CrossToOpenBuy=true;
     }
   if(StochCurr>UpperThreshold&&StochPrev>UpperThreshold)
     {
      CrossToOpenSell=true;
     }

//تقاطع فوق ال80

   if(StochCurr>UpperThreshold)
     {
      CrossToCloseBuy=true;
     }
//تقاطع اسفل ال20

   if(StochCurr<LowerThreShold)
     {
      CrossToCloseSell=true;
     }
  }





//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
string GetlastOrderType()
  {
   int last_order_profit=1;
   int lastOrd=0;
   string s="";
   int counter=0;
   double lastProfit=0;
   string LastOrderType="";
   string myResult="";
//loop for all closed
   for(int i=OrdersHistoryTotal()-1; i>=0; i--)
     {
      OrderSelect(i,SELECT_BY_POS,MODE_HISTORY);
      if(OrderSymbol()==_Symbol)
         if(i==OrdersHistoryTotal()-1)
           {
            lastProfit=(OrderProfit()+OrderSwap()+OrderCommission());
            if(OrderType()==OP_BUY)
               LastOrderType="Buy";
            if(OrderType()==OP_SELL)

               LastOrderType="Sell";
            if(lastProfit<0)
               s =" lose";
            last_order_profit=1;
            if(lastProfit>0)
               s =" profit";
            last_order_profit=0;

           }
      myResult=LastOrderType+" and Profit is : "+lastProfit+" "+s;
     }
   return (myResult);
  }







//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool lastOrderbool()
  {
   int lastOrd=0;
   int counter=0;
   double lastProfit=0;
   bool y;

//loop for all closed
   for(int i=OrdersHistoryTotal()-1; i>=0; i--)
     {
      OrderSelect(i,SELECT_BY_POS,MODE_HISTORY);
      if(OrderSymbol()==_Symbol)
         if(i==OrdersHistoryTotal()-1)
           {
            lastProfit=(OrderProfit()+OrderSwap()+OrderCommission());
            if(OrderType()==OP_BUY)

               if(OrderType()==OP_SELL)


                  if(lastProfit<0)
                     y =false;

            if(lastProfit>0)
               y=true;


           }

     }
   if(OrdersHistoryTotal()==0)
      y=true;
//Print("No Order found");
   return (y);
  }









//+------------------------------------------------------------------+
void OnTick()
  {


//Candel Filter
   bool  candelbuy;
   bool candelsell;
//Tail Of previos candel
   double hight =iHigh(_Symbol,Time_Period,1);
   double low =iLow(_Symbol,Time_Period,1);

//Previos Candel boody details
   double open =iOpen(_Symbol,Time_Period,1);
   double close=iClose(_Symbol,Time_Period,1);

   if(open<close)
     {
      candelbuy=true;
     }

   if(open>close)
     {
      candelsell=true;
     }

//Tail Of previos candel
//+------------------------------------------------------------------+





   bool lastt=lastOrderbool();


   if(fixedLote==true)
     {

      //Last Order Check lot
      if(lastt==true)
        {
         lotSize=Lot_fixed_Size;
        }
      if(lastt==false)
        {

         lotSize=2*Lot_fixed_Size;
        }



      double TP_Amount=TakeProfit*lotSize;



      string last=GetlastOrderType();

      //       Comment("By Eng Ibrahim Hamed\nibrahim.hamed112@hotmail.com\n\nNumber of TP point is : "+TakeProfit+" Point",
      //              "\nProfit will : "+TP_Amount+" $ \nLot Size : "+lotSize+"\nLast Order is : "+last+"\n"+lastt+"\n Account Balance : "+AccountBalance()+"\n Account Equity : "+AccountEquity());
      //
      Comment("By Eng Ibrahim Hamed\nibrahim.hamed112@hotmail.com\n\nNumber of TP point is : "+TakeProfit+" Point",
              "\nProfit will : "+TP_Amount+" $ \nLot Size : "+lotSize+"\nLast Order is : "+"\nAccount Balance : "+AccountBalance()+"\nAccount Equity : "+AccountEquity());
     }
   else
     {
      bool lastt=lastOrderbool();

      lotSize=0;
      //Calculate the tp in percentage
      double accountEq= AccountEquity();
      //double accountBl= AccountBalance();
      tpPrecent=(accountEq/100)*TPpercent;
      //Calculate the Lote size

      //Last Order Check lot

      if(lastt==true)
         lotSize=tpPrecent/TakeProfit;


      else
         if(lastt==false)

           {
            double lottSize=(tpPrecent/TakeProfit);
            lotSize=2*lottSize;

           }

      lotSize = NormalizeDouble(lotSize,3)/10;
      string last=GetlastOrderType();

      //Comment("By Eng Ibrahim Hamed\nibrahim.hamed112@hotmail.com\n\nProfit percentage according to"+ TPpercent+"% is : "+tpPrecent+" $ \nLot Size : "+lotSize+
      //              "\nLast Order is : "+last+"\n"+lastt+"\nAccount Balance : "+AccountBalance()+"\nAccount Equity : "+AccountEquity());


      Comment("By Eng Ibrahim Hamed\nibrahim.hamed112@hotmail.com\n\nProfit percentage according to"+ TPpercent+"% is : "+tpPrecent+" $ \nLot Size : "+lotSize+
              "\nLast Order is : "+last+"\nAccount Balance : "+AccountBalance()+"\nAccount Equity : "+AccountEquity());
     }





//Calling initialization, checks and technical analysis
   if(Period()==Time_Period)
     {

      Initialize();
      CheckCanOrder();
      CheckStochCross();

      //Check of Entry/Exit signal with operations to perform
      if(CrossToCloseBuy)
         CloseAll(OP_BUY);

      if(CrossToCloseSell)
         CloseAll(OP_SELL);
         
         
       //cross to open buy and candel 
      if(CrossToOpenBuy&&candelbuy)
        {

         if(CanOpenBuy && CanOrder)
            OpenNew(OP_BUY);
        }
        //cross to open sell and candel sell
      if(CrossToOpenSell&&candelsell)
        {
         if(CanOpenSell && CanOrder)
            OpenNew(OP_SELL);
        }

     }

   else
     {
      Print("Time frame wrong Please select : "+Time_Period);

     }




  }



//+------------------------------------------------------------------+
