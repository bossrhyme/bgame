## ContentRegistry — Autoload
##
## Tüm statik oyun içeriğini assets/data/ altından yükler ve
## ID-tabanlı Dictionary yapıları aracılığıyla sisteme sunar.
##
## Mimari kuralları (GDD #2):
##   - Salt okunur: runtime'da kayıt eklenemez, silinemez, değiştirilemez
##   - Pull mimarisi: downstream sistemler sorgular, bu sistem push yapmaz
##   - Bilinmeyen ID → null döner + push_error(); çökmez
##   - Yükleme: DirAccess ile otomatik tarama (manifest gerekmez)
class_name ContentRegistry
extends Node

## Yükleme dizinleri (res:// göreli yollar). Hardcode edilmez.
@export var recipes_dir: String = "res://assets/data/recipes/"
@export var upgrades_dir: String = "res://assets/data/upgrades/"
@export var employees_dir: String = "res://assets/data/employees/"
@export var locations_dir: String = "res://assets/data/locations/"
@export var customer_types_dir: String = "res://assets/data/customer_types/"

var _recipes: Dictionary = {}          ## StringName → RecipeData
var _upgrades: Dictionary = {}         ## StringName → UpgradeData
var _employees: Dictionary = {}        ## StringName → EmployeeData
var _locations: Dictionary = {}        ## StringName → LocationData
var _customer_types: Dictionary = {}   ## StringName → CustomerTypeData

var is_ready: bool = false


func _ready() -> void:
	_load_directory(recipes_dir, _recipes, "RecipeData")
	_load_directory(upgrades_dir, _upgrades, "UpgradeData")
	_load_directory(employees_dir, _employees, "EmployeeData")
	_load_directory(locations_dir, _locations, "LocationData")
	_load_directory(customer_types_dir, _customer_types, "CustomerTypeData")
	_validate_all()
	is_ready = true


# ── Public API ────────────────────────────────────────────────────────────────

## Tarif döner. Bilinmeyen id → null + hata logu.
func get_recipe(id: StringName) -> RecipeData:
	return _get(_recipes, id, "RecipeData") as RecipeData


## Tüm tarifleri döner.
func get_all_recipes() -> Array[RecipeData]:
	return _all_values(_recipes) as Array[RecipeData]


## Upgrade döner. Bilinmeyen id → null + hata logu.
func get_upgrade(id: StringName) -> UpgradeData:
	return _get(_upgrades, id, "UpgradeData") as UpgradeData


## Tüm upgrade'leri döner.
func get_all_upgrades() -> Array[UpgradeData]:
	return _all_values(_upgrades) as Array[UpgradeData]


## Çalışan döner. Bilinmeyen id → null + hata logu.
func get_employee(id: StringName) -> EmployeeData:
	return _get(_employees, id, "EmployeeData") as EmployeeData


## Tüm çalışanları döner.
func get_all_employees() -> Array[EmployeeData]:
	return _all_values(_employees) as Array[EmployeeData]


## Lokasyon döner. Bilinmeyen id → null + hata logu.
func get_location(id: StringName) -> LocationData:
	return _get(_locations, id, "LocationData") as LocationData


## Tüm lokasyonları döner.
func get_all_locations() -> Array[LocationData]:
	return _all_values(_locations) as Array[LocationData]


## Müşteri tipi döner. Bilinmeyen id → null + hata logu.
func get_customer_type(id: StringName) -> CustomerTypeData:
	return _get(_customer_types, id, "CustomerTypeData") as CustomerTypeData


## Tüm müşteri tiplerini döner.
func get_all_customer_types() -> Array[CustomerTypeData]:
	return _all_values(_customer_types) as Array[CustomerTypeData]


# ── Internal ──────────────────────────────────────────────────────────────────

func _load_directory(dir_path: String, target: Dictionary, type_name: String) -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		push_warning("ContentRegistry: dizin bulunamadı: %s" % dir_path)
		return

	var files := DirAccess.get_files_at(dir_path)
	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue
		var full_path: String = dir_path + file_name
		var res = load(full_path)
		if res == null:
			push_error("ContentRegistry: yüklenemedi: %s" % full_path)
			continue
		var id: StringName = res.get("id")
		if id == &"":
			push_error("ContentRegistry: id boş: %s" % full_path)
			continue
		if target.has(id):
			push_warning("ContentRegistry: duplicate id '%s' — %s üzerine yazıldı" % [id, full_path])
		target[id] = res


func _get(dict: Dictionary, id: StringName, type_name: String) -> Resource:
	if dict.has(id):
		return dict[id]
	push_error("ContentRegistry: bilinmeyen %s id: '%s'" % [type_name, id])
	return null


func _all_values(dict: Dictionary) -> Array:
	return dict.values()


func _validate_all() -> void:
	# UpgradeData: effect_per_level boş veya max_level uyumsuz
	for id in _upgrades:
		var u: UpgradeData = _upgrades[id]
		if u.effect_per_level.is_empty():
			push_error("ContentRegistry: UpgradeData '%s' effect_per_level boş — kaldırıldı" % id)
			_upgrades.erase(id)
			continue
		if u.max_level != u.effect_per_level.size():
			push_warning("ContentRegistry: UpgradeData '%s' max_level=%d ≠ effect_per_level.size()=%d — max_level düzeltildi" \
				% [id, u.max_level, u.effect_per_level.size()])
			u.max_level = u.effect_per_level.size()

	# CustomerTypeData: tüm spawn_weight = 0 → EC-6
	var total_weight: float = 0.0
	for id in _customer_types:
		total_weight += (_customer_types[id] as CustomerTypeData).spawn_weight
	if total_weight == 0.0 and not _customer_types.is_empty():
		push_error("ContentRegistry: tüm CustomerTypeData spawn_weight=0 — tümü 1'e sıfırlandı")
		for id in _customer_types:
			(_customer_types[id] as CustomerTypeData).spawn_weight = 1.0
