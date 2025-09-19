## Complément au script d'économie Toliss A320/A321 - Module Cost Index

### Objectif du module Cost Index
Intégrer le paramètre Cost Index (CI) comme variable économique dynamique dans le script d'usure et d'économie, reflétant fidèlement les politiques opérationnelles d'Air France, EasyJet et Wizz Air.

## Définition et implémentation du Cost Index

### Formule de base Cost Index
```
Cost Index = (Coûts liés au temps en USD/minute) / (Coût carburant en USD/kg)

CI = (Coût_Equipage + Coût_Maintenance + Coût_Amortissement) / Prix_Carburant_kg
```

### Valeurs réalistes par compagnie (2024-2025)

#### Air France - Profil Premium/Réseau
```
CI_Air_France = {
    A320: 10-15 (valeur standard: 12),
    A321: 15-20 (valeur standard: 17),
    Facteur_Ponctualite: 1.2 (hub CDG contraintes slots),
    Ajustement_Prix_Carburant: CI = CI_base * (1.10 - Prix_Carburant/1000)
}
```

#### EasyJet - Low-Cost Optimisé
```
CI_EasyJet = {
    A320CEO: 12 (optimisation carburant),
    A320NEO: 10 (efficacité moteurs),
    A321: 23 (densité élevée, rotation rapide),
    Politique: "Carburant prioritaire sur temps"
}
```

#### Wizz Air - Ultra Low-Cost Dynamique
```
CI_Wizz_Air = {
    Range: 8-20 (ajustement selon conditions),
    A320CEO_Retirement: 8-12 (maximiser économies avant retrait),
    A321NEO: 15-18 (équilibre performance/coût),
    Facteur_P&W_Issues: CI +3 si moteur P&W (compenser immobilisations)
}
```

## Impact du Cost Index sur les paramètres de vol

### 1. Vitesse de croisière optimale
```lua
function calculate_cruise_speed(cost_index, altitude, weight)
    -- Vitesse économique de base A320
    local econ_speed = 0.78  -- Mach
    local max_speed = 0.82   -- Mach
    
    -- Calcul vitesse optimale selon CI
    local speed_factor = math.min(cost_index / 100, 0.8)
    local target_speed = econ_speed + (max_speed - econ_speed) * speed_factor
    
    return target_speed
end
```

### 2. Profil de montée optimisé
```lua
CI_CLIMB_PROFILES = {
    [0] = {rate: "250 kts to FL100, then 300/.78M", profile: "ECO"},
    [20] = {rate: "250 kts to FL100, then 320/.80M", profile: "STD"},
    [50] = {rate: "250 kts to FL100, then 340/.82M", profile: "FAST"},
    [99] = {rate: "Maximum climb rate", profile: "MAX"}
}
```

### 3. Impact économique dynamique
```lua
function calculate_ci_fuel_impact(base_consumption, cost_index, flight_time)
    -- CI bas = économie carburant, CI haut = consommation +
    local fuel_factor = 1 + (cost_index - 20) * 0.003  -- ±3% par 10 points CI
    local time_factor = 1 - (cost_index - 20) * 0.002  -- temps réduit si CI haut
    
    return {
        fuel_consumed = base_consumption * fuel_factor,
        flight_time_ratio = time_factor,
        total_cost = fuel_cost + (crew_cost * flight_time_ratio)
    }
end
```

## Variables dynamiques du Cost Index

### Ajustement prix carburant
```lua
FUEL_PRICE_CI_ADJUSTMENT = {
    -- Prix carburant bas (0.70 USD/kg) -> CI plus haut acceptable
    [0.70] = {multiplier: 1.3, reason: "Carburant bon marché"},
    -- Prix standard (0.95 USD/kg) -> CI normal
    [0.95] = {multiplier: 1.0, reason: "Prix standard"},
    -- Prix élevé (1.20 USD/kg) -> CI réduit pour économiser
    [1.20] = {multiplier: 0.7, reason: "Carburant cher"}
}
```

