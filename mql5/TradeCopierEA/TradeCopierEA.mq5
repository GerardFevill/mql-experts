#include <Trade\Trade.mqh>

input int      CopyCount       = 2;            // Nombre de duplications
input bool     UseLotRatio     = true;         // true = ratio, false = lot fixe
input double   LotRatio        = 1.0;          // Ratio (si activé)
input double   FixedLot        = 0.1;          // Lot fixe (si ratio désactivé)
input int      MyMagicNumber   = 123456;       // Magic Number de l’EA
input bool     UpdateSLTP      = true;         // Mettre à jour SL/TP si modifiés

CTrade trade;
struct CopyInfo {
   ulong ticket;
   ulong origin_ticket;
};

CopyInfo copies[];
ulong last_checked = 0;

// Vérifie si une position est déjà copiée
bool IsCopyAlreadyMade(ulong origin_ticket) {
   for (int i = 0; i < ArraySize(copies); i++) {
      if (copies[i].origin_ticket == origin_ticket)
         return true;
   }
   return false;
}

// Enregistre une copie
void RegisterCopy(ulong ticket, ulong origin_ticket) {
   CopyInfo info;
   info.ticket = ticket;
   info.origin_ticket = origin_ticket;
   ArrayResize(copies, ArraySize(copies) + 1);
   copies[ArraySize(copies) - 1] = info;
   Print("[TradeCopierEA] Position copiée: Original=" + IntegerToString(origin_ticket) + ", Copie=" + IntegerToString(ticket));
}

// Supprime un élément du tableau copies
void RemoveFromArray(int index) {
   int size = ArraySize(copies);
   // Vérifier que l'index est valide
   if(index < 0 || index >= size) return;
   
   // Déplacer les éléments pour combler le trou
   for(int i = index; i < size - 1; i++) {
      copies[i] = copies[i + 1];
   }
   
   // Réduire la taille du tableau
   ArrayResize(copies, size - 1);
}

// Ferme les copies d'une position
void CloseCopiesOf(ulong origin_ticket) {
   Print("[TradeCopierEA] Tentative de fermeture des copies pour l'original: " + IntegerToString(origin_ticket));
   for (int i = ArraySize(copies) - 1; i >= 0; i--) {
      if (copies[i].origin_ticket == origin_ticket) {
         if (PositionSelectByTicket(copies[i].ticket)) {
            bool success = trade.PositionClose(copies[i].ticket);
            if(success) {
               Print("[TradeCopierEA] Position fermée avec succès: Ticket=" + IntegerToString(copies[i].ticket));
            } else {
               Print("[TradeCopierEA] ERREUR: Échec fermeture position: Ticket=" + IntegerToString(copies[i].ticket) + ", Code=" + IntegerToString(GetLastError()));
            }
         } else {
            Print("[TradeCopierEA] Position introuvable ou déjà fermée: Ticket=" + IntegerToString(copies[i].ticket));
         }
         RemoveFromArray(i);
      }
   }
}

void OnTick() {
   int total = PositionsTotal();
   
   // Log simple pour montrer que l'EA est actif (toutes les 100 ticks)
   static int tick_counter = 0;
   tick_counter++;
   if(tick_counter % 100 == 0) {
      Print("[TradeCopierEA] Actif - Positions totales: " + IntegerToString(total) + ", Copies suivies: " + IntegerToString(ArraySize(copies)));
   }
   
   for (int i = 0; i < total; i++) {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;

      if (!PositionSelectByTicket(ticket))
         continue;

      // Ne traiter que les nouvelles positions
      datetime opentime = (datetime)PositionGetInteger(POSITION_TIME);
      if (opentime <= last_checked)
         continue;

      int magic = (int)PositionGetInteger(POSITION_MAGIC);
      if (magic == MyMagicNumber)
         continue; // Ne pas copier nos propres trades

      if (IsCopyAlreadyMade(ticket))
         continue; // Déjà copié

      // --- Informations du trade source ---
      string symbol     = PositionGetString(POSITION_SYMBOL);
      double volume     = PositionGetDouble(POSITION_VOLUME);
      double sl         = PositionGetDouble(POSITION_SL);
      double tp         = PositionGetDouble(POSITION_TP);
      int    type       = (int)PositionGetInteger(POSITION_TYPE);

      double copiedLot = UseLotRatio ? volume * LotRatio : FixedLot;

      for (int j = 0; j < CopyCount; j++) {
         trade.SetExpertMagicNumber(MyMagicNumber);
         bool success = false;
         string comment = "TC#" + IntegerToString(j+1) + "/" + IntegerToString(CopyCount) + " de " + IntegerToString(ticket);
         
         if (type == POSITION_TYPE_BUY)
            success = trade.Buy(copiedLot, symbol, 0, sl, tp, comment);
         else if (type == POSITION_TYPE_SELL)
            success = trade.Sell(copiedLot, symbol, 0, sl, tp, comment);

         if (success)
            RegisterCopy(trade.ResultOrder(), ticket);
      }

      last_checked = opentime;
   }

   // Vérifier fermeture du trade d'origine
   int copies_size = ArraySize(copies);
   if(copies_size > 0) {  // Vérifier que le tableau n'est pas vide
      for (int i = copies_size - 1; i >= 0; i--) {
         // Vérifier que l'index est toujours valide (la taille peut changer)
         if(i >= ArraySize(copies)) continue;
         
         if (!PositionSelectByTicket(copies[i].origin_ticket)) {
            // L'original est fermé
            Print("[TradeCopierEA] Position originale fermée détectée: " + IntegerToString(copies[i].origin_ticket));
            CloseCopiesOf(copies[i].origin_ticket);
         } else if (UpdateSLTP && PositionSelectByTicket(copies[i].ticket) && PositionSelectByTicket(copies[i].origin_ticket)) {
            double origin_sl = PositionGetDouble(POSITION_SL);
            double origin_tp = PositionGetDouble(POSITION_TP);

            double copy_sl = PositionGetDouble(POSITION_SL);
            double copy_tp = PositionGetDouble(POSITION_TP);

            if (MathAbs(origin_sl - copy_sl) > _Point || MathAbs(origin_tp - copy_tp) > _Point) {
               bool success = trade.PositionModify(copies[i].ticket, origin_sl, origin_tp);
               if(success) {
                  Print("[TradeCopierEA] SL/TP mis à jour: Ticket=" + IntegerToString(copies[i].ticket));
               } else {
                  Print("[TradeCopierEA] ERREUR: Échec mise à jour SL/TP: Ticket=" + IntegerToString(copies[i].ticket) + ", Code=" + IntegerToString(GetLastError()));
               }
            }
         }
      }
   }
}
