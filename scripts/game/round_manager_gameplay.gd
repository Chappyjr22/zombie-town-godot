class_name ZombieTownGameplayRoundManager
extends ZombieTownRoundManager

signal zombie_killed(zombie: ZombieTownZombie)

func _on_zombie_died(zombie: ZombieTownZombie) -> void:
	zombie_killed.emit(zombie)
	super._on_zombie_died(zombie)
