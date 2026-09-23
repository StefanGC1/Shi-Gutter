class_name PeeFuel
extends RefCounted

## Componenta comuna de "rezerva" pentru jet, folosita identic de player si
## de NPC-uri, ca sa se comporte EXACT la fel pe ambele parti:
## - cand incepe sa traga (prima apasare): consuma instant START_COST%
## - cat timp tine apasat, in continuare: se consuma DRAIN_PER_SECOND% / secunda
## - cat timp NU e apasat (indiferent daca s-a golit sau nu): dupa REGEN_DELAY
##   secunde de inactivitate, se reincarca REGEN_PER_SECOND% / secunda

const MAX_FUEL := 100.0
const START_COST := 5.0
const DRAIN_PER_SECOND := 2.5
const REGEN_PER_SECOND := 10.0
## Cat asteapta dupa ce s-a lasat butonul, inainte sa inceapa reincarcarea;
## impiedica "spam click" sa reincarce instant.
const REGEN_DELAY := 0.5

var value := MAX_FUEL
## Retine INTENTIA (butonul apasat), nu daca a tras efectiv - altfel, daca
## rezerva se goleste cat butonul e tot apasat, orice strop de reincarcare ar
## fi taxat imediat cu inca un START_COST si bara ar parea ca nu se mai umple.
var _was_want_fire := false
var _idle_timer := 0.0

## Fractiune 0..1, utila pentru bara din UI.
func fraction() -> float:
	return value / MAX_FUEL

## want_fire = ce isi doreste sursa (buton apasat / duel activ in cadrul asta).
## Returneaza daca chiar trage in cadrul asta (poate fi false daca rezerva e goala).
func update(delta: float, want_fire: bool) -> bool:
	if want_fire:
		if not _was_want_fire and value > 0.0:
			# Prima apasare (tranzitie eliberat -> apasat): cost instant, o singura data.
			value = maxf(0.0, value - START_COST)
		elif _was_want_fire and value > 0.0:
			# Tinut apasat in continuare: consum pe secunda.
			value = maxf(0.0, value - DRAIN_PER_SECOND * delta)
		_idle_timer = 0.0
	else:
		# Butonul NU e apasat: reincarca, dupa un mic delay, indiferent cat mai era ramas.
		_idle_timer += delta
		if _idle_timer >= REGEN_DELAY:
			value = minf(MAX_FUEL, value + REGEN_PER_SECOND * delta)
	var firing := want_fire and value > 0.0
	_was_want_fire = want_fire
	return firing
