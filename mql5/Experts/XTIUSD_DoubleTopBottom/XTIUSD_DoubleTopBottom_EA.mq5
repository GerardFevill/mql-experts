//+------------------------------------------------------------------+
//|                                     XTIUSD_DoubleTopBottom_EA.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// Inclusion des bibliothèques nécessaires
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

// Définition des constantes
#define SYMBOL "XTIUSD"
#define TIMEFRAME PERIOD_M2

// Paramètres d'entrée
input int VWAPPeriod = 20;         // Période du VWAP
input int RSIPeriod = 14;          // Période du RSI
input int PatternBars = 4;         // Nombre de barres pour le pattern M/W
input double RangeThreshold = 0.1; // Seuil pour détecter un range plat (%)
input int FlatRangeCount = 7;      // Nombre de bougies pour un range plat

// Paramètres de trading
input double TakeProfit1 = 0.20;   // Premier Take Profit (%)
input double TakeProfit2 = 0.25;   // Deuxième Take Profit (%)
input double TakeProfit3 = 0.30;   // Troisième Take Profit (%)
input double StopLoss = 0.10;      // Stop Loss (%)
input double TrailThreshold = 0.09; // Seuil pour déplacer le SL à l'entrée (%)

// Paramètres de temps
input int StartHour = 15;          // Heure de début (Paris)
input int StartMinute = 50;        // Minute de début
input int EndHour = 17;            // Heure de fin (Paris)
input int EndMinute = 0;           // Minute de fin

// Variables globales
CTrade trade;
CPositionInfo positionInfo;
CSymbolInfo symbolInfo;
int vwapHandle;
int rsiHandle;
datetime lastTradeTime = 0;
bool inTradingWindow = false;

//+------------------------------------------------------------------+
//| Fonction d'initialisation de l'Expert Advisor                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Vérification du symbole
    if(_Symbol != SYMBOL)
    {
        Print("Cet EA est conçu uniquement pour le symbole ", SYMBOL);
        return INIT_PARAMETERS_INCORRECT;
    }
    
    // Vérification du timeframe
    if(_Period != TIMEFRAME)
    {
        Print("Cet EA est conçu uniquement pour le timeframe M2");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    // Initialisation des indicateurs
    vwapHandle = iCustom(_Symbol, _Period, "VWAP", VWAPPeriod);
    if(vwapHandle == INVALID_HANDLE)
    {
        Print("Erreur lors de la création de l'indicateur VWAP");
        return INIT_FAILED;
    }
    
    rsiHandle = iRSI(_Symbol, _Period, RSIPeriod, PRICE_CLOSE);
    if(rsiHandle == INVALID_HANDLE)
    {
        Print("Erreur lors de la création de l'indicateur RSI");
        return INIT_FAILED;
    }
    
    // Initialisation de l'objet trade
    trade.SetExpertMagicNumber(123456);
    trade.SetMarginMode();
    trade.SetTypeFillingBySymbol(_Symbol);
    
    // Initialisation de l'objet symbolInfo
    symbolInfo.Name(_Symbol);
    symbolInfo.RefreshRates();
    
    Print("EA initialisé avec succès");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Fonction de désinitialisation de l'Expert Advisor                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Libération des handles d'indicateurs
    if(vwapHandle != INVALID_HANDLE)
        IndicatorRelease(vwapHandle);
    
    if(rsiHandle != INVALID_HANDLE)
        IndicatorRelease(rsiHandle);
    
    Print("EA désinitalisé");
}

