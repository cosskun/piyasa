import 'dart:math';
import 'item.dart';

/// Şirket yapay zeka stratejisi / karakteri
enum NpcStrategy {
  aggressive,    // Büyüme odaklı, hammadde azaldığında agresif fiyat artırır, oyuncunun ilanını hemen kapar
  balanced,      // Dengeli sanayici, düzenli üretim ve tüketim yapar, piyasa ortalamasında seyreder
  bargainHunter, // Fırsatçı / Tutumlu, düşük fiyattan alım yapar, yüksek marjla satar
}

/// Şirketin ürün için aciliyet durumu
enum NpcBidUrgency {
  low,      // Stok bol / Doygun (Düşük fiyat verir)
  normal,   // Normal işletme stoğu
  critical, // Kritik hammadde kıtlığı (Piyasa üstü yüksek prim teklif eder)
}

/// NPC Şirketinin bir ürün için anlık Alış Emri (Oyuncu bu fiyattan anında şirkete satabilir)
class NpcBuyBid {
  final String itemId;
  double pricePerUnit;
  int demandedQuantity;
  NpcBidUrgency urgency;
  double lastChangePercent;

  NpcBuyBid({
    required this.itemId,
    required this.pricePerUnit,
    required this.demandedQuantity,
    this.urgency = NpcBidUrgency.normal,
    this.lastChangePercent = 0.0,
  });

