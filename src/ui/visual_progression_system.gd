## VisualProgressionSystem — Görsel İlerleme Servisi
##
## UpgradeTree.upgrade_purchased sinyalini dinleyerek üç görsel kategorinin
## (OVEN, SHOWCASE, DECOR) tier değerini hesaplar ve sahne node'larına iletir.
##
## Tier = o kategorideki upgrade'lerin toplam seviyesi.
## Sinyal yalnızca tier değişince yayılır.
##
## GDD: design/gdd/visual-progression-system.md
class_name VisualProgressionSystem
extends Node

## Fırın görsel tier'ı değişince yayılır (oven_temperature, dough_quality, vb.).
signal oven_visual_changed(tier: int)
## Vitrin görsel tier'ı değişince yayılır (showcase_width).
signal showcase_visual_changed(tier: int)
## Dekorasyon görsel tier'ı değişince yayılır (customer_satisfaction, vb.).
signal decor_visual_changed(tier: int)

## OVEN kategorisine ait upgrade ID'leri.
const OVEN_UPGRADES: Array[StringName] = [
	&"oven_temperature",
	&"dough_quality",
	&"oven_capacity",
	&"auto_dough",
	&"ingredient_storage",
]

## SHOWCASE kategorisine ait upgrade ID'leri.
const SHOWCASE_UPGRADES: Array[StringName] = [
	&"showcase_width",
]

## DECOR kategorisine ait upgrade ID'leri.
const DECOR_UPGRADES: Array[StringName] = [
	&"customer_satisfaction",
	&"loyalty_card",
	&"vip_lounge",
]

var _oven_tier: int = 0
var _showcase_tier: int = 0
var _decor_tier: int = 0

## Dependency injection (test izolasyonu).
var _upgrade_ref: UpgradeTree = null


func _ready() -> void:
	var tree := _get_upgrade_tree()
	if tree:
		tree.upgrade_purchased.connect(_on_upgrade_purchased)
	else:
		push_warning("VisualProgressionSystem: UpgradeTree bağlanamadı")


# ── Public API ────────────────────────────────────────────────────────────────

## Tüm kategorileri UpgradeTree'den yeniden hesaplar.
## Save/Load sonrası çağrılmalıdır.
func refresh(upgrade_tree: UpgradeTree) -> void:
	if upgrade_tree == null:
		push_warning("VisualProgressionSystem: refresh() — UpgradeTree null")
		return
	_recalculate_all(upgrade_tree)


## Mevcut OVEN tier değerini döner.
var oven_tier: int:
	get: return _oven_tier

## Mevcut SHOWCASE tier değerini döner.
var showcase_tier: int:
	get: return _showcase_tier

## Mevcut DECOR tier değerini döner.
var decor_tier: int:
	get: return _decor_tier


# ── Signal Handler ────────────────────────────────────────────────────────────

func _on_upgrade_purchased(upgrade_id: StringName, _new_level: int) -> void:
	var tree := _get_upgrade_tree()
	if tree == null:
		return

	if upgrade_id in OVEN_UPGRADES:
		_update_oven(tree)
	elif upgrade_id in SHOWCASE_UPGRADES:
		_update_showcase(tree)
	elif upgrade_id in DECOR_UPGRADES:
		_update_decor(tree)
	else:
		push_warning("VisualProgressionSystem: bilinmeyen upgrade_id '%s'" % upgrade_id)


# ── Internal ──────────────────────────────────────────────────────────────────

func _recalculate_all(tree: UpgradeTree) -> void:
	_update_oven(tree)
	_update_showcase(tree)
	_update_decor(tree)


func _update_oven(tree: UpgradeTree) -> void:
	var new_tier: int = _sum_levels(tree, OVEN_UPGRADES)
	if new_tier != _oven_tier:
		_oven_tier = new_tier
		oven_visual_changed.emit(_oven_tier)


func _update_showcase(tree: UpgradeTree) -> void:
	var new_tier: int = _sum_levels(tree, SHOWCASE_UPGRADES)
	if new_tier != _showcase_tier:
		_showcase_tier = new_tier
		showcase_visual_changed.emit(_showcase_tier)


func _update_decor(tree: UpgradeTree) -> void:
	var new_tier: int = _sum_levels(tree, DECOR_UPGRADES)
	if new_tier != _decor_tier:
		_decor_tier = new_tier
		decor_visual_changed.emit(_decor_tier)


func _sum_levels(tree: UpgradeTree, ids: Array[StringName]) -> int:
	var total: int = 0
	for id: StringName in ids:
		total += tree.get_current_level(id)
	return total


func _get_upgrade_tree() -> UpgradeTree:
	if _upgrade_ref:
		return _upgrade_ref
	return get_node_or_null("/root/UpgradeTree") as UpgradeTree
