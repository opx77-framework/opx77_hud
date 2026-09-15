# opx77_hud — architecture

opx77_hud est le HUD joueur d'OPX//77 : une surface WebUI qui dessine ce que deux autres
resources détiennent — la santé, l'armure, l'argent et le métier d'`opx77_core`, l'endurance, la
faim, la soif et la street cred d'`opx77_status` — ainsi que la bande de puces d'état
qu'`opx77_status` publie. Elle masque aussi le HUD du jeu, parce qu'elle dessine son remplaçant.
Elle ne décide rien et n'écrit rien : aucun mutateur du core, aucune base de données, aucun
event serveur hormis la réponse de `/hud` qui revient au joueur qui l'a tapée. Le mode d'emploi
est dans le README ; ce document dit pourquoi le code est écrit ainsi.

Le code est commenté en anglais par blocs d'annotation ; cette documentation est en français.

## Manifeste

L'ordre de chargement est l'ordre du manifeste, et il porte :

- `config.lua` est un `shared_script` parce que les deux moitiés le lisent : la mise en page côté
  client, le nom de la commande côté serveur.
- `shared/locale.lua` vient après `config.lua` parce qu'il lit `LOCALE` au chargement ; les deux
  catalogues viennent juste après lui, pour qu'aucun fichier plus bas n'appelle `locale()` contre
  un catalogue vide. Les trois sont partagés parce que la commande, et donc la ligne d'usage
  traduite, vit côté serveur.
- `server/main.lua` n'existe que pour la commande : le runtime client d'OPEN//77 n'installe pas
  `RegisterCommand`.
- Côté client : `client/state.lua` crée `OpxHud.State` ; `client/vanilla.lua` coupe le HUD du jeu
  avant que le nôtre ne dessine par-dessus ; `client/keys.lua` crée `OpxHud.Keys` avant
  `client/main.lua`, qui enregistre la touche à travers lui et dessine ce que `State` tient ;
  `client/exports.lua` vient en dernier, parce que publier la surface affirme qu'elle existe.
- Chaque script est listé sur sa propre ligne : un glob de script qui ne correspond à rien refuse
  tout le jeu de resources de la session (`script_pattern_empty:...`). `web_files { "web/**" }`
  est la seule forme de glob sûre.
- `reload_policy "reconnect"` : c'est la politique d'une resource qui possède une surface CEF,
  qu'on ne remplace jamais en place.
- `web_ui_auto_create false` : la page est créée dans `client/main.lua`, pour qu'un échec soit une
  ligne de log et non une resource muette.

Permissions :

- `network.events` — la réponse de `/hud`, de la moitié serveur vers la moitié client de cette
  même resource (`opx77_hud:visibility`, `opx77_hud:notice`) ; rien d'affiché ne passe par le réseau.
- `ui.vanilla.hud` — `client/vanilla.lua` masque le HUD du jeu pour qu'il ne soit pas dessiné sous
  celui-ci.
- `input.actions` — `client/keys.lua` : `RegisterKeyMapping` pour la touche afficher/masquer, et
  `Open77.input.isCaptured`, pour qu'une touche tapée dans le chat ou un formulaire ne masque pas
  le HUD.

## Contrats

La liste des exports, de la commande, des events et des clés de configuration est dans le README
et dans opx77_doc ; elle n'est pas recopiée ici.

- **Toute réponse d'export** est une table portant `ok`, construite par `response`
  (`client/exports.lua`). Aucune export ne refuse ni ne lève : `ok` vaut toujours `true`.
- **`setVisible`** teste `value ~= false` : toute autre valeur, `nil` compris, affiche. La réponse
  porte la visibilité obtenue, pas celle demandée.
- **`vanilla`** est en lecture seule, volontairement sans setter : le HUD du jeu est à cette
  resource de masquer parce qu'elle dessine le remplaçant, et un second avis venu d'ailleurs est
  la façon dont un joueur se retrouve sans aucun HUD.
- **`opx77_hud:visibility` et `opx77_hud:notice`** sont des canaux internes entre les deux moitiés,
  pas une API.

## Deux sources, lues une fois puis poussées

