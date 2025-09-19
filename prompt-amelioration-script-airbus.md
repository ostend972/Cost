## Objectif
Améliorer le script existant avec des données économiques réalistes basées sur les opérations d'Air France, EasyJet et Wizz Air pour créer une expérience de simulation plus authentique.

## Données opérationnelles réelles à intégrer

### Air France A320 - Coûts par heure de vol (2024)
- **Coût opérationnel total** : 4 829 USD/heure
- **Carburant** : 2 407 USD/heure (2 500 kg/h à ~0,96 USD/kg)
- **Maintenance** : 916 USD/heure
- **Équipage** : 964 USD/heure (Commandant + Copilote + charges)
- **Propriété/Amortissement** : 536 USD/heure

### EasyJet A320/A320neo - Paramètres opérationnels
- **Coût opérationnel estimé** : 10 800 USD/heure
- **Consommation carburant** : 2 500 kg/h (A320 CEO) / 2 300 kg/h (A320neo)
- **Économies maintenance A320neo** : -5% sur maintenance cellule
- **Économies carburant sharklets** : -2 à -4% sur vols long-courriers
- **Configuration typique** : 180 sièges, rotation rapide 25 minutes

### Wizz Air A321 - Défis opérationnels actuels
- **Augmentation coûts maintenance** : +16% (problèmes moteurs P&W)
- **Avions immobilisés** : 20% de la flotte (problèmes GTF)
- **Coût maintenance par heure** : 270 USD/heure
- **Stratégie flotte** : Remplacement A320 CEO par A321neo
- **Amortissement accéléré** : +28,1% due au vieillissement CEO

## Paramètres de simulation à ajuster

### 1. Coûts de carburant dynamiques
```
Consommation_Croisière = 2500 kg/h (CEO) / 2300 kg/h (NEO)
Prix_Carburant = 0.85-1.10 USD/kg (variable selon marché)
Facteur_Phase_Vol = {
    Roulage: 150 kg/h,
    Montée: 4200 kg/h,
    Croisière: 2500 kg/h,
    Descente: 1800 kg/h
}
```

### 2. Maintenance préventive et corrective
```
Maintenance_Base_Heure = 509 USD/h
Facteurs_Usure = {
    Atterrissages_durs: +15% coût maintenance,
    Vols_court_courrier: +10% (plus de cycles),
    Âge_Avion: +2% par année après 5 ans,
    Problèmes_Moteur_P&W: +25% si A321neo
}
```

### 3. Coûts d'équipage réalistes
```
Coût_Équipage_Heure = {
    Commandant: 180-220 EUR/h vol,
    Copilote: 120-150 EUR/h vol,
    Charges_Sociales: +30% du salaire brut
}
Per_Diem = 45-65 EUR/jour selon destination
```

### 4. Frais aéroportuaires variables
```
Redevances_Atterrissage = {
    Paris_CDG: 259 EUR (A320, >75T),
    Nice: 65 EUR (A320, 25T),
    Toulouse: 100 EUR + 3 EUR/T (>24T),
    Londres_Heathrow: 450 EUR,
    Barcelone: 180 EUR
}
Frais_Passagers = 8-25 EUR/pax selon aéroport
```

### 5. Système d'usure progressive
```
Usure_Composants = {
    Train_Atterrissage: 6 USD/h + 107 USD/cycle,
    APU: 15 USD/h (si utilisé),
    Pneus_Freins: 107 USD/cycle,
    Révision_Moteur: 45 000 USD/6000h,
    Inspection_C: 350 000 USD/26 000h
}
```

## Événements aléatoires à intégrer

### Pannes réalistes (fréquences basées sur données constructeur)
- **Panne APU** : 1/2000 vols (coût : 2 500 EUR)
- **Problème hydraulique** : 1/5000 vols (retard : 2h, coût : 8 000 EUR)  
- **Panne moteur P&W (A321neo)** : 1/1000 vols (immobilisation : 30 jours)
- **Grève contrôle aérien** : Impact France 2-3 fois/an
- **Conditions météo** : Surcoût carburant +5-15%

## Paramètres économiques par compagnie

### Profil "Air France" (Premium/Réseau)
- Coefficient maintenance : 1.0
- Coefficient carburant : 1.0 (optimisé)
- Coefficient équipage : 1.2 (salaires élevés)
- Focus qualité service vs coût

### Profil "EasyJet" (Low-Cost Efficace)
- Coefficient maintenance : 0.9 (flotte jeune)
- Coefficient carburant : 0.95 (A320neo, sharklets)
- Coefficient équipage : 0.8 (optimisé)
- Rotation rapide, forte utilisation

### Profil "Wizz Air" (Ultra Low-Cost, défis actuels)
- Coefficient maintenance : 1.16 (problèmes P&W)
- Coefficient carburant : 0.85 (A321, densité élevée)
- Coefficient équipage : 0.7 (salaires Europe de l'Est)
- 20% flotte immobilisée aléatoirement

## Indicateurs de performance à afficher

### Tableau de bord économique
- **Coût par heure de vol** (objectif : Air France 4 829 USD/h)
- **Coût par siège-kilomètre** (CASK)
- **Consommation carburant/100km/pax** (objectif : 3-3,5L)
- **Taux d'utilisation flotte** (objectif : 10-12h/jour)
- **Fiabilité technique** (annulations <1%)

### Alertes de gestion
- Maintenance dépassant budget (+10%)
- Consommation carburant anormale
- Usure accélérée composants critiques
- Immobilisations prolongées

## Code d'exemple pour intégration

```lua
-- Configuration économique réaliste
AIRLINE_PROFILES = {
    AIR_FRANCE = {
        fuel_efficiency = 1.0,
        maintenance_factor = 1.0,
        crew_cost_factor = 1.2,
        base_cost_per_hour = 4829
    },
    EASYJET = {
        fuel_efficiency = 0.95,
        maintenance_factor = 0.9,
        crew_cost_factor = 0.8,
        base_cost_per_hour = 10800
    },
    WIZZ_AIR = {
        fuel_efficiency = 0.85,
        maintenance_factor = 1.16,
        crew_cost_factor = 0.7,
        pw_grounding_risk = 0.20
    }
}

-- Calcul coût opérationnel réaliste
function calculate_operating_cost(flight_time, distance, airline_profile)
    local fuel_cost = flight_time * 2500 * 0.96 * airline_profile.fuel_efficiency
    local maintenance_cost = flight_time * 509 * airline_profile.maintenance_factor
    local crew_cost = flight_time * 180 * airline_profile.crew_cost_factor
    
    return fuel_cost + maintenance_cost + crew_cost
end
```

## Ressources pour validation
- Données IATA sur coûts opérationnels
- Rapports annuels Air France-KLM, EasyJet, Wizz Air
- Statistics Form 41 (DOT américain)
- Base Aircraft Cost Calculator

Cette approche permettra de créer un script économiquement réaliste reflétant fidèlement les défis opérationnels actuels des compagnies aériennes européennes sur famille Airbus A320.