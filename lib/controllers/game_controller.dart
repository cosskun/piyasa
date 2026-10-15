import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/item.dart';
import '../models/market_item.dart';
import '../models/facility.dart';
import '../models/store.dart';
import '../models/market_listing.dart';
import '../models/market_offer.dart';
import '../models/bank_loan.dart';
import '../models/limit_order.dart';
import '../services/notification_service.dart';
import '../services/save_service.dart';

class GameController extends ChangeNotifier {
  // Finans (Sıfırdan Başlangıç Sermayesi - Çoklu Tesis Alımına Uygun)
  double cash = 30000.0;
  double bankSavings = 0.0;
  double _legacyActiveLoan = 0.0;
  BankLoan? currentLoan;
  double get activeLoan => currentLoan?.remainingTotal ?? _legacyActiveLoan;
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

  // Borsa Limit Alış Emirleri (Fiyat Düşünce Otomatik Alım)
  final List<LimitBuyOrder> limitBuyOrders = [];
  int get pendingOrdersCount => limitBuyOrders.where((o) => o.isPending).length;

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
    saveState();
  }

  // Sayaçlar ve Simülasyon
  Timer? _gameLoopTimer;
  final Random _random = Random();
  double _marketTickTimer = 0.0;
  double _bankTickTimer = 0.0;
  double _statsHourlyRevenue = 0.0;
  double _communityRefreshTimer = 0.0;
  double _incomingOfferTimer = 0.0;
  double _autoSaveTickTimer = 0.0;

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
    'Adapazarı Patates Birliği',
    'Pelit Artisan Çikolata',
    'Karadeniz Orman & Kereste',
    'İnegöl Masif Mobilya',
    'Ergani Madencilik A.Ş.',
    'İskenderun Demir-Çelik',
    'Tüpraş Rafineri & Polimer',
    'Aselsan Mikro Elektronik',
  ];

  GameController({bool autoLoad = false}) {
    _initializeMarket();
    _initializeCommunityListings();
    _startGameLoop();
    if (autoLoad) {
      loadFromStorage();
    }
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

  void tickForTesting(double dt) => _tick(dt);

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

        // Teklif gelmiş olsa dahi ürünler rezerve ayrılmadan açık pazarda normal fiyattan satılır.
        // İlandaki kalan stok teklif miktarının altına düşerse teklif otomatik düşer.
        for (var off in offers) {
          if (off.direction == OfferDirection.incoming &&
              off.listingId == listing.id &&
              off.status == OfferStatus.pending) {
            if (listing.remainingQuantity < off.quantity) {
              off.status = OfferStatus.expired;
              latestNotificationToast =
                  '🏷️ ${listing.item.name} ilanınızdaki ürünler normal fiyattan (${listing.pricePerUnit.toStringAsFixed(2)} ₺) satıldı! ${off.buyerName} teklifi otomatik kapandı.';
            }
          }
        }

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
            NotificationService().showOfferDecisionNotification(
              sellerName: offer.sellerName,
              itemName: offer.item.name,
              quantity: offer.quantity,
              price: offer.offeredPricePerUnit,
              accepted: true,
            );
          } else {
            offer.status = OfferStatus.rejected;
            latestNotificationToast =
                '❌ TEKLİF REDDEDİLDİ: "${offer.sellerName}", ${offer.quantity} adet ${offer.item.name} için verdiğiniz teklifi çok düşük buldu.';
            NotificationService().showOfferDecisionNotification(
              sellerName: offer.sellerName,
              itemName: offer.item.name,
              quantity: offer.quantity,
              price: offer.offeredPricePerUnit,
              accepted: false,
            );
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
            NotificationService().showIncomingOfferNotification(
              buyerName: buyer,
              itemName: target.item.name,
              quantity: qty,
              price: offeredUnit,
            );
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
      _checkLimitBuyOrders();
    }

    // 8. Banka Faiz & Kredi Taksit Döngüsü
    _bankTickTimer += dt;
    if (_bankTickTimer >= 60.0) {
      _bankTickTimer = 0.0;
      if (bankSavings > 0) {
        bankSavings += bankSavings * 0.005; // %0.5 mevduat getirisi
      }
      if (_legacyActiveLoan > 0) {
        _legacyActiveLoan += _legacyActiveLoan * 0.012;
      }
    }

    // Aktif Kredi Günlük Taksit Döngüsü
    if (currentLoan != null && !currentLoan!.isFullyPaid) {
      currentLoan!.nextInstallmentTimer += dt;
      if (currentLoan!.nextInstallmentTimer >= BankLoan.installmentInterval) {
        currentLoan!.nextInstallmentTimer = 0.0;
        final nextIdx = currentLoan!.paidInstallments;
        if (nextIdx < currentLoan!.schedule.length) {
          final installment = currentLoan!.schedule[nextIdx];
          if (cash >= installment.totalAmount) {
            cash -= installment.totalAmount;
            installment.isPaid = true;
            currentLoan!.paidInstallments++;
            currentLoan!.remainingPrincipal = max(0.0, currentLoan!.remainingPrincipal - installment.principalAmount);
            currentLoan!.remainingInterest = max(0.0, currentLoan!.remainingInterest - installment.interestAmount);

            if (currentLoan!.isFullyPaid) {
              latestNotificationToast =
                  '🎉 TEBRİKLER! ${currentLoan!.title} kredisinin tüm taksitleri ödendi ve borç kapandı!';
              currentLoan = null;
            } else {
              latestNotificationToast =
                  '💳 BANKA: ${currentLoan!.title} kredisinin ${currentLoan!.paidInstallments}. gün taksiti (${installment.totalAmount.toStringAsFixed(0)} ₺) kasadan otomatik ödendi.';
            }
            notifyListeners();
          } else {
            latestNotificationToast =
                '⚠️ BANKA UYARISI: Kasada yetersiz bakiye (${installment.totalAmount.toStringAsFixed(0)} ₺ gerekiyor) nedeniyle kredi taksiti ödenemedi!';
            notifyListeners();
          }
        }
      }
    }

    _autoSaveTickTimer += dt;
    if (_autoSaveTickTimer >= 3.0) {
      _autoSaveTickTimer = 0.0;
      saveState();
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

    // Mülklerin yatırım değerleri
    for (var f in ownedFacilities) {
      total += f.totalInvestedValue;
    }
    for (var s in ownedStores) {
      total += s.totalInvestedValue;
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
    saveState();
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
    saveState();
    return null;
  }

  // === BORSA LİMİT ALIŞ EMİRLERİ (FİYAT DÜŞÜNCE OTOMATİK ALIM) ===
  String? placeLimitBuyOrder({
    required String itemId,
    required double targetPrice,
    required int quantity,
  }) {
    if (quantity <= 0) return 'Lütfen geçerli bir miktar girin.';
    if (targetPrice <= 0) return 'Lütfen 0\'dan büyük bir hedef fiyat girin.';

    final mItem = marketItems[itemId];
    if (mItem == null) return 'Ürün borsada bulunamadı.';

    if (targetPrice >= mItem.currentPrice) {
      return 'Hedef fiyat, anlık borsa fiyatından (${mItem.currentPrice.toStringAsFixed(2)} ₺) daha düşük olmalıdır. '
          'Hemen almak için "Hızlı Al" butonunu kullanabilirsiniz.';
    }

    final totalCost = targetPrice * quantity;
    if (cash < totalCost) {
      return 'Yetersiz nakit! Bu alış emrinin teminatı için ${totalCost.toStringAsFixed(0)} ₺ gereklidir.';
    }

    final itemData = ItemRegistry.get(itemId);
    if (itemData == null) return 'Ürün bulunamadı.';

    final weightNeeded = quantity * itemData.weight;
    if (currentWarehouseWeight + weightNeeded > maxWarehouseCapacity) {
      return 'Deponuzda bu sipariş için (${weightNeeded.toStringAsFixed(0)} kg) yeterli yer yok! Depoyu genişletin.';
    }

    // Karşılıksız emir verilmesini önlemek için tutar bloke edilir
    cash -= totalCost;

    final order = LimitBuyOrder(
      id: 'ord_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(999)}',
      itemId: itemId,
      targetPrice: double.parse(targetPrice.toStringAsFixed(2)),
      quantity: quantity,
      totalReservedCost: totalCost,
      createdAt: DateTime.now(),
      status: LimitOrderStatus.pending,
    );

    limitBuyOrders.insert(0, order);
    notifyListeners();
    saveState();
    return null;
  }

  String? cancelLimitBuyOrder(LimitBuyOrder order) {
    if (!order.isPending) return 'Bu emir artık iptal edilemez.';

    // Bloke edilen teminat iade edilir
    cash += order.totalReservedCost;
    order.status = LimitOrderStatus.cancelled;
    order.statusMessage = 'İptal edildi.';
    notifyListeners();
    saveState();
    return null;
  }

  void _checkLimitBuyOrders() {
    bool hasChanges = false;
    for (var order in limitBuyOrders) {
      if (!order.isPending) continue;

      final mItem = marketItems[order.itemId];
      if (mItem == null) continue;

      // Fiyat hedeflenen seviyeye veya daha altına düştü mü?
      if (mItem.currentPrice <= order.targetPrice) {
        final itemData = ItemRegistry.get(order.itemId);
        if (itemData == null) continue;

        final weightNeeded = order.quantity * itemData.weight;
        if (currentWarehouseWeight + weightNeeded <= maxWarehouseCapacity) {
          final actualPrice = mItem.currentPrice;
          final actualTotalCost = actualPrice * order.quantity;

          // Fiyat iyileştirmesi: Eğer piyasa hedeften de aşağı düşmüşse aradaki fark oyuncuya kalır!
          final refund = order.totalReservedCost - actualTotalCost;
          if (refund > 0) {
            cash += refund;
          }

          warehouse[order.itemId] = (warehouse[order.itemId] ?? 0) + order.quantity;
          order.status = LimitOrderStatus.completed;
          order.executedAt = DateTime.now();
          order.executedPrice = actualPrice;
          order.statusMessage = 'İcra Edildi: ${actualPrice.toStringAsFixed(2)} ₺';

          latestNotificationToast =
              '🎯 ALIŞ EMRİ GERÇEKLEŞTİ! ${order.quantity} adet ${itemData.name}, '
              'hedeflediğiniz ${order.targetPrice.toStringAsFixed(2)} ₺ fiyattan (${actualPrice.toStringAsFixed(2)} ₺) '
              'otomatik satın alındı ve deponuza yüklendi!';
          NotificationService().showLimitOrderExecutedNotification(
            itemName: itemData.name,
            quantity: order.quantity,
            price: actualPrice,
          );
          hasChanges = true;
        } else {
          order.statusMessage = 'Depo Dolu! Yer açıldığında alınacak.';
        }
      }
    }
    if (hasChanges) {
      notifyListeners();
    }
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
    saveState();
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
    saveState();
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
    saveState();
    return null;
  }

  // === OYUNCUNUN KENDİ İLANINA GELEN TEKLİFİ ONAYLAMA & REDDETME ===
  String? acceptIncomingOffer(MarketOffer offer) {
    if (offer.status == OfferStatus.expired) {
      return 'İlanınızdaki ürünler pazarda tam fiyattan satıldığı için bu teklif artık geçerli değil.';
    }
    if (offer.status != OfferStatus.pending) return 'Bu teklif artık geçerli değil.';
    final listing = activeListings.where((l) => l.id == offer.listingId).firstOrNull;
    if (listing == null || listing.remainingQuantity < offer.quantity) {
      offer.status = OfferStatus.expired;
      notifyListeners();
      saveState();
      return 'İlanınızdaki ürünler pazarda tam fiyattan satıldığı için bu teklif otomatik olarak kapandı.';
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
    saveState();
    return null;
  }

  void rejectIncomingOffer(MarketOffer offer) {
    offer.status = OfferStatus.rejected;
    notifyListeners();
    saveState();
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
    saveState();
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

    // İlan iptal edilirse bekleyen teklifler de düşer
    for (var off in offers) {
      if (off.direction == OfferDirection.incoming &&
          off.listingId == listing.id &&
          off.status == OfferStatus.pending) {
        off.status = OfferStatus.expired;
      }
    }

    activeListings.remove(listing);
    notifyListeners();
    saveState();
    return null;
  }

  // === MÜLK SATIN ALMA & GELİŞTİRME ===
  String? buyFacility(ProductionFacility bp, {int quantity = 1}) {
    if (quantity <= 0) return 'Geçersiz miktar.';
    final totalCost = bp.purchaseCost * quantity;
    if (cash < totalCost) {
      return 'Yetersiz nakit! (${totalCost.toStringAsFixed(0)} ₺ gerekiyor)';
    }

    cash -= totalCost;
    for (int i = 0; i < quantity; i++) {
      ownedFacilities.add(bp.copy());
    }
    notifyListeners();
    saveState();
    return null;
  }

  String? buyStarterPackage({
    required String packageName,
    required List<MapEntry<ProductionFacility, int>> facilities,
  }) {
    double totalCost = 0;
    for (final entry in facilities) {
      totalCost += entry.key.purchaseCost * entry.value;
    }
    if (cash < totalCost) {
      return 'Yetersiz nakit! (${totalCost.toStringAsFixed(0)} ₺ gerekiyor)';
    }

    cash -= totalCost;
    for (final entry in facilities) {
      for (int i = 0; i < entry.value; i++) {
        ownedFacilities.add(entry.key.copy());
      }
    }
    latestNotificationToast = '🎉 $packageName başarıyla kuruldu! Tesisleriniz üretime başladı.';
    notifyListeners();
    saveState();
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
    saveState();
    return null;
  }

  // === TESİS GERİ SATMA (LİKİDASYON) ===
  String? sellFacility(ProductionFacility fac) {
    if (!ownedFacilities.contains(fac)) {
      return 'Tesis bulunamadı.';
    }

    final refund = fac.resaleValue;
    ownedFacilities.remove(fac);
    cash += refund;
    latestNotificationToast = '💰 ${fac.emoji} ${fac.name} satıldı ve ${refund.toStringAsFixed(0)} ₺ nakite dönüştürüldü.';
    notifyListeners();
    saveState();
    return null;
  }

  String? buyStore(RetailStore bp) {
    if (cash < bp.purchaseCost) {
      return 'Yetersiz nakit! (${bp.purchaseCost.toStringAsFixed(0)} ₺ gerekiyor)';
    }

    cash -= bp.purchaseCost;
    ownedStores.add(bp.copy());
    notifyListeners();
    saveState();
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
    saveState();
    return null;
  }

  // === DÜKKAN GERİ SATMA / DEVRETME (LİKİDASYON) ===
  String? sellStore(RetailStore store) {
    if (!ownedStores.contains(store)) {
      return 'Dükkan bulunamadı.';
    }

    final refund = store.resaleValue;
    int returnedToWarehouse = 0;
    int liquidatedStock = 0;
    double liquidatedEarnings = 0.0;

    if (store.shelfStock > 0) {
      final item = ItemRegistry.get(store.productItemId);
      final weightPerItem = item?.weight ?? 1.0;
      final spaceLeft = max(0.0, maxWarehouseCapacity - currentWarehouseWeight);
      final canFit = (spaceLeft / weightPerItem).floor();

      returnedToWarehouse = min(store.shelfStock, canFit);
      liquidatedStock = store.shelfStock - returnedToWarehouse;

      if (returnedToWarehouse > 0) {
        warehouse[store.productItemId] = (warehouse[store.productItemId] ?? 0) + returnedToWarehouse;
      }

      if (liquidatedStock > 0) {
        final mItem = marketItems[store.productItemId];
        final unitPrice = mItem?.quickSellPrice ?? (item?.basePrice ?? 1.0) * 0.8;
        liquidatedEarnings = liquidatedStock * unitPrice;
        cash += liquidatedEarnings;
      }
    }

    ownedStores.remove(store);
    cash += refund;

    String detail = '🏪 ${store.emoji} ${store.name} devredildi ve ${refund.toStringAsFixed(0)} ₺ nakit alındı.';
    if (returnedToWarehouse > 0) {
      detail += ' Raftaki $returnedToWarehouse ürün depoya aktarıldı.';
    }
    if (liquidatedStock > 0) {
      detail += ' Depoya sığmayan $liquidatedStock ürün ${liquidatedEarnings.toStringAsFixed(0)} ₺ karşılığı toptan satıldı.';
    }
    latestNotificationToast = detail;
    notifyListeners();
    saveState();
    return null;
  }

  void toggleStoreAutoRestock(RetailStore store, bool val) {
    store.autoRestock = val;
    notifyListeners();
    saveState();
  }

  // === BANKA İŞLEMLERİ ===
  String? depositToBank(double amount) {
    if (amount <= 0 || cash < amount) return 'Yetersiz nakit.';
    cash -= amount;
    bankSavings += amount;
    notifyListeners();
    saveState();
    return null;
  }

  String? withdrawFromBank(double amount) {
    if (amount <= 0 || bankSavings < amount) return 'Hesapta yeterli para yok.';
    bankSavings -= amount;
    cash += amount;
    notifyListeners();
    saveState();
    return null;
  }

  double get maxLoanLimit => max(25000.0, netWorth * 0.45);

  double getInterestRateForAmount(double amount) {
    if (amount <= 20000) return 0.008; // %0.8 faiz
    if (amount <= 60000) return 0.012; // %1.2 faiz
    return 0.016; // %1.6 faiz
  }

  String? takeDetailedLoan({
    required double principal,
    required int installments,
    String? title,
  }) {
    if (principal <= 0) return 'Geçersiz kredi tutarı.';
    if (currentLoan != null && !currentLoan!.isFullyPaid) {
      return 'Zaten aktif bir krediniz bulunmaktadır. Yeni kredi çekmek için mevcut borcunuzu kapatmalısınız.';
    }
    if (principal > maxLoanLimit) {
      return 'Kredi limitiniz aşıldı! Maksimum limit: ${maxLoanLimit.toStringAsFixed(0)} ₺';
    }

    final rate = getInterestRateForAmount(principal);
    final schedule = BankLoan.generateSchedule(
      principal: principal,
      interestRatePerPeriod: rate,
      installments: installments,
    );
    final totalInterest = principal * rate * installments;

    currentLoan = BankLoan(
      id: 'loan_${DateTime.now().millisecondsSinceEpoch}',
      title: title ??
          (principal <= 20000
              ? 'Mikro İşletme Kredisi'
              : (principal <= 60000 ? 'KOBİ Büyüme Kredisi' : 'Sanayi Yatırım Kredisi')),
      principal: principal,
      interestRate: rate,
      totalInstallments: installments,
      remainingPrincipal: principal,
      remainingInterest: totalInterest,
      takenAt: DateTime.now(),
      schedule: schedule,
    );

    cash += principal;
    notifyListeners();
    saveState();
    return null;
  }

  String? payLoanInstallment() {
    if (currentLoan == null || currentLoan!.isFullyPaid) return 'Ödenecek aktif kredi yok.';
    final nextIdx = currentLoan!.paidInstallments;
    if (nextIdx >= currentLoan!.schedule.length) {
      currentLoan = null;
      notifyListeners();
      saveState();
      return null;
    }

    final installment = currentLoan!.schedule[nextIdx];
    if (cash < installment.totalAmount) {
      return 'Yetersiz nakit! Taksit tutarı: ${installment.totalAmount.toStringAsFixed(0)} ₺';
    }

    cash -= installment.totalAmount;
    installment.isPaid = true;
    currentLoan!.paidInstallments++;
    currentLoan!.remainingPrincipal =
        max(0.0, currentLoan!.remainingPrincipal - installment.principalAmount);
    currentLoan!.remainingInterest =
        max(0.0, currentLoan!.remainingInterest - installment.interestAmount);

    if (currentLoan!.isFullyPaid) {
      latestNotificationToast =
          '🎉 TEBRİKLER! ${currentLoan!.title} kredisinin tüm taksitleri ödendi ve borç kapandı!';
      currentLoan = null;
    }

    notifyListeners();
    saveState();
    return null;
  }

  String? repayEntireLoanEarly() {
    if (currentLoan == null || currentLoan!.isFullyPaid) return 'Ödenecek aktif kredi yok.';
    // Erken kapatmada kalan faize %50 indirim uygulanır
    double earlyCost = currentLoan!.remainingPrincipal + (currentLoan!.remainingInterest * 0.5);
    if (cash < earlyCost) {
      return 'Yetersiz nakit! Erken kapatma tutarı: ${earlyCost.toStringAsFixed(0)} ₺';
    }

    cash -= earlyCost;
    latestNotificationToast =
        '🎉 ${currentLoan!.title} kredisi erken kapatıldı! (%50 faiz indirimi uygulandı)';
    currentLoan = null;
    notifyListeners();
    saveState();
    return null;
  }

  String? takeLoan(double amount) {
    return takeDetailedLoan(
      principal: amount,
      installments: 10,
      title: 'Standart İşletme Kredisi',
    );
  }

  String? repayLoan(double amount) {
    if (currentLoan != null) {
      if (amount >= currentLoan!.remainingTotal * 0.8) {
        return repayEntireLoanEarly();
      } else {
        return payLoanInstallment();
      }
    }
    if (_legacyActiveLoan <= 0) return 'Ödenecek aktif kredi yok.';
    double pay = min(amount, _legacyActiveLoan);
    if (cash < pay) return 'Yetersiz nakit.';
    cash -= pay;
    _legacyActiveLoan -= pay;
    notifyListeners();
    saveState();
    return null;
  }

  // === DEPO BÜYÜTME ===
  String? expandWarehouse() {
    double cost = maxWarehouseCapacity * 5.0; // Her kg kapasite için 5 TL
    if (cash < cost) return 'Yetersiz nakit! (${cost.toStringAsFixed(0)} ₺ gerekiyor)';

    cash -= cost;
    maxWarehouseCapacity += 500; // +500 kg kapasite
    notifyListeners();
    saveState();
    return null;
  }

  // === OYUN KAYDI & YEREL DEPOLAMA (PERSISTENCE) ===
  void saveState() {
    SaveService().save(this);
  }

  Future<bool> loadFromStorage() async {
    return await SaveService().load(this);
  }

  Future<void> resetProgress() async {
    await SaveService().clear();
    cash = 30000.0;
    bankSavings = 0.0;
    _legacyActiveLoan = 0.0;
    currentLoan = null;
    maxWarehouseCapacity = 500.0;
    warehouse.clear();
    ownedFacilities.clear();
    ownedStores.clear();
    activeListings.clear();
    offers.clear();
    limitBuyOrders.clear();
    _initializeMarket();
    _initializeCommunityListings();
    notifyListeners();
  }

  Map<String, dynamic> toSaveJson() {
    return {
      'version': 1,
      'savedAt': DateTime.now().toIso8601String(),
      'cash': cash,
      'bankSavings': bankSavings,
      'maxWarehouseCapacity': maxWarehouseCapacity,
      'isDarkMode': isDarkMode,
      'currentLoan': currentLoan?.toJson(),
      'warehouse': Map<String, int>.from(warehouse),
      'marketItems': marketItems.map((k, v) => MapEntry(k, v.toJson())),
      'ownedFacilities': ownedFacilities.map((f) => f.toJson()).toList(),
      'ownedStores': ownedStores.map((s) => s.toJson()).toList(),
      'activeListings': activeListings.map((l) => l.toJson()).toList(),
      'communityListings': communityListings.map((l) => l.toJson()).toList(),
      'offers': offers.map((o) => o.toJson()).toList(),
      'limitBuyOrders': limitBuyOrders.map((o) => o.toJson()).toList(),
    };
  }

  void loadFromSaveJson(Map<String, dynamic> data) {
    if (data.containsKey('cash')) {
      cash = (data['cash'] as num).toDouble();
    }
    if (data.containsKey('bankSavings')) {
      bankSavings = (data['bankSavings'] as num).toDouble();
    }
    if (data.containsKey('maxWarehouseCapacity')) {
      maxWarehouseCapacity = (data['maxWarehouseCapacity'] as num).toDouble();
    }
    if (data.containsKey('isDarkMode')) {
      isDarkMode = data['isDarkMode'] as bool? ?? isDarkMode;
    }

    if (data['currentLoan'] != null) {
      try {
        currentLoan = BankLoan.fromJson(data['currentLoan'] as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Error loading currentLoan: $e');
      }
    } else {
      currentLoan = null;
    }

    if (data['warehouse'] != null) {
      warehouse.clear();
      final wh = data['warehouse'] as Map<String, dynamic>;
      wh.forEach((k, v) {
        int cnt = (v as num).toInt();
        if (cnt > 0) warehouse[k] = cnt;
      });
    }

    if (data['marketItems'] != null) {
      final mItems = data['marketItems'] as Map<String, dynamic>;
      mItems.forEach((k, v) {
        if (v is Map<String, dynamic> && marketItems.containsKey(k)) {
          marketItems[k] = MarketItem.fromJson(v);
        }
      });
    }

    if (data['ownedFacilities'] != null) {
      ownedFacilities.clear();
      for (var f in data['ownedFacilities'] as List) {
        try {
          final fac = ProductionFacility.fromJson(f as Map<String, dynamic>);
          if (fac != null) ownedFacilities.add(fac);
        } catch (e) {
          debugPrint('Error loading facility: $e');
        }
      }
    }

    if (data['ownedStores'] != null) {
      ownedStores.clear();
      for (var s in data['ownedStores'] as List) {
        try {
          final store = RetailStore.fromJson(s as Map<String, dynamic>);
          if (store != null) ownedStores.add(store);
        } catch (e) {
          debugPrint('Error loading store: $e');
        }
      }
    }

    if (data['activeListings'] != null) {
      activeListings.clear();
      for (var l in data['activeListings'] as List) {
        try {
          activeListings.add(MarketListing.fromJson(l as Map<String, dynamic>));
        } catch (e) {
          debugPrint('Error loading activeListing: $e');
        }
      }
    }

    if (data['communityListings'] != null && (data['communityListings'] as List).isNotEmpty) {
      communityListings.clear();
      for (var c in data['communityListings'] as List) {
        try {
          communityListings.add(MarketListing.fromJson(c as Map<String, dynamic>));
        } catch (e) {
          debugPrint('Error loading communityListing: $e');
        }
      }
    }

    if (data['offers'] != null) {
      offers.clear();
      for (var o in data['offers'] as List) {
        try {
          offers.add(MarketOffer.fromJson(o as Map<String, dynamic>));
        } catch (e) {
          debugPrint('Error loading offer: $e');
        }
      }
    }

    if (data['limitBuyOrders'] != null) {
      limitBuyOrders.clear();
      for (var ord in data['limitBuyOrders'] as List) {
        try {
          limitBuyOrders.add(LimitBuyOrder.fromJson(ord as Map<String, dynamic>));
        } catch (e) {
          debugPrint('Error loading limitBuyOrder: $e');
        }
      }
    }

    notifyListeners();
  }

  @override
  void dispose() {
    saveState();
    _gameLoopTimer?.cancel();
    super.dispose();
  }
}
