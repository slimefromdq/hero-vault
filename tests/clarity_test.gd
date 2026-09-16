extends SceneTree
## Visual-clarity data: damage ledger, floating numbers, telegraph snapshots and CSV columns.
const Battle = preload("res://scripts/battle.gd")
const BattleView = preload("res://scripts/battle_view.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _init() -> void:
	var b := Battle.new()
	b.setup(4702, 0, 0, 0)
	var saw_popup := false
	var saw_swing := false
	for i in range(3600):
		b.step()
		saw_popup = saw_popup or not b.frame().popups.is_empty()
		saw_swing = saw_swing or not b.frame().swings.is_empty()
	check(saw_popup, "Hits produce floating numbers")
	check(saw_swing, "Melee windups are exposed for telegraphs")
	# Ledger agrees with the damage rows it summarises.
	var from_records := {}
	for row in b.records:
		if row.kind == "damage" and b.get_unit(row.target).get("creep", true) == false:
			from_records[row.target] = from_records.get(row.target, 0.0)+row.value
			check(not str(row.get("ability", "")).is_empty(), "Every hero damage row names its source ability")
	for u in b.units:
		if u.creep:
			continue
		var rows: Array = b.damage_taken(u.id)
		var taken := 0.0
		for r in rows:
			taken += r.taken
			var rebuilt: float = r.boosted-r.mitigated-r.intercepted-r.bodyguard-r.absorbed-r.overkill
			check(absf(rebuilt-r.taken) < 0.05, "%s: breakdown steps add up for %s" % [u.name, r.ability])
		check(absf(taken-from_records.get(u.id, 0.0)) < 0.05, u.name + " ledger matches CSV damage")
	var labels := {}
	for target in b.damage_ledger:
		for r in b.damage_ledger[target].values():
			labels[r.ability] = true
	check(labels.has("Basic attack"), "Basic attacks are labelled")
	# Protection steps are recorded.
	var victim: Dictionary = b.units[0]
	victim.hp = victim.max_hp
	victim.shield = 30.0
	victim.stun = 0.0
	b.intermission.time = 0.0
	b.damage_label = "Test blast"
	b.apply_damage(victim, 100.0, b.units[5].id, false, "ability")
	var row: Dictionary = b.records[-1]
	for i in range(b.records.size()-1, -1, -1):
		if b.records[i].kind == "damage":
			row = b.records[i]
			break
	check(row.ability == "Test blast", "Explicit ability label is kept")
	check(row.raw_damage == 100.0 and row.absorbed == 30.0, "Raw and shield-absorbed damage are recorded")
	check(row.mitigated > 0 and absf(row.boosted_damage-row.mitigated-row.absorbed-row.value) < 0.05, "Defense reduction is recorded")
	check(b.damage_label == "", "Labels are consumed by one hit")
	var popup: Dictionary = b.popups[-1]
	check(popup.absorbed == 30.0 and popup.kind == "ability", "Popup carries shield and damage type")
	# Snapshots keep presentation data for replays.
	b.snapshot()
	check(b.history[-1].has("popups") and b.history[-1].has("swings"), "Replays keep popups and swings")
	# CSV includes the breakdown columns.
	var path := "user://clarity_test.csv"
	check(b.export_csv(path) == OK, "CSV exports")
	var header := FileAccess.get_file_as_string(path).get_slice("\n", 0)
	for column in ["raw_damage", "crit", "intercepted", "defense", "mitigated", "bodyguard", "overkill"]:
		check(column in header, "CSV has " + column)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# Status pills.
	var tags := BattleView.statuses({"stun": 1.0, "shield": 5.0})
	check(tags.size() == 2 and tags[0][0] == "STUN", "Stun is the first status pill")
	print("CLARITY PASS" if failures == 0 else "CLARITY FAIL (%d)" % failures)
	quit(1 if failures else 0)
