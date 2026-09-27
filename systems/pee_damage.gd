class_name PeeDamage
extends RefCounted

## Componenta comuna de "viata", folosita identic de player si de NPC-ul de
## duel (la fel cum PeeFuel e folosit identic de amandoi pentru rezerva de
## pipi). Stropii individuali vin mult mai des decat o data la 0.1s (pee_stream
## trage ~36 stropi/secunda), deci damage-ul NU se aplica per strop - in loc,
## cat timp esti lovit continuu se acumuleaza timpul real de expunere si se
## scade 1 HP la fiecare DAMAGE_INTERVAL secunde de expunere. Daca stropii se
## opresc mai mult de GRACE secunde, expunerea se considera terminata.

const DAMAGE_INTERVAL := 0.1
const GRACE := 0.15

var max_health: float
var health: float
var _grace_timer := 0.0
var _damage_accum := 0.0

func _init(starting_max_health: float) -> void:
	max_health = starting_max_health
	health = max_health

## Fractiune 0..1, utila pentru bara din UI.
func fraction() -> float:
	return health / max_health if max_health > 0.0 else 0.0

## Apelat din receive_pee_hit() de fiecare data cand un strop chiar loveste.
func register_hit() -> void:
	_grace_timer = GRACE

## Apelat in fiecare _physics_process(delta). Returneaza true cand tocmai s-a
## scazut HP in cadrul asta (util pentru un eventual efect de flash in UI).
func tick(delta: float) -> bool:
	if _grace_timer <= 0.0:
		_damage_accum = 0.0
		return false
	_grace_timer -= delta
	_damage_accum += delta
	var damaged := false
	while _damage_accum >= DAMAGE_INTERVAL and health > 0.0:
		_damage_accum -= DAMAGE_INTERVAL
		health = maxf(0.0, health - 1.0)
		damaged = true
	return damaged

func is_dead() -> bool:
	return health <= 0.0

## Reseteaza la viata plina (folosit ca "respawn"/reincepere dupa 0 HP - acesta
## e un duel de antrenament fara meniu de game-over, deci ciclul continua).
func reset() -> void:
	health = max_health
	_grace_timer = 0.0
	_damage_accum = 0.0
