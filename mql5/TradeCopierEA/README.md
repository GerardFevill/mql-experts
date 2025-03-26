# 📘 TradeCopierEA – MQL5

Un Expert Advisor MQL5 conçu pour **copier automatiquement** les trades manuels et ceux ouverts par d’autres EA sur le **même compte**, en évitant de copier ses propres duplications, avec gestion complète de la synchronisation.

---

## 🎯 Fonctionnalité principale

- Copie **immédiatement** tout trade détecté ouvert manuellement ou par un autre EA
- Permet de faire **plusieurs duplications**
- Copie le **SL / TP**
- Met à jour le **SL / TP si modifiés**
- Ferme automatiquement toutes les **copies** si le **trade d’origine est fermé**
- Évite les **boucles de duplication infinie** grâce à un Magic Number propre

---

## ⚙️ Paramètres (Inputs)

| Paramètre         | Type     | Description |
|-------------------|----------|-------------|
| `CopyCount`       | `int`    | Nombre de duplications à faire pour chaque trade détecté |
| `UseLotRatio`     | `bool`   | `true` = on utilise `LotRatio`, `false` = on utilise `FixedLot` |
| `LotRatio`        | `double` | Si activé, chaque copie a un lot = lot du trade original × `LotRatio` |
| `FixedLot`        | `double` | Si `UseLotRatio` = false, chaque copie aura ce lot fixe |
| `MyMagicNumber`   | `int`    | Magic number utilisé pour identifier les positions ouvertes par l’EA |
| `UpdateSLTP`      | `bool`   | Mettre à jour SL/TP des copies si ceux du trade source changent |

---

## 🚫 Ce que l’EA ne fait **pas**

- ❌ Ne copie **pas ses propres trades**
- ❌ Ne copie **pas les ordres en attente** (buy/sell limit/stop)
- ❌ Ne filtre pas les symboles (il copie tous)
- ❌ Ne vérifie pas le spread, ni le slippage
- ❌ Ne restreint pas les heures (fonctionne 24/24)

---

## 📂 Installation

1. Ouvre **MetaEditor** dans MetaTrader 5
2. Va dans : `Fichier > Nouveau > Expert Advisor (template)`
3. Nomme le fichier : `TradeCopierEA.mq5`
4. Colle le code fourni dans le fichier
5. Compile le fichier (`F7`)
6. Dans MetaTrader, glisse l’EA sur un **graphique quelconque**
7. Active le **trading automatique** 🟢

---

## 🧪 Recommandations de test

- Teste sur un **compte démo**
- Ouvre des positions manuelles et observe si les duplications sont déclenchées
- Laisse un autre EA ouvrir un trade, et vérifie la copie
- Ferme le trade source et regarde si les copies sont bien fermées

---

## 📈 Exemple d’usage

Si tu ouvres un trade de **0.10 lot BUY EURUSD** à la main, avec un SL et un TP :

- L’EA va créer **`CopyCount`** copies (ex : 3), chacune :
  - Avec un volume de **0.10 × LotRatio** ou **FixedLot**
  - Avec **le même SL / TP**
- Si tu modifies le SL/TP d’origine → les copies seront mises à jour
- Si tu fermes la position manuelle → toutes les copies seront fermées

---

## 🔽 Télécharger l'EA

👉 [Télécharger TradeCopierEA.mq5](https://github.com/GerardFevill/mql-experts/tree/main/mql5/TradeCopierEA/TradeCopierEA.mq5)

> Remplace ce lien par l’URL réelle vers ton fichier `.mq5`

---

## 📌 Améliorations possibles

- Journalisation avancée (`Print()` dans le journal)
- Interface visuelle (boutons, panneau)
- Filtrage par symboles spécifiques
- Filtrage par horaire de la journée
- Limitation du nombre total de copies actives

---

## 🔐 Licence

Ce code est libre de modification et d’utilisation à des fins personnelles.  
Pour un usage commercial, vérifie les réglementations de ton broker.
