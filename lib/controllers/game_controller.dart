import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/item.dart';
import '../models/market_item.dart';
import '../models/facility.dart';
import '../models/store.dart';
import '../models/market_listing.dart';
import '../models/market_offer.dart';

class GameController extends ChangeNotifier {
  // Finans (Sıfırdan Başlangıç Sermayesi)
  double cash = 10000.0;
  double bankSavings = 0.0;
  double activeLoan = 0.0;
  double maxWarehouseCapacity = 500.0; // 500 kg başlangıç deposu

  // Depo (Hammadde ve Ürünler - Tamamen Boş)
  final Map<String, int> warehouse = {};

  // Borsa ve Toptan Pazar
  final Map<String, MarketItem> marketItems = {};

  // Oyuncunun Pazardaki Kendi Fiyatıyla Açtığı Satış İlanları
  final List<MarketListing> activeListings = [];

  // Diğer Oyuncuların (Topluluk / Simülasyon) Pazar İlanları
  final List<MarketListing> communityListings = [];

  // Pazar Teklifleri (Gelen ve Verilen Teklifler)
  final List<MarketOffer> offers = [];

  // Anlık Bildirim / Toast Mesajı (Telefon ekranında uyarı göstermek için)
  String? latestNotificationToast;
  void clearNotificationToast() {
    latestNotificationToast = null;
  }

  // Rozet sayaçları
  int get pendingIncomingOffersCount =>
      offers.where((o) => o.direction == OfferDirection.incoming && o.status == OfferStatus.pending).length;
  int get acceptedOutgoingOffersCount =>
      offers.where((o) => o.direction == OfferDirection.outgoing && o.status == OfferStatus.accepted).length;
  int get totalActiveOffersBadge => pendingIncomingOffersCount + acceptedOutgoingOffersCount;

  // Mülkler (Sıfırdan Başlangıç: Tesis ve dükkan yok, oyuncu kendi seçecek)
  final List<ProductionFacility> ownedFacilities = [];
  final List<RetailStore> ownedStores = [];