`opx77_core` est lu une seule fois au démarrage avec son export `GetPlayerData`, pour rattraper un
personnage chargé avant cette resource ; ensuite, seulement par ses events locaux
`opx77:client:onPlayerLoaded`, `playerDataChanged` et `onPlayerUnloaded`. Le core renvoie tout
`PlayerData` à chaque changement, donc rien n'est fusionné ici. `opx77_status` suit le même schéma :
`getNeeds` une fois (`pullNeeds`), puis `opx77:status:needs`. Aucune boucle ne sonde l'une ou
l'autre.

`call` (`client/main.lua`) lit un échec à trois niveaux : la resource ne tourne pas
(`GetResourceState`, un indice), l'appel n'est pas parti (`promise` absente — une promesse est un
userdata, testée par présence), l'appel est parti et a échoué (`callError`), ou la resource a
répondu par un refus. Son troisième retour, `answered`, dit si la resource a exécuté l'export :
**seul un refus efface quelque chose**. Un appel qui n'a jamais atterri ne dit rien du personnage,
et `pull` / `pullNeeds` gardent alors ce qu'ils avaient ; un refus d'`opx77_status` (pas de
personnage, ou son serveur n'a pas encore répondu) fait autorité.

Les noms `opx77:status:needs` et `opx77:status:effects` sont écrits en dur : une resource satellite
ne peut pas lire la configuration d'une autre.

`opx77_status` démonte sa bande de puces en s'arrêtant mais ne lève aucun adieu pour les besoins :
`onClientResourceStop` les efface donc ici, pour que les jauges qu'il possède quittent le cadre au
lieu de rester figées sur leur dernière valeur.

## Une valeur absente n'est jamais dessinée à zéro

Une barre de faim vide est une chose sur laquelle un joueur agit. `OpxHud.State.SetNeeds` n'adopte
les besoins que si `ready == true` et que `values` est une table ; sinon `needsReady` est faux et
`need` répond `nil`, et les blocs `needs` et `cyber` n'ajoutent rien. Une valeur non finie répond
aussi `nil`. `OpxHud.State.Finite` fait le test : `value == value` est le test NaN, NaN étant la
seule valeur différente d'elle-même.

## Construire les lignes

`OpxHud.State.View` exécute un constructeur par nom de `BLOCKS`, dans l'ordre de la liste ; un nom
inconnu est ignoré, et `BLOCKS` qui n'est pas une table ne construit rien.

- `THRESHOLD` : tout ce qui n'est pas un nombre fini se lit comme `false` (toujours afficher),
  parce qu'une comparaison contre une chaîne lèverait au lieu de refuser.
- `buildVitals` : la santé toujours, l'armure seulement au-dessus de zéro, sans ton — une armure
  basse n'est pas l'alerte qu'est une santé basse.
- `buildMoney` : `EDDIES` et `BANK` d'abord, puis les autres types triés. La liste des types
  supplémentaires n'est allouée que pour un opérateur qui en a configuré, et ne garde que les clés
  chaînes : `table.sort` sur des clés de types mélangés lève, et `:lower()` sur un nombre aussi.
  `KNOWN_SET` est construit une fois, pas à chaque frame.
- `buildIdentity` : la ligne de métier (ton `on` en service) et `CRED`, arrondie vers le bas,
  au-dessus de zéro.

Une jauge ne porte pas de libellé : `gauge()` dans `web/hud.js` dessine l'icône, les segments et la
valeur, et n'en lit jamais. Seules les lignes de texte en portent un.

## Une frame qui ne change rien n'envoie rien

`draw` réduit la vue à une signature (`OpxHud.State.Signature`) et ne l'envoie que si elle diffère
de `drawn`, la dernière acceptée par la page.

- La signature est une seule liste plate jointe une fois : six champs par ligne, donc le nombre de
  lignes se relit dans le nombre de champs et aucun séparateur de ligne n'est nécessaire. Une vue
  absente répond `"\0"` : un personnage sans ligne et pas de personnage du tout sont deux frames
  différentes.
- Les puces rejoignent la signature (`effects.signature`, trois champs par puce puis les trois de
  la bande) : une puce qui apparaît est un repaint même si aucune jauge n'a bougé. Elle est
  calculée sur les valeurs que la frame porte, jamais sur le payload brut, et `remainingMs` n'y
  entre pas : un compte à rebours qui avance n'est pas une nouvelle image, la page l'anime sur sa
  propre horloge.
- Toute la surface, bande de puces comprise, tient à une seule classe `open` : masquer se décide
  donc sur `State.visible` et non sur la vue. Une puce vivante ne garde pas à l'écran un HUD que le
  joueur a éteint.
- Un message qui n'a pas atterri (`send` rend `false`) remet `drawn` à `nil` : la page dessine
  encore une frame plus ancienne.
- Deux cas forcent l'envoi : `hud:ready` (la page est neuve, `drawn` décrit un DOM qui n'existe
  plus) et un changement de visibilité (elle ne fait pas partie de la signature, donc une frame
  sinon identique serait sautée).