### Contraintes opérationnelles
```lua
CI_OPERATIONAL_FACTORS = {
    hub_congestion = {
        CDG: +5,  -- Slots contraints, priorité ponctualité
        LGW: +3,  -- Congestion Gatwick
        BUD: +2   -- Hub Wizz Air, rotations rapides
    },
    weather_conditions = {
        strong_headwinds: +8,  -- Compenser vent contraire
        tailwinds: -3,         -- Profiter vent favorable
        storms_ahead: +12      -- Éviter zones dangereuses
    },
    fleet_issues = {
        pw_engine_problems: +5,  -- Wizz Air - compenser retards
        maintenance_backlog: +7, -- Accélérer vols restants
        crew_duty_limits: +15    -- Maximiser avant limite service
    }
}
```

## Interface utilisateur Cost Index

### Sélecteur compagnie avec CI automatique
```lua
AIRLINE_CI_PRESETS = {
    {name: "Air France", ci_min: 10, ci_max: 15, ci_default: 12},
    {name: "EasyJet", ci_min: 8, ci_max: 25, ci_default: 12},
    {name: "Wizz Air", ci_min: 8, ci_max: 20, ci_default: 15},
    {name: "Custom", ci_min: 0, ci_max: 99, ci_default: 20}
}
```

### Calculateur CI optimal temps réel
```lua
function suggest_optimal_ci(fuel_price, crew_cost_hour, maintenance_cost_hour, route_distance)
    local time_cost_per_minute = (crew_cost_hour + maintenance_cost_hour) / 60
    local fuel_cost_per_kg = fuel_price
    
    local theoretical_ci = time_cost_per_minute / fuel_cost_per_kg
    
    -- Ajustements pratiques
    local practical_ci = math.max(5, math.min(80, theoretical_ci))
    
    return {
        suggested_ci = practical_ci,
        fuel_savings_low_ci = calculate_fuel_savings(practical_ci - 10),
        time_savings_high_ci = calculate_time_savings(practical_ci + 10)
    }
end
```

## Affichage des résultats CI

### Tableau de bord économique étendu
```
=== COST INDEX ANALYSIS ===
Current CI: 15 (Air France Standard)
Fuel Impact: +2.3% vs CI 0
Time Saved: 8 minutes vs CI 0
Cost Analysis:
- Extra Fuel Cost: €127
- Time Value Saved: €145
- Net Benefit: +€18 (optimal)

Real-time CI Suggestion: 17
Reason: Fuel price favorable (€0.89/kg)
```

### Comparateur multi-CI
```
CI Comparison for CDG-BCN (A320):
┌────┬─────────┬──────────┬──────────┬───────────┐
│ CI │ Time    │ Fuel (kg)│ Cost (€) │ Company   │
├────┼─────────┼──────────┼──────────┼───────────┤
│ 8  │ 1h47m   │ 1,847    │ 2,043    │ Wizz Air  │
│ 12 │ 1h44m   │ 1,891    │ 2,087    │ Air France│
│ 23 │ 1h38m   │ 1,967    │ 2,156    │ EasyJet   │
└────┴─────────┴──────────┴──────────┴───────────┘
```

## Événements spéciaux CI

### Réactions automatiques
```lua
SPECIAL_CI_EVENTS = {
    fuel_shortage_airport = {ci_adjustment: -15, reason: "Économiser carburant"},
    crew_overtime_risk = {ci_adjustment: +25, reason: "Éviter heures sup"},
    slot_restrictions = {ci_adjustment: +10, reason: "Respecter créneaux"},
    emergency_diversion = {ci_override: 99, reason: "Priorité sécurité"}
}
```

## Validation historique

### Base de données CI réelles
Intégrer une base de données des Cost Index réellement utilisés par les compagnies :
- Air France A320: CI 12 (vols moyen-courrier UE)
- EasyJet A320: CI 12-15 (selon saison)
- Wizz Air A321: CI 15-18 (optimisation flotte jeune)

Cette intégration du Cost Index transformera le script en véritable simulateur de gestion opérationnelle, où chaque décision CI impacte directement l'économie du vol, comme dans les vrais centres de contrôle opérationnel (OCC) des compagnies aériennes.

## Code d'intégration final
```lua
-- Module Cost Index pour script Toliss
function init_cost_index_system()
    -- Initialisation selon profil compagnie sélectionné
    local airline = get_selected_airline()
    set_default_ci(AIRLINE_CI_PRESETS[airline].ci_default)
    
    -- Monitoring temps réel
    monitor_fuel_price_changes()
    monitor_operational_constraints()
    
    -- Interface pilote
    create_ci_adjustment_interface()
end
```

