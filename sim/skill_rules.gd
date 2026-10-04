class_name SkillRules
extends RefCounted
## Pravidla přidělování dovedností (čistá logika, bez uzlů a náhody):
## kterou práci dovednost spouští, proč ji lumík nemůže dostat a kolik
## lumíků stojí v jednom bodě (výběr v davu). LevelSim.can_assign() je
## jen zkratka pro refusal() == NONE.

## Proč dovednost nejde přidělit (NONE = jde). Text pro hráče volí rozhraní.
## GONE: lumík neexistuje nebo už odešel, FINISHED: mise skončila,
## NO_SKILL: došly kusy, DYING: umírá nebo je doma, ALREADY: trvalou
## vlastnost nebo bombu už má, NOT_WORKING: padá, leze, snáší se nebo
## blokuje (pracovní dovednost nejde), SAME_WORK: tu práci už dělá.
enum Refusal { NONE, GONE, FINISHED, NO_SKILL, DYING, ALREADY, NOT_WORKING, SAME_WORK }


## Stav, do kterého pracovní dovednost lumíka přepne (-1 = trvalá vlastnost nebo bomba).
static func state_for_skill(skill: int) -> int:
	match skill:
		Lemming.Skill.BLOCKER:
			return Lemming.State.BLOCKER
		Lemming.Skill.BUILDER:
			return Lemming.State.BUILDER
		Lemming.Skill.BASHER:
			return Lemming.State.BASHER
		Lemming.Skill.DIGGER:
			return Lemming.State.DIGGER
		Lemming.Skill.MINER:
			return Lemming.State.MINER
	return -1


## Důvod, proč lumíkovi nejde dovednost přidělit (Refusal.NONE = jde).
static func refusal(sim: LevelSim, lem: Lemming, skill: int) -> int:
	if lem == null or lem.removed or lem.id < 0 or lem.id >= sim.lemmings.size() \
			or sim.lemmings[lem.id] != lem:
		return Refusal.GONE
	if sim.finished:
		return Refusal.FINISHED
	if int(sim.skills.get(skill, 0)) <= 0:
		return Refusal.NO_SKILL
	if lem.state in LevelSim.DYING_STATES:
		return Refusal.DYING
	return _skill_refusal(lem, skill)


## Kolik živých lumíků stojí v bodě (stejný dosah jako LevelSim.find_lemming_at).
static func crowd_at(sim: LevelSim, point: Vector2) -> int:
	var count := 0
	for lem in sim.lemmings:
		if lem.removed or lem.state in LevelSim.DYING_STATES:
			continue
		if absf(point.x - (lem.x + 0.5)) <= 4.0 \
				and point.y >= lem.y - SimConst.LEMMING_HEIGHT - 1.5 and point.y <= lem.y + 1.5:
			count += 1
	return count


## Pravidla samotné dovednosti u živého lumíka, který ji ještě má k dispozici.
static func _skill_refusal(lem: Lemming, skill: int) -> int:
	var already := false
	match skill:
		Lemming.Skill.CLIMBER:
			already = lem.can_climb
		Lemming.Skill.FLOATER:
			already = lem.has_floater
		Lemming.Skill.BOMBER:
			already = lem.bomb_ticks >= 0
		_:
			var target := state_for_skill(skill)
			if target < 0 or lem.state not in Lemming.WORKING_STATES:
				return Refusal.NOT_WORKING
			return Refusal.SAME_WORK if lem.state == target else Refusal.NONE
	return Refusal.ALREADY if already else Refusal.NONE