`send` enveloppe `page:send` dans un `pcall` : chaque appelant est un handler ou le thread de
démarrage, et une levée de l'hôte doit être journalisée plutôt que de les terminer.

## La bande d'effets est une entrée non fiable

Le bus local du client est commun à tout l'hôte : n'importe quelle resource peut lever
`opx77:status:effects`. Le handler borne donc tout avant la page, qui garde un élément par id de
puce : au plus `MAX_CHIPS` (12) puces, sans id elles sont écartées ; `hiddenCount` ramène le
compte au-delà à `0..MAX_HIDDEN` (999, le plus grand `+N` qui se lit encore comme un nombre) ;
`anchorOf` refuse une chaîne de plus de 32 caractères ; `offsetOf` refuse un décalage hors de
`0..SURFACE_HEIGHT`. Le payload est porté dans la frame suivante plutôt qu'envoyé seul, pour que la
page n'ait jamais deux sources décidant quand elle repeint.

## La surface WebUI

`onClientResourceStart` crée la page sur la couche `hud`, 1920 × 1080, 30 fps, `zIndex = 705`,
transparente, et **visible dès la création** : une surface créée masquée n'envoie jamais de frame
une fois montrée. `drawn`, `page` et `pageReady` sont oubliés à l'arrêt de cette resource.

Lua ignore tout message sortant tant que la page n'a pas levé `hud:ready` ; `web/hud.js` le lève
quoi qu'il se soit passé pendant son initialisation. `hud:config` part une fois par page ;
`hud:diag` rapporte les erreurs de la page dans le log client, puisque le pont avale les exceptions
des handlers et que la console CEF n'atteint pas le log.

Le thread de démarrage lit chaque source une fois, pour un personnage chargé avant cette
resource ; tout changement ultérieur arrive par un event.

## Répondre au joueur

`/hud` n'a qu'une réponse, la ligne d'usage d'un argument inconnu ; afficher ou masquer ne répond
rien, le HUD qui monte ou descend est la réponse. Le serveur n'envoie pas de ligne de chat : le
chat est pour ce que disent les joueurs. Il envoie `opx77_hud:notice`, et `OpxHud.Runtime.Notify`
lève un toast via `opx77_notify` dans un emplacement unique remplacé (`opx77_hud.answer`) : un
joueur qui répète une faute de frappe voit un toast, pas une pile. Avec `NOTIFY = false`, quand
`opx77_notify` ne tourne pas ou refuse, la même ligne part dans le chat (`chatLine`), et le log le
dit une seule fois (`notifyReported`). `opx77_notify` n'est jamais une dépendance.

La commande est ouverte (`restricted` à `false`) : masquer son propre HUD n'est pas un acte
d'opérateur. Le serveur ne décide rien du HUD : il traduit le mot tapé en mode et le renvoie au
client.

## La touche

`OpxHud.Keys.Register` déclare la correspondance à l'hôte par `RegisterKeyMapping` : l'onglet des
raccourcis du menu pause la liste sous le nom localisé et le joueur la réassigne là. Rien ici ne lit
une touche soi-même. L'id `opx77_hud.toggle` est stable, parce qu'une réassignation est stockée
sous lui.

- Deux formes de réponse sont documentées : le guide des touches rend `true, key`, la référence
  d'API la touche seule. Les deux sont un enregistrement ; `false|nil, reason` est un refus, qui
  coûte une ligne de log, la commande restant disponible.
- Un appui pendant qu'une autre surface tient le clavier (le composeur du chat, un formulaire
  opx77_input, le menu pause) ne fait rien (`captured`) : une touche tapée dedans ne doit pas agir
  derrière.
- `OpxHud.Keys.Setting` accepte un nom de touche ou `false` ; toute autre valeur est le défaut,
  annoncé une fois.
