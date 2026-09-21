# Shit Gutter

Prototip Godot 4.6 first-person. Fluxul curent este:
**Meniu principal → CharacterSelector → hub de benzinărie → terminalul restaurantului → meci local de test → hub.**

## Pornire

1. Dezarhivează Godot 4.6 Standard pentru Windows x86_64. Nu este necesară varianta .NET.
2. În Godot, apasă **Import** și selectează `project.godot`.
3. Așteaptă importarea modelelor și texturilor.
4. Apasă **F5**, apoi **Singleplayer**, și alege un personaj pentru a intra în hub.
5. Urmează marcajele galbene până la restaurantul **La Ultima Masă**.
6. Privește terminalul verde de la tejghea, de la cel mult 2,8 metri, și apasă **E**.
7. Alege **Pornește meci de test**. Ajungi în playground.
8. Din playground, **Escape → Înapoi în hub**.

Proiectul folosește Forward+ cu Direct3D 12 pe Windows și Jolt Physics.
Pentru a rula o scenă individuală, deschide-o și apasă **F6**.

## Controale

| Acțiune | Control |
| --- | --- |
| Mișcare | WASD sau săgețile |
| Privire | Mouse |
| Săritură | Space |
| Interacțiune cu obiectul privit | E |
| Așezare pe o toaletă liberă / ridicare | E |
| Jet de pișat, doar așezat | Ține click stânga; țintește cu mouse-ul |
| Pornește/reia o rundă de țintire, pe toaleta de antrenament | R |
| Alege alt personaj (în timpul jocului); după alegere revii în hub | H |
| Deschide/închide meniul, anulează interacțiunea | Escape |

Meniurile eliberează cursorul și blochează mișcarea, săritura și mouse-look.
La închidere, controlul jucătorului revine automat. Dacă jucătorul cade sub hartă,
este readus la punctul de pornire.

## Personajul activ

CharacterSelector oferă personajul verde, bunicul albastru și doamna mov.
Alegerea este păstrată în `Data.SelectPlayer` pe durata sesiunii și folosită
în hub și playground. Vitezele colegului sunt păstrate: verde 5, albastru 3,
mov 10. Escape din selector revine la meniul principal.

`systems/world_session.gd` creează un singur `new_player`, din scena personajului
ales, la nodul `PlayerSpawn` din fiecare hartă. Transformarea este aplicată înainte
de `_ready()`, astfel încât și respawn-ul folosește punctul corect. Pentru a muta
locul de pornire, mută sau rotește `PlayerSpawn` în editor. Nu adăuga un player
manual în hub sau playground: acesta ar dubla controllerul și camera.

Modelul verde privește nativ spre +Z. În scena jucătorului este rotit cu 180°,
astfel încât fața, camera și deplasarea înainte să fie aliniate pe -Z.
Modelul este ridicat cu 0,082764 m pentru a pune tălpile la nivelul solului;
camera stabilă este la `(0, 1.64, -0.245)`, la nivelul ochilor, spre față.
Corpul folosește stratul vizual 2 și nu este văzut de camera locală (stratul 1),
pentru a evita vederea interiorului capului. Rămâne vizibil în editor și pentru
camere externe care includ stratul 2.

Animația `MersCaracter1` este folosită pentru mers. GLB-ul nu conține animații
dedicate de idle sau săritură: momentan se folosește postura neutră în acele stări.
Animațiile originale, inclusiv `Salut` și `StatToaleta`, sunt păstrate.
`systems/character_animations.gd` copiază bibliotecile pentru fiecare instanță și
leagă pistele la scheletul real, inclusiv după redenumirea armăturii cu Make Local.
Mersul rulează în buclă; `StatToaleta` rulează o dată și rămâne în poziția așezat.
Nu trebuie modificat importul GLB pentru a activa bucla la runtime.

## Hub și intrarea în meci

Hub-ul este o schiță editabilă: curte, parcare, pompe, restaurant, toalete,
indicatoare și coliziuni. Toate obiectele de decor sunt noduri în `hub.tscn`,
astfel încât pot fi mutate sau înlocuite cu modele finale în editor.

Apropierea de restaurant nu pornește nimic automat. Terminalul trebuie privit
de aproape și activat cu E. Meniul afișează antrenamentul local, harta Playground,
un jucător și butonul de confirmare. Multiplayer-ul este dezactivat explicit:
**nu există încă server, coadă de matchmaking, lobby de rețea sau meci online**.
Hub-ul este local în această etapă.

Lângă punctul de pornire, în stânga, terminalul galben **SCHIMBĂ PERSONAJUL**
deschide CharacterSelector cu E. Trebuie privit de aproape (maximum 2,8 m),
la fel ca terminalul de meci. După alegere revii la spawn-ul hub-ului cu noul
personaj. Tasta H rămâne disponibilă și în hub, și în playground.

Escape deschide un meniu cu continuare, întoarcere în hub (din playground) și
întoarcere la meniul principal.

## Integrare cu munca echipei

### Toaleta și jetul

În hub poți folosi toaletele libere. În playground, în dreapta punctului de
pornire, există o **toaletă de antrenament** orientată spre trei ținte turcoaz.
Privește vasul de aproape și apasă E. Camera coboară, mișcarea și săritura sunt
blocate, iar mouse-ul controlează țintirea (75° în stânga/dreapta).
Ține click stânga pentru jet; ținta clipește și numără loviturile.
Apasă E din nou ca să te ridici. Ridicarea verifică spațiul liber pentru corp.

### Mini-joc de țintire

Pe toaleta de antrenament, **R** pornește o rundă de **30 de secunde**.
Lovește ținta **galbenă**, marcată „ȚINTEȘTE AICI”, cu trei picături pentru
**10 puncte**. Următoarea țintă se activează automat; țintele gri nu dau puncte.
HUD-ul arată timpul, scorul și recordul din vizita curentă în playground.
Recordul nu este salvat pe disc și se resetează când părăsești harta.

Escape îngheață cronometrul până la continuare. E/ridicarea sau respawn-ul
anulează runda, fără a înregistra un record. După expirarea timpului, R începe
o rundă nouă. R nu repornește o rundă în desfășurare și nu funcționează de pe
alte toalete. În afara rundelor poți trage liber, cu contoarele de lovituri.

Logica este izolată în `systems/practice_challenge.gd`, cu HUD-ul în
`Scenes/practice_challenge.tscn`; durata și loviturile necesare se pot regla
în Inspector. Folosește semnalul `hit_received(source)` al țintelor, fără
a modifica HP-ul NPC-urilor sau datele globale ale colegilor.

### Ocupare și coliziuni

Toaletele rezervate de NPC-uri, inclusiv cele spre care încă merg, apar ocupate
și nu pot fi luate de jucător. Aceeași rezervare `occupied_by` este folosită de
NPC-uri și player. Ridicarea, respawn-ul și eliminarea playerului eliberează vasul.
Escape oprește jetul și deschide meniul, păstrând locul ocupat; după continuare
trebuie apăsat din nou click stânga. H permite în continuare schimbarea personajului.

Jetul este comun tuturor celor trei personaje, cu picături balistice și verificare
de coliziune între pozițiile succesive: pereții opresc loviturile. Există limite
pentru picături/stropi, iar efectele sunt eliminate la pauză și ridicare.
Prototipul `GPUParticles3D` din scena verde este păstrat, dar dezactivat.
Acesta este gameplay local; rezervările și loviturile nu sunt sincronizate în rețea.

- **Character selector:** `Scenes/character_selection_screen.gd` setează
  `Data.SelectPlayer` și deschide hub-ul. `systems/world_session.gd` instanțiază
  scena aleasă din `actors/player/` și expune personajul activ prin `new_player`.
  Referința veche `$Player3D` a fost eliminată din controllerul sesiunii.
  H este disponibil în timpul jocului, nu în meniul de pauză sau al terminalului.
- **Interacțiuni:** există o singură acțiune Input Map, `interact`, legată de E.
  `Interactor` este un RayCast3D atașat camerei; verifică raza de 2,8 m și primul
  obstacol. Pereții blochează interacțiunea.
- **Obiecte noi:** expun metodele `get_interaction_prompt() -> String` și
  `interact(player)`. Se poate reutiliza `systems/interaction/interactable.gd`
  și semnalul lui `activated(player)`. Corpul fizic trebuie să fie pe stratul 1
  sau 3; stratul 3 este rezervat obiectelor interactive. Nu adăuga încă un handler
  global pentru E în scriptul toaletei.
- **Toalete:** `systems/interaction/toilet.gd` este atașat rădăcinii scenei
  `Scenes/Toilet.tscn`. Expune `try_reserve(actor)`, `release(actor)`,
  `occupant()` și contractul `interact(actor)`. `seat_offset` reglează poziția
  controllerului înainte de deplasarea oaselor din animația de așezare.
- **Viață/lovituri:** `new_player.pee_hit(collider, point, normal, source)` emite
  o dată pentru fiecare picătură care lovește primul corp fizic. Colegul poate
  conecta sistemul de HP aici sau poate implementa
  `receive_pee_hit(source, point, normal)` pe corpul lovit. Folosește o singură
  variantă pentru damage, pentru a nu aplica de două ori aceeași lovitură.
  Momentan ținta de antrenament numără loviturile; nu este introdus un sistem de
  viață paralel. Coliziunile NPC-urilor rămân active și când sunt așezați.
- **Matchmaking/QTE:** confirmarea meniului este gestionată în
  `systems/world_session.gd`. Acum deschide direct harta de test; serviciul de
  matchmaking și logica meciului pot fi conectate ulterior aici.

## Structură

```text
actors/characters/    Cele trei personaje și texturile lor
actors/player/        Controller first-person și scena jucătorului
assets/              Modele, texturi și pachetul Kenney original
Scenes/Toilet.tscn    Scena de toaletă adăugată de colegi
Scenes/character_selection_screen.tscn  Alegerea personajului
Sigletons/data.gd     Autoload Data, inclusiv personajul selectat
maps/hub/            Benzinăria
maps/playground/     Harta meciului de test
maps/test_3d/        Scena inițială
menus/main_menu/     Intrarea în joc
systems/interaction/ Detectarea și contractul comun pentru interacțiuni
systems/world_session.gd  Meniuri, blocarea inputului și tranziții
ui/                  HUD, meniul meciului și meniul Escape
tests/               Verificarea automată a fluxului
```

## Verificare automată

După importarea proiectului în editor, rulează din rădăcina repository-ului
(înlocuiește `godot` cu calea executabilului tău, dacă nu este în PATH):

```text
godot --headless --path . --script res://tests/hub_flow_test.gd --log-file .godot/hub-test.log
godot --headless --path . --script res://tests/toilet_flow_test.gd --log-file .godot/toilet-test.log
godot --headless --path . --script res://tests/practice_challenge_test.gd --log-file .godot/practice-test.log
```

Testul verifică traseul meniu → selector → hub → playground → hub → meniu,
toate cele trei personaje și păstrarea vitezelor/selecției, un singur player și o
singură cameră, pornirea și respawn-ul la `PlayerSpawn`, schimbarea cu H sau
terminalul de personaje (distanță, prompt și blocare în pauză), mersul
și săritura, detectarea de aproape, blocarea prin pereți și blocarea inputului
în meniuri. La succes afișează `HUB_FLOW_OK`.
Poziția camerei, modelul și interfața se verifică suplimentar prin rulare grafică.
`TOILET_FLOW_OK` confirmă testele celor trei rig-uri (oase animate efectiv),
izolarea între două instanțe, ocuparea comună NPC/player, raza și pereții,
așezarea/ridicarea, jetul, loviturile pe țintă, pauza și eliberarea rezervării.
`PRACTICE_CHALLENGE_OK` verifică lovituri reale pe toate trei țintele cu fiecare
personaj, scorul, expirarea timpului, pauza, reluarea, anularea și schimbarea scenei.

## Asset-uri

Pachetul Kenney Animated Characters Retro este păstrat ca sursă, dar nu mai este
folosit de jucătorul activ. Licența sa CC0 se află în
`assets/characters/kenney_animated_characters_retro/License.txt`.
Personajul verde și obiectele de toaletă sunt cele adăugate de echipă.

Păstrează fișierele sursă, fișierele `.import` și `.uid` în Git.
Folderul `.godot/` este cache generat local și este ignorat.