***

 Intégration automatique des données SimBrief via lien XML

## Objectif
Permettre au script d’importer et d’analyser directement un plan de vol SimBrief XML donné par URL, afin de charger dynamiquement la route, le carburant, les aéroports, les paramètres d’altitude et optimiser les coûts et l’usure en fonction des données réelles.

***

## Étapes recommandées

1. **Récupération du fichier XML SimBrief depuis le lien**

```lua
-- Fonction pour récupérer le fichier XML à partir de l'URL SimBrief
function fetchSimBriefXML(url)
    local http = require("socket.http")
    local body, code = http.request(url)
    if code == 200 then
        return body
    else
        print("Erreur récupération SimBrief: " .. tostring(code))
        return nil
    end
end

local simbrief_xml_url = "https://www.simbrief.com/ofp/flightplans/xml/LFPOLFBO_XML_1758323052.xml"
local simbrief_xml = fetchSimBriefXML(simbrief_xml_url)
```

2. **Parsing du XML avec xml2lua**

```lua
local xml2lua = require("xml2lua")
local handler = require("xmlhandler.tree")

local parser = xml2lua.parser(handler)
parser:parse(simbrief_xml)

local ofp = handler.root.OFP[1]  -- Noeud racine du plan de vol
```

3. **Extraction des données utiles**

```lua
local origin = ofp.departure.icao_code
local destination = ofp.arrival.icao_code
local block_fuel = tonumber(ofp.fuel.block.text)
local alternate = ofp.alternate[1].icao_code
local cost_index = tonumber(ofp.cruise.costindex) or 20
local route = {}

for _, wpt in ipairs(ofp.route.rr) do
    table.insert(route, wpt.text)
end
```

4. **Intégration dans la logique économique et d’usure**

- Utiliser `block_fuel` pour calculer le coût carburant réel.
- Affecter `origin`, `destination`, et `alternate` aux frais d’aéroport, en utilisant le tableau AIRPORT_FEES déjà existant.
- Ajuster la vitesse, la consommation en fonction du `cost_index`.
- Adapter l’usure des moteurs et des composants en fonction du plan de vol, des vents et du poids extrait du XML.

***

## Exemple d’appel d’intégration

```lua
function integrateSimBriefData(url)
    local xml_data = fetchSimBriefXML(url)
    if xml_data then
        local parser = xml2lua.parser(handler)
        parser:parse(xml_data)
        local ofp = handler.root.OFP[1]

        local origin = ofp.departure.icao_code
        local destination = ofp.arrival.icao_code
        local block_fuel = tonumber(ofp.fuel.block.text)
        local cost_index = tonumber(ofp.cruise.costindex) or 20

        -- Appliquer les données au script
        AIRPORT_FEES.current_origin = AIRPORT_FEES[origin] or AIRPORT_FEES.DEFAULT
        AIRPORT_FEES.current_destination = AIRPORT_FEES[destination] or AIRPORT_FEES.DEFAULT

        updateFuelCosts(block_fuel)
        updateCostIndex(cost_index)
        updateRoute(ofp.route)

        print("Données SimBrief intégrées pour vol " .. origin .. " -> " .. destination)
    else
        print("Échec d'intégration des données SimBrief")
    end
end

-- Lancer l’intégration
integrateSimBriefData(simbrief_xml_url)
```

***

## Notes et ressources utiles

- Ce script nécessite la bibliothèque Lua `socket.http` pour effectuer des requêtes HTTP depuis X-Plane/FlyWithLua.
- Utilisez `xml2lua` (ou un autre parser XML Lua) pour décoder le plan SimBrief.
- Vous pouvez automatiser la récupération via API SimBrief avec une clé utilisateur pour plus de flexibilité.
- Veillez à gérer les erreurs réseau et XML partiels.

-- Dépendances nécessaires (placer dans Resources/plugins/FlyWithLua/modules/)
local socket = require("socket.http")   -- Pour les requêtes HTTP
local xml2lua = require("xml2lua")       -- Parser XML Lua disponible dans FlyWithLua
local handler = require("xmlhandler.tree")

