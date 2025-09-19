# 📖 Documentation WearAndTear - ToLiss A321neo

## 🎯 Configuration Optimisée pour A321neo

Votre script WearAndTear est maintenant parfaitement configuré pour le ToLiss A321neo avec les paramètres suivants :

### ⚙️ Paramètres Ajustés
- **Temps d'usure avion** : 1200 heures (meilleure durabilité A321neo)
- **Temps d'usure moteurs** : 600 heures (moteurs NEO plus endurants)
- **Vitesse max** : 470 KTAS (A321neo plus rapide)
- **Coût révision avion** : 120 000€
- **Coût révision moteurs** : 75 000€
- **Revenus par kg/heure** : 0.85€ (capacité supérieure A321neo)

## 🚀 Fonctionnalités Activées

### ✈️ Vieillissement Dynamique
- Usure en temps réel basée sur la vitesse (TAS) et la poussée (N1)
- Effets réalistes sur la traînée et la consommation carburant
- Persistance entre les sessions via fichiers `WearAndTear.txt`

### 💰 Économie Réaliste
- Revenus basés sur la charge utile et le temps de vol
- Coûts de carburant : 0.92€/kg (prix Jet-A 2023)
- Révisions payantes pour remettre à neuf

### 🎮 Menu Intégré
Accessible via : **Menu X-Plane → ToLiss A321 → ToLiss Wear & Tear**

Options disponibles :
- Révisions avion/moteurs
- Affichage revenus de vol
- Coûts de ravitaillement
- Solde de trésorerie
- Valeur PERF MCDU
- Options de debug et paramètres

## 📊 Utilisation du MCDU

Pour mettre à jour la valeur PERF :
1. Allez dans **MCDU → DATA → A/C STATUS**
2. Tapez **"ARM"** dans **CHG CODE**
3. Entrez la valeur affichée dans le menu Wear & Tear (format: `/+X.X`)
4. Supprimez **"ARM"** pour verrouiller

## 💾 Gestion des Livrées

Chaque livrée a son propre fichier de persistance :
- Emplacement : `liveries/[nom_livrée]/WearAndTear.txt`
- Format : `Paramètre=Valeur:Type`
- Modification possible avec un éditeur de texte

## ⚡ Démarrage Rapide

1. **Chargez votre A321neo** dans X-Plane
2. **Ravitaillez** - la détection est automatique
3. **Démarrez les moteurs** et lancez le chrono écoulé
4. **Décollez** - l'usure commence à >100 KTAS
5. **Atterrissez et coupez les moteurs** - revenus calculés

## 🔧 Paramètres Avancés

Modifiable dans [`WearAndTear.lua`](scripts/WearAndTear/WearAndTear.lua) :
- `Random_Start_Vals = true` - Âge aléatoire si pas de fichier
- `Aircraft_Start_Val = -1` - Valeur neuve par défaut
- `Debug = 0` - Mode debug désactivé

## ❓ Support

Le script est officiellement compatible avec :
- ✅ A319, A320neo, A321/321neo
- ❌ A340-600 (datarefs manquantes)

**Crédits** : Script original par BK/RandomUser (2023)
**Licence** : EUPL v1.2