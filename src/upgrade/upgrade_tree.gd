## UpgradeTree
##
## Upgrade satın alma akışını, efekt hesaplamasını ve Config Resource'larının
## güncellenmesini yönetir.
##
## Mimari kuralları (GDD Upgrade Tree System):
##   - Maliyet: base_cost × 3^(level-1)
##   - Efekt: effect_per_level[current_level - 1] (0-indexed)
##   - Satın alma kilidi: _is_purchasing; 0.5 sn sonra serbest bırakılır (çift tap önlemi)
##   - Tüm upgrade verileri ContentRegistry'den; test izolasyonu için _registry_ref
##   - Economy bağımlılığı enjeksiyonla (_economy_ref)
class_name UpgradeTree
extends Node

## Upgrade satın alındığında yayılır.
signal upgrade_purchased(upgrade_id: StringName, new_level: int)
## Üretim upgrade'i değişince OvenManager'a iletilir.
signal production_config_changed(cfg: ProductionConfig)
## Müşteri upgrade'i değişince CustomerOrderSystem'e iletilir.
signal customer_config_changed(cfg: CustomerConfig)

# ── Config Resources ──────────────────────────────────────────────────────────

## Üretim parametreleri (OvenManager bu Resource'u okur).
var production_config: ProductionConfig = ProductionConfig.new()

## Müşteri parametreleri (CustomerOrderSystem bu Resource'u okur).
var customer_config: CustomerConfig = CustomerConfig.new()

# ── Runtime durumu ────────────────────────────────────────────────────────────

## StringName → int (mevcut seviye; 0 = henüz satın alınmadı)
var _levels: Dictionary = {}

## StringName → UpgradeData (ContentRegistry veya test enjeksiyonu)
var _upgrades: Dictionary = {}

## Çift tap kilidi (GDD EC-2)
var _is_purchasing: bool = false

## Dependency injection
var _economy_ref: EconomySystem = null
var _registry_ref: ContentRegistry = null


func _ready() -> void:
	var registry := _get_registry()
	if registry:
		for upgrade: UpgradeData in registry.get_all_upgrades():
			_upgrades[upgrade.id] = upgrade
	_apply_effects()


# ── Public API — Sorgulama ────────────────────────────────────────────────────

## Upgrade'in mevcut seviyesini döner (0 = satın alınmadı).
func get_current_level(upgrade_id: StringName) -> int:
	return _levels.get(upgrade_id, 0)


## Upgrade'in max seviyede olup olmadığını döner.
func is_maxed(upgrade_id: StringName) -> bool:
	var upgrade: UpgradeData = _upgrades.get(upgrade_id)
	if upgrade == null:
		return false
	return _levels.get(upgrade_id, 0) >= upgrade.max_level


## Bir sonraki seviyenin maliyetini döner. Maxed veya bilinmeyen → 0.
func get_next_cost(upgrade_id: StringName) -> int:
	var upgrade: UpgradeData = _upgrades.get(upgrade_id)
	if upgrade == null:
		return 0
	var level: int = _levels.get(upgrade_id, 0)
	if level >= upgrade.max_level:
		return 0
	return compute_cost(upgrade.base_cost, level + 1)


## Mevcut seviyedeki efekti döner. Seviye 0 ise 0.0.
func get_current_effect(upgrade_id: StringName) -> float:
	var upgrade: UpgradeData = _upgrades.get(upgrade_id)
	if upgrade == null:
		return 0.0
	var level: int = _levels.get(upgrade_id, 0)
	if level <= 0:
		return 0.0
	return upgrade.effect_per_level[level - 1]


## Bir sonraki seviyenin efektini döner (UI önizleme). Maxed → 0.0.
func get_next_effect(upgrade_id: StringName) -> float:
	var upgrade: UpgradeData = _upgrades.get(upgrade_id)
	if upgrade == null:
		return 0.0
	var level: int = _levels.get(upgrade_id, 0)
	if level >= upgrade.max_level:
		return 0.0
	return upgrade.effect_per_level[level]


# ── Public API — Satın Alma ───────────────────────────────────────────────────

## Upgrade satın alır.
## Returns: true → başarılı; false → kilitli / maxed / yetersiz bakiye / bilinmeyen ID
func purchase(upgrade_id: StringName) -> bool:
	if _is_purchasing:
		return false  # Çift tap kilidi (GDD EC-2)

	var upgrade: UpgradeData = _upgrades.get(upgrade_id)
	if upgrade == null:
		push_error("UpgradeTree: bilinmeyen upgrade '%s'" % upgrade_id)
		return false

	var current_level: int = _levels.get(upgrade_id, 0)
	if current_level >= upgrade.max_level:
		return false  # Zaten maxed

	var next_level: int = current_level + 1
	var cost: int = compute_cost(upgrade.base_cost, next_level)

	var economy := _get_economy()
	if economy == null:
		return false

	# Ödeme
	if upgrade.costs_badge:
		if not economy.spend_rozet(cost):
			return false
	else:
		if not economy.spend_gold(cost):
			return false

	# Kilit aç
	_is_purchasing = true
	_levels[upgrade_id] = next_level
	_apply_effects()
	upgrade_purchased.emit(upgrade_id, next_level)

	# 0.5 sn sonra kilidi kaldır (GDD Tuning Knobs: purchase_lock_timeout)
	var t := get_tree().create_timer(0.5)
	t.timeout.connect(func():
		if is_instance_valid(self):
			_is_purchasing = false
	)
	return true


# ── Public API — Maliyet Formülü ──────────────────────────────────────────────

## Verilen base_cost ve level için maliyeti hesaplar (F-1: base_cost × 3^(level-1)).
static func compute_cost(base_cost: int, level: int) -> int:
	return int(base_cost * pow(3.0, level - 1))


# ── Kayıt/Yükleme ─────────────────────────────────────────────────────────────

## SaveLoadManager tarafından çağrılır.
func serialize() -> Dictionary:
	return {"levels": _levels.duplicate()}


## Yalnızca prestij sıfırlaması için: tüm seviyeleri 0'a indirir.
## LocationSystem.do_prestige() dışında çağrılmamalıdır.
func reset_levels() -> void:
	for id: StringName in _levels:
		_levels[id] = 0
	_apply_effects()


## SaveLoadManager tarafından çağrılır. Bozuk level → max_level'a sabitlenir.
func deserialize(data: Dictionary) -> void:
	var saved_levels: Dictionary = data.get("levels", {})
	for id in saved_levels:
		var level: int = saved_levels[id]
		var upgrade: UpgradeData = _upgrades.get(id)
		if upgrade == null:
			push_warning("UpgradeTree: kayıtta bilinmeyen upgrade '%s' — atlandı" % id)
			continue
		if level > upgrade.max_level:
			push_error("UpgradeTree: '%s' level=%d > max_level=%d — max'a sabitlendi" \
				% [id, level, upgrade.max_level])
			level = upgrade.max_level
		if level < 0:
			level = 0
		_levels[id] = level
	_apply_effects()


# ── Internal — Efekt Uygulaması ───────────────────────────────────────────────

func _apply_effects() -> void:
	_apply_production_effects()
	_apply_customer_effects()
	production_config_changed.emit(production_config)
	customer_config_changed.emit(customer_config)


func _apply_production_effects() -> void:
	# bake_speed_multiplier: 1.0 + effect at current level
	var ot_level: int = _levels.get(&"oven_temperature", 0)
	var ot: UpgradeData = _upgrades.get(&"oven_temperature")
	production_config.bake_speed_multiplier = 1.0 + \
		(ot.effect_per_level[ot_level - 1] if ot and ot_level > 0 else 0.0)

	# dough_quality_bonus: effect at current level
	var dq_level: int = _levels.get(&"dough_quality", 0)
	var dq: UpgradeData = _upgrades.get(&"dough_quality")
	production_config.dough_quality_bonus = \
		dq.effect_per_level[dq_level - 1] if dq and dq_level > 0 else 0.0

	# oven_capacity: 1 + kümülatif toplam
	var oc_level: int = _levels.get(&"oven_capacity", 0)
	var oc: UpgradeData = _upgrades.get(&"oven_capacity")
	var cap: int = 1
	if oc:
		for i in range(oc_level):
			cap += int(oc.effect_per_level[i])
	production_config.oven_capacity = cap

	# auto_dough_level: seviye doğrudan
	production_config.auto_dough_level = _levels.get(&"auto_dough", 0)

	# storage_cap: effect at current level
	var is_level: int = _levels.get(&"ingredient_storage", 0)
	var is_data: UpgradeData = _upgrades.get(&"ingredient_storage")
	production_config.storage_cap = \
		int(is_data.effect_per_level[is_level - 1]) if is_data and is_level > 0 else 0


func _apply_customer_effects() -> void:
	# max_active_orders = 4 + kümülatif showcase_width etkisi
	var sw_level: int = _levels.get(&"showcase_width", 0)
	var sw: UpgradeData = _upgrades.get(&"showcase_width")
	var extra_slots: int = 0
	if sw:
		for i in range(sw_level):
			extra_slots += int(sw.effect_per_level[i])
	customer_config.max_active_orders = 4 + extra_slots

	# patience_multiplier = 1.0 + kümülatif customer_satisfaction etkisi
	var cs_level: int = _levels.get(&"customer_satisfaction", 0)
	var cs: UpgradeData = _upgrades.get(&"customer_satisfaction")
	var patience_bonus: float = 0.0
	if cs:
		for i in range(cs_level):
			patience_bonus += cs.effect_per_level[i]
	customer_config.patience_multiplier = 1.0 + patience_bonus

	# vip_spawn_rate = 0.05 × (1 + effect) eğer vip_lounge alındıysa
	var vip_level: int = _levels.get(&"vip_lounge", 0)
	var vip: UpgradeData = _upgrades.get(&"vip_lounge")
	customer_config.vip_spawn_rate = \
		0.05 * (1.0 + vip.effect_per_level[0]) if vip and vip_level > 0 else 0.05

	# repeat_customer_gold_bonus
	var lc_level: int = _levels.get(&"loyalty_card", 0)
	var lc: UpgradeData = _upgrades.get(&"loyalty_card")
	customer_config.repeat_customer_gold_bonus = \
		lc.effect_per_level[0] if lc and lc_level > 0 else 0.0


# ── Bağımlılık enjeksiyonu ────────────────────────────────────────────────────

func _get_economy() -> EconomySystem:
	if _economy_ref:
		return _economy_ref
	return get_node_or_null("/root/Economy") as EconomySystem


func _get_registry() -> ContentRegistry:
	if _registry_ref:
		return _registry_ref
	return get_node_or_null("/root/ContentRegistry") as ContentRegistry