//+------------------------------------------------------------------+
//| Fonction principale de l'Expert Advisor                           |
//+------------------------------------------------------------------+
void OnTick()
{
    // Vérification de l'heure de trading (Paris)
    inTradingWindow = IsWithinTradingHours();
    if(!inTradingWindow)
    {
        // Si nous sommes hors de la fenêtre de trading, on ne fait rien
        return;
    }
    
    // Vérification des nouvelles bougies
    if(!IsNewBar())
    {
        // Si ce n'est pas une nouvelle bougie, on gère uniquement les positions existantes
        ManageOpenPositions();
        return;
    }
    
    // Mise à jour des données du symbole
    symbolInfo.RefreshRates();
    
    // Vérification des conditions pour ouvrir un nouveau trade
    if(PositionsTotal() == 0)
    {
        // Vérification du range plat (condition anti-piège)
        if(IsFlatRange(FlatRangeCount))
        {
            Print("Range plat détecté - Pas de nouveaux trades");
            return;
        }
        
        // Vérification des patterns
        int patternType = DetectPattern();
        
        if(patternType == 1) // Double Haut "M" - Signal de vente
        {
            // Vérification des conditions d'entrée pour une vente
            double entryPrice = CalculateSellEntryPrice();
            if(entryPrice > 0)
            {
                OpenSellPosition(entryPrice);
            }
        }
        else if(patternType == 2) // Double Bas "W" - Signal d'achat
        {
            // Vérification des conditions d'entrée pour un achat
            double entryPrice = CalculateBuyEntryPrice();
            if(entryPrice > 0)
            {
                OpenBuyPosition(entryPrice);
            }
        }
    }
    else
    {
        // Gestion des positions ouvertes
        ManageOpenPositions();
    }
}

//+------------------------------------------------------------------+
//| Vérifie si nous sommes dans la fenêtre de trading (heure Paris)  |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
    MqlDateTime localTime;
    TimeToStruct(TimeLocal(), localTime);
    
    // Conversion en minutes depuis minuit
    int currentTimeInMinutes = localTime.hour * 60 + localTime.min;
    int startTimeInMinutes = StartHour * 60 + StartMinute;
    int endTimeInMinutes = EndHour * 60 + EndMinute;
    
    return (currentTimeInMinutes >= startTimeInMinutes && currentTimeInMinutes < endTimeInMinutes);
}