  // Tema (Varsayılan Açık Tema, Butonla Değiştirilebilir)
  bool isDarkMode = false;

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    notifyListeners();
  }

  // Sayaçlar ve Simülasyon
  Timer? _gameLoopTimer;
  final Random _random = Random();
  double _marketTickTimer = 0.0;
  double _bankTickTimer = 0.0;
  double _statsHourlyRevenue = 0.0;
  double _communityRefreshTimer = 0.0;
  double _incomingOfferTimer = 0.0;

  static const List<String> _simulatedSellers = [
    'Anadolu Tahıl Ticaret',
    'Çukurova Pamuk Sanayi',
    'Ege Çiftlik Mandırası',
    'Boğaziçi Kahve & Gıda',
    'Marmara Un Değirmenleri',
    'Toros Meyvecilik A.Ş.',
    'Trakyalı Dokuma Ltd.',
    'Akdeniz Gurme Peynir',
    'Yeşil Vadi Çiftliği',
    'Başkent Toptan Gıda',
  ];

  GameController() {
    _initializeMarket();
    _initializeCommunityListings();
    _startGameLoop();
  }

  void _initializeMarket() {
    for (var item in ItemRegistry.getAll()) {
      marketItems[item.id] = MarketItem(
        itemId: item.id,
        currentPrice: item.basePrice,
      );
    }
  }

  void _initializeCommunityListings() {
    final allItems = ItemRegistry.getAll();
    for (int i = 0; i < 7; i++) {
      final item = allItems[_random.nextInt(allItems.length)];
      final mItem = marketItems[item.id];
      final base = mItem?.currentPrice ?? item.basePrice;
      // %90 ile %114 arası fiyat
      final priceMultiplier = 0.90 + _random.nextDouble() * 0.24;
      final price = double.parse((base * priceMultiplier).toStringAsFixed(2));
      final seller = _simulatedSellers[_random.nextInt(_simulatedSellers.length)];
      final qty = (_random.nextInt(6) + 3) * 5; // 15 - 40 adet

      communityListings.add(
        MarketListing(
          id: 'comm_${DateTime.now().millisecondsSinceEpoch}_$i',
          itemId: item.id,
          initialQuantity: qty,
          remainingQuantity: qty,
          pricePerUnit: price,
          listedAt: DateTime.now().subtract(Duration(minutes: _random.nextInt(60))),
          sellerName: seller,
          isPlayerListing: false,
        ),
      );
    }
  }

  void _startGameLoop() {
    const tickIntervalMs = 100; // 0.1 saniye
    const deltaSeconds = tickIntervalMs / 1000.0;

    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: tickIntervalMs), (_) {
      _tick(deltaSeconds);
    });
  }

  void _tick(double dt) {
    // 1. Tarlalar ve Fabrikalar
    for (var fac in ownedFacilities) {
      if (!fac.isProducing) continue;

      bool canProceed = true;
      fac.recipe.inputs.forEach((inItemId, inCount) {
        int inWarehouse = warehouse[inItemId] ?? 0;
        if (inWarehouse < inCount) {
          canProceed = false;
        }
      });

      if (!canProceed) {
        fac.statusMessage = 'Hammadde Bekleniyor';
        fac.progress = 0.0;
        continue;
      }

      fac.progress += dt / fac.effectiveDuration;
      fac.statusMessage = 'Üretiliyor (%${(fac.progress * 100).toInt()})';

      if (fac.progress >= 1.0) {
        fac.progress = 0.0;
        fac.recipe.inputs.forEach((inItemId, inCount) {
          warehouse[inItemId] = (warehouse[inItemId] ?? 0) - inCount;
          if (warehouse[inItemId]! <= 0) warehouse.remove(inItemId);
        });

        int outCount = fac.effectiveOutput;
        var outItemData = ItemRegistry.get(fac.recipe.outputItemId);
        double addedWeight = outCount * (outItemData?.weight ?? 1.0);

        if (currentWarehouseWeight + addedWeight <= maxWarehouseCapacity) {
          warehouse[fac.recipe.outputItemId] = (warehouse[fac.recipe.outputItemId] ?? 0) + outCount;
          fac.statusMessage = 'Hasat/Üretim Tamamlandı!';
        } else {
          fac.statusMessage = 'Depo Dolu! Ürün Bekliyor';
        }
      }
    }

    // 2. Perakende Mağazalar & Müşteri Satışları
    for (var store in ownedStores) {
      if (store.autoRestock && store.shelfStock < store.shelfCapacity) {
        int need = store.shelfCapacity - store.shelfStock;
        int inWh = warehouse[store.productItemId] ?? 0;
        if (inWh > 0) {
          int take = min(need, inWh);
          warehouse[store.productItemId] = inWh - take;
          if (warehouse[store.productItemId]! <= 0) {
            warehouse.remove(store.productItemId);
          }
          store.shelfStock += take;
        }
      }

      if (store.shelfStock <= 0) {
        store.statusMessage = 'Raf Boş! Ürün bekleniyor';
        store.timerProgress = 0.0;
        continue;
      }

      store.timerProgress += dt / store.effectiveInterval;
      if (store.timerProgress >= 1.0) {
        store.timerProgress = 0.0;
        store.shelfStock--;
        cash += store.retailPrice;
        store.totalRevenue += store.retailPrice;
        _statsHourlyRevenue += store.retailPrice;
        store.statusMessage = 'Satıldı! (+${store.retailPrice.toStringAsFixed(0)} ₺)';
      }
    }

    // 3. Pazardaki Oyuncu İlanlarının Satışı (Sistem / Müşteriler satın alır)
    for (int i = activeListings.length - 1; i >= 0; i--) {
      final listing = activeListings[i];
      if (listing.isCompleted) {
        activeListings.removeAt(i);
        continue;
      }

      final mItem = marketItems[listing.itemId];
      if (mItem == null) continue;

      double priceRatio = mItem.currentPrice / listing.pricePerUnit;
      double speedFactor = (priceRatio * priceRatio).clamp(0.12, 3.5);
      double interval = 4.0 / speedFactor;

      listing.saleProgressTimer += dt / interval;
      if (listing.saleProgressTimer >= 1.0) {
        listing.saleProgressTimer = 0.0;
        int batch = min(listing.remainingQuantity, max(1, (priceRatio * 2.5).round()));
        listing.remainingQuantity -= batch;
        double earn = batch * listing.pricePerUnit;
        cash += earn;
        listing.totalEarned += earn;

        if (listing.isCompleted) {
          activeListings.removeAt(i);
        }
      }
    }

    // 4. Verilen Tekliflerin Değerlendirilmesi (Simüle Satıcılar Teklifi İnceler)
    for (var offer in offers) {
      if (offer.direction == OfferDirection.outgoing && offer.status == OfferStatus.pending) {
        offer.decisionTimer += dt;
        if (offer.decisionTimer >= 3.5) { // 3.5 saniye sonra karar
          offer.decisionTimer = 0.0;
          double ratio = offer.offeredPricePerUnit / offer.originalPricePerUnit;
          // %85 ve üstü ise veya piyasaya yakınsa kabul şansı yüksek
          bool accepted = ratio >= 0.85 || (_random.nextDouble() < (ratio * ratio * 0.95));
          if (accepted) {
            offer.status = OfferStatus.accepted;
            latestNotificationToast =
                '🔔 TEKLİFİNİZ ONAYLANDI! "${offer.sellerName}", ${offer.quantity} adet ${offer.item.name} teklifinizi (${offer.offeredPricePerUnit.toStringAsFixed(2)} ₺) kabul etti! Teklifler sekmesinden satın alabilirsiniz.';
          } else {
            offer.status = OfferStatus.rejected;
            latestNotificationToast =
                '❌ TEKLİF REDDEDİLDİ: "${offer.sellerName}", ${offer.quantity} adet ${offer.item.name} için verdiğiniz teklifi çok düşük buldu.';
          }
          notifyListeners();
        }
      }
    }

    // 5. Oyuncunun İlanlarına Gelen Yeni Teklifler (Simüle Alıcılar Teklif Verir)
    if (activeListings.isNotEmpty) {
      _incomingOfferTimer += dt;
      if (_incomingOfferTimer >= 22.0) {
        _incomingOfferTimer = 0.0;
        final candidateListings = activeListings.where((l) => l.remainingQuantity > 0).toList();
        if (candidateListings.isNotEmpty) {
          final target = candidateListings[_random.nextInt(candidateListings.length)];
          bool hasPending = offers.any((o) => o.listingId == target.id && o.status == OfferStatus.pending);
          if (!hasPending) {
            final buyerPool = [
              'Ahmet Usta Fırıncılık',
              'Güven Toptancılık',
              'Marmara Gurme Restoran',
              'Yıldız Otel & Gıda',
              'Sultanbeyli Çiftliği',
              'Akdeniz Dağıtım',
              'Boğaziçi Marketler',
            ];
            final buyer = buyerPool[_random.nextInt(buyerPool.length)];
            int qty = min(target.remainingQuantity, max(5, (_random.nextInt(3) + 1) * 5));
            double ratio = 0.88 + _random.nextDouble() * 0.14; // %88 - %102 arası
            double offeredUnit = double.parse((target.pricePerUnit * ratio).toStringAsFixed(2));

            final incOffer = MarketOffer(
              id: 'inc_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(999)}',
              listingId: target.id,
              itemId: target.itemId,
              buyerName: buyer,
              sellerName: 'Siz',
              quantity: qty,
              originalPricePerUnit: target.pricePerUnit,
              offeredPricePerUnit: offeredUnit,
              direction: OfferDirection.incoming,
              status: OfferStatus.pending,
              createdAt: DateTime.now(),
              message: '$qty adet için birim başı $offeredUnit ₺ teklif ediyorum, uygun mudur?',
            );
            offers.insert(0, incOffer);
            latestNotificationToast =
                '📩 YENİ TEKLİF GELDİ! $buyer, ${target.item.name} ilanınıza birim başı $offeredUnit ₺ teklif etti. Teklifler sekmesinden inceleyin.';
            notifyListeners();
          }
        }
      }
    }

    // 6. Topluluk Pazarının Canlılığı (İlan Yenileme)
    _communityRefreshTimer += dt;
    if (_communityRefreshTimer >= 18.0) {
      _communityRefreshTimer = 0.0;
      if (communityListings.length < 10) {
        final allItems = ItemRegistry.getAll();
        final item = allItems[_random.nextInt(allItems.length)];
        final mItem = marketItems[item.id];
        final base = mItem?.currentPrice ?? item.basePrice;
        final priceMultiplier = 0.90 + _random.nextDouble() * 0.22;
        final price = double.parse((base * priceMultiplier).toStringAsFixed(2));
        final seller = _simulatedSellers[_random.nextInt(_simulatedSellers.length)];
        final qty = (_random.nextInt(5) + 2) * 5;

        communityListings.add(
          MarketListing(
            id: 'comm_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(99)}',
            itemId: item.id,
            initialQuantity: qty,
            remainingQuantity: qty,
            pricePerUnit: price,
            listedAt: DateTime.now(),
            sellerName: seller,
            isPlayerListing: false,
          ),
        );
      }
    }

    // 7. Borsa Fiyat Dalgalanması (Her 15 saniyede bir)
    _marketTickTimer += dt;
    if (_marketTickTimer >= 15.0) {
      _marketTickTimer = 0.0;
      for (var item in marketItems.values) {
        item.updatePrice(rnd: _random);
      }
    }

    // 8. Banka Faiz Döngüsü (Her 60 saniyede bir)
    _bankTickTimer += dt;
    if (_bankTickTimer >= 60.0) {
      _bankTickTimer = 0.0;
      if (bankSavings > 0) {
        bankSavings += bankSavings * 0.005; // %0.5 faiz
      }
      if (activeLoan > 0) {
        activeLoan += activeLoan * 0.012; // %1.2 kredi faizi
      }
    }

    notifyListeners();
  }

  // === DEPONUN AĞIRLIĞI VE HESAPLAR ===
  double get statsHourlyRevenue => _statsHourlyRevenue;

  double get currentWarehouseWeight {
    double total = 0.0;
    warehouse.forEach((itemId, count) {
      var it = ItemRegistry.get(itemId);
      if (it != null) {
        total += count * it.weight;
      }
    });
    return total;
  }

  double get netWorth {
    double total = cash + bankSavings - activeLoan;

    // Depodaki ürünlerin borsa değeri
    warehouse.forEach((itemId, count) {
      var m = marketItems[itemId];
      if (m != null) {
        total += m.wholesaleSellPrice * count;
      }
    });

    // Pazardaki aktif satış ilanlarının değeri
    for (var l in activeListings) {
      total += l.remainingQuantity * l.pricePerUnit;
    }

    // Mülklerin satın alma değerleri
    for (var f in ownedFacilities) {
      total += f.purchaseCost;
    }
    for (var s in ownedStores) {
      total += s.purchaseCost;
    }

    return total;
  }

  // === PAZAR İŞLEMLERİ (AL - SAT) ===
  String? buyFromMarket(String itemId, int qty) {
    if (qty <= 0) return 'Geçersiz miktar.';
    var mItem = marketItems[itemId];
    var data = ItemRegistry.get(itemId);
    if (mItem == null || data == null) return 'Ürün bulunamadı.';

    double totalCost = mItem.wholesaleBuyPrice * qty;
    if (cash < totalCost) {
      return 'Yetersiz nakit! (${totalCost.toStringAsFixed(0)} ₺ gerekiyor)';
    }

    double weightNeeded = qty * data.weight;
    if (currentWarehouseWeight + weightNeeded > maxWarehouseCapacity) {
      return 'Depoda yeterli alan yok!';
    }

    cash -= totalCost;
    warehouse[itemId] = (warehouse[itemId] ?? 0) + qty;
    mItem.updatePrice(bias: 0.02, rnd: _random);
    notifyListeners();
    return null;
  }

  String? sellToMarket(String itemId, int qty) {
    if (qty <= 0) return 'Geçersiz miktar.';
    var mItem = marketItems[itemId];
    var data = ItemRegistry.get(itemId);
    if (mItem == null || data == null) return 'Ürün bulunamadı.';

    int currentStock = warehouse[itemId] ?? 0;
    if (currentStock < qty) {
      return 'Depoda yeterli $qty adet ${data.name} yok!';
    }

    double totalEarnings = mItem.quickSellPrice * qty;
    warehouse[itemId] = currentStock - qty;
    if (warehouse[itemId]! <= 0) warehouse.remove(itemId);

    cash += totalEarnings;
    mItem.updatePrice(bias: -0.02, rnd: _random);
    notifyListeners();
    return null;
  }

  // === DİĞER OYUNCULARDAN ÜRÜN SATIN ALMA (TOPLULUK PAZARI) ===
  String? buyFromCommunityListing(MarketListing listing, int qty) {
    if (qty <= 0) return 'Geçersiz miktar.';
    if (listing.remainingQuantity < qty) return 'Bu ilanda yeterli stok kalmadı.';
    double totalCost = listing.pricePerUnit * qty;
    if (cash < totalCost) {
      return 'Yetersiz nakit! (${totalCost.toStringAsFixed(0)} ₺ gerekiyor)';
    }
    double weightNeeded = qty * listing.item.weight;
    if (currentWarehouseWeight + weightNeeded > maxWarehouseCapacity) {
      return 'Deponuzda yeterli yer yok! Depoyu genişletin.';
    }

    cash -= totalCost;
    warehouse[listing.itemId] = (warehouse[listing.itemId] ?? 0) + qty;
    listing.remainingQuantity -= qty;
    if (listing.remainingQuantity <= 0) {
      communityListings.remove(listing);
    }
    notifyListeners();
    return null;
  }

  // === DİĞER OYUNCUNUN İLANINA TEKLİF VERME (PAZARLIK) ===
  String? makeOfferOnListing(
    MarketListing listing,
    int qty,
    double offeredPricePerUnit, {
    String message = 'Şu fiyata olur mu?',
  }) {
    if (qty <= 0) return 'Geçersiz miktar.';
    if (qty > listing.remainingQuantity) {
      return 'İlandaki mevcut miktardan (${listing.remainingQuantity}) fazla teklif veremezsiniz.';
    }
    if (offeredPricePerUnit <= 0) return 'Lütfen geçerli bir birim fiyat girin.';
    double totalOffer = qty * offeredPricePerUnit;
    if (cash < totalOffer) {
      return 'Bu teklifi satın alabilmek için kasanızda en az ${totalOffer.toStringAsFixed(0)} ₺ olmalıdır.';
    }

    final offer = MarketOffer(
      id: 'off_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(999)}',
      listingId: listing.id,
      itemId: listing.itemId,
      buyerName: 'Siz',
      sellerName: listing.sellerName,
      quantity: qty,
      originalPricePerUnit: listing.pricePerUnit,
      offeredPricePerUnit: double.parse(offeredPricePerUnit.toStringAsFixed(2)),
      direction: OfferDirection.outgoing,
      status: OfferStatus.pending,
      createdAt: DateTime.now(),
      message: message,
    );

    offers.insert(0, offer);
    notifyListeners();
    return null;
  }

  // === ONAYLANAN VERİLEN TEKLİFİ SATIN ALMA ===
  String? buyAcceptedOffer(MarketOffer offer) {
    if (offer.status != OfferStatus.accepted) return 'Bu teklif şu an satın alınamaz durumda.';
    double totalCost = offer.totalOfferedPrice;
    if (cash < totalCost) return 'Yetersiz nakit! (${totalCost.toStringAsFixed(0)} ₺ gerekiyor)';
    double weightNeeded = offer.quantity * offer.item.weight;
    if (currentWarehouseWeight + weightNeeded > maxWarehouseCapacity) {
      return 'Depoda yeterli yer yok! Depoyu genişletin.';
    }

    cash -= totalCost;
    warehouse[offer.itemId] = (warehouse[offer.itemId] ?? 0) + offer.quantity;
    offer.status = OfferStatus.completed;

    // İlgili ilanın stokunu da düş
    final target = communityListings.where((l) => l.id == offer.listingId).firstOrNull;
    if (target != null) {
      target.remainingQuantity -= offer.quantity;
      if (target.remainingQuantity <= 0) {
        communityListings.remove(target);
      }
    }
    notifyListeners();
    return null;
  }

  // === OYUNCUNUN KENDİ İLANINA GELEN TEKLİFİ ONAYLAMA & REDDETME ===
  String? acceptIncomingOffer(MarketOffer offer) {
    if (offer.status != OfferStatus.pending) return 'Bu teklif artık geçerli değil.';
    final listing = activeListings.where((l) => l.id == offer.listingId).firstOrNull;
    if (listing == null || listing.remainingQuantity < offer.quantity) {
      offer.status = OfferStatus.rejected;
      notifyListeners();
      return 'İlanınızda bu miktarda ürün kalmamış.';
    }

    listing.remainingQuantity -= offer.quantity;
    double earnings = offer.totalOfferedPrice;
    cash += earnings;
    listing.totalEarned += earnings;
    offer.status = OfferStatus.completed;

    if (listing.isCompleted) {
      activeListings.remove(listing);
    }
    notifyListeners();
    return null;
  }

  void rejectIncomingOffer(MarketOffer offer) {
    offer.status = OfferStatus.rejected;
    notifyListeners();
  }

  // === KENDİ BELİRLEDİĞİN FİYATLA PAZARA İLAN KOYMA ===
  String? createListing(String itemId, int qty, double pricePerUnit) {
    if (qty <= 0) return 'Geçersiz miktar.';
    if (pricePerUnit <= 0) return 'Fiyat sıfırdan büyük olmalıdır.';

    var data = ItemRegistry.get(itemId);
    if (data == null) return 'Ürün bulunamadı.';

    int currentStock = warehouse[itemId] ?? 0;
    if (currentStock < qty) {
      return 'Deponuzda bu miktarda ${data.name} yok! (Mevcut: $currentStock)';
    }

    warehouse[itemId] = currentStock - qty;
    if (warehouse[itemId]! <= 0) warehouse.remove(itemId);

    final listing = MarketListing(
      id: 'list_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}',
      itemId: itemId,
      initialQuantity: qty,
      remainingQuantity: qty,
      pricePerUnit: double.parse(pricePerUnit.toStringAsFixed(2)),
      listedAt: DateTime.now(),
      sellerName: 'Siz',
      isPlayerListing: true,
    );

    activeListings.add(listing);
    notifyListeners();
    return null;
  }

  String? cancelListing(MarketListing listing) {
    if (listing.remainingQuantity > 0) {
      var data = listing.item;
      double neededWeight = listing.remainingQuantity * data.weight;
      if (currentWarehouseWeight + neededWeight > maxWarehouseCapacity) {
        return 'Deponuzda kalan ürünleri geri alacak yeterli yer yok! Depoyu büyütün.';
      }

      warehouse[listing.itemId] = (warehouse[listing.itemId] ?? 0) + listing.remainingQuantity;
    }

    activeListings.remove(listing);
    notifyListeners();
    return null;
  }

  // === MÜLK SATIN ALMA & GELİŞTİRME ===
  String? buyFacility(ProductionFacility bp) {
    if (cash < bp.purchaseCost) {
      return 'Yetersiz nakit! (${bp.purchaseCost.toStringAsFixed(0)} ₺ gerekiyor)';
    }

    cash -= bp.purchaseCost;
    ownedFacilities.add(bp.copy());
    notifyListeners();
    return null;
  }

  String? upgradeFacility(ProductionFacility fac) {
    double cost = fac.upgradeCost;
    if (cash < cost) {
      return 'Yetersiz bakiye! (${cost.toStringAsFixed(0)} ₺ gerekiyor)';
    }

    cash -= cost;
    fac.level++;
    notifyListeners();
    return null;
  }

  String? buyStore(RetailStore bp) {
    if (cash < bp.purchaseCost) {
      return 'Yetersiz nakit! (${bp.purchaseCost.toStringAsFixed(0)} ₺ gerekiyor)';
    }

    cash -= bp.purchaseCost;
    ownedStores.add(bp.copy());
    notifyListeners();
    return null;
  }

  String? upgradeStore(RetailStore store) {
    double cost = store.upgradeCost;
    if (cash < cost) {
      return 'Yetersiz bakiye! (${cost.toStringAsFixed(0)} ₺ gerekiyor)';
    }

    cash -= cost;
    store.level++;
    store.shelfCapacity += 25;
    notifyListeners();
    return null;
  }

  void toggleStoreAutoRestock(RetailStore store, bool val) {
    store.autoRestock = val;
    notifyListeners();
  }

  // === BANKA İŞLEMLERİ ===
  String? depositToBank(double amount) {
    if (amount <= 0 || cash < amount) return 'Yetersiz nakit.';
    cash -= amount;
    bankSavings += amount;
    notifyListeners();
    return null;
  }

  String? withdrawFromBank(double amount) {
    if (amount <= 0 || bankSavings < amount) return 'Hesapta yeterli para yok.';
    bankSavings -= amount;
    cash += amount;
    notifyListeners();
    return null;
  }

  String? takeLoan(double amount) {
    double maxAllowed = max(20000.0, netWorth * 0.4);
    if (activeLoan + amount > maxAllowed) {
      return 'Kredi limitiniz aşıldı! Maksimum limit: ${maxAllowed.toStringAsFixed(0)} ₺';
    }
    activeLoan += amount;
    cash += amount;
    notifyListeners();
    return null;
  }

  String? repayLoan(double amount) {
    if (amount <= 0 || activeLoan <= 0) return 'Ödenecek aktif kredi yok.';
    double pay = min(amount, activeLoan);
    if (cash < pay) return 'Yetersiz nakit.';
    cash -= pay;
    activeLoan -= pay;
    notifyListeners();
    return null;
  }

  // === DEPO BÜYÜTME ===
  String? expandWarehouse() {
    double cost = maxWarehouseCapacity * 5.0; // Her kg kapasite için 5 TL
    if (cash < cost) return 'Yetersiz nakit! (${cost.toStringAsFixed(0)} ₺ gerekiyor)';

    cash -= cost;
    maxWarehouseCapacity += 500; // +500 kg kapasite
    notifyListeners();
    return null;
  }

  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    super.dispose();
  }
}