-- Tableau des frais aéroportuaires
local AIRPORT_FEES = {
    CDG = 259,
    ORY = 210,
    NCE = 65,
    MRS = 75,
    TLS = 100,
    LYS = 85,
    BOD = 70,
    LIL = 70,
    NTE = 78,
    SXB = 78,
    BSL = 82,
    BZR = 60,
    FDF = 112,
    RUN = 110,
    TUF = 65,
    BIA = 68,
    AJACCIO = 70,
    DEFAULT = 150
}

-- URL SimBrief XML (exemple lien fourni)
local SIMBRIEF_XML_URL = "https://www.simbrief.com/ofp/flightplans/xml/LFPOLFBO_XML_1758323052.xml"

-- Fonction pour récupérer XML depuis SimBrief
function fetchSimBriefXML(url)
    local response_body = {}
    local res, code = socket.request{
        url = url,
        sink = ltn12.sink.table(response_body)
    }
    
    if code == 200 then
        return table.concat(response_body)
    else
        logMsg("Erreur téléchargement SimBrief XML - code: "..tostring(code))
        return nil
    end
end

-- Fonction pour parser XML SimBrief
function parseSimBriefXML(xml_data)
    local parser = xml2lua.parser(handler)
    parser:parse(xml_data)
    return handler.root.OFP[1]
end

-- Fonction principale d’intégration des données SimBrief dans le script de vol
function integrateSimBriefPlan(url)
    local xml = fetchSimBriefXML(url)
    if not xml then
        logMsg("Impossible de récupérer le fichier SimBrief XML")
        return
    end

    local ofp = parseSimBriefXML(xml)
    if not ofp then
        logMsg("Erreur parsing SimBrief XML")
        return
    end

    -- Récupérer données clés
    local origin = ofp.departure.icao_code
    local destination = ofp.arrival.icao_code
    local block_fuel = tonumber(ofp.fuel.block.text) or 0
    local alternate = (ofp.alternate and ofp.alternate[1] and ofp.alternate[1].icao_code) or ""
    local cost_index = tonumber(ofp.cruise.costindex) or 20

    -- Récupération des waypoints/routes
    local route = {}
    if ofp.route and ofp.route.rr then
        for _, wpt in ipairs(ofp.route.rr) do
            table.insert(route, wpt.text)
        end
    end

    -- Calcul frais aéroport basés sur destination/origin
    local origin_fee = AIRPORT_FEES[origin] or AIRPORT_FEES.DEFAULT
    local dest_fee = AIRPORT_FEES[destination] or AIRPORT_FEES.DEFAULT

    -- Mise à jour des variables globales (à adapter selon votre script)
    DATA_ORIGIN = origin
    DATA_DESTINATION = destination
    DATA_BLOCK_FUEL = block_fuel
    DATA_ALTERNATE = alternate
    DATA_COST_INDEX = cost_index
    DATA_ROUTE = route
    DATA_ORIGIN_FEE = origin_fee
    DATA_DEST_FEE = dest_fee

    -- Logging des infos de vol
    logMsg(string.format("Vol %s -> %s avec %d kg carburant, CI=%d, origine frais %d€, dest frais %d€", origin, destination, block_fuel, cost_index, origin_fee, dest_fee))
    
    -- Exemple d’application : recalcul coûts économiques + modifier usure moteur...
    updateEconomyAndWear(block_fuel, cost_index, origin_fee, dest_fee)

    -- Mise à jour interface cockpit/tablette
    updateFlightPlanInUI(DATA_ROUTE, origin, destination, cost_index)
end

-- Exemple simple fonction de mise à jour économie et usure (à compléter selon besoin)
function updateEconomyAndWear(block_fuel, cost_index, origin_fee, dest_fee)
    local fuel_cost_per_kg = 0.96 -- ex. prix carburant
    local fuel_cost = block_fuel * fuel_cost_per_kg
    local total_fees = origin_fee + dest_fee
    -- Calcul coût total
    local total_cost = fuel_cost + total_fees
    -- Appliquez ici vos règles de consommation/usure/model économique
    -- Par exemple : Usure moteur augmente avec block_fuel / heures vol estimées
    logMsg(string.format("Coût carburant estimé : %.2f USD, frais aéroport total : %d EUR", fuel_cost, total_fees))
end

-- Fonction affichage mise à jour UI (adapter selon votre display)
function updateFlightPlanInUI(route, origin, destination, ci)
    -- Affiche plan de vol, CI, etc. sur tablette ou EFB
    -- Ceci dépendra de votre UI spécifique dans X-Plane FPS cockpit