//+------------------------------------------------------------------+
//| Vérifie s'il y a une nouvelle bougie                             |
//+------------------------------------------------------------------+
bool IsNewBar()
{
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(_Symbol, _Period, 0);
    
    if(lastBarTime != currentBarTime)
    {
        lastBarTime = currentBarTime;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Détecte les patterns Double Haut (M) et Double Bas (W)           |
//| Retourne: 0 = Pas de pattern, 1 = Double Haut, 2 = Double Bas    |
//+------------------------------------------------------------------+
int DetectPattern()
{
    // Récupération des données de prix
    double closes[10], highs[10], lows[10];
    if(CopyClose(_Symbol, _Period, 0, 10, closes) <= 0) return 0;
    if(CopyHigh(_Symbol, _Period, 0, 10, highs) <= 0) return 0;
    if(CopyLow(_Symbol, _Period, 0, 10, lows) <= 0) return 0;
    
    // Récupération des données VWAP
    double vwapBuffer[10], vwapZone3Upper[10], vwapZone3Lower[10];
    if(CopyBuffer(vwapHandle, 0, 0, 10, vwapBuffer) <= 0) return 0;
    if(CopyBuffer(vwapHandle, 3, 0, 10, vwapZone3Upper) <= 0) return 0;
    if(CopyBuffer(vwapHandle, 4, 0, 10, vwapZone3Lower) <= 0) return 0;
    
    // Récupération des données RSI
    double rsiValues[10];
    if(CopyBuffer(rsiHandle, 0, 0, 10, rsiValues) <= 0) return 0;
    
    // Vérification du pattern Double Haut "M"
    if(PatternBars <= 5 && 
       // Premier pic ferme dans la zone 3 du VWAP
       closes[4] >= vwapZone3Lower[4] && closes[4] <= vwapZone3Upper[4] &&
       // Deuxième pic au même niveau ou plus haut que le premier
       highs[2] >= highs[4] &&
       // RSI qui baisse entre les deux pics
       rsiValues[2] < rsiValues[4] &&
       // La 4e bougie du "M" ferme à moitié ou plus bas que la précédente
       closes[1] <= (closes[2] + lows[2]) / 2)
    {
        Print("Pattern Double Haut (M) détecté");
        return 1; // Double Haut "M"
    }
    
    // Vérification du pattern Double Bas "W"
    if(PatternBars <= 5 && 
       // Premier creux ferme dans la zone 3 du VWAP
       closes[4] >= vwapZone3Lower[4] && closes[4] <= vwapZone3Upper[4] &&
       // Deuxième creux au même niveau ou plus bas que le premier
       lows[2] <= lows[4] &&
       // RSI qui monte entre les deux creux
       rsiValues[2] > rsiValues[4] &&
       // La 4e bougie du "W" ferme à moitié ou plus haut que la précédente
       closes[1] >= (closes[2] + highs[2]) / 2)
    {
        Print("Pattern Double Bas (W) détecté");
        return 2; // Double Bas "W"
    }
    
    return 0; // Pas de pattern détecté
}

//+------------------------------------------------------------------+
//| Calcule le prix d'entrée pour une position d'achat               |
//+------------------------------------------------------------------+
double CalculateBuyEntryPrice()
{
    double closes[2], opens[2], highs[2], lows[2];
    if(CopyClose(_Symbol, _Period, 0, 2, closes) <= 0) return 0;
    if(CopyOpen(_Symbol, _Period, 0, 2, opens) <= 0) return 0;
    if(CopyHigh(_Symbol, _Period, 0, 2, highs) <= 0) return 0;
    if(CopyLow(_Symbol, _Period, 0, 2, lows) <= 0) return 0;
    
    double currentPrice = symbolInfo.Ask();
    double bodySize = MathAbs(closes[0] - opens[0]);
    double bodyPercent = bodySize / closes[0] * 100;
    double upperWick = highs[0] - MathMax(closes[0], opens[0]);
    double lowerWick = MathMin(closes[0], opens[0]) - lows[0];
    double wickRatio = (upperWick + lowerWick) / bodySize;
    
    // Si le corps < 0.20% et mèche < 1/3 du corps → achat au marché
    if(bodyPercent < 0.20 && wickRatio < 1.0/3.0)
    {
        return currentPrice;
    }
    
    // Si corps ≥ +0.25% → achat à moitié du corps -0.02%
    if(closes[0] > opens[0] && bodyPercent >= 0.25 && bodyPercent < 0.30)
    {
        double midPoint = opens[0] + bodySize / 2;
        return midPoint * (1 - 0.0002); // -0.02%
    }
    
    // Si corps ≥ +0.30% → moitié -0.03%
    if(closes[0] > opens[0] && bodyPercent >= 0.30 && bodyPercent < 0.40)
    {
        double midPoint = opens[0] + bodySize / 2;
        return midPoint * (1 - 0.0003); // -0.03%
    }
    
    // Si corps ≥ +0.40% → moitié -0.04%
    if(closes[0] > opens[0] && bodyPercent >= 0.40)
    {
        double midPoint = opens[0] + bodySize / 2;
        return midPoint * (1 - 0.0004); // -0.04%
    }
    
    return 0; // Aucune condition d'entrée satisfaite
}

//+------------------------------------------------------------------+
//| Calcule le prix d'entrée pour une position de vente              |
//+------------------------------------------------------------------+
double CalculateSellEntryPrice()
{
    double closes[2], opens[2], highs[2], lows[2];
    if(CopyClose(_Symbol, _Period, 0, 2, closes) <= 0) return 0;
    if(CopyOpen(_Symbol, _Period, 0, 2, opens) <= 0) return 0;
    if(CopyHigh(_Symbol, _Period, 0, 2, highs) <= 0) return 0;
    if(CopyLow(_Symbol, _Period, 0, 2, lows) <= 0) return 0;
    
    double currentPrice = symbolInfo.Bid();
    double bodySize = MathAbs(closes[0] - opens[0]);
    double bodyPercent = bodySize / closes[0] * 100;
    double upperWick = highs[0] - MathMax(closes[0], opens[0]);
    double lowerWick = MathMin(closes[0], opens[0]) - lows[0];
    double wickRatio = (upperWick + lowerWick) / bodySize;
    
    // Si le corps < 0.20% et mèche < 1/3 du corps → vente au prix du marché
    if(bodyPercent < 0.20 && wickRatio < 1.0/3.0)
    {
        return currentPrice;
    }
    
    // Si corps ≤ -0.25% → vente à moitié du corps +0.02%
    if(closes[0] < opens[0] && bodyPercent >= 0.25 && bodyPercent < 0.30)
    {
        double midPoint = closes[0] + bodySize / 2;
        return midPoint * (1 + 0.0002); // +0.02%
    }
    
    // Si corps ≤ -0.30% → moitié +0.03%
    if(closes[0] < opens[0] && bodyPercent >= 0.30 && bodyPercent < 0.40)
    {
        double midPoint = closes[0] + bodySize / 2;
        return midPoint * (1 + 0.0003); // +0.03%
    }
    
    // Si corps ≤ -0.40% → moitié +0.04%
    if(closes[0] < opens[0] && bodyPercent >= 0.40)
    {
        double midPoint = closes[0] + bodySize / 2;
        return midPoint * (1 + 0.0004); // +0.04%
    }
    
    return 0; // Aucune condition d'entrée satisfaite
}

//+------------------------------------------------------------------+
//| Ouvre une position d'achat                                        |
//+------------------------------------------------------------------+
void OpenBuyPosition(double entryPrice)
{
    double currentPrice = symbolInfo.Ask();
    double stopLossPrice = entryPrice * (1 - StopLoss / 100);
    double takeProfit1Price = entryPrice * (1 + TakeProfit1 / 100);
    double takeProfit2Price = entryPrice * (1 + TakeProfit2 / 100);
    double takeProfit3Price = entryPrice * (1 + TakeProfit3 / 100);
    
    // Calcul du volume en fonction du risque
    double volume = CalculateVolume(entryPrice, stopLossPrice);
    
    // Si le prix d'entrée est proche du prix actuel, on utilise un ordre au marché
    if(MathAbs(entryPrice - currentPrice) / currentPrice < 0.0001)
    {
        if(trade.Buy(volume, _Symbol, 0, stopLossPrice, takeProfit1Price, "Double Bas W"))
        {
            Print("Position d'achat ouverte au marché: Volume=", volume, ", SL=", stopLossPrice, ", TP=", takeProfit1Price);
            lastTradeTime = TimeCurrent();
        }
        else
        {
            Print("Erreur lors de l'ouverture de la position d'achat: ", GetLastError());
        }
    }
    else
    {
        // Sinon, on utilise un ordre limite
        if(trade.BuyLimit(volume, entryPrice, _Symbol, stopLossPrice, takeProfit1Price, ORDER_TIME_DAY, 0, "Double Bas W"))
        {
            Print("Ordre limite d'achat placé: Prix=", entryPrice, ", Volume=", volume, ", SL=", stopLossPrice, ", TP=", takeProfit1Price);
        }
        else
        {
            Print("Erreur lors du placement de l'ordre limite d'achat: ", GetLastError());
        }
    }
}

//+------------------------------------------------------------------+
//| Ouvre une position de vente                                       |
//+------------------------------------------------------------------+
void OpenSellPosition(double entryPrice)
{
    double currentPrice = symbolInfo.Bid();
    double stopLossPrice = entryPrice * (1 + StopLoss / 100);
    double takeProfit1Price = entryPrice * (1 - TakeProfit1 / 100);
    double takeProfit2Price = entryPrice * (1 - TakeProfit2 / 100);
    double takeProfit3Price = entryPrice * (1 - TakeProfit3 / 100);
    
    // Calcul du volume en fonction du risque
    double volume = CalculateVolume(entryPrice, stopLossPrice);
    
    // Si le prix d'entrée est proche du prix actuel, on utilise un ordre au marché
    if(MathAbs(entryPrice - currentPrice) / currentPrice < 0.0001)
    {
        if(trade.Sell(volume, _Symbol, 0, stopLossPrice, takeProfit1Price, "Double Haut M"))
        {
            Print("Position de vente ouverte au marché: Volume=", volume, ", SL=", stopLossPrice, ", TP=", takeProfit1Price);
            lastTradeTime = TimeCurrent();
        }
        else
        {
            Print("Erreur lors de l'ouverture de la position de vente: ", GetLastError());
        }
    }
    else
    {
        // Sinon, on utilise un ordre limite
        if(trade.SellLimit(volume, entryPrice, _Symbol, stopLossPrice, takeProfit1Price, ORDER_TIME_DAY, 0, "Double Haut M"))
        {
            Print("Ordre limite de vente placé: Prix=", entryPrice, ", Volume=", volume, ", SL=", stopLossPrice, ", TP=", takeProfit1Price);
        }
        else
        {
            Print("Erreur lors du placement de l'ordre limite de vente: ", GetLastError());
        }
    }
}

//+------------------------------------------------------------------+
//| Calcule le volume de trading en fonction du risque                |
//+------------------------------------------------------------------+
double CalculateVolume(double entryPrice, double stopLossPrice)
{
    double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * 0.01; // Risque de 1% du solde
    double priceDifference = MathAbs(entryPrice - stopLossPrice);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double pointValue = tickValue / tickSize;
    
    double volume = riskAmount / (priceDifference * pointValue);
    
    // Arrondir au lot minimal
    double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double stepVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    volume = MathFloor(volume / stepVolume) * stepVolume;
    volume = MathMax(minVolume, MathMin(volume, maxVolume));
    
    return volume;
}

//+------------------------------------------------------------------+
//| Gère les positions ouvertes                                       |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(positionInfo.SelectByIndex(i))
        {
            if(positionInfo.Symbol() != _Symbol) continue;
            
            double entryPrice = positionInfo.PriceOpen();
            double currentPrice = (positionInfo.PositionType() == POSITION_TYPE_BUY) ? symbolInfo.Bid() : symbolInfo.Ask();
            double stopLoss = positionInfo.StopLoss();
            double takeProfit = positionInfo.TakeProfit();
            
            // Calcul du profit actuel en pourcentage
            double currentProfit = 0;
            if(positionInfo.PositionType() == POSITION_TYPE_BUY)
            {
                currentProfit = (currentPrice - entryPrice) / entryPrice * 100;
            }
            else
            {
                currentProfit = (entryPrice - currentPrice) / entryPrice * 100;
            }
            
            // Si le profit atteint le seuil, déplacer le SL à l'entrée
            if(currentProfit >= TrailThreshold && stopLoss != entryPrice)
            {
                if(positionInfo.PositionType() == POSITION_TYPE_BUY)
                {
                    if(trade.PositionModify(positionInfo.Ticket(), entryPrice, takeProfit))
                    {
                        Print("Stop Loss déplacé à l'entrée pour la position d'achat #", positionInfo.Ticket());
                    }
                }
                else
                {
                    if(trade.PositionModify(positionInfo.Ticket(), entryPrice, takeProfit))
                    {
                        Print("Stop Loss déplacé à l'entrée pour la position de vente #", positionInfo.Ticket());
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Vérifie si le marché est dans un range plat horizontal           |
//+------------------------------------------------------------------+
bool IsFlatRange(int count)
{
    double closes[20];
    if(CopyClose(_Symbol, _Period, 0, count + 1, closes) <= 0) return false;
    
    double highestClose = closes[ArrayMaximum(closes, 0, count)];
    double lowestClose = closes[ArrayMinimum(closes, 0, count)];
    
    // Calcul de la variation en pourcentage
    double rangePercent = (highestClose - lowestClose) / lowestClose * 100;
    
    return (rangePercent <= RangeThreshold);
}

//+------------------------------------------------------------------+
//| Fonction personnalisée pour l'indicateur VWAP                     |
//+------------------------------------------------------------------+
// Note: Cette fonction est un placeholder pour l'indicateur VWAP
// Vous devrez créer un indicateur VWAP séparé ou utiliser un existant
//+------------------------------------------------------------------+
