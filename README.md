# Shit Gutter

Prototip Godot 4.6 first-person. Fluxul curent este:
**Meniu principal → hub de benzinărie → terminalul restaurantului → meci local de test → hub.**

## Pornire

1. Dezarhivează Godot 4.6 Standard pentru Windows x86_64. Nu este necesară varianta .NET.
2. În Godot, apasă **Import** și selectează `project.godot`.
3. Așteaptă importarea modelelor și texturilor.
4. Apasă **F5**, apoi **Intră în hub**.
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
| Deschide/închide meniul, anulează interacțiunea | Escape |

Meniurile eliberează cursorul și blochează mișcarea, săritura și mouse-look.
La închidere, controlul jucătorului revine automat. Dacă jucătorul cade sub hartă,
este readus la punctul de pornire.

## Personajul activ

Jucătorul folosește exclusiv `actors/characters/PersonajVerde.glb`, cu materialele
sale originale. Personajul alb Kenney și copia decorativă a personajului verde
nu mai sunt instanțiate în playground.

Modelul verde privește nativ spre +Z. În scena jucătorului este rotit cu 180°,
astfel încât fața, camera și deplasarea înainte să fie aliniate pe -Z.
Modelul este ridicat cu 0,082764 m pentru a pune tălpile la nivelul solului;
camera stabilă este la `(0, 1.64, -0.245)`, la nivelul ochilor, spre față.
Corpul folosește stratul vizual 2 și nu este văzut de camera locală (stratul 1),
pentru a evita vederea interiorului capului. Rămâne vizibil în editor și pentru
camere externe care includ stratul 2.

Animația `MersCaracter1` este folosită pentru mers. GLB-ul nu conține animații
dedicate de idle sau săritură: momentan se folosește postura neutră în acele stări.
Animațiile originale, inclusiv `Salut` și `StatToaleta`, sunt păstrate pentru
integrarea selectorului și a interacțiunii cu toaletele.

## Hub și intrarea în meci

Hub-ul este o schiță editabilă: curte, parcare, pompe, restaurant, toalete,
indicatoare și coliziuni. Toate obiectele de decor sunt noduri în `hub.tscn`,
astfel încât pot fi mutate sau înlocuite cu modele finale în editor.

Apropierea de restaurant nu pornește nimic automat. Terminalul trebuie privit
de aproape și activat cu E. Meniul afișează antrenamentul local, harta Playground,
un jucător și butonul de confirmare. Multiplayer-ul este dezactivat explicit:
**nu există încă server, coadă de matchmaking, lobby de rețea sau meci online**.
Hub-ul este local în această etapă.

Escape deschide un meniu cu continuare, întoarcere în hub (din playground) și
întoarcere la meniul principal.

## Integrare cu munca echipei

- **Character selector:** punctul de integrare este `actors/player/player_3d.tscn`.
  Controllerul folosește acum scheletul și animația de mers ale personajului verde.
  Înlocuirea modelului cu alte rig-uri va necesita adaptarea referințelor din script.
- **Interacțiuni:** există o singură acțiune Input Map, `interact`, legată de E.
  `Interactor` este un RayCast3D atașat camerei; verifică raza de 2,8 m și primul
  obstacol. Pereții blochează interacțiunea.
- **Obiecte noi:** expun metodele `get_interaction_prompt() -> String` și
  `interact(player)`. Se poate reutiliza `systems/interaction/interactable.gd`
  și semnalul lui `activated(player)`. Corpul fizic trebuie să fie pe stratul 1
  sau 3; stratul 3 este rezervat obiectelor interactive. Nu adăuga încă un handler
  global pentru E în scriptul toaletei.
- **Toalete:** sunt plasate în hub și păstrate în playground. Așezarea cu E și
  animația `StatToaleta` nu sunt conectate încă, fiind partea colegului.
- **Matchmaking/QTE:** confirmarea meniului este gestionată în
  `systems/world_session.gd`. Acum deschide direct harta de test; serviciul de
  matchmaking și logica meciului pot fi conectate ulterior aici.

## Structură

```text
actors/characters/    Personajul verde și texturile lui
actors/player/        Controller first-person și scena jucătorului
assets/              Modele, texturi și pachetul Kenney original
Scenes/Toilet.tscn    Scena de toaletă adăugată de colegi
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
```

Testul verifică traseul meniu → hub → playground → hub → meniu, un singur
personaj activ, mersul și săritura, detectarea de aproape, blocarea prin pereți,
blocarea inputului în meniuri și respawn-ul. La succes afișează `HUB_FLOW_OK`.
Poziția camerei, modelul și interfața se verifică suplimentar prin rulare grafică.

## Asset-uri

Pachetul Kenney Animated Characters Retro este păstrat ca sursă, dar nu mai este
folosit de jucătorul activ. Licența sa CC0 se află în
`assets/characters/kenney_animated_characters_retro/License.txt`.
Personajul verde și obiectele de toaletă sunt cele adăugate de echipă.

Păstrează fișierele sursă, fișierele `.import` și `.uid` în Git.
Folderul `.godot/` este cache generat local și este ignorat.
