## GameEnums — Oyun genelinde paylaşılan enum tanımları.
## Tüm sistemler bu dosyadan import eder; hardcode sayısal değer kullanılmaz.
class_name GameEnums


enum RecipeCategory {
	BASIC,      ## Temel ekmekler — başlangıç
	WORLD,      ## Dünya tarifleri — Sev. 5-15
	SPECIAL,    ## Özel tarifler — Sev. 15-30
	SWEET,      ## Tatlı tarifler — Sev. 25-40
	LEGENDARY,  ## Efsanevi tarifler — Prestige
}

enum UpgradeCategory {
	PRODUCTION,  ## Pişirme hızı, kapasite, otomasyon
	CUSTOMER,    ## Sipariş slotu, sabır, VIP
	DELIVERY,    ## Teslimat kapasitesi ve hızı
}

enum UpgradeEffectType {
	BAKE_SPEED,        ## Pişirme hızı çarpanı
	OVEN_CAPACITY,     ## Eş zamanlı fırın slotu
	DOUGH_QUALITY,     ## Hamur kalitesi → gelir bonusu
	AUTO_DOUGH,        ## Otomatik hamur seviyesi
	STORAGE_CAP,       ## Malzeme depo kapasitesi
	CUSTOMER_CAPACITY, ## Sipariş panosu slot sayısı
	PATIENCE,          ## Müşteri sabır çarpanı
	VIP_RATE,          ## VIP spawn oranı
	DELIVERY_CAPACITY, ## Teslimat sipariş kapasitesi
	DELIVERY_SPEED,    ## Teslimat hızı çarpanı
}

enum EmployeeRole {
	DOUGH_MAKER,  ## Hamur yoğurmayı otomatize eder
	OVEN_MASTER,  ## Pişirme hızını artırır
	CASHIER,      ## Satış işlemlerini hızlandırır
	DELIVERY,     ## Teslimat siparişlerini yönetir
}