  ItemData get item => ItemRegistry.get(itemId)!;

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'pricePerUnit': pricePerUnit,
    'demandedQuantity': demandedQuantity,
    'urgency': urgency.name,
    'lastChangePercent': lastChangePercent,
  };

  static NpcBuyBid fromJson(Map<String, dynamic> json) {
    return NpcBuyBid(
      itemId: json['itemId'] as String,
      pricePerUnit: (json['pricePerUnit'] as num).toDouble(),
      demandedQuantity: (json['demandedQuantity'] as num).toInt(),
      urgency: NpcBidUrgency.values.firstWhere(
        (e) => e.name == json['urgency'],
        orElse: () => NpcBidUrgency.normal,
      ),
      lastChangePercent: (json['lastChangePercent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// NPC Şirketinin bir ürün için anlık Satış Teklifi (Oyuncu bu fiyattan anında şirketten satın alabilir)
class NpcSellOffer {
  final String itemId;
  double pricePerUnit;
  int availableQuantity;
  double lastChangePercent;

  NpcSellOffer({
    required this.itemId,
    required this.pricePerUnit,
    required this.availableQuantity,
    this.lastChangePercent = 0.0,
  });

  ItemData get item => ItemRegistry.get(itemId)!;

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'pricePerUnit': pricePerUnit,
    'availableQuantity': availableQuantity,
    'lastChangePercent': lastChangePercent,
  };

  static NpcSellOffer fromJson(Map<String, dynamic> json) {
    return NpcSellOffer(
      itemId: json['itemId'] as String,
      pricePerUnit: (json['pricePerUnit'] as num).toDouble(),
      availableQuantity: (json['availableQuantity'] as num).toInt(),
      lastChangePercent: (json['lastChangePercent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Otonom NPC Şirketi Modeli
class NpcCompany {
  final String id;
  final String name;
  final String emoji;
  final String sector;
  final String motto;
  final NpcStrategy strategy;
  double capital; // Nakit bütçe (TL)
  final int maxStorageCapacity;

  // Envanter: { itemId: miktar }
  final Map<String, int> inventory;

  // Hedef stok seviyeleri: { itemId: hedefAdet }
  final Map<String, int> targetStock;

  // Satın aldığı ürünler (Girdiler)
  final List<String> inputItemIds;

  // Ürettiği / Sattığı ürünler (Çıktılar)
  final List<String> outputItemIds;

  // İsteğe bağlı üretim dönüşüm kuralı: inputs -> outputs
  final Map<String, int>? recipeInputs;
  final String? recipeOutputItemId;
  final int recipeOutputAmount;
  final double productionDurationSeconds;
  double productionTimer;

  // Anlık Alış ve Satış Emirleri
  final Map<String, NpcBuyBid> buyBids;
  final Map<String, NpcSellOffer> sellOffers;

  String statusMessage;
  double lastActionTimestamp;

  NpcCompany({
    required this.id,
    required this.name,
    required this.emoji,
    required this.sector,
    required this.motto,
    required this.strategy,
    required this.capital,
    this.maxStorageCapacity = 4000,
    Map<String, int>? inventory,
    Map<String, int>? targetStock,
    required this.inputItemIds,
    required this.outputItemIds,
    this.recipeInputs,
    this.recipeOutputItemId,
    this.recipeOutputAmount = 1,
    this.productionDurationSeconds = 6.0,
    this.productionTimer = 0.0,
    Map<String, NpcBuyBid>? buyBids,
    Map<String, NpcSellOffer>? sellOffers,
    this.statusMessage = 'İşlemler normal',
    this.lastActionTimestamp = 0.0,
  })  : inventory = inventory ?? {},
        targetStock = targetStock ?? {},
        buyBids = buyBids ?? {},
        sellOffers = sellOffers ?? {};

  /// Depodaki toplam ürün adedi
  int get totalStoredItems => inventory.values.fold(0, (sum, qty) => sum + qty);

  /// Kalan depo boşluğu
  int get remainingStorage => max(0, maxStorageCapacity - totalStoredItems);

  /// Belirli bir ürünün doluluk oranı (0.0 - 1.0+)
  double getStockFillRatio(String itemId) {
    final current = inventory[itemId] ?? 0;
    final target = targetStock[itemId] ?? 300;
    if (target <= 0) return 1.0;
    return current / target;
  }

  /// Otonom Simülasyon Döngüsü (Karar Motoru & Üretim/Tüketim)
  void tickSimulation({
    required double dt,
    required Map<String, double> marketBasePrices,
    required List<NpcCompany> allCompanies,
    required Random rnd,
  }) {
    // 1. Üretim ve Dönüşüm Döngüsü (Fabrika / Atölye mantığı)
    if (recipeInputs != null && recipeOutputItemId != null) {
      productionTimer += dt;
      if (productionTimer >= productionDurationSeconds) {
        productionTimer = 0.0;
        _executeProductionCycle(rnd);
      }
    } else {
      // Tarım veya Nihai Tüketim/İhracat döngüsü
      productionTimer += dt;
      if (productionTimer >= productionDurationSeconds) {
        productionTimer = 0.0;
        _executeNaturalHarvestOrConsumption(rnd);
      }
    }

    // 2. Fiyat ve Emir Güncellemesi (Stok & Rakip Analizi)
    _updateCompetitiveBids(marketBasePrices: marketBasePrices, allCompanies: allCompanies, rnd: rnd);
  }

  /// Reçeteye göre hammadde tüketip mamul üretme
  void _executeProductionCycle(Random rnd) {
    if (recipeInputs == null || recipeOutputItemId == null) return;

    // Girdi kontrolü
    bool hasAllInputs = true;
    for (var entry in recipeInputs!.entries) {
      if ((inventory[entry.key] ?? 0) < entry.value) {
        hasAllInputs = false;
        break;
      }
    }

    if (hasAllInputs && remainingStorage >= recipeOutputAmount) {
      // Girdileri düş
      for (var entry in recipeInputs!.entries) {
        inventory[entry.key] = (inventory[entry.key] ?? 0) - entry.value;
      }
      // Çıktıyı ekle
      inventory[recipeOutputItemId!] = (inventory[recipeOutputItemId!] ?? 0) + recipeOutputAmount;
      statusMessage = '⚙️ Üretim tamamlandı (+$recipeOutputAmount ${ItemRegistry.get(recipeOutputItemId!)?.name ?? ''})';
    } else if (!hasAllInputs) {
      statusMessage = '⚠️ Hammadde bekleniyor';
    }
  }

  /// Hammadde üreticilerinin hasat yapması ya da perakendecilerin tüketmesi
  void _executeNaturalHarvestOrConsumption(Random rnd) {
    // Eğer sadece çıktı üretiyorsa (Tarla, Maden, Orman)
    if (inputItemIds.isEmpty && outputItemIds.isNotEmpty) {
      for (var outId in outputItemIds) {
        final current = inventory[outId] ?? 0;
        final target = targetStock[outId] ?? 400;
        if (current < target && remainingStorage >= 5) {
          int harvested = rnd.nextInt(4) + 2; // 2 - 5 adet hasat
          inventory[outId] = current + harvested;
          statusMessage = '🌱 Doğal hasat yapıldı (+$harvested)';
        }
      }
    }

    // Eğer nihai ürün tüketiyorsa (Perakende toptancısı / İhracatçı)
    if (outputItemIds.isEmpty && inputItemIds.isNotEmpty) {
      for (var inId in inputItemIds) {
        final current = inventory[inId] ?? 0;
        if (current > 0) {
          int consumed = min(current, rnd.nextInt(5) + 2);
          inventory[inId] = current - consumed;
          // Kasaya perakende/ihracat hasılatı girer
          final item = ItemRegistry.get(inId);
          double revenue = consumed * (item?.retailSuggestedPrice ?? (item?.basePrice ?? 10.0) * 1.3);
          capital += revenue;
          statusMessage = '🛒 Şehir halkına satıldı (+${revenue.toStringAsFixed(0)} ₺)';
        }
      }
    }
  }

  /// Rekabetçi Alış ve Satış Fiyatlarını Belirleme
  void _updateCompetitiveBids({
    required Map<String, double> marketBasePrices,
    required List<NpcCompany> allCompanies,
    required Random rnd,
  }) {
    // === ALIŞ EMİRLERİ (Şirketin Satın Almak İstediği Mallar) ===
    for (var itemId in inputItemIds) {
      final basePrice = marketBasePrices[itemId] ?? ItemRegistry.get(itemId)?.basePrice ?? 10.0;
      final fillRatio = getStockFillRatio(itemId);
      final currentStock = inventory[itemId] ?? 0;
      final target = targetStock[itemId] ?? 300;
      final neededQty = max(20, target - currentStock);

      NpcBidUrgency urgency;
      double multiplier;

      // Şirket stratejisine ve doluluk oranına göre fiyat çarpanı
      if (fillRatio < 0.25) {
        // Kritik Kıtlık! Acil hammadde aranıyor!
        urgency = NpcBidUrgency.critical;
        multiplier = strategy == NpcStrategy.aggressive
            ? 1.12 + rnd.nextDouble() * 0.06 // %112 - %118
            : 1.06 + rnd.nextDouble() * 0.05; // %106 - %111
      } else if (fillRatio < 0.75) {
        // Normal İşletme
        urgency = NpcBidUrgency.normal;
        multiplier = strategy == NpcStrategy.bargainHunter
            ? 0.95 + rnd.nextDouble() * 0.04 // %95 - %99
            : 0.99 + rnd.nextDouble() * 0.05; // %99 - %104
      } else {
        // Stok Dolu / Doygun
        urgency = NpcBidUrgency.low;
        multiplier = 0.86 + rnd.nextDouble() * 0.06; // %86 - %92 (fiyat kırar)
      }

      // RAKİP ANALİZİ: Aynı ürünü alan başka şirket var mı?
      if (urgency != NpcBidUrgency.low) {
        double highestCompetitorBid = 0.0;
        for (var comp in allCompanies) {
          if (comp.id != id && comp.buyBids.containsKey(itemId)) {
            highestCompetitorBid = max(highestCompetitorBid, comp.buyBids[itemId]!.pricePerUnit);
          }
        }
        // Eğer rakip fiyatı bizden yüksekse ve stok durumumuz kritikse rakibin %1 üstüne çıkmaya çalış
        if (highestCompetitorBid > 0 && strategy != NpcStrategy.bargainHunter) {
          double matchPrice = highestCompetitorBid * 1.01;
          if (matchPrice <= basePrice * 1.25) {
            multiplier = max(multiplier, matchPrice / basePrice);
          }
        }
      }

      double finalBidPrice = double.parse((basePrice * multiplier).toStringAsFixed(2));
      final oldBid = buyBids[itemId];
      double changePct = oldBid != null && oldBid.pricePerUnit > 0
          ? ((finalBidPrice - oldBid.pricePerUnit) / oldBid.pricePerUnit) * 100
          : 0.0;

      buyBids[itemId] = NpcBuyBid(
        itemId: itemId,
        pricePerUnit: finalBidPrice,
        demandedQuantity: neededQty,
        urgency: urgency,
        lastChangePercent: double.parse(changePct.toStringAsFixed(1)),
      );
    }

    // === SATIŞ TEKLİFLERİ (Şirketin Pazara Arz Ettiği Mallar) ===
    for (var itemId in outputItemIds) {
      final currentStock = inventory[itemId] ?? 0;
      if (currentStock <= 5) {
        // Satacak mal yok
        sellOffers.remove(itemId);
        continue;
      }

      final basePrice = marketBasePrices[itemId] ?? ItemRegistry.get(itemId)?.basePrice ?? 10.0;
      final fillRatio = getStockFillRatio(itemId);

      // Çok stok varsa fiyat kırar (%95 - %98), stok azsa piyasa fiyatından satar (%101 - %106)
      double multiplier = fillRatio > 0.8
          ? 0.94 + rnd.nextDouble() * 0.04
          : 1.01 + rnd.nextDouble() * 0.05;

      double finalSellPrice = double.parse((basePrice * multiplier).toStringAsFixed(2));
      final oldOffer = sellOffers[itemId];
      double changePct = oldOffer != null && oldOffer.pricePerUnit > 0
          ? ((finalSellPrice - oldOffer.pricePerUnit) / oldOffer.pricePerUnit) * 100
          : 0.0;

      // Stoğunun %60'ını satışa çıkarır
      int offerQty = max(10, (currentStock * 0.6).round());

      sellOffers[itemId] = NpcSellOffer(
        itemId: itemId,
        pricePerUnit: finalSellPrice,
        availableQuantity: offerQty,
        lastChangePercent: double.parse(changePct.toStringAsFixed(1)),
      );
    }
  }

  /// Oyuncu şirkete doğrudan satış yaptığında
  bool executePlayerSellToNpc({
    required String itemId,
    required int quantity,
    required double agreedPricePerUnit,
  }) {
    double totalCost = quantity * agreedPricePerUnit;
    if (capital < totalCost) return false;
    if (remainingStorage < quantity) return false;

    capital -= totalCost;
    inventory[itemId] = (inventory[itemId] ?? 0) + quantity;

    // Alış emrini güncelle
    if (buyBids.containsKey(itemId)) {
      buyBids[itemId]!.demandedQuantity = max(0, buyBids[itemId]!.demandedQuantity - quantity);
    }

    statusMessage = '🤝 Oyuncudan $quantity adet ${ItemRegistry.get(itemId)?.name ?? ''} satın alındı';
    return true;
  }

  /// Oyuncu şirketten doğrudan satın aldığında
  bool executePlayerBuyFromNpc({
    required String itemId,
    required int quantity,
    required double agreedPricePerUnit,
  }) {
    int currentStock = inventory[itemId] ?? 0;
    if (currentStock < quantity) return false;

    double revenue = quantity * agreedPricePerUnit;
    capital += revenue;
    inventory[itemId] = currentStock - quantity;

    if (sellOffers.containsKey(itemId)) {
      sellOffers[itemId]!.availableQuantity = max(0, sellOffers[itemId]!.availableQuantity - quantity);
    }

    statusMessage = '📦 Oyuncuya $quantity adet ${ItemRegistry.get(itemId)?.name ?? ''} satıldı';
    return true;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'sector': sector,
    'motto': motto,
    'strategy': strategy.name,
    'capital': capital,
    'maxStorageCapacity': maxStorageCapacity,
    'inventory': inventory,
    'targetStock': targetStock,
    'inputItemIds': inputItemIds,
    'outputItemIds': outputItemIds,
    'recipeInputs': recipeInputs,
    'recipeOutputItemId': recipeOutputItemId,
    'recipeOutputAmount': recipeOutputAmount,
    'productionDurationSeconds': productionDurationSeconds,
    'buyBids': buyBids.map((k, v) => MapEntry(k, v.toJson())),
    'sellOffers': sellOffers.map((k, v) => MapEntry(k, v.toJson())),
    'statusMessage': statusMessage,
  };

  static NpcCompany fromJson(Map<String, dynamic> json) {
    return NpcCompany(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      sector: json['sector'] as String,
      motto: json['motto'] as String,
      strategy: NpcStrategy.values.firstWhere(
        (e) => e.name == json['strategy'],
        orElse: () => NpcStrategy.balanced,
      ),
      capital: (json['capital'] as num).toDouble(),
      maxStorageCapacity: (json['maxStorageCapacity'] as num?)?.toInt() ?? 4000,
      inventory: (json['inventory'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          {},
      targetStock: (json['targetStock'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          {},
      inputItemIds: (json['inputItemIds'] as List<dynamic>?)?.cast<String>() ?? [],
      outputItemIds: (json['outputItemIds'] as List<dynamic>?)?.cast<String>() ?? [],
      recipeInputs: (json['recipeInputs'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      ),
      recipeOutputItemId: json['recipeOutputItemId'] as String?,
      recipeOutputAmount: (json['recipeOutputAmount'] as num?)?.toInt() ?? 1,
      productionDurationSeconds: (json['productionDurationSeconds'] as num?)?.toDouble() ?? 6.0,
      buyBids: (json['buyBids'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, NpcBuyBid.fromJson(v as Map<String, dynamic>)),
          ) ??
          {},
      sellOffers: (json['sellOffers'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, NpcSellOffer.fromJson(v as Map<String, dynamic>)),
          ) ??
          {},
      statusMessage: json['statusMessage'] as String? ?? 'İşlemler normal',
    );
  }
}
