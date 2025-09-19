Afin de rendre l'expérience de vol de l'A321 (et des autres monocouloirs ToLiss, comme l'A319 et l'A320) plus variée, j'ai écrit un script d'« usure » ​​pour XLua. Ce script vieillira l'avion et le moteur à l'usage, dégradant progressivement les performances en affectant les références de données correspondant aux curseurs « Âge de l'avion » et « Âge du moteur » dans l'ISCS (et donc la traînée de la cellule et le rendement du moteur). Il propose également une simulation d'économie d'énergie allégée (inspirée des packs d'extension de réalité) pour rendre le jeu plus intéressant, stimulant et motivant.


Avant que cela ne trouve officiellement son chemin dans la bibliothèque de téléchargement, j'aimerais qu'il soit testé en version bêta par d'autres utilisateurs de ToLiss ici, en particulier pour les éléments de la section « Compatibilité » ci-dessous.

 

Historique des versions :

30/08/2023 - Ajout d'un menu, d'un système économique simplifié, d'un mode strict et de nombreuses modifications internes. Si cela s'avère finalement trop bugué, l'ancienne version est toujours disponible sous le nom OLD_Toliss_WearAndTear_230802zip.
02/08/2023 - Ajout du vieillissement dynamique, en fonction du TAS (avion) ​​et du N1 (moteur)
30/07/2023 - Initiale
 

Caractéristiques:

Vieillissement persistant, automatique et dynamique des avions et des moteurs à l'aide des références de données des fonctions « Âge de l'avion » et « Âge du moteur » de tout Airbus ToLiss (en théorie ; voir « Compatibilité » ci-dessous). Conformément au manuel de simulation de ToLiss, l'âge de l'avion ajuste la traînée et l'âge du moteur la consommation de carburant spécifique.
Simulation d'économie légère. Les révisions pour rajeunir l'appareil coûtent de l'argent, qui doit être gagné en faisant voler une charge utile. Le carburant coûte aussi de l'argent.
Chaque livrée est traitée individuellement, offrant des possibilités de personnalisation spécifiques à l'opérateur.
Fournit des valeurs « PERF » pour le MCDU adaptées à l'âge du moteur.
Petit et léger grâce à Xlua.
Fournit son propre menu dans la barre de menu principale de X-Plane.
Inclut un script bonus optionnel (voir ci-dessous).
 

Compatibilité:

Avion :
Malheureusement, cette fonctionnalité n'est pas compatible avec l'A340-600, car elle ne dispose pas des références de données requises (« toliss_airbus/iscsinterface/aircraftAge » et « toliss_airbus/iscsinterface/engineAge »).
Son fonctionnement est confirmé pour l'A319, l'A320neo et l'A321/321neo.
X-Plane 11 :
Non testé, mais supporté théoriquement, avec des limitations. Le principal problème de compatibilité avec XP11 est l'absence de la référence de données « sim/aircraft/view/acf_relative_path », utilisée dans XP12 pour créer un chemin d'accès au fichier de persistance lorsque la livrée par défaut est utilisée (c'est-à-dire celle qui n'est chargée depuis aucun dossier de livrées). J'ai implémenté un paramètre pour désactiver cette vérification et une protection contre le chargement de cette référence de données afin de contourner ce problème sous XP11. Les résultats des tests sont les bienvenus ! Attention : n'utilisez pas la livrée Airbus « par défaut » sous XP11, sinon la persistance ne fonctionnera pas !
Systèmes d'exploitation :
Compatible avec Linux et Windows. Tests sur Mac bienvenus.
Fonctionnalités spécifiques à ToLiss :
Cette fonctionnalité pourrait ne pas fonctionner correctement avec la fonction « Aller au point de cheminement » des Airbus ToLiss. Les tests sont néanmoins bienvenus.
 

Installation:

TéléchargerToliss_WearAndTear_230831.zipet décompressez-le.
Quittez X-Plane, s'il est en cours d'exécution ou passez à un autre avion qu'un Airbus ToLiss.
Décompressez l'archive téléchargée.
Si vous utilisez déjà d’autres scripts XLua pour l’Airbus :

Déplacez les dossiers « WearAndTear » et (éventuellement ; voir « Bonus » ci-dessous) « Random_Startup_Brightness » de « xlua/scripts » vers « [Dossier racine ToLiSS Airbus]/plugins/xlua/scripts ».
Sinon:

Copiez le dossier « xlua » dans « [dossier racine ToLiSS Airbus]/plugins ».
Démarrez un vol avec votre Airbus ToLiss. Si vous voyez un menu « ToLiss A3xx [...] » dans la barre de menu principale de X-Plane avec un sous-menu « ToLiss Wear & Tear », cela signifie que l'installation a réussi.

 

Désinstallation:

Quitter X-Plane
Si vous utilisez d’autres scripts XLua pour l’Airbus :

Supprimez les dossiers « WearAndTear » et (éventuellement ; voir « Bonus » ci-dessous) « Random_Startup_Brightness » de « [Dossier racine ToLiSS Airbus]/plugins/xlua/scripts ».
Sinon:

Supprimez le dossier « xlua » de « [Dossier racine ToLiSS Airbus]/plugins ».
 

Menu:

Le menu « ToLiss Wear & Tear » se trouve dans le menu de l'avion « ToLiss A3xx [...] » et comporte les éléments suivants :

Toliss_WT_Menu.jpg

« Avion : [...] » : Lorsque le prix d'une révision est indiqué, cliquez dessus pour réviser l'appareil et le remettre à l'état neuf. Sans prix, la révision est impossible. Le niveau d'usure actuel est également affiché.
« Moteurs : [...] » : Comme ci-dessus, mais pour les moteurs.
« Revenus du vol » : affiche les revenus actuels du vol et fournit des indications sur la marche à suivre pour les générer ou les encaisser (lorsque le mode « Strict » est activé). Lorsque « Débogage » est activé, cliquer sur ce bouton forcera la détection de la charge utile actuelle en cas d'échec de la méthode automatique.
Coût du ravitaillement :  affiche le coût du ravitaillement en cours. Le ravitaillement n'est détecté que lorsque tous les moteurs sont arrêtés et son coût est déduit du prix au démarrage du moteur. Lorsque le mode « Débogage » est activé, un clic force la réinitialisation de la détection du ravitaillement.
« Espèces » :  affiche le montant actuel en espèces. Aucun effet lorsque vous cliquez dessus.
« Performances MCDU » :  affiche la valeur actuelle du paramètre « Performances » dans le menu « Données -> État du climatiseur » du MCDU (voir « Utilisation » ci-dessous). Ce paramètre est actualisé lorsque vous cliquez dessus.
« Debug » : active le mode de débogage pour une sortie et des fonctionnalités supplémentaires de la console de développement.
« Vieillissement progressif » : si désactivé, les changements d'âge ne s'appliquent qu'à la fin du vol. Cliquez pour activer/désactiver.
Persistance : Si cette option est désactivée, le fichier de persistance n'est pas enregistré dans « liveries/[nom de la livrée]/WearAndTear.txt » . Nécessaire pour l'enregistrement automatique. Cliquez pour activer/désactiver.
Sauvegarde automatique : si cette option est activée, le fichier de persistance est automatiquement enregistré à l'intervalle affiché. Cet intervalle doit être modifié manuellement en modifiant le fichier de persistance. La persistance doit être activée. Cliquez pour activer/désactiver cette option.
Mode strict : désactivé, certaines règles sont assouplies (voir « Principes de conception » ci-dessous). Cliquez pour activer/désactiver.
« Enregistrer l'usure » : lorsque vous cliquez dessus, écrit les données de persistance dans « liveries/[nom de la livrée]/WearAndTear.txt » .
« Charger l'usure et la déchirure » : lorsque vous cliquez dessus, lit les données de persistance à partir de « liveries/[nom de la livrée]/WearAndTear.txt » .
« Réinitialiser l'usure » : lorsque vous cliquez dessus, réinitialise l'usure aux valeurs initiales (par défaut).
 

Usage:

Lors de la première utilisation d'une livrée Airbus ToLiss, le script générera un âge aléatoire pour l'avion et le moteur. Si vous souhaitez une livrée entièrement nouvelle, vous devrez modifier le script en conséquence (voir « Configuration du script » ci-dessous).
Chargez l'Airbus et ravitaillez-le (ravitaillage rapide ou lent possible). La détection de ravitaillement fonctionne pour le chargement et le déchargement du carburant. Le coût du carburant est déduit du revenu du vol à la fin du vol.
Mettez à jour la valeur « PERF » dans le menu « DONNÉES --> ÉTAT CLIMATISATION » du MCDU en déverrouillant le champ « IDLE/PERF ». Pour ce faire, saisissez « ARM » dans le champ « CODE CHG ». La dernière valeur est disponible dans le menu « Usure » ​​(voir « Menu » ci-dessus). Assurez-vous de la saisir avec une barre oblique, par exemple « /+0,5 ». Une fois terminé, supprimez « ARM » pour verrouiller à nouveau le champ.
Démarrez au moins un moteur et affichez le temps écoulé sur le panneau principal pour collecter les revenus de vol. Les revenus sont collectés par tick de mise à jour (5 secondes par défaut). L'option de menu « Recettes de vol » (voir « Menu » ci-dessus) est astucieuse et vous rappelle les différentes conditions requises pour un paiement réussi. Les revenus ne s'affichent qu'après une minute de temps écoulé (voir « Problèmes connus » ci-dessous).
Les moteurs vieillissent en consommant du carburant. Comme il n'existe qu'un seul paramètre d'âge pour les moteurs des Airbus ToLiss, le vieillissement est proportionnel (par exemple, un moteur sur deux en fonctionnement – moitié du taux de vieillissement).
Décollage. Le vieillissement des moteurs dépendant de N1, il est conseillé d'utiliser votre poussée FLEX et votre indice de coût pour minimiser le vieillissement des moteurs et de l'avion à long terme. En mode « strict », le décollage est obligatoire pour débloquer les revenus de vol ultérieurement.
Effectuez votre vol. Dès que la vitesse est supérieure à 100 KTAS, la cellule vieillit. Plus la vitesse est élevée, plus le vieillissement est rapide.
L'enregistrement automatique du fichier de persistance sera effectué à intervalles réguliers, s'il est activé.
Atterrissez, coupez vos moteurs et arrêtez le temps écoulé. Dès que ces deux opérations sont terminées, les revenus du vol seront ajoutés à votre compte. Si le mode « strict » est activé, vous devez avoir déjà volé pour effectuer cette opération (sinon, vous pourriez simplement rester à la porte d'embarquement toute la journée pour générer des revenus). Les données de vol seront réinitialisées pour le vol suivant et le fichier de persistance ( « liveries/[nom de la livrée]/WearAndTear.txt » ) sera écrit ou mis à jour (si la persistance est activée). Le résultat financier de votre vol sera imprimé dans le fichier Log.txt et dans la console développeur de XP.
Si l'avion et les moteurs ne sont pas dans un état neuf, vous pouvez les réviser en cliquant sur les options de menu appropriées. En mode « strict », cela n'est pas possible si vous avez trop peu de fonds.
Prenez votre prochain vol si vous le souhaitez. N'oubliez pas de réinitialiser le compteur de temps écoulé en mode « strict », sinon vous ne recevrez aucun paiement !
Si vous changez d'avion ou mettez fin à votre session X-Plane, le fichier de persistance sera écrit ou mis à jour, s'il est activé. Si le vieillissement progressif n'est pas activé, le nouvel âge de l'avion et du moteur sera appliqué.
 

Configuration:

Vous pouvez modifier le fichier de persistance ( WearAndTear.txt ) avec un éditeur de texte. Son format de ligne est : « [Nom du paramètre]=[Valeur du paramètre]:[Type du paramètre] ». Modifiez uniquement la valeur du paramètre, pas son nom ni son type !

Il s'agit de la liste actuelle des paramètres stockés dans le fichier de persistance avec les valeurs par défaut actuelles :

Age_Aircraft=[randomized value]:number 	- The current aircraft age (min: -1, max: 2, default: random).
Age_Engines=[randomized value]:number 	- The current engine age (min: -1, max: 2, default: random).
Autosave=1:number 			- Autosave on/off, see "Menu" above (1 or 0).
AutosaveInterval=300:number 		- The autosave interval, in seconds. Must be greater than zero.
Cash=200000:number 			- The current amount of cash.
Cost_Aircraft=1:number 			- The cost of an aircraft overhaul. Default: 100000.
Cost_Engines=1:number 			- The cost of an engine overhaul. Default: 50000.
Cost_FuelPerKg=0.92:number 		- The cost of fuel per kg (default from Jet-A price in € as of 2023/08/28)
Currency=€:string 			- A string for the currency displayed in the menu. Use a symbol, ISO code or fantasy currency. Default: €
Debug=0:number 				- Debug mode on/off, see "Menu" above (1 or 0).
GradualAging=1:number 			- Gradual aging, see "Menu" above (1 or 0).
Persistence=1:number 			- Persistence, see "Menu" above (1 or 0).
RevenuePerKgPerHr=0.75:number 		- The revenue per kg of payload per flight hour. Assumption for the default value of 0.75: 1 pax is 100 kg with baggage and pays 150€ for a 2 hr flight: 150/100/2 = 0.75 €/kg/hr
Strict=1:number 			- "Strict" mode, see "Menu" above (1 or 0).
 

Le fichier de script principal, « [dossier d'installation principal de ToLiss Airbus]/plugins/xlua/scripts/WearAndTear/WearWearAndTear.lua », peut également être modifié avec un éditeur de texte, idéalement après l'arrêt de X-Plane. Il est plus adapté à la configuration générale des valeurs de départ ou à la configuration approfondie des paramètres. Voici quelques exemples d'informations intéressantes pour les utilisateurs :

-- General
local Persistence_File = "WearAndTear.txt"  -- Name of the persistence file (stored in the livery's folder)
-- Starting values
local Random_Start_Vals = true              -- True = Randomize the starting values if no persistence file is present, False = Do not randomize, always start with brand new aircraft and engines.
local Aircraft_Start_Val = -1               -- Default starting value for the aircraft age without randomization (-1 = brand new; 2 = Worn out)
local Engine_Start_Val = -1                 -- Default starting value for the engine age without randomization (-1 = brand new; 2 = Worn out)
-- Aircraft aging time
local Aircraft_Wear_Time = 1000             -- Aircraft: Time (in hours) for new to worn out at KTAS = TAS_Max (see ToLiss_Max_TAS below)
local Engine_Wear_Time = 500                -- Engines: Time (in hours) for new to worn out at 100% N1
-- Timers
local InitDelay = 1                         -- Delay (in seconds) before applying age values upon startup
local UpdateInterval = 5                    -- Update interval (in seconds) for calculating age (with GradualAging = true) or flight time (with GradualAging = false)
 

Problèmes connus :

Si votre X-Plane a tendance à planter à la fermeture (par exemple à cause de ce bug ), assurez-vous d'activer la sauvegarde automatique. Sinon, l'âge accumulé pendant la session sera perdu !
Il est impossible de réinitialiser l'âge avec les curseurs ISCS. Pour réviser votre Airbus, effectuez-le depuis le menu, modifiez manuellement le fichier WearAndTear.txt ou supprimez-le simplement.
La valeur de « PERF » ne peut pas être définie automatiquement.
L'affichage « [Début du temps écoulé] » reste actif même si les moteurs sont allumés et que le chronomètre est lancé jusqu'à ce qu'une minute se soit écoulée. Ce problème est inévitable, car le chronomètre n'utilise pas les secondes, mais uniquement les minutes et les heures.
Le dispositif de suivi du niveau de carburant peut enregistrer de très légers changements dans les niveaux de carburant lors du démarrage ou de l'arrêt de l'APU ou des moteurs.
Le coût du carburant et les recettes des billets ne sont qu'une estimation et sont totalement déséquilibrés. Toute suggestion d'amélioration des valeurs par défaut est la bienvenue.
 