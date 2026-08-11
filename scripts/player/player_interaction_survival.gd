class_name ZombieTownSurvivalInteraction
extends ZombieTownGameplayInteraction

const MAX_QUICK_REVIVE_PURCHASES := 3

var quick_revive_purchases := 0

func _ready() -> void:
	super._ready()
	if player is ZombieTownSurvivalPlayer:
		var survival_player := player as ZombieTownSurvivalPlayer
		survival_player.quick_revive_consumed.connect(_on_quick_revive_consumed)

func _physics_process(delta: float) -> void:
	if player is ZombieTownSurvivalPlayer:
		var survival_player := player as ZombieTownSurvivalPlayer
		if survival_player.is_downed():
			_set_current(null)
			return
	super._physics_process(delta)

func _prompt_for(interactable: ZombieTownInteractable) -> String:
	if interactable.interaction_kind == &"perk" and interactable.item_id == &"revive":
		if has_perk(&"revive"):
			return "%s  [OWNED]" % interactable.display_name
		if quick_revive_purchases >= MAX_QUICK_REVIVE_PURCHASES:
			return "%s  [DEPLETED]" % interactable.display_name
	return super._prompt_for(interactable)

func _is_affordable(interactable: ZombieTownInteractable) -> bool:
	if interactable.interaction_kind == &"perk" and interactable.item_id == &"revive":
		if has_perk(&"revive") or quick_revive_purchases >= MAX_QUICK_REVIVE_PURCHASES:
			return true
	return super._is_affordable(interactable)

func _activate(interactable: ZombieTownInteractable) -> void:
	if interactable.interaction_kind == &"perk" and interactable.item_id == &"revive" and quick_revive_purchases >= MAX_QUICK_REVIVE_PURCHASES and not has_perk(&"revive"):
		return
	super._activate(interactable)

func _purchase_perk(perk_id: StringName, cost: int) -> void:
	if perk_id != &"revive":
		super._purchase_perk(perk_id, cost)
		return
	if has_perk(&"revive") or quick_revive_purchases >= MAX_QUICK_REVIVE_PURCHASES:
		return
	if not _spend_points(cost):
		return
	if not player is ZombieTownSurvivalPlayer:
		player.points += cost
		player.stats_changed.emit(player.points, player.kills, player.headshots)
		return
	perks[&"revive"] = true
	quick_revive_purchases += 1
	var survival_player := player as ZombieTownSurvivalPlayer
	survival_player.grant_quick_revive()

func _on_quick_revive_consumed() -> void:
	perks.erase(&"revive")
	_refresh_prompt()