- La touche bascule côté client, sans l'aller-retour que fait la commande : celle-ci ne décide rien,
  elle ne renvoie qu'une bascule.

## Le HUD du jeu

Laissé seul, Cyberpunk continue de dessiner sa barre de santé, son horloge et sa minimap sous
celui-ci. `OpxHud.Vanilla.Apply` applique `VANILLA` au démarrage, et à nouveau sur
`opx77:client:onPlayerLoaded`, parce que le jeu ramène son HUD à l'incarnation, qui arrive après le
démarrage de cette resource.

- `api` résout `Open77.hud` à chaque entrée : ce fichier se charge avant que la session soit prête.
- `known` valide les noms contre `Open77.hud.components()` ; une réponse vide n'est pas l'affirmation
  qu'il n'y a aucun composant, elle vaut absence de réponse, et rien n'est alors validé.
- `found` garde la visibilité de chaque composant avant le premier `Apply`, une seule fois ;
  `Apply` peut être rappelé sans l'écraser. `OpxHud.Vanilla.Restore` remet ces valeurs à l'arrêt,
  seulement pour les composants dont le client a rapporté la visibilité.
- `OpxHud.Vanilla.Snapshot` est ce que l'export `vanilla` rend, pour qui débogue un HUD qui ne
  veut pas partir.

## Horloge serveur

La limite de débit de la suggestion de chat compare `nowMs` à `lastSuggestedMs`.
`Open77.time.monotonic` répond en **secondes** ; une lecture non finie est écartée plutôt que
propagée. Garder la dernière lecture ne serait pas une dégradation sûre : une horloge figée rendrait
`atMs - previous` nul pour tout joueur déjà servi, sous le plancher, et plus aucun joueur ne
recevrait la suggestion jusqu'à la fin du processus. `nowMs` retombe donc sur `GetGameTimer`, la
même horloge du planificateur, déjà en millisecondes, et le dit une fois.

`chat:ready` est un net event qu'un client peut envoyer librement, d'où le plancher
`SUGGEST_RATE_MS` (10 s) par joueur. `forget` retire l'entrée d'un joueur parti :
`onPlayerDisconnected` est le départ d'un joueur **admis** ; une connexion refusée à la porte ne
passe pas par là (c'est `onPlayerRejected`, que cette resource n'écoute pas). `source` n'est pas
renseigné pour un event diffusé par l'hôte, et l'id arrive en chaîne : un id qui ne se convertit
pas vaut une ligne de log plutôt qu'une clé fantôme.

## Locales

`shared/locale.lua` publie `OpxHud.Locale` et le raccourci global `locale`. Un code inconnu est
accepté par `OpxHud.Locale.Set` : les catalogues s'enregistrent après ce fichier, il n'y a encore
rien contre quoi le vérifier. Une traduction manquante retombe sur `en`, puis sur la clé elle-même ;
un paramètre sans valeur laisse son `{nom}` tel qu'écrit. `LOCALE` est appliqué au chargement, sinon
il serait inerte. Les lignes de log restent en anglais.

## Couleurs

Les tons des lignes (`bad`, `warn`, `on`) sont décidés en Lua et rendus par des classes. Le style
de la page lit les jetons de `web/open77-ui.css`, le fichier de la plateforme recopié à l'identique
dans chaque resource et jamais modifié, et ceux du bloc `:root` en tête de `web/hud.css`.

## Invariants

- **Une surface WebUI par resource**, créée par son propre code, canaux nommés `hud:<action>`.
- **Une resource qui modifie l'état du joueur le relâche à son arrêt** : le HUD du jeu est remis à
  l'arrêt, et `reload_policy "reconnect"` couvre le rechargement.
- **Une resource ne touche pas aux internes d'une autre** : le core et `opx77_status` ne sont lus que
  par leurs exports et leurs events documentés, et chaque appel est vérifié aux trois niveaux.
- **Un pouvoir se vérifie côté serveur** : il n'y en a pas ici ; la seule commande est ouverte.

## Limites connues

- Le thread de démarrage exécute `pullNeeds` et `pull` sous `pcall`, et tous deux attendent une
  promesse (`promise:await()` dans `call`). Le reste du framework ne cède jamais la main sous un
  `pcall` ; seul l'envoi devrait y être.
