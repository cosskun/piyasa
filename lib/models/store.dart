import 'dart:math';
import 'item.dart';

class StoreProductSlot {
  String itemId;
  int shelfCapacity;
  int shelfStock;
  double retailPrice;
  bool autoRestock;
  bool isSelling;
  double saleTimerProgress;

  StoreProductSlot({
    required this.itemId,
    this.shelfCapacity = 40,
    this.shelfStock = 0,
    required this.retailPrice,
    this.autoRestock = true,
    this.isSelling = true,
    this.saleTimerProgress = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'shelfCapacity': shelfCapacity,
    'shelfStock': shelfStock,
    'retailPrice': retailPrice,
    'autoRestock': autoRestock,
    'isSelling': isSelling,
    'saleTimerProgress': saleTimerProgress,
  };

  static StoreProductSlot fromJson(Map<String, dynamic> json) {
    final itemId = json['itemId'] as String? ?? 'bread';
    final item = ItemRegistry.get(itemId);
    return StoreProductSlot(
      itemId: itemId,
      shelfCapacity: (json['shelfCapacity'] as num?)?.toInt() ?? 40,
      shelfStock: (json['shelfStock'] as num?)?.toInt() ?? 0,
      retailPrice: (json['retailPrice'] as num?)?.toDouble() ?? (item?.retailSuggestedPrice ?? 20.0),
      autoRestock: json['autoRestock'] as bool? ?? true,
      isSelling: json['isSelling'] as bool? ?? true,
      saleTimerProgress: (json['saleTimerProgress'] as num?)?.toDouble() ?? 0.0,
    );
  }

  StoreProductSlot copy() {
    return StoreProductSlot(
      itemId: itemId,
      shelfCapacity: shelfCapacity,
      shelfStock: shelfStock,
      retailPrice: retailPrice,
      autoRestock: autoRestock,
      isSelling: isSelling,
      saleTimerProgress: saleTimerProgress,
    );
  }
}

class RetailStore {
  final String id;
  final String blueprintId;
  final String name;
  final String emoji;
  final String description;
  final List<String> allowedProductIds;
  final double purchaseCost;
  final double baseUpgradeCost;
  final double saleIntervalSeconds;
  final double baseOperatingExpense; // Dakikalık kira ve personel gideri

  int level;
  double timerProgress;
  double totalRevenue;
  String statusMessage;
  bool isSelling;
  final List<StoreProductSlot> productSlots;

  RetailStore({
    required this.id,
    String? blueprintId,
    required this.name,
    required this.emoji,
    required this.description,
    required this.allowedProductIds,
    required this.purchaseCost,
    required this.baseUpgradeCost,
    required this.saleIntervalSeconds,
    this.baseOperatingExpense = 30.0,
    this.level = 1,
    this.timerProgress = 0.0,
    this.totalRevenue = 0.0,
    this.statusMessage = 'Müşteri Bekleniyor',
    this.isSelling = true,
    List<StoreProductSlot>? productSlots,
  })  : blueprintId = blueprintId ?? id,
        productSlots = productSlots ?? [];

  /// Dükkan seviyesine göre açılabilen maksimum ürün sayısı (Seviye 1: 1 ürün ... Seviye 5: max 5 ürün)
  int get maxProductSlots => min(5, level);

  /// Birinci aktif ürün (geriye dönük uyumluluk için)
  String get productItemId => productSlots.isNotEmpty
      ? productSlots.first.itemId
      : (allowedProductIds.isNotEmpty ? allowedProductIds.first : 'bread');

  /// Toplam raftaki stok
  int get shelfStock => productSlots.fold(0, (sum, s) => sum + s.shelfStock);
  set shelfStock(int val) {
    if (productSlots.isNotEmpty) productSlots.first.shelfStock = val;
  }

  /// Birinci ürün raf kapasitesi
  int get shelfCapacity => productSlots.isNotEmpty ? productSlots.first.shelfCapacity : 50;
  set shelfCapacity(int val) {
    if (productSlots.isNotEmpty) productSlots.first.shelfCapacity = val;
  }