end

-- Démarrage intégration SimBrief plan
do
    integrateSimBriefPlan(SIMBRIEF_XML_URL)
end


Voici une explication détaillée et un exemple  à intégrer dans votre script pour configurer le FMC (MCDU) du Toliss A320/A321 avec les paramètres IDLE et PERF en fonction des données de l’avion et de son usure/maintenance.

***

# Intégrer IDLE et PERF dans la configuration FMC du Toliss A320/A321

### Contexte

- Le **PERF factor** est une correction appliquée sur la consommation de carburant estimée par le FMC. Il compense l’usure moteur, la saleté du compresseur, ou d'autres écarts par rapport aux valeurs théoriques.[1][2]
- Le **IDLE factor** ajuste la gestion verticale pendant la descente, modifiant la poussée minimum (idle thrust) pour s’adapter aux conditions réelles, telles que vent ou usure.[2][1]
- Ces facteurs sont généralement maintenus et actualisés par le département maintenance en fonction des données moteur réelles.

### Objectif

Configurer dynamiquement la page PERF du FMC dans votre script avec ces valeurs, afin d’avoir un calcul précis de la consommation carburant et une meilleure gestion verticale.

***

### Exemple de prompt et snippet Lua (FlyWithLua) pour configurer PERF/IDLE

```lua
-- Exemple de récupération des données IDLE/PERF stockées (à intégrer dans la logique maintenance)
local factors = {
    PERF = 1.8,  -- Exemple : consommation carburant est +1.8% au dessus du modèle standard
    IDLE = 0.5   -- Exemple : idle factor positif, descente plus douce/début plus tôt
}

-- Fonction d'écriture FMC PERF / IDLE variables (exemple simulation)
function configureFMCPerfIdle(perf_factor, idle_factor)
    -- Ces variables sont fictives, adaptez-les aux DataRefs réels du Toliss ou FlyWithLua
    local dataref_perf_factor = find_dataref("sim/cockpit2/engine/EGT_correction") -- Exemple DataRef
    local dataref_idle_factor = find_dataref("sim/cockpit2/fmc/idle_factor")

    if dataref_perf_factor then
        dataref_perf_factor = perf_factor -- injection PERF factor calculé
        logMsg("PERF factor FMC réglé à : " .. tostring(perf_factor))
    end
    if dataref_idle_factor then
        dataref_idle_factor = idle_factor -- injection IDLE factor calculé
        logMsg("IDLE factor FMC réglé à : " .. tostring(idle_factor))
    end
end

-- Appel avec les valeurs issues de maintenance ou calculées dynamiquement
configureFMCPerfIdle(factors.PERF, factors.IDLE)
```

***

### Comment intégrer ce script dans votre maintenance

1. Collectez les données réelles de consommation moteur et d’usure (ex : à partir de vos logs ou via SimBrief + modèles internes).
2. Calculez ou mettez à jour votre facteur PERF (en %) et IDLE (en intensité de poussée idle).
3. Lors de la préparation du vol, injectez ces valeurs dans le FMC via ce script.
4. Le FMC utilisera alors ces paramètres pour affiner la performance de vol, la prévision carburant, la trajectoire, etc.

***

### Inspirations Techniques

- Les facteurs PERF et IDLE impactent les calculs fuel flow et profils de descente optimisés FMGC.[1][2]
- Un PERF factor positif signifie plus de consommation fuel que prévu, souvent moteur usé.
- Un IDLE factor > 0 ralentit la descente, avec un début plus anticipé.
- Dans la vraie vie, des valeurs sont souvent comprises entre -2 à +3% pour PERF, et -1 à +1 pour IDLE.

***

### Sources et approfondissement

- https://www.linkedin.com/posts/the-a320-study-guide_a320pilot-flighttraining-studentpilot-activity-7226191267636932611--EZr
- https://forum.aeroversity.com/t/what-are-the-idle-perf-factors/52

***

Cet ajout permettra d’avoir un FMC parfaitement adapté à la configuration réelle et état de l’avion, pour un réalisme accru en vol et en performance économique.

Si besoin d’aide pour localiser les DataRefs Toliss exacts pour ces variables, je peux vous guider plus précisément.
