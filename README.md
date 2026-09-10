# Shit Gutter

Prototip de joc 3D first-person realizat în Godot. Proiectul include un meniu principal, o scenă singleplayer de test, un personaj animat și platforme pe care se poate merge și sări.

## Cerințe

- Godot 4.6 Standard pentru Windows x86_64.
- Placă video compatibilă Direct3D 12 sau Vulkan.
- Git este opțional și este necesar doar pentru versionarea proiectului.
- Varianta Godot .NET și .NET SDK nu sunt necesare; proiectul folosește GDScript.

## Instalare și pornire

1. Descarcă și dezarhivează Godot 4.6 Standard.
2. Pornește Godot și apasă `Import`.
3. Selectează fișierul `project.godot` din rădăcina repository-ului.
4. Așteaptă finalizarea importului modelelor FBX și al texturilor.
5. Apasă `F5` pentru a porni jocul de la meniul principal.

Scena principală este `menus/main_menu/main_menu.tscn`.

## Controale

În meniu:

- Mouse sau tastatură pentru selectarea butoanelor.
- `Singleplayer` deschide scena de test.
- `Multiplayer` este momentan un placeholder și nu pornește nimic.

În joc:

- `WASD` sau săgețile: deplasare.
- Mouse: rotirea camerei first-person.
- `Space`: săritură.
- `Escape`: eliberează cursorul.
- Click în fereastra jocului: capturează din nou cursorul.

## Ce este implementat

- Meniu principal cu Singleplayer și Multiplayer.
- Tranziție din meniu către scena singleplayer.
- Cameră first-person și mouse-look.
- Mișcare relativă la direcția camerei.
- Săritură, gravitație și coliziune cu terenul și platformele.
- Model Kenney cu skin și animații pentru idle, alergare și săritură.
- Teren de test, trei platforme, iluminare și cer procedural.

## Structura proiectului

```text
actors/player/        Scena și scriptul jucătorului
assets/characters/    Modelele, skin-urile și animațiile Kenney
maps/playground/      Scena singleplayer curentă
maps/test_3d/         Scena inițială de test
materials/            Materialele proiectului
menus/main_menu/      Meniul principal și logica lui
project.godot         Configurația Godot și scena de pornire
```

## Asset-uri și licență

Personajele și animațiile provin din pachetul `Animated Characters Retro` creat de Kenney. Pachetul este distribuit sub licența Creative Commons Zero (CC0) și poate fi folosit în proiecte personale și comerciale.

Licența originală este păstrată în:

`assets/characters/kenney_animated_characters_retro/License.txt`

Fișierele FBX și texturile sursă trebuie păstrate în folderul lor actual. Godot generează automat fișierele de import din folderul `.godot`, care nu trebuie adăugat în Git.

## De făcut

- Implementarea modului multiplayer.
- Meniu de pauză și întoarcere la meniul principal.
- Setări pentru sensibilitatea mouse-ului, sunet și grafică.
- Gameplay, obiective și niveluri complete.
- Sunete, efecte și interfață finală.