  /// Birinci ürün perakende satış fiyatı
  double get retailPrice => productSlots.isNotEmpty ? productSlots.first.retailPrice : 18.0;
  set retailPrice(double val) {
    if (productSlots.isNotEmpty) productSlots.first.retailPrice = val;
  }

  /// Otomatik ikmal
  bool get autoRestock => productSlots.isNotEmpty && productSlots.every((s) => s.autoRestock);
  set autoRestock(bool val) {
    for (var s in productSlots) {
      s.autoRestock = val;
    }
  }

  double get upgradeCost => baseUpgradeCost * pow(1.5, level - 1);
  double get effectiveInterval => max(0.8, saleIntervalSeconds - (level - 1) * 0.25);

  /// Dükkan seviyesine göre tek satış döngüsündeki müşteri sepet hacmi (Senkronizasyon)
  int get saleBatchSize {
    if (level <= 1) return 1;
    if (level == 2) return 2;
    if (level == 3) return 3;
    if (level == 4) return 5;
    return 8;
  }

  /// Toplam yatırılan sermaye bedeli (Satın alma maliyeti + yapılan seviye geliştirme harcamaları)
  double get totalInvestedValue {
    double total = purchaseCost;
    for (int lvl = 1; lvl < level; lvl++) {
      total += baseUpgradeCost * pow(1.5, lvl - 1);
    }
    return total;
  }

  /// Geri satış / Nakite dönüştürme bedeli (%70 ikinci el likidasyon oranı)
  double get resaleValue => (totalInvestedValue * 0.70).roundToDouble();

  /// Dakikalık efektif dükkan gideri (Açıksa seviyeye göre artar, durdurulduysa %25 asgari kira payı)
  double get effectiveOperatingExpense {
    if (!isSelling) return (baseOperatingExpense * 0.25).roundToDouble();
    return (baseOperatingExpense * (1.0 + (level - 1) * 0.20)).roundToDouble();
  }

  RetailStore copy({String? newId}) {
    return RetailStore(
      id: newId ?? '${id}_${DateTime.now().millisecondsSinceEpoch}',
      blueprintId: blueprintId,
      name: name,
      emoji: emoji,
      description: description,
      allowedProductIds: List<String>.from(allowedProductIds),
      purchaseCost: purchaseCost,
      baseUpgradeCost: baseUpgradeCost,
      saleIntervalSeconds: saleIntervalSeconds,
      baseOperatingExpense: baseOperatingExpense,
      level: level,
      timerProgress: timerProgress,
      totalRevenue: totalRevenue,
      statusMessage: statusMessage,
      isSelling: isSelling,
      productSlots: productSlots.map((s) => s.copy()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'blueprintId': blueprintId,
    'level': level,
    'shelfCapacity': shelfCapacity,
    'shelfStock': shelfStock,
    'retailPrice': retailPrice,
    'autoRestock': autoRestock,
    'isSelling': isSelling,
    'totalRevenue': totalRevenue,
    'productSlots': productSlots.map((s) => s.toJson()).toList(),
  };

  static RetailStore? fromJson(Map<String, dynamic> json) {
    final bpId = json['blueprintId'] as String? ?? json['id'] as String;
    final blueprints = getBlueprints();
    final match = blueprints.firstWhere(
      (b) => b.id == bpId || bpId.startsWith(b.id),
      orElse: () => blueprints.first,
    );
    final store = match.copy(newId: json['id'] as String?);
    store.level = (json['level'] as num?)?.toInt() ?? 1;
    store.totalRevenue = (json['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    store.isSelling = json['isSelling'] as bool? ?? true;
    if (!store.isSelling) {
      store.statusMessage = 'Satışlar Durduruldu';
    }

    if (json['productSlots'] != null && (json['productSlots'] as List).isNotEmpty) {
      store.productSlots.clear();
      for (var sJson in json['productSlots'] as List) {
        store.productSlots.add(StoreProductSlot.fromJson(sJson as Map<String, dynamic>));
      }
    } else {
      // Legacy format migration
      final pId = json['productItemId'] as String? ?? store.productItemId;
      final stock = (json['shelfStock'] as num?)?.toInt() ?? 0;
      final cap = (json['shelfCapacity'] as num?)?.toInt() ?? store.shelfCapacity;
      final price = (json['retailPrice'] as num?)?.toDouble() ?? store.retailPrice;
      final auto = json['autoRestock'] as bool? ?? true;
      store.productSlots.clear();
      store.productSlots.add(StoreProductSlot(
        itemId: pId,
        shelfCapacity: cap,
        shelfStock: stock,
        retailPrice: price,
        autoRestock: auto,
      ));
    }
    return store;
  }

  static List<RetailStore> getBlueprints() {
    return [
      RetailStore(
        id: 'kiosk_bread',
        name: 'Köşe Büfe & Fırın',
        emoji: '🏪',
        description: 'Mahallenin kalbi. Taze somun ekmek, un, kruvasan, pasta ve sıcak kahve satışı.',
        allowedProductIds: const ['bread', 'croissant', 'pastry_cake', 'flour', 'juice', 'cheese', 'coffee_cup'],
        purchaseCost: 4500.0,
        baseUpgradeCost: 2250.0,
        saleIntervalSeconds: 2.5,
        productSlots: [
          StoreProductSlot(
            itemId: 'bread',
            shelfCapacity: 50,
            retailPrice: 18.0,
          ),
        ],
      ),
      RetailStore(
        id: 'delicatessen_shop',
        name: 'Gurme Şarküteri & Peynirci',
        emoji: '🧀',
        description: 'Mandıra lezzetleri. Doğal köy peyniri, tereyağı, süzme yoğurt ve çiftlik sütü satışı.',
        allowedProductIds: const ['cheese', 'butter', 'yogurt', 'milk', 'bread', 'gourmet_chocolate', 'fruit'],
        purchaseCost: 7500.0,
        baseUpgradeCost: 3750.0,
        saleIntervalSeconds: 3.5,
        productSlots: [
          StoreProductSlot(
            itemId: 'cheese',
            shelfCapacity: 35,
            retailPrice: 110.0,
          ),
        ],
      ),
      RetailStore(
        id: 'juice_bar',
        name: 'Vitamin Meyve Barı',
        emoji: '🥤',
        description: 'Taze sıkılmış doğal meyve suları, taze meyveler ve serinletici içecekler.',
        allowedProductIds: const ['juice', 'fruit', 'french_fries', 'bread', 'coffee_cup'],
        purchaseCost: 8500.0,
        baseUpgradeCost: 4250.0,
        saleIntervalSeconds: 3.0,
        productSlots: [
          StoreProductSlot(
            itemId: 'juice',
            shelfCapacity: 40,
            retailPrice: 48.0,
          ),
        ],
      ),
      RetailStore(
        id: 'fast_food_joint',
        name: 'Fast-Food & Patatesçi',
        emoji: '🍟',
        description: 'Sıcak altın çıtır patates külahları, burger ekmekleri ve soğuk içecekler.',
        allowedProductIds: const ['french_fries', 'potato', 'juice', 'bread', 'coffee_cup'],
        purchaseCost: 10000.0,
        baseUpgradeCost: 5000.0,
        saleIntervalSeconds: 2.8,
        productSlots: [
          StoreProductSlot(
            itemId: 'french_fries',
            shelfCapacity: 45,
            retailPrice: 42.0,
          ),
        ],
      ),
      RetailStore(
        id: 'coffee_house',
        name: '3. Nesil Kahve Dükkanı',
        emoji: '☕',
        description: 'Taze demlenmiş aromatik filtre kahve, sütlü latte, kavrulmuş paket kahve ve çikolatalar.',
        allowedProductIds: const ['coffee_cup', 'coffee_latte', 'roasted_coffee', 'croissant', 'coffee_bean', 'gourmet_chocolate', 'bread'],
        purchaseCost: 14000.0,
        baseUpgradeCost: 7000.0,
        saleIntervalSeconds: 3.5,
        productSlots: [
          StoreProductSlot(
            itemId: 'coffee_cup',
            shelfCapacity: 35,
            retailPrice: 65.0,
          ),
        ],
      ),
      RetailStore(
        id: 'chocolatier_shop',
        name: 'Artisan Çikolata Butiği',
        emoji: '🍫',
        description: 'Sütlü gurme kutu çikolatalar, aromatik kakao ve özel hediyelik tatlar.',
        allowedProductIds: const ['gourmet_chocolate', 'pastry_cake', 'cocoa', 'milk', 'coffee_cup', 'juice'],
        purchaseCost: 18000.0,
        baseUpgradeCost: 9000.0,
        saleIntervalSeconds: 4.2,
        productSlots: [
          StoreProductSlot(
            itemId: 'gourmet_chocolate',
            shelfCapacity: 25,
            retailPrice: 210.0,
          ),
        ],
      ),
      RetailStore(
        id: 'clothing_boutique',
        name: 'Moda & Giyim Butiği',
        emoji: '👗',
        description: 'Pamuklu tişört, triko kazak, hırka, hakiki deri ceket ve lüks elbiseler.',
        allowedProductIds: const ['cotton_tshirt', 'wool_sweater', 'cardigan', 'leather_jacket', 'designer_dress', 'clothes', 'fabric', 'cotton'],
        purchaseCost: 35000.0,
        baseUpgradeCost: 17500.0,
        saleIntervalSeconds: 5.0,
        productSlots: [
          StoreProductSlot(
            itemId: 'clothes',
            shelfCapacity: 25,
            retailPrice: 260.0,
          ),
        ],
      ),
      RetailStore(
        id: 'furniture_showroom',
        name: 'Tasarım Mobilya Mağazası',
        emoji: '🛋️',
        description: 'Doğal ahşap sandalyeler, yemek masaları ve masif gardırop tasarımı.',
        allowedProductIds: const ['furniture_chair', 'furniture_table', 'furniture_wardrobe', 'plank', 'wood_log'],
        purchaseCost: 55000.0,
        baseUpgradeCost: 27500.0,
        saleIntervalSeconds: 6.0,
        productSlots: [
          StoreProductSlot(
            itemId: 'furniture_chair',
            shelfCapacity: 20,
            retailPrice: 320.0,
          ),
        ],
      ),
      RetailStore(
        id: 'electronics_store',
        name: 'Teknoloji & Telefon Mağazası',
        emoji: '📱',
        description: 'Akıllı telefonlar, dizüstü bilgisayarlar (laptop) ve akıllı saatler.',
        allowedProductIds: const ['smartphone', 'laptop', 'smartwatch', 'plastic_pellet', 'steel_ingot'],
        purchaseCost: 95000.0,
        baseUpgradeCost: 47500.0,
        saleIntervalSeconds: 7.0,
        productSlots: [
          StoreProductSlot(
            itemId: 'smartphone',
            shelfCapacity: 15,
            retailPrice: 680.0,
          ),
        ],
      ),
    ];
  }
}

/// Dükkan B2B Kurumsal Tedarik Sözleşmesi (Otel, Restoran, Aşevi vb. Hacimli Satışlar)
class StoreB2BContract {
  final String id;
  final String blueprintId;
  final String title;
  final String clientName;
  final String description;
  final String itemId;
  final int requiredQuantity;
  final double rewardCash;
  final int rewardPrestige;
  final int minStoreLevel;
  final String badge;

  const StoreB2BContract({
    required this.id,
    required this.blueprintId,
    required this.title,
    required this.clientName,
    required this.description,
    required this.itemId,
    required this.requiredQuantity,
    required this.rewardCash,
    this.rewardPrestige = 20,
    this.minStoreLevel = 2,
    this.badge = 'B2B SÖZLEŞMESİ',
  });

  static const List<StoreB2BContract> blueprints = [
    // Köşe Büfe & Fırın
    StoreB2BContract(
      id: 'b2b_bread_hotel',
      blueprintId: 'kiosk_bread',
      title: 'Grand Bosphorus Otel Açık Büfe Tedariği',
      clientName: 'Grand Bosphorus Hotel & Spa',
      description: 'Lüks şehir oteli açık büfesi için toplu taze somun ekmek tedarik sözleşmesi.',
      itemId: 'bread',
      requiredQuantity: 100,
      rewardCash: 2400.0,
      rewardPrestige: 25,
      minStoreLevel: 2,
      badge: '🏨 OTEL SÖZLEŞMESİ',
    ),
    StoreB2BContract(
      id: 'b2b_bread_soup_kitchen',
      blueprintId: 'kiosk_bread',
      title: 'Büyükşehir Aşevi Ekmek Sevkiyatı',
      clientName: 'Şehir Sosyal Yardım Vakfı',
      description: 'Kent aşevleri için haftalık yüksek hacimli somun ekmek teslimatı.',
      itemId: 'bread',
      requiredQuantity: 300,
      rewardCash: 7200.0,
      rewardPrestige: 50,
      minStoreLevel: 3,
      badge: '🏛️ BELEDİYE PROTOKOLÜ',
    ),
    StoreB2BContract(
      id: 'b2b_croissant_cafe_chain',
      blueprintId: 'kiosk_bread',
      title: 'Fransız Pastane Zinciri Kruvasan İhalesi',
      clientName: 'La Petite Patisserie Zinciri',
      description: '10 şubeli gurme pastane zinciri için tereyağlı çıtır kruvasan teslimatı.',
      itemId: 'croissant',
      requiredQuantity: 150,
      rewardCash: 8500.0,
      rewardPrestige: 70,
      minStoreLevel: 4,
      badge: '🥐 GURME ZİNCİR',
    ),

    // Gurme Şarküteri & Peynirci
    StoreB2BContract(
      id: 'b2b_cheese_bistro',
      blueprintId: 'delicatessen_shop',
      title: 'Marina Bistro Şarküteri Tabağı Tedariği',
      clientName: 'Marina Yacht Club Bistro',
      description: 'Marina restoranı şarap ve peynir tabakları için geleneksel olgun peynir teslimatı.',
      itemId: 'cheese',
      requiredQuantity: 50,
      rewardCash: 6500.0,
      rewardPrestige: 30,
      minStoreLevel: 2,
      badge: '🧀 RESTORAN KONTRATI',
    ),
    StoreB2BContract(
      id: 'b2b_butter_pastry',
      blueprintId: 'delicatessen_shop',
      title: 'Usta Baklavacı Hakiki Tereyağı İhalesi',
      clientName: 'Gaziantep Köşk Baklavaları',
      description: 'Özel yapım şerbetli tatlılar için birinci kalite tuzsuz çiftlik tereyağı.',
      itemId: 'butter',
      requiredQuantity: 80,
      rewardCash: 12800.0,
      rewardPrestige: 60,
      minStoreLevel: 3,
      badge: '🧈 ÖZEL SİPARİŞ',
    ),

    // Vitamin Meyve Barı
    StoreB2BContract(
      id: 'b2b_juice_fit_club',
      blueprintId: 'juice_bar',
      title: 'Fitness & Welness Club Detoks İçeceği Tedariği',
      clientName: 'Titanium Performance Gym',
      description: 'Sporcular ve üyeler için günlük taze sıkılmış doğal karışım meyve suları.',
      itemId: 'juice',
      requiredQuantity: 100,
      rewardCash: 5800.0,
      rewardPrestige: 35,
      minStoreLevel: 2,
      badge: '🏋️ SPOR MERKEZİ',
    ),

    // Fast Food & Patatesçi
    StoreB2BContract(
      id: 'b2b_fries_stadium',
      blueprintId: 'fast_food_joint',
      title: 'Şehir Stadyumu Derbi Günü Büfe Tedariği',
      clientName: 'Metropol Arena İşletmesi',
      description: 'Büyük lig maçı taraftarları için dondurulmuş çıtır patates külahları partisi.',
      itemId: 'french_fries',
      requiredQuantity: 200,
      rewardCash: 10500.0,
      rewardPrestige: 45,
      minStoreLevel: 2,
      badge: '⚽ STADYUM İHALESİ',
    ),

    // 3. Nesil Kahve Dükkanı
    StoreB2BContract(
      id: 'b2b_coffee_tech_hub',
      blueprintId: 'coffee_house',
      title: 'Teknopark Ar-Ge Merkezi Ofis Kahve Barı',
      clientName: 'Silicon Technopark A.Ş.',
      description: 'Yazılımcılar ve girişimciler için haftalık aromatik sıcak kahve tedariği.',
      itemId: 'coffee_cup',
      requiredQuantity: 150,
      rewardCash: 11500.0,
      rewardPrestige: 40,
      minStoreLevel: 2,
      badge: '💻 TEKNOLOJİ ÜSSÜ',
    ),
    StoreB2BContract(
      id: 'b2b_coffee_convention',
      blueprintId: 'coffee_house',
      title: 'Uluslararası Zirve Kahve Molası Servisi',
      clientName: 'World Trade Summit Convention',
      description: '3 günlük uluslararası iş kongresinde ikram edilecek 300 fincan kahve paketi.',
      itemId: 'coffee_cup',
      requiredQuantity: 300,
      rewardCash: 24000.0,
      rewardPrestige: 80,
      minStoreLevel: 3,
      badge: '🌍 DÜNYA KONGRESİ',
    ),

    // Artisan Çikolata
    StoreB2BContract(
      id: 'b2b_choc_corporate_gift',
      blueprintId: 'chocolatier_shop',
      title: 'Banka Genel Müdürlüğü Prestij Hediye Kutuları',
      clientName: 'Anadolu Yatırım Bankası',
      description: 'VIP kurumsal müşterilere gönderilmek üzere el yapımı gurme kutu çikolatalar.',
      itemId: 'gourmet_chocolate',
      requiredQuantity: 60,
      rewardCash: 14500.0,
      rewardPrestige: 60,
      minStoreLevel: 2,
      badge: '🎁 KURUMSAL HEDİYE',
    ),

    // Moda & Giyim Butiği
    StoreB2BContract(
      id: 'b2b_clothes_department',
      blueprintId: 'clothing_boutique',
      title: 'Çok Katlı AVM Mağazası Sezon Koleksiyonu',
      clientName: 'Moda Galleria Zinciri',
      description: 'Yeni sezon vitrinleri için birinci kalite giyim ürünleri konsinye teslimatı.',
      itemId: 'clothes',
      requiredQuantity: 50,
      rewardCash: 16000.0,
      rewardPrestige: 60,
      minStoreLevel: 2,
      badge: '👗 AVM ZİNCİRİ',
    ),

    // Tasarım Mobilya
    StoreB2BContract(
      id: 'b2b_furniture_office',
      blueprintId: 'furniture_showroom',
      title: 'Yeni Hukuk Bürosu Çalışma Sandalyeleri',
      clientName: 'Global Adalet Plaza Ofisi',
      description: 'Yeni kurulan hukuk bürosu için masif ahşap konsept sandalyeler.',
      itemId: 'furniture_chair',
      requiredQuantity: 40,
      rewardCash: 15500.0,
      rewardPrestige: 70,
      minStoreLevel: 2,
      badge: '⚖️ PLAZA SÖZLEŞMESİ',
    ),

    // Teknoloji & Telefon Mağazası
    StoreB2BContract(
      id: 'b2b_phone_corp_fleet',
      blueprintId: 'electronics_store',
      title: 'Lojistik Saha Ekibi Kurumsal Akıllı Telefon Filosu',
      clientName: 'Trans-Anadolu Ekspres Lojistik',
      description: 'Kurye ve filo takip ekiplerine dağıtılacak kurumsal akıllı telefon paketi.',
      itemId: 'smartphone',
      requiredQuantity: 25,
      rewardCash: 21000.0,
      rewardPrestige: 90,
      minStoreLevel: 2,
      badge: '📱 KURUMSAL FİLO',
    ),
  ];

  static List<StoreB2BContract> getContractsForStore(RetailStore store) {
    return blueprints
        .where((c) => c.blueprintId == store.blueprintId || c.blueprintId == store.id)
        .toList();
  }
}
