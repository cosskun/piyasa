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
import '../models/player_level.dart';
import '../models/offline_report.dart';
import '../services/notification_service.dart';
import '../services/save_service.dart';
import '../services/firebase_service.dart';
import '../services/audit_log_service.dart';
import '../models/audit_log.dart';

class GameController extends ChangeNotifier {
  // Finans (Sıfırdan Başlangıç Sermayesi: 10.000 TL)
  double cash = 10000.0;
  double bankSavings = 0.0;
  double _legacyActiveLoan = 0.0;
  BankLoan? currentLoan;
  double get activeLoan => currentLoan?.remainingTotal ?? _legacyActiveLoan;
  double maxWarehouseCapacity = 5000.0; // 5.000 kg başlangıç deposu ve siloları

  // Son aktiflik ve Çevrimdışı Kazanç Raporu
  DateTime? lastActiveAt;
  OfflineCatchUpReport? latestOfflineReport;
  void clearLatestOfflineReport() {
    latestOfflineReport = null;
  }

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
  late final ValueNotifier<bool> themeModeNotifier = ValueNotifier<bool>(isDarkMode);

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    themeModeNotifier.value = isDarkMode;
    notifyListeners();
    saveState();
  }

  // Sayaçlar ve Simülasyon
  Timer? _gameLoopTimer;
  StreamSubscription<List<MarketListing>>? _cloudMarketSub;
  final Random _random = Random();
  double _marketTickTimer = 0.0;
  double _bankTickTimer = 0.0;
  double _statsHourlyRevenue = 0.0;
  double _communityRefreshTimer = 0.0;
  double _incomingOfferTimer = 0.0;
  double _autoSaveTickTimer = 0.0;
  double _uiTickTimer = 0.0;

  static const List<String> _officialReserveSellers = [
    '🏛️ Piyasa Merkez Rezervi',
    '🌾 Toprak Mahsulleri Ofisi (TMO)',
    '🏭 Sanayi & İkmal Deposu',
    '🏢 Devlet Emtia Rezervi',
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
    // 1. Resmi Piyasa Rezervi İlanları (Tüm oyuncular ve yeni başlayanlar için garantili piyasa stokları)
    for (int i = 0; i < 8; i++) {
      final item = allItems[i % allItems.length];
      final mItem = marketItems[item.id];
      final base = mItem?.currentPrice ?? item.basePrice;
      // Piyasa fiyatı civarında adil fiyat (%98 - %103)
      final priceMultiplier = 0.98 + _random.nextDouble() * 0.05;
      final price = double.parse((base * priceMultiplier).toStringAsFixed(2));
      final seller = _officialReserveSellers[i % _officialReserveSellers.length];
      final qty = (_random.nextInt(6) + 4) * 25; // 100 - 225 adet bol stok

      communityListings.add(
        MarketListing(
          id: 'res_${DateTime.now().millisecondsSinceEpoch}_$i',
          itemId: item.id,
          initialQuantity: qty,
          remainingQuantity: qty,
          pricePerUnit: price,
          listedAt: DateTime.now().subtract(Duration(minutes: _random.nextInt(30))),
          sellerName: seller,
          sellerId: 'SYSTEM',
          isPlayerListing: false,
          isOfficialReserve: true,
        ),
      );
    }
    // NOT: Kesinlikle sahte/simüle edilmiş oyuncu ilanları eklenmez.
    // Pazardaki oyuncu ilanları YALNIZCA veritabanına kayıtlı gerçek oyuncuların açtığı ilanlardan oluşur.
  }

  bool _isGameLoopPaused = false;
  bool get isGameLoopPaused => _isGameLoopPaused;

  void _startGameLoop() {
    if (_isGameLoopPaused) return;
    _gameLoopTimer?.cancel();
    const tickIntervalMs = 100; // 0.1 saniye
    const deltaSeconds = tickIntervalMs / 1000.0;

    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: tickIntervalMs), (_) {
      _tick(deltaSeconds);
    });
  }

  /// Oyun arka plana alındığında aktif döngüyü duraklatır ve son aktiflik zamanını kilitler
  void pauseGameLoop() {
    if (_isGameLoopPaused) return;
    _isGameLoopPaused = true;
    _gameLoopTimer?.cancel();
    _gameLoopTimer = null;
    saveState();
  }

  /// Oyuna geri dönüldüğünde çevrimdışı süreci tamamlar ve döngüyü yeniden başlatır
  Future<void> resumeGameLoop() async {
    if (!_isGameLoopPaused && _gameLoopTimer != null) return;
    _isGameLoopPaused = false;
    await onAppResumed();
    _startGameLoop();
  }

  void tickForTesting(double dt) => _tick(dt);

  void _tick(double dt) {
    if (_isGameLoopPaused) return;

    bool stateChanged = false;

    // 1. Tarlalar ve Fabrikalar
    for (var fac in ownedFacilities) {
      if (!fac.isProducing) {
        fac.statusMessage = 'Üretim Durduruldu';
        fac.progress = 0.0;
        continue;
      }

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
        stateChanged = true;
      }
    }

    // 2. Perakende Mağazalar & Müşteri Satışları (Çoklu Ürün Rafları)
    for (var store in ownedStores) {
      if (!store.isSelling) {
        store.statusMessage = 'Satışlar Durduruldu';
        store.timerProgress = 0.0;
        continue;
      }

      // 2.1 Her aktif ürün rafı için depodan otomatik çekme
      for (var slot in store.productSlots) {
        if (slot.autoRestock && slot.shelfStock < slot.shelfCapacity) {
          int need = slot.shelfCapacity - slot.shelfStock;
          int inWh = warehouse[slot.itemId] ?? 0;
          if (inWh > 0) {
            int take = min(need, inWh);
            warehouse[slot.itemId] = inWh - take;
            if (warehouse[slot.itemId]! <= 0) {
              warehouse.remove(slot.itemId);
            }
            slot.shelfStock += take;
          }
        }
      }

      // 2.2 Satış Kontrolü (Her ürünün satış hızı belirlediğiniz fiyata ve piyasa talebine bağlıdır)
      final activeSellingSlots = store.productSlots.where((s) => s.isSelling).toList();
      if (activeSellingSlots.isEmpty) {
        store.statusMessage = 'Satışlar Durduruldu';
        store.timerProgress = 0.0;
        continue;
      }

      final stockedSlots = activeSellingSlots.where((s) => s.shelfStock > 0).toList();
      if (stockedSlots.isEmpty) {
        store.statusMessage = 'Raflar Boş! Ürün bekleniyor';
        store.timerProgress = 0.0;
        continue;
      }

      store.timerProgress = (store.timerProgress + dt / store.effectiveInterval) % 1.0;

      int itemsSoldThisBatch = 0;
      double revenueThisBatch = 0.0;
      String lastSoldName = '';

      for (var slot in stockedSlots) {
        final demandRatio = getProductDemandRatio(slot.itemId, slot.retailPrice);
        // Fiyat piyasanın altındaysa talep artar (hızlanır), üstündeyse talep düşer (yavaşlar)
        final slotInterval = max(0.4, store.effectiveInterval / demandRatio);
        slot.saleTimerProgress += dt / slotInterval;

        if (slot.saleTimerProgress >= 1.0) {
          slot.saleTimerProgress = 0.0;
          slot.shelfStock--;
          revenueThisBatch += slot.retailPrice;
          itemsSoldThisBatch++;
          lastSoldName = ItemRegistry.get(slot.itemId)?.name ?? slot.itemId;
        }
      }

      if (itemsSoldThisBatch > 0) {
        cash += revenueThisBatch;
        store.totalRevenue += revenueThisBatch;
        _statsHourlyRevenue += revenueThisBatch;
        if (itemsSoldThisBatch == 1) {
          store.statusMessage = '$lastSoldName satıldı! (+${revenueThisBatch.toStringAsFixed(0)} ₺)';
        } else {
          store.statusMessage = '$itemsSoldThisBatch ürün satıldı! (+${revenueThisBatch.toStringAsFixed(0)} ₺)';
        }
        stateChanged = true;
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

        // Pazara koyulan ürün satıldıkça merkezi depo ve silolardan düşer
        int currentStock = warehouse[listing.itemId] ?? 0;
        int actualDeduct = min(batch, currentStock);
        if (actualDeduct > 0) {
          warehouse[listing.itemId] = currentStock - actualDeduct;
          if (warehouse[listing.itemId]! <= 0) warehouse.remove(listing.itemId);
        }

        listing.remainingQuantity -= batch;
        double earn = batch * listing.pricePerUnit;
        cash += earn;
        listing.totalEarned += earn;
        stateChanged = true;

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

    // Bulut pazar senkronizasyonunun canlı kalmasını sağla
    if (_cloudMarketSub == null && FirebaseService().isCloudConnected) {
      _setupCloudMarketSync();
    }

    // 6. Topluluk ve Resmi Piyasa Rezervinin Düzenli Stok Yenilemesi (Her 12 saniyede bir)
    _communityRefreshTimer += dt;
    if (_communityRefreshTimer >= 12.0) {
      _communityRefreshTimer = 0.0;
      _replenishSystemMarketStock();
      stateChanged = true;
    }

    // 7. Borsa Fiyat Dalgalanması (Her 15 saniyede bir)
    _marketTickTimer += dt;
    if (_marketTickTimer >= 15.0) {
      _marketTickTimer = 0.0;
      for (var item in marketItems.values) {
        item.updatePrice(rnd: _random);
      }
      _checkLimitBuyOrders();
      stateChanged = true;
    }

    // 8. Banka Faiz & Kredi Taksit Döngüsü
    _bankTickTimer += dt;
    if (_bankTickTimer >= 60.0) {
      _bankTickTimer = 0.0;
      if (bankSavings > 0) {
        bankSavings += bankSavings * 0.005; // %0.5 mevduat getirisi
        stateChanged = true;
      }
      if (_legacyActiveLoan > 0) {
        _legacyActiveLoan += _legacyActiveLoan * 0.012;
        stateChanged = true;
      }
    }

    // Aktif Kredi Günlük Taksit Döngüsü ve Gecikme Cezası
    if (currentLoan != null && !currentLoan!.isFullyPaid) {
      currentLoan!.nextInstallmentTimer += dt;
      if (currentLoan!.nextInstallmentTimer >= BankLoan.installmentInterval) {
        currentLoan!.nextInstallmentTimer = 0.0;
        final nextIdx = currentLoan!.paidInstallments;
        if (nextIdx < currentLoan!.schedule.length) {
          final installment = currentLoan!.schedule[nextIdx];
          final amountToPay = installment.effectiveTotalAmount;

          if (cash >= amountToPay) {
            cash -= amountToPay;
            installment.isPaid = true;
            final wasOverdue = installment.isOverdue;
            installment.isOverdue = false;
            currentLoan!.paidInstallments++;
            currentLoan!.remainingPrincipal = max(0.0, currentLoan!.remainingPrincipal - installment.principalAmount);
            currentLoan!.remainingInterest = max(0.0, currentLoan!.remainingInterest - installment.interestAmount);
            if (installment.penaltyAmount > 0) {
              currentLoan!.totalPenalty = max(0.0, currentLoan!.totalPenalty - installment.penaltyAmount);
            }

            if (currentLoan!.isFullyPaid) {
              latestNotificationToast =
                  '🎉 TEBRİKLER! ${currentLoan!.title} kredisinin tüm taksitleri ödendi ve borç kapandı!';
              NotificationService().showLoanFullyPaidNotification(loanTitle: currentLoan!.title);
              currentLoan = null;
            } else {
              if (wasOverdue) {
                latestNotificationToast =
                    '💳 BANKA: Gecikmedeki ${installment.installmentNumber}. gün taksiti (${amountToPay.toStringAsFixed(0)} ₺) cezasıyla birlikte ödendi.';
                NotificationService().showLoanRepaidNotification(
                  loanTitle: currentLoan!.title,
                  installmentNumber: installment.installmentNumber,
                  amount: amountToPay,
                  isOverdueSettlement: true,
                );
              } else {
                latestNotificationToast =
                    '💳 BANKA: ${currentLoan!.title} kredisinin ${installment.installmentNumber}. gün taksiti (${amountToPay.toStringAsFixed(0)} ₺) kasadan otomatik ödendi.';
                NotificationService().showLoanRepaidNotification(
                  loanTitle: currentLoan!.title,
                  installmentNumber: installment.installmentNumber,
                  amount: amountToPay,
                  isOverdueSettlement: false,
                );
              }
            }
            notifyListeners();
          } else {
            // Ödenemedi: Ceza işlemeye başlar ve telefona bildirim gider
            installment.isOverdue = true;
            installment.overdueCycles++;
            final penaltyIncrement = max(50.0, (installment.totalAmount * 0.05).roundToDouble());
            installment.penaltyAmount += penaltyIncrement;
            currentLoan!.totalPenalty += penaltyIncrement;

            latestNotificationToast =
                '⚠️ BANKA CEZASI: Kasada bakiye yetersiz! ${installment.installmentNumber}. gün taksitine +${penaltyIncrement.toStringAsFixed(0)} ₺ ceza eklendi (Toplam: ${installment.effectiveTotalAmount.toStringAsFixed(0)} ₺)!';

            NotificationService().showLoanOverduePenaltyNotification(
              loanTitle: currentLoan!.title,
              installmentNumber: installment.installmentNumber,
              amount: installment.totalAmount,
              penaltyAmount: installment.penaltyAmount,
            );
            notifyListeners();
          }
        }
      }
    }

    _autoSaveTickTimer += dt;
    if (_autoSaveTickTimer >= 45.0) {
      _autoSaveTickTimer = 0.0;
      saveState();
    }

    final hasActiveProgress = ownedFacilities.any((f) => f.isProducing) ||
        ownedStores.any((s) => s.isSelling) ||
        activeListings.isNotEmpty;

    _uiTickTimer += dt;
    if (stateChanged || (hasActiveProgress && _uiTickTimer >= 0.5)) {
      _uiTickTimer = 0.0;
      notifyListeners();
    }
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

  // === SEVİYE SİSTEMİ (NET SERVET BAZLI) ===
  double highestNetWorth = 0.0;

  double get effectiveLevelNetWorth {
    final current = netWorth;
    if (current > highestNetWorth) {
      highestNetWorth = current;
    }
    return max(highestNetWorth, current);
  }

  int get playerLevel {
    final worth = effectiveLevelNetWorth;
    for (int i = PlayerLevelInfo.tiers.length - 1; i >= 0; i--) {
      if (worth >= PlayerLevelInfo.tiers[i].minNetWorth) {
        if (i == PlayerLevelInfo.tiers.length - 1) {
          int extra = 0;
          double step = PlayerLevelInfo.tiers.last.minNetWorth;
          while (worth >= step * 1.5) {
            extra++;
            step *= 1.5;
          }
          return PlayerLevelInfo.tiers.last.level + extra;
        }
        return PlayerLevelInfo.tiers[i].level;
      }
    }
    return 1;
  }

  String get playerTitle => PlayerLevelInfo.getInfoForLevel(playerLevel).title;
  PlayerLevelInfo get playerLevelInfo => PlayerLevelInfo.getInfoForLevel(playerLevel);

  double get currentLevelMinNetWorth => PlayerLevelInfo.getInfoForLevel(playerLevel).minNetWorth;

  double get nextLevelNetWorth {
    final currentLvl = playerLevel;
    return PlayerLevelInfo.getInfoForLevel(currentLvl + 1).minNetWorth;
  }

  double get levelProgress {
    final worth = effectiveLevelNetWorth;
    final minW = currentLevelMinNetWorth;
    final nextW = nextLevelNetWorth;
    if (nextW <= minW) return 1.0;
    return ((worth - minW) / (nextW - minW)).clamp(0.0, 1.0);
  }

  bool get canTakeBankLoan => playerLevel >= 5;

  double get netWorthNeededForLoan => max(0.0, 200000.0 - effectiveLevelNetWorth);

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

    AuditLogService().log(
      category: LogCategory.trade,
      action: 'MARKET_BUY',
      title: 'Borsa Alımı: ${data.name}',
      description: '$qty adet ${data.name} birim başı ${mItem.wholesaleBuyPrice.toStringAsFixed(2)} ₺ fiyattan satın alındı.',
      amountChange: -totalCost,
      cashAfter: cash,
      details: {
        'itemId': itemId,
        'itemName': data.name,
        'quantity': qty,
        'unitPrice': mItem.wholesaleBuyPrice,
        'totalCost': totalCost,
      },
    );

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

    AuditLogService().log(
      category: LogCategory.trade,
      action: 'MARKET_SELL',
      title: 'Borsa Satışı: ${data.name}',
      description: '$qty adet ${data.name} birim başı ${mItem.quickSellPrice.toStringAsFixed(2)} ₺ fiyattan toptan satıldı.',
      amountChange: totalEarnings,
      cashAfter: cash,
      details: {
        'itemId': itemId,
        'itemName': data.name,
        'quantity': qty,
        'unitPrice': mItem.quickSellPrice,
        'totalEarnings': totalEarnings,
      },
    );

    notifyListeners();
    saveState();
    return null;
  }

  // === BORSA LİMİT ALIŞ EMİRLERİ (FİYAT DÜŞÜNCE VEYA ANINDA OTOMATİK ALIM) ===
  String? placeLimitBuyOrder({
    required String itemId,
    required double targetPrice,
    required int quantity,
  }) {
    if (quantity <= 0) return 'Lütfen geçerli bir miktar girin.';
    if (targetPrice <= 0) return 'Lütfen 0\'dan büyük bir hedef fiyat girin.';

    final mItem = marketItems[itemId];
    if (mItem == null) return 'Ürün borsada bulunamadı.';

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

    AuditLogService().log(
      category: LogCategory.trade,
      action: 'LIMIT_ORDER_PLACED',
      title: 'Limit Alış Emri: ${itemData.name}',
      description: '$quantity adet ${itemData.name} için ${order.targetPrice.toStringAsFixed(2)} ₺ hedef fiyat emri verildi (${totalCost.toStringAsFixed(0)} ₺ bloke edildi).',
      amountChange: -totalCost,
      cashAfter: cash,
      details: {
        'orderId': order.id,
        'itemId': itemId,
        'quantity': quantity,
        'targetPrice': targetPrice,
        'reservedCost': totalCost,
      },
    );

    // Pazarda veya borsada bu fiyata uygun ürün varsa anında icra et
    _checkLimitBuyOrders();

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

    AuditLogService().log(
      category: LogCategory.trade,
      action: 'LIMIT_ORDER_CANCELLED',
      title: 'Alış Emri İptal: ${order.item.name}',
      description: 'Bekleyen emir iptal edildi ve bloke edilen ${order.totalReservedCost.toStringAsFixed(0)} ₺ kasanıza iade edildi.',
      amountChange: order.totalReservedCost,
      cashAfter: cash,
      details: {
        'orderId': order.id,
        'refund': order.totalReservedCost,
      },
    );

    notifyListeners();
    saveState();
    return null;
  }

  void _replenishSystemMarketStock() {
    // 0 kalan veya tükenmiş ilanları temizle
    communityListings.removeWhere((l) => l.remainingQuantity <= 0);

    final activeReserveCount = communityListings.where((l) => l.isOfficialReserve).length;

    // Eğer resmi rezerv ilanları 12'nin altına düşmüşse piyasaya yeni taze stok enjekte et
    if (activeReserveCount < 12) {
      final allItems = ItemRegistry.getAll();
      final existingReserveItemIds =
          communityListings.where((l) => l.isOfficialReserve).map((l) => l.itemId).toSet();
      final missingItems =
          allItems.where((it) => !existingReserveItemIds.contains(it.id)).toList();

      final itemToStock = missingItems.isNotEmpty
          ? missingItems[_random.nextInt(missingItems.length)]
          : allItems[_random.nextInt(allItems.length)];

      final mItem = marketItems[itemToStock.id];
      final base = mItem?.currentPrice ?? itemToStock.basePrice;
      // Piyasa fiyatı civarlarında dengeli fiyat (%98 - %104)
      final priceMultiplier = 0.98 + _random.nextDouble() * 0.06;
      final price = double.parse((base * priceMultiplier).toStringAsFixed(2));
      final seller = _officialReserveSellers[_random.nextInt(_officialReserveSellers.length)];
      final qty = (_random.nextInt(6) + 4) * 25; // 100 - 225 adet bol stok

      communityListings.add(
        MarketListing(
          id: 'res_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(999)}',
          itemId: itemToStock.id,
          initialQuantity: qty,
          remainingQuantity: qty,
          pricePerUnit: price,
          listedAt: DateTime.now(),
          sellerName: seller,
          sellerId: 'SYSTEM',
          isPlayerListing: false,
          isOfficialReserve: true,
        ),
      );
      notifyListeners();
    }
  }

  void _checkLimitBuyOrders() {
    bool hasChanges = false;
    for (var order in limitBuyOrders) {
      if (!order.isPending) continue;

      final mItem = marketItems[order.itemId];
      if (mItem == null) continue;

      final itemData = ItemRegistry.get(order.itemId);
      if (itemData == null) continue;

      final weightNeeded = order.quantity * itemData.weight;
      if (currentWarehouseWeight + weightNeeded > maxWarehouseCapacity) {
        order.statusMessage = 'Depo Dolu! Yer açıldığında alınacak.';
        continue;
      }

      // 1. Önce Topluluk / Oyuncu Pazarında bu fiyata veya altına ürün satan ilan var mı bak
      MarketListing? bestCommunityListing;
      for (var l in communityListings) {
        if (l.itemId == order.itemId &&
            l.remainingQuantity >= order.quantity &&
            l.pricePerUnit <= order.targetPrice &&
            !l.isPlayerListing) {
          if (bestCommunityListing == null || l.pricePerUnit < bestCommunityListing.pricePerUnit) {
            bestCommunityListing = l;
          }
        }
      }

      // En uygun icra fiyatını belirle (Pazar ilanı mı yoksa borsa kotasyonu mu?)
      double? execPrice;
      bool isFromCommunity = false;

      if (bestCommunityListing != null && bestCommunityListing.pricePerUnit <= mItem.currentPrice) {
        execPrice = bestCommunityListing.pricePerUnit;
        isFromCommunity = true;
      } else if (mItem.currentPrice <= order.targetPrice) {
        execPrice = mItem.currentPrice;
        isFromCommunity = false;
      }

      // Fiyat hedeflenen seviyeye veya daha altına denk geldiyse emri icra et!
      if (execPrice != null) {
        final actualTotalCost = execPrice * order.quantity;

        // Fiyat iyileştirmesi: Eğer piyasa hedeften de aşağıdaysa aradaki fark oyuncuya iade edilir!
        final refund = order.totalReservedCost - actualTotalCost;
        if (refund > 0) {
          cash += refund;
        }

        warehouse[order.itemId] = (warehouse[order.itemId] ?? 0) + order.quantity;
        order.status = LimitOrderStatus.completed;
        order.executedAt = DateTime.now();
        order.executedPrice = execPrice;
        order.statusMessage = 'İcra Edildi: ${execPrice.toStringAsFixed(2)} ₺${isFromCommunity ? " (Pazar İlanı)" : ""}';

        if (isFromCommunity && bestCommunityListing != null) {
          bestCommunityListing.remainingQuantity -= order.quantity;
          if (bestCommunityListing.remainingQuantity <= 0) {
            communityListings.remove(bestCommunityListing);
          }
          if (FirebaseService().isCloudConnected) {
            FirebaseService().buyFromPublicMarket(listing: bestCommunityListing, quantityToBuy: order.quantity);
          }
        }

        AuditLogService().log(
          category: LogCategory.trade,
          action: 'LIMIT_ORDER_EXECUTED',
          title: 'Alış Emri İcra Edildi: ${itemData.name}',
          description: '${order.quantity} adet ${itemData.name} birim başı ${execPrice.toStringAsFixed(2)} ₺ fiyattan ${isFromCommunity ? "pazardan" : "borsadan"} satın alındı.${refund > 0 ? ' (${refund.toStringAsFixed(0)} ₺ fiyat iyileşme iadesi)' : ''}',
          amountChange: refund > 0 ? refund : null,
          cashAfter: cash,
          details: {
            'orderId': order.id,
            'quantity': order.quantity,
            'executedPrice': execPrice,
            'refund': refund,
            'isFromCommunity': isFromCommunity,
          },
        );

        latestNotificationToast =
            '🎯 ALIŞ EMRİ GERÇEKLEŞTİ! ${order.quantity} adet ${itemData.name}, '
            '${execPrice.toStringAsFixed(2)} ₺ birim fiyatla otomatik satın alındı ve deponuza yüklendi!';
        NotificationService().showLimitOrderExecutedNotification(
          itemName: itemData.name,
          quantity: order.quantity,
          price: execPrice,
        );
        hasChanges = true;
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
    if (FirebaseService().isCloudConnected) {
      FirebaseService().buyFromPublicMarket(listing: listing, quantityToBuy: qty);
    }

    AuditLogService().log(
      category: LogCategory.trade,
      action: 'COMMUNITY_BUY',
      title: 'Pazar Alımı: ${listing.item.name}',
      description: '$qty adet ${listing.item.name}, ${listing.sellerName} satıcısından ${listing.pricePerUnit.toStringAsFixed(2)} ₺ fiyattan alındı.',
      amountChange: -totalCost,
      cashAfter: cash,
      details: {
        'listingId': listing.id,
        'itemId': listing.itemId,
        'sellerName': listing.sellerName,
        'quantity': qty,
        'pricePerUnit': listing.pricePerUnit,
        'totalCost': totalCost,
      },
    );

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

    AuditLogService().log(
      category: LogCategory.trade,
      action: 'OFFER_BOUGHT',
      title: 'Teklif Satın Alındı: ${offer.item.name}',
      description: '${offer.sellerName} satıcısından ${offer.quantity} adet ${offer.item.name} ${offer.offeredPricePerUnit.toStringAsFixed(2)} ₺ fiyattan teslim alındı.',
      amountChange: -totalCost,
      cashAfter: cash,
      details: {
        'offerId': offer.id,
        'sellerName': offer.sellerName,
        'quantity': offer.quantity,
        'unitPrice': offer.offeredPricePerUnit,
        'totalCost': totalCost,
      },
    );

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

    // Depodan satıldıkça stok düşer
    int currentStock = warehouse[listing.itemId] ?? 0;
    if (currentStock < offer.quantity) {
      offer.status = OfferStatus.expired;
      notifyListeners();
      saveState();
      return 'Deponuzda bu teklifi karşılayacak kadar ${offer.item.name} kalmadı!';
    }
    warehouse[listing.itemId] = currentStock - offer.quantity;
    if (warehouse[listing.itemId]! <= 0) warehouse.remove(listing.itemId);

    listing.remainingQuantity -= offer.quantity;
    double earnings = offer.totalOfferedPrice;
    cash += earnings;
    listing.totalEarned += earnings;
    offer.status = OfferStatus.completed;

    if (listing.isCompleted) {
      activeListings.remove(listing);
    }

    AuditLogService().log(
      category: LogCategory.trade,
      action: 'OFFER_ACCEPTED',
      title: 'Gelen Teklif Satıldı: ${offer.item.name}',
      description: '${offer.buyerName} alıcısına ${offer.quantity} adet ${offer.item.name} ${offer.offeredPricePerUnit.toStringAsFixed(2)} ₺ fiyattan satıldı.',
      amountChange: earnings,
      cashAfter: cash,
      details: {
        'offerId': offer.id,
        'buyerName': offer.buyerName,
        'quantity': offer.quantity,
        'unitPrice': offer.offeredPricePerUnit,
        'totalEarnings': earnings,
      },
    );

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
    int alreadyListed = activeListings
        .where((l) => l.itemId == itemId && !l.isCompleted)
        .fold(0, (sum, l) => sum + l.remainingQuantity);

    if (currentStock < alreadyListed + qty) {
      return 'Deponuzda bu miktarda boşta ${data.name} yok! (Depo: $currentStock, İlandaki: $alreadyListed)';
    }

    // DİKKAT: Ürünler satıldıkça merkezi depo ve silolardan düşer, ilan açarken fiziksel stok depoda kalır.

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
    FirebaseService().publishListingToMarket(listing);

    AuditLogService().log(
      category: LogCategory.trade,
      action: 'LISTING_CREATED',
      title: 'Pazar İlanı Açıldı: ${data.name}',
      description: '$qty adet ${data.name} birim başı ${pricePerUnit.toStringAsFixed(2)} ₺ fiyatla satışa koyuldu.',
      cashAfter: cash,
      details: {
        'listingId': listing.id,
        'itemId': itemId,
        'quantity': qty,
        'pricePerUnit': pricePerUnit,
      },
    );

    notifyListeners();
    saveState();
    return null;
  }

  String? cancelListing(MarketListing listing) {
    // Ürün ilana koyulduğunda depodan silinmediği için iptal anında depoya iade eklemesi yapılmaz.
    // İlan iptal edilirse bekleyen teklifler de düşer
    for (var off in offers) {
      if (off.direction == OfferDirection.incoming &&
          off.listingId == listing.id &&
          off.status == OfferStatus.pending) {
        off.status = OfferStatus.expired;
      }
    }

    activeListings.remove(listing);
    FirebaseService().cancelListingInMarket(listing.id);

    AuditLogService().log(
      category: LogCategory.trade,
      action: 'LISTING_CANCELLED',
      title: 'İlan İptal Edildi: ${listing.item.name}',
      description: 'Pazar ilanı iptal edildi (${listing.remainingQuantity} adet ${listing.item.name}).',
      cashAfter: cash,
      details: {
        'listingId': listing.id,
        'itemId': listing.itemId,
        'remainingQuantity': listing.remainingQuantity,
      },
    );

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

    AuditLogService().log(
      category: LogCategory.facility,
      action: 'FACILITY_BUY',
      title: 'Tesis Kuruldu: ${bp.name}',
      description: '$quantity adet ${bp.name} ${totalCost.toStringAsFixed(0)} ₺ yatırımla kuruldu.',
      amountChange: -totalCost,
      cashAfter: cash,
      details: {
        'facilityId': bp.id,
        'facilityName': bp.name,
        'quantity': quantity,
        'totalCost': totalCost,
      },
    );

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

    AuditLogService().log(
      category: LogCategory.facility,
      action: 'PACKAGE_BUY',
      title: 'Başlangıç Paketi Kuruldu: $packageName',
      description: '$packageName ${totalCost.toStringAsFixed(0)} ₺ yatırımla kuruldu.',
      amountChange: -totalCost,
      cashAfter: cash,
      details: {
        'packageName': packageName,
        'totalCost': totalCost,
      },
    );

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

    AuditLogService().log(
      category: LogCategory.facility,
      action: 'FACILITY_UPGRADE',
      title: 'Tesis Geliştirildi: ${fac.name}',
      description: '${fac.name} Seviye ${fac.level}\'e yükseltildi (${cost.toStringAsFixed(0)} ₺).',
      amountChange: -cost,
      cashAfter: cash,
      details: {
        'facilityId': fac.id,
        'facilityName': fac.name,
        'newLevel': fac.level,
        'cost': cost,
      },
    );

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

    AuditLogService().log(
      category: LogCategory.facility,
      action: 'FACILITY_SELL',
      title: 'Tesis Devredildi: ${fac.name}',
      description: '${fac.name} satıldı ve ${refund.toStringAsFixed(0)} ₺ tahsil edildi.',
      amountChange: refund,
      cashAfter: cash,
      details: {
        'facilityId': fac.id,
        'facilityName': fac.name,
        'refund': refund,
      },
    );

    latestNotificationToast = '💰 ${fac.emoji} ${fac.name} satıldı ve ${refund.toStringAsFixed(0)} ₺ nakite dönüştürüldü.';
    notifyListeners();
    saveState();
    return null;
  }

  void toggleFacilityProducing(ProductionFacility fac, [bool? val]) {
    fac.isProducing = val ?? !fac.isProducing;
    fac.statusMessage = fac.isProducing ? 'Üretim Hazır' : 'Üretim Durduruldu';
    if (!fac.isProducing) {
      fac.progress = 0.0;
    }
    latestNotificationToast = fac.isProducing
        ? '🌿 ${fac.emoji} ${fac.name} üretimi başlatıldı.'
        : '⏸️ ${fac.emoji} ${fac.name} üretimi durduruldu.';
    notifyListeners();
    saveState();
  }

  String? buyStore(RetailStore bp) {
    if (cash < bp.purchaseCost) {
      return 'Yetersiz nakit! (${bp.purchaseCost.toStringAsFixed(0)} ₺ gerekiyor)';
    }

    cash -= bp.purchaseCost;
    ownedStores.add(bp.copy());

    AuditLogService().log(
      category: LogCategory.retail,
      action: 'STORE_BUY',
      title: 'Dükkan Açıldı: ${bp.name}',
      description: '${bp.name} ${bp.purchaseCost.toStringAsFixed(0)} ₺ yatırımla açıldı.',
      amountChange: -bp.purchaseCost,
      cashAfter: cash,
      details: {
        'storeId': bp.id,
        'storeName': bp.name,
        'cost': bp.purchaseCost,
      },
    );

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
    for (var s in store.productSlots) {
      s.shelfCapacity += 10;
    }

    AuditLogService().log(
      category: LogCategory.retail,
      action: 'STORE_UPGRADE',
      title: 'Dükkan Geliştirildi: ${store.name}',
      description: '${store.name} Seviye ${store.level}\'e yükseltildi (${cost.toStringAsFixed(0)} ₺).',
      amountChange: -cost,
      cashAfter: cash,
      details: {
        'storeId': store.id,
        'storeName': store.name,
        'newLevel': store.level,
        'cost': cost,
      },
    );

    if (store.level <= 5) {
      latestNotificationToast = '🎉 ${store.name} Seviye ${store.level}\'e yükseldi! Yeni ürün rafı (${store.maxProductSlots} ürün) açıldı.';
    } else {
      latestNotificationToast = '🎉 ${store.name} Seviye ${store.level}\'e yükseldi! Satış hızı ve raf kapasitesi arttı.';
    }
    notifyListeners();
    saveState();
    return null;
  }

  // === ÇOKLU ÜRÜN RAFLARI YÖNETİMİ ===
  String? addProductSlotToStore(RetailStore store, String itemId) {
    if (store.productSlots.length >= store.maxProductSlots) {
      return 'Bu mağaza şu an en fazla ${store.maxProductSlots} ürün satabilir. Daha fazla ürün satmak için mağazanızı yükseltin! (Maksimum 5 ürün)';
    }

    if (store.productSlots.any((s) => s.itemId == itemId)) {
      return 'Bu ürün zaten mağazanızın raflarında mevcut.';
    }

    if (!store.allowedProductIds.contains(itemId)) {
      return 'Bu mağaza türü bu ürünü satmak için uygun değildir.';
    }

    final item = ItemRegistry.get(itemId);
    if (item == null) return 'Ürün bulunamadı.';

    final initialCap = 35 + (store.level - 1) * 10;
    final slot = StoreProductSlot(
      itemId: itemId,
      shelfCapacity: initialCap,
      shelfStock: 0,
      retailPrice: item.retailSuggestedPrice,
      autoRestock: true,
    );

    store.productSlots.add(slot);

    // Varsa depodan rafa çek
    int inWh = warehouse[itemId] ?? 0;
    if (inWh > 0) {
      int take = min(inWh, initialCap);
      warehouse[itemId] = inWh - take;
      if (warehouse[itemId]! <= 0) warehouse.remove(itemId);
      slot.shelfStock = take;
    }

    latestNotificationToast = '🛒 ${item.emoji} ${item.name} mağaza raflarına eklendi!';
    notifyListeners();
    saveState();
    return null;
  }

  String? removeProductSlotFromStore(RetailStore store, StoreProductSlot slot) {
    if (store.productSlots.length <= 1) {
      return 'Mağazada en az bir ürün bulunmalıdır.';
    }

    if (slot.shelfStock > 0) {
      final item = ItemRegistry.get(slot.itemId);
      final weightPerItem = item?.weight ?? 1.0;
      final spaceLeft = max(0.0, maxWarehouseCapacity - currentWarehouseWeight);
      final canFit = (spaceLeft / weightPerItem).floor();
      int returned = min(slot.shelfStock, canFit);
      int liquidated = slot.shelfStock - returned;

      if (returned > 0) {
        warehouse[slot.itemId] = (warehouse[slot.itemId] ?? 0) + returned;
      }
      if (liquidated > 0) {
        final mItem = marketItems[slot.itemId];
        final unitPrice = mItem?.quickSellPrice ?? (item?.basePrice ?? 1.0) * 0.8;
        cash += liquidated * unitPrice;
      }
    }

    store.productSlots.remove(slot);
    latestNotificationToast = 'Ürün rafı kaldırıldı.';
    notifyListeners();
    saveState();
    return null;
  }

  String? restockStoreSlot(RetailStore store, StoreProductSlot slot, int amount) {
    int inWh = warehouse[slot.itemId] ?? 0;
    if (inWh <= 0) {
      return 'Deponuzda bu üründen kalmamış!';
    }
    int room = slot.shelfCapacity - slot.shelfStock;
    if (room <= 0) {
      return 'Bu ürünün rafı tamamen dolu!';
    }
    int transfer = min(amount, min(inWh, room));
    warehouse[slot.itemId] = inWh - transfer;
    if (warehouse[slot.itemId]! <= 0) warehouse.remove(slot.itemId);
    slot.shelfStock += transfer;
    notifyListeners();
    saveState();
    return null;
  }

  void setStoreSlotRetailPrice(RetailStore store, StoreProductSlot slot, double newPrice) {
    slot.retailPrice = max(1.0, double.parse(newPrice.toStringAsFixed(2)));
    notifyListeners();
    saveState();
  }

  /// Sistem/Piyasa tarafından belirlenen güncel perakende referans fiyatı
  double getMarketRetailPrice(String itemId) {
    final item = ItemRegistry.get(itemId);
    final mItem = marketItems[itemId];
    if (item == null) return 20.0;
    if (mItem != null && item.basePrice > 0) {
      // Dinamik borsa fiyatına göre ölçeklenen perakende piyasa referansı
      return double.parse((mItem.currentPrice * (item.retailSuggestedPrice / item.basePrice)).toStringAsFixed(1));
    }
    return item.retailSuggestedPrice;
  }

  /// Satış fiyatına göre müşteri talebi ve satış hızı çarpanı:
  /// Fiyat piyasa fiyatının altındaysa talep artar (satışlar hızlanır, max 3.0x).
  /// Fiyat piyasa fiyatının üstündeyse talep düşer (satışlar yavaşlar, min 0.05x).
  double getProductDemandRatio(String itemId, double retailPrice) {
    final refPrice = getMarketRetailPrice(itemId);
    if (retailPrice <= 0 || refPrice <= 0) return 1.0;
    final priceRatio = refPrice / retailPrice;
    return double.parse(pow(priceRatio, 1.6).clamp(0.05, 3.0).toStringAsFixed(2));
  }

  void toggleStoreSlotAutoRestock(StoreProductSlot slot, bool val) {
    slot.autoRestock = val;
    notifyListeners();
    saveState();
  }

  void toggleStoreSelling(RetailStore store, [bool? val]) {
    store.isSelling = val ?? !store.isSelling;
    store.statusMessage = store.isSelling ? 'Müşteri Bekleniyor' : 'Satışlar Durduruldu';
    latestNotificationToast = store.isSelling
        ? '🏪 ${store.emoji} ${store.name} satışları başlatıldı.'
        : '⏸️ ${store.emoji} ${store.name} satışları durduruldu.';
    notifyListeners();
    saveState();
  }

  void toggleStoreSlotSelling(RetailStore store, StoreProductSlot slot, [bool? val]) {
    slot.isSelling = val ?? !slot.isSelling;
    final item = ItemRegistry.get(slot.itemId);
    final itemName = item?.name ?? slot.itemId;
    latestNotificationToast = slot.isSelling
        ? '🛒 $itemName satışı başlatıldı.'
        : '⏸️ $itemName satışı durduruldu.';
    notifyListeners();
    saveState();
  }

  // === DÜKKAN GERİ SATMA / DEVRETME (LİKİDASYON) ===
  String? sellStore(RetailStore store) {
    if (!ownedStores.contains(store)) {
      return 'Dükkan bulunamadı.';
    }

    final refund = store.resaleValue;
    int totalReturnedToWarehouse = 0;
    int totalLiquidatedStock = 0;
    double totalLiquidatedEarnings = 0.0;

    for (var slot in store.productSlots) {
      if (slot.shelfStock > 0) {
        final item = ItemRegistry.get(slot.itemId);
        final weightPerItem = item?.weight ?? 1.0;
        final spaceLeft = max(0.0, maxWarehouseCapacity - currentWarehouseWeight);
        final canFit = (spaceLeft / weightPerItem).floor();

        int returned = min(slot.shelfStock, canFit);
        int liquidated = slot.shelfStock - returned;

        if (returned > 0) {
          warehouse[slot.itemId] = (warehouse[slot.itemId] ?? 0) + returned;
          totalReturnedToWarehouse += returned;
        }

        if (liquidated > 0) {
          final mItem = marketItems[slot.itemId];
          final unitPrice = mItem?.quickSellPrice ?? (item?.basePrice ?? 1.0) * 0.8;
          double earn = liquidated * unitPrice;
          totalLiquidatedEarnings += earn;
          totalLiquidatedStock += liquidated;
        }
      }
    }

    cash += (refund + totalLiquidatedEarnings);
    ownedStores.remove(store);

    AuditLogService().log(
      category: LogCategory.retail,
      action: 'STORE_SELL',
      title: 'Dükkan Devredildi: ${store.name}',
      description: '${store.name} devredildi (${(refund + totalLiquidatedEarnings).toStringAsFixed(0)} ₺ tahsil edildi).',
      amountChange: refund + totalLiquidatedEarnings,
      cashAfter: cash,
      details: {
        'storeId': store.id,
        'storeName': store.name,
        'refund': refund,
        'liquidatedStock': totalLiquidatedEarnings,
        'totalGained': refund + totalLiquidatedEarnings,
      },
    );

    String detail = '🏪 ${store.emoji} ${store.name} devredildi ve ${refund.toStringAsFixed(0)} ₺ nakit alındı.';
    if (totalReturnedToWarehouse > 0) {
      detail += ' Raflardaki $totalReturnedToWarehouse ürün depoya aktarıldı.';
    }
    if (totalLiquidatedStock > 0) {
      detail += ' Depoya sığmayan $totalLiquidatedStock ürün ${totalLiquidatedEarnings.toStringAsFixed(0)} ₺ karşılığı toptan satıldı.';
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

    AuditLogService().log(
      category: LogCategory.finance,
      action: 'BANK_DEPOSIT',
      title: 'Mevduat Yatırıldı',
      description: '${amount.toStringAsFixed(0)} ₺ banka mevduat hesabına yatırıldı.',
      amountChange: -amount,
      cashAfter: cash,
      details: {'amount': amount, 'bankSavingsAfter': bankSavings},
    );

    notifyListeners();
    saveState();
    return null;
  }

  String? withdrawFromBank(double amount) {
    if (amount <= 0 || bankSavings < amount) return 'Hesapta yeterli para yok.';
    bankSavings -= amount;
    cash += amount;

    AuditLogService().log(
      category: LogCategory.finance,
      action: 'BANK_WITHDRAW',
      title: 'Mevduat Çekildi',
      description: '${amount.toStringAsFixed(0)} ₺ mevduat hesabından nakite çekildi.',
      amountChange: amount,
      cashAfter: cash,
      details: {'amount': amount, 'bankSavingsAfter': bankSavings},
    );

    notifyListeners();
    saveState();
    return null;
  }

  double get maxLoanLimit {
    if (!canTakeBankLoan) return 0.0;
    // Seviye 5 (Sanayici) taban kredi limiti: 100.000 TL
    // Seviye arttıkça taban limit katlanır (1.8^(playerLevel - 5))
    // ve net servet teminat çarpanı kademeli olarak yükselir.
    final levelMultiplier = pow(1.8, playerLevel - 5).toDouble();
    final baseLimit = 100000.0 * levelMultiplier;
    final netWorthRatio = 0.45 + (playerLevel - 5) * 0.10;
    final currentWorth = max(0.0, netWorth);
    return baseLimit + (currentWorth * netWorthRatio);
  }

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
    if (!canTakeBankLoan) {
      return 'Banka kredisi çekebilmek için en az Seviye 5 (Sanayici) olmalısınız. (Mevcut Seviyeniz: $playerLevel)';
    }
    if (principal <= 0) return 'Geçersiz kredi tutarı.';
    if (currentLoan != null && !currentLoan!.isFullyPaid) {
      return 'Zaten aktif bir krediniz bulunmaktadır. Yeni kredi çekmek için mevcut borcunuzu kapatmalısınız.';
    }
    if (principal > maxLoanLimit) {
      return 'Kredi limitiniz aşıldı! Seviye $playerLevel maksimum limitiniz: ${maxLoanLimit.toStringAsFixed(0)} ₺';
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

    AuditLogService().log(
      category: LogCategory.finance,
      action: 'LOAN_TAKEN',
      title: 'Kredi Çekildi: ${currentLoan!.title}',
      description: '${principal.toStringAsFixed(0)} ₺ tutarında, $installments gün vadeli kredi onaylandı.',
      amountChange: principal,
      cashAfter: cash,
      details: {
        'loanId': currentLoan!.id,
        'title': currentLoan!.title,
        'principal': principal,
        'installments': installments,
        'interestRate': rate,
      },
    );

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
    final amountToPay = installment.effectiveTotalAmount;
    if (cash < amountToPay) {
      return 'Yetersiz nakit! Taksit tutarı: ${amountToPay.toStringAsFixed(0)} ₺';
    }

    cash -= amountToPay;
    installment.isPaid = true;
    final wasOverdue = installment.isOverdue;
    installment.isOverdue = false;
    currentLoan!.paidInstallments++;
    currentLoan!.remainingPrincipal =
        max(0.0, currentLoan!.remainingPrincipal - installment.principalAmount);
    currentLoan!.remainingInterest =
        max(0.0, currentLoan!.remainingInterest - installment.interestAmount);
    if (installment.penaltyAmount > 0) {
      currentLoan!.totalPenalty = max(0.0, currentLoan!.totalPenalty - installment.penaltyAmount);
    }

    AuditLogService().log(
      category: LogCategory.finance,
      action: 'LOAN_INSTALLMENT_PAID',
      title: 'Kredi Taksiti Ödendi: ${currentLoan!.title}',
      description: '${installment.installmentNumber}. gün taksiti (${amountToPay.toStringAsFixed(0)} ₺) ödendi.',
      amountChange: -amountToPay,
      cashAfter: cash,
      details: {
        'loanId': currentLoan!.id,
        'installmentNumber': installment.installmentNumber,
        'amount': amountToPay,
        'penalty': installment.penaltyAmount,
      },
    );

    if (currentLoan!.isFullyPaid) {
      latestNotificationToast =
          '🎉 TEBRİKLER! ${currentLoan!.title} kredisinin tüm taksitleri ödendi ve borç kapandı!';
      NotificationService().showLoanFullyPaidNotification(loanTitle: currentLoan!.title);
      currentLoan = null;
    } else {
      if (wasOverdue) {
        latestNotificationToast =
            '💳 BANKA: Gecikmedeki ${installment.installmentNumber}. gün taksiti (${amountToPay.toStringAsFixed(0)} ₺) cezasıyla birlikte ödendi.';
        NotificationService().showLoanRepaidNotification(
          loanTitle: currentLoan!.title,
          installmentNumber: installment.installmentNumber,
          amount: amountToPay,
          isOverdueSettlement: true,
        );
      } else {
        latestNotificationToast =
            '💳 BANKA: ${currentLoan!.title} ${installment.installmentNumber}. gün taksiti (${amountToPay.toStringAsFixed(0)} ₺) ödendi.';
        NotificationService().showLoanRepaidNotification(
          loanTitle: currentLoan!.title,
          installmentNumber: installment.installmentNumber,
          amount: amountToPay,
          isOverdueSettlement: false,
        );
      }
    }

    notifyListeners();
    saveState();
    return null;
  }

  String? repayEntireLoanEarly() {
    if (currentLoan == null || currentLoan!.isFullyPaid) return 'Ödenecek aktif kredi yok.';
    // Erken kapatmada kalan faize %50 indirim uygulanır, varsa ceza eklenir
    double earlyCost = currentLoan!.remainingPrincipal + (currentLoan!.remainingInterest * 0.5) + currentLoan!.totalPenalty;
    if (cash < earlyCost) {
      return 'Yetersiz nakit! Erken kapatma tutarı: ${earlyCost.toStringAsFixed(0)} ₺';
    }

    cash -= earlyCost;

    AuditLogService().log(
      category: LogCategory.finance,
      action: 'LOAN_EARLY_SETTLED',
      title: 'Kredi Erken Kapatıldı: ${currentLoan!.title}',
      description: 'Kalan borç ${earlyCost.toStringAsFixed(0)} ₺ ödenerek tamamen kapatıldı.',
      amountChange: -earlyCost,
      cashAfter: cash,
      details: {
        'loanId': currentLoan!.id,
        'settlementCost': earlyCost,
      },
    );

    latestNotificationToast =
        '🎉 ${currentLoan!.title} kredisi erken kapatıldı! (%50 faiz indirimi uygulandı)';
    NotificationService().showLoanFullyPaidNotification(loanTitle: currentLoan!.title);
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

    AuditLogService().log(
      category: LogCategory.facility,
      action: 'WAREHOUSE_EXPAND',
      title: 'Depo Genişletildi (+500 kg)',
      description: 'Depo kapasitesi ${maxWarehouseCapacity.toStringAsFixed(0)} kg\'a çıkarıldı (${cost.toStringAsFixed(0)} ₺).',
      amountChange: -cost,
      cashAfter: cash,
      details: {'cost': cost, 'newCapacity': maxWarehouseCapacity},
    );

    notifyListeners();
    saveState();
    return null;
  }

  // === ÇEVRİMDIŞI ZAMAN MOTORU (OFFLINE CATCH-UP SIMULATION) ===
  OfflineCatchUpReport processOfflineCatchUp(
    DateTime fromTime, {
    DateTime? toTime,
    List<Map<String, dynamic>>? offlineSales,
  }) {
    final now = toTime ?? DateTime.now();
    final elapsed = now.difference(fromTime);
    final totalSeconds = max(0.0, elapsed.inSeconds.toDouble());
    final startingCash = cash;
    final Map<String, int> producedItems = {};
    bool warehouseFull = false;

    if (totalSeconds < 3) {
      lastActiveAt = now;
      return OfflineCatchUpReport(
        elapsedDuration: elapsed,
        producedItems: {},
        startingCash: startingCash,
        endingCash: cash,
      );
    }

    // Mikro-adım simülasyonu (Zincirleme: Tarla -> Fabrika -> Depo -> Dükkan -> Nakit)
    const stepSeconds = 4.0;
    final steps = min(1500, max(1, (totalSeconds / stepSeconds).round()));
    final dt = totalSeconds / steps;

    int retailItemsSold = 0;
    double retailRevenue = 0.0;
    int marketItemsSold = 0;
    double marketRevenue = 0.0;

    for (int step = 0; step < steps; step++) {
      // 1. Tesisler (Tarlalar ve Fabrikalar)
      for (var fac in ownedFacilities) {
        if (!fac.isProducing) continue;

        bool canProceed = true;
        fac.recipe.inputs.forEach((inItemId, inCount) {
          int inWarehouse = warehouse[inItemId] ?? 0;
          if (inWarehouse < inCount) canProceed = false;
        });

        if (!canProceed) continue;

        fac.progress += dt / fac.effectiveDuration;
        while (fac.progress >= 1.0) {
          fac.progress -= 1.0;

          // Girdi tüketimi
          fac.recipe.inputs.forEach((inItemId, inCount) {
            warehouse[inItemId] = (warehouse[inItemId] ?? 0) - inCount;
            if (warehouse[inItemId]! <= 0) warehouse.remove(inItemId);
          });

          int outCount = fac.effectiveOutput;
          var outItemData = ItemRegistry.get(fac.recipe.outputItemId);
          double addedWeight = outCount * (outItemData?.weight ?? 1.0);

          if (currentWarehouseWeight + addedWeight <= maxWarehouseCapacity) {
            warehouse[fac.recipe.outputItemId] =
                (warehouse[fac.recipe.outputItemId] ?? 0) + outCount;
            producedItems[fac.recipe.outputItemId] =
                (producedItems[fac.recipe.outputItemId] ?? 0) + outCount;
          } else {
            warehouseFull = true;
            fac.progress = 1.0;
            break;
          }
        }
      }

      // 2. Perakende Dükkanlar (Otomatik Raf Doldurma ve Müşteri Satışları)
      for (var store in ownedStores) {
        if (!store.isSelling) continue;

        for (var slot in store.productSlots) {
          if (slot.autoRestock && slot.shelfStock < slot.shelfCapacity) {
            int need = slot.shelfCapacity - slot.shelfStock;
            int inWh = warehouse[slot.itemId] ?? 0;
            if (inWh > 0) {
              int take = min(need, inWh);
              warehouse[slot.itemId] = inWh - take;
              if (warehouse[slot.itemId]! <= 0) warehouse.remove(slot.itemId);
              slot.shelfStock += take;
            }
          }
        }

        final activeSellingSlots =
            store.productSlots.where((s) => s.isSelling && s.shelfStock > 0).toList();
        for (var slot in activeSellingSlots) {
          final demandRatio = getProductDemandRatio(slot.itemId, slot.retailPrice);
          final slotInterval = max(0.4, store.effectiveInterval / demandRatio);
          slot.saleTimerProgress += dt / slotInterval;

          while (slot.saleTimerProgress >= 1.0 && slot.shelfStock > 0) {
            slot.saleTimerProgress -= 1.0;
            slot.shelfStock--;
            retailRevenue += slot.retailPrice;
            retailItemsSold++;
            cash += slot.retailPrice;
            store.totalRevenue += slot.retailPrice;
            _statsHourlyRevenue += slot.retailPrice;
          }
        }
      }

      // 3. Açık Pazar İlan Satışları (Lokal Simülasyon)
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
        while (listing.saleProgressTimer >= 1.0 && listing.remainingQuantity > 0) {
          listing.saleProgressTimer -= 1.0;
          int batch = min(listing.remainingQuantity, max(1, (priceRatio * 2.5).round()));

          // Depodan satıldıkça düş
          int currentStock = warehouse[listing.itemId] ?? 0;
          int actualDeduct = min(batch, currentStock);
          if (actualDeduct > 0) {
            warehouse[listing.itemId] = currentStock - actualDeduct;
            if (warehouse[listing.itemId]! <= 0) warehouse.remove(listing.itemId);
          }

          listing.remainingQuantity -= batch;
          double earn = batch * listing.pricePerUnit;
          cash += earn;
          listing.totalEarned += earn;
          marketItemsSold += batch;
          marketRevenue += earn;

          if (listing.isCompleted) {
            activeListings.removeAt(i);
            break;
          }
        }
      }
    }

    // 4. Çevrimdışı Pazar Satışları (Firebase Bulut Pazarı)
    if (offlineSales != null && offlineSales.isNotEmpty) {
      for (var sale in offlineSales) {
        final rev = (sale['totalRevenue'] as num?)?.toDouble() ?? 0.0;
        final qty = (sale['quantity'] as num?)?.toInt() ?? 0;
        final saleItemId = sale['itemId'] as String?;
        if (saleItemId != null && qty > 0) {
          int currentStock = warehouse[saleItemId] ?? 0;
          int deduct = min(currentStock, qty);
          if (deduct > 0) {
            warehouse[saleItemId] = currentStock - deduct;
            if (warehouse[saleItemId]! <= 0) warehouse.remove(saleItemId);
          }
        }
        if (!FirebaseService().isCloudConnected) {
          cash += rev;
        }
        marketRevenue += rev;
        marketItemsSold += qty;
      }
    }

    // 5. Banka Vadeli Mevduat Faizi (Her 60 saniyede %0.5)
    double bankInterestEarned = 0.0;
    final bankCycles = (totalSeconds / 60.0).floor();
    if (bankCycles > 0 && bankSavings > 0) {
      final initialSavings = bankSavings;
      for (int i = 0; i < min(bankCycles, 720); i++) {
        bankSavings += bankSavings * 0.005;
      }
      bankInterestEarned = bankSavings - initialSavings;
    }

    // 6. Kredi Taksit Döngüsü (Her 45 saniyede bir gün/taksit)
    int loanInstallmentsPaid = 0;
    int loanInstallmentsOverdue = 0;
    double loanPenaltiesIncurred = 0.0;
    double totalLoanPaidAmount = 0.0;

    if (currentLoan != null && !currentLoan!.isFullyPaid) {
      final loanCycles = (totalSeconds / BankLoan.installmentInterval).floor();
      for (int i = 0; i < loanCycles && !currentLoan!.isFullyPaid; i++) {
        final nextIdx = currentLoan!.paidInstallments;
        if (nextIdx >= currentLoan!.schedule.length) break;

        final installment = currentLoan!.schedule[nextIdx];
        final amountToPay = installment.effectiveTotalAmount;

        if (cash >= amountToPay) {
          cash -= amountToPay;
          totalLoanPaidAmount += amountToPay;
          installment.isPaid = true;
          installment.isOverdue = false;
          currentLoan!.paidInstallments++;
          currentLoan!.remainingPrincipal =
              max(0.0, currentLoan!.remainingPrincipal - installment.principalAmount);
          currentLoan!.remainingInterest =
              max(0.0, currentLoan!.remainingInterest - installment.interestAmount);
          loanInstallmentsPaid++;
          if (currentLoan!.isFullyPaid) {
            currentLoan = null;
            break;
          }
        } else {
          installment.isOverdue = true;
          installment.overdueCycles++;
          final penaltyIncrement =
              max(50.0, (installment.totalAmount * 0.05).roundToDouble());
          installment.penaltyAmount += penaltyIncrement;
          currentLoan!.totalPenalty += penaltyIncrement;
          loanInstallmentsOverdue++;
          loanPenaltiesIncurred += penaltyIncrement;
        }
      }
    }

    lastActiveAt = now;
    if (netWorth > highestNetWorth) {
      highestNetWorth = netWorth;
    }

    final report = OfflineCatchUpReport(
      elapsedDuration: elapsed,
      producedItems: producedItems,
      warehouseFull: warehouseFull,
      retailItemsSold: retailItemsSold,
      retailRevenue: retailRevenue,
      marketItemsSold: marketItemsSold,
      marketRevenue: marketRevenue,
      incomingOffersCount: 0,
      bankInterestEarned: bankInterestEarned,
      loanInstallmentsPaid: loanInstallmentsPaid,
      loanInstallmentsOverdue: loanInstallmentsOverdue,
      loanPenaltiesIncurred: loanPenaltiesIncurred,
      totalLoanPaidAmount: totalLoanPaidAmount,
      startingCash: startingCash,
      endingCash: cash,
    );

    if (report.hasAnyActivity) {
      latestOfflineReport = report;

      AuditLogService().log(
        category: LogCategory.system,
        action: 'OFFLINE_CATCHUP',
        title: 'Çevrimdışı Şirket Kazancı',
        description: 'Siz yokken işletmeleriniz ${(retailRevenue + marketRevenue).toStringAsFixed(0)} ₺ ciro yaptı.',
        amountChange: cash - startingCash,
        cashAfter: cash,
        details: {
          'retailRevenue': retailRevenue,
          'marketRevenue': marketRevenue,
          'bankInterestEarned': bankInterestEarned,
          'totalLoanPaidAmount': totalLoanPaidAmount,
        },
      );
    } else if (elapsed.inSeconds >= 4) {
      if (ownedFacilities.any((f) => f.isProducing)) {
        latestNotificationToast =
            '⏱️ Tekrar hoş geldiniz! (${report.formattedDuration} çevrimdışı kaldınız). Tesislerinizin üretim süreci ilerletildi.';
      } else if (ownedFacilities.isEmpty && ownedStores.isEmpty) {
        latestNotificationToast =
            '⏱️ Tekrar hoş geldiniz! (${report.formattedDuration} çevrimdışı kaldınız). Çevrimdışı pasif kazanç için Üretim sekmesinden tarla veya fabrika kurabilirsiniz.';
      } else {
        latestNotificationToast =
            '⏱️ Tekrar hoş geldiniz! (${report.formattedDuration} çevrimdışı kaldınız). İşletmeleriniz hazır bekliyor.';
      }
    }

    notifyListeners();
    saveState();
    return report;
  }

  // === OYUN KAYDI & YEREL + BULUT DEPOLAMA (HYBRID PERSISTENCE) ===
  void saveState({String? targetPlayerId}) {
    lastActiveAt = DateTime.now();
    final pid = targetPlayerId ?? FirebaseService().playerId;
    final saveData = toSaveJson();
    SaveService().saveDirectData(saveData, playerId: pid);
    FirebaseService().syncPlayerAssetsToCloud(saveData, targetPlayerId: pid);
  }

  Future<void> onAppResumed() async {
    if (lastActiveAt != null) {
      final resumeTime = DateTime.now();
      final elapsed = resumeTime.difference(lastActiveAt!);
      final offlineSales = await FirebaseService().claimOfflineSales();
      if (elapsed.inSeconds >= 3) {
        processOfflineCatchUp(lastActiveAt!, toTime: resumeTime, offlineSales: offlineSales);
      }
    }
    lastActiveAt = DateTime.now();
    saveState();
  }

  /// Yeni bir oyuncu için tertemiz, fabrikasız, dükkansız başlangıç durumu oluşturur
  void resetToNewGame() {
    cash = 10000.0;
    bankSavings = 0.0;
    _legacyActiveLoan = 0.0;
    currentLoan = null;
    highestNetWorth = 10000.0;
    maxWarehouseCapacity = 5000.0; // 5.000 kg başlangıç deposu
    lastActiveAt = DateTime.now();
    latestOfflineReport = null;
    latestNotificationToast = null;
    warehouse.clear();
    ownedFacilities.clear();
    ownedStores.clear();
    activeListings.clear();
    offers.clear();
    limitBuyOrders.clear();
    isDarkMode = false;
    themeModeNotifier.value = false;
    _initializeMarket();
    _initializeCommunityListings();
    notifyListeners();
  }

  Future<bool> loadFromStorage({String? playerId}) async {
    final pid = playerId ?? FirebaseService().playerId;

    // 1. Yerel cihazdaki son kaydı oku ve anında belleğe yükle (0 ms gecikme)
    final localData = await SaveService().getLocalSaveData(playerId: pid);
    if (localData != null) {
      loadFromSaveJson(localData);
    }

    // 2. Buluttaki oyuncu verisini oku
    Map<String, dynamic>? cloudData;
    try {
      cloudData = await FirebaseService().fetchPlayerAssetsFromCloud(targetPlayerId: pid);
    } catch (e) {
      debugPrint('Cloud data fetch error: $e');
    }

    // 3. Akıllı Hibrit Karşılaştırma & Yükleme
    if (localData != null && cloudData != null) {
      final localFacilities = (localData['ownedFacilities'] as List?)?.length ?? 0;
      final cloudFacilities = (cloudData['ownedFacilities'] as List?)?.length ?? 0;
      final localStores = (localData['ownedStores'] as List?)?.length ?? 0;
      final cloudStores = (cloudData['ownedStores'] as List?)?.length ?? 0;
      final localAssets = localFacilities + localStores;
      final cloudAssets = cloudFacilities + cloudStores;

      final localSavedAt = DateTime.tryParse(localData['savedAt'] as String? ?? '');
      final cloudSavedAt = DateTime.tryParse(cloudData['savedAt'] as String? ?? '');

      // KURAL 1: Yerelde tesisler/tarlalar var ve buluttakinden fazlaysa, ASLA yereli ezme!
      if (localAssets > cloudAssets) {
        loadFromSaveJson(localData);
        saveState(targetPlayerId: pid); // Bulutu da yerelle eşitle
      } else if (cloudAssets > localAssets) {
        loadFromSaveJson(cloudData);
        await SaveService().saveDirectData(cloudData, playerId: pid);
      } else if (localSavedAt != null && cloudSavedAt != null) {
        if (localSavedAt.isAfter(cloudSavedAt) || localSavedAt.isAtSameMomentAs(cloudSavedAt)) {
          loadFromSaveJson(localData);
          saveState(targetPlayerId: pid);
        } else {
          loadFromSaveJson(cloudData);
          await SaveService().saveDirectData(cloudData, playerId: pid);
        }
      } else {
        // Tarih yoksa servet ve nakdi daha yüksek olan tarafı yükle
        final localNet = (localData['netWorth'] as num?)?.toDouble() ?? 0.0;
        final cloudNet = (cloudData['netWorth'] as num?)?.toDouble() ?? 0.0;
        if (localNet >= cloudNet) {
          loadFromSaveJson(localData);
          saveState(targetPlayerId: pid);
        } else {
          loadFromSaveJson(cloudData);
          await SaveService().saveDirectData(cloudData, playerId: pid);
        }
      }
    } else if (localData != null) {
      loadFromSaveJson(localData);
      saveState(targetPlayerId: pid); // Buluta da aktar
    } else if (cloudData != null && (cloudData.containsKey('ownedFacilities') || cloudData.containsKey('warehouse') || cloudData.containsKey('savedAt'))) {
      loadFromSaveJson(cloudData);
      await SaveService().saveDirectData(cloudData, playerId: pid);
    } else {
      // Yerel veya bulutta veri bulunamadıysa cihazdaki genel son aktif yedeği ara
      final fallbackData = await SaveService().getLastFallbackSaveData(forPlayerId: pid);
      if (fallbackData != null) {
        loadFromSaveJson(fallbackData);
        await SaveService().saveDirectData(fallbackData, playerId: pid);
        saveState(targetPlayerId: pid);
        return true;
      }

      // Gerçekten sıfır / yeni bir oyuncu profili!
      resetToNewGame();
      final freshData = toSaveJson();
      await SaveService().saveDirectData(freshData, playerId: pid);
      saveState(targetPlayerId: pid);
      return true;
    }

    // 4. Çevrimdışı pazar satışlarını çek
    final offlineSales = await FirebaseService().claimOfflineSales();

    // 5. Oyun kapalıyken geçen süre boyunca Tesisleri, Dükkanları ve Bankayı çalıştır!
    if (lastActiveAt != null) {
      final elapsed = DateTime.now().difference(lastActiveAt!);
      if (elapsed.inSeconds >= 5) {
        processOfflineCatchUp(lastActiveAt!, offlineSales: offlineSales);
      }
    } else {
      lastActiveAt = DateTime.now();
    }

    _setupCloudMarketSync();

    return true;
  }

  void _setupCloudMarketSync() {
    if (FirebaseService().isCloudConnected) {
      _cloudMarketSub?.cancel();
      _cloudMarketSub = FirebaseService().streamPublicMarketListings().listen((cloudListings) {
        final myId = FirebaseService().playerId;
        final activeCloudOthers = cloudListings.where((l) {
          final isMine = l.isPlayerListing || (l.sellerId != null && l.sellerId == myId);
          return !isMine && !l.isCompleted && l.sellerId != null && l.sellerId != 'SYSTEM';
        }).toList();
        final cloudOtherIds = activeCloudOthers.map((l) => l.id).toSet();

        // 1. Bulutta tamamlanmış, silinmiş veya eski sahte simüle edilmiş ilanları temizle
        communityListings.removeWhere((l) =>
            !l.isOfficialReserve && (l.sellerId == null || l.id.startsWith('comm_') || !cloudOtherIds.contains(l.id)));

        // 2. Yeni ve güncellenen diğer gerçek oyuncu ilanlarını listeye entegre et
        for (var cListing in activeCloudOthers) {
          final idx = communityListings.indexWhere((l) => l.id == cListing.id);
          if (idx >= 0) {
            communityListings[idx] = cListing;
          } else {
            // Gerçek oyuncu ilanlarını listenin en başına yerleştir
            communityListings.insert(0, cListing);
          }
        }
        notifyListeners();
      });
    }
  }

  Future<void> resetProgress({String? playerId}) async {
    final pid = playerId ?? FirebaseService().playerId;
    await SaveService().clear(playerId: pid);
    resetToNewGame();
    await SaveService().save(this, playerId: pid);
  }

  Map<String, dynamic> toSaveJson() {
    return {
      'version': 1,
      'savedAt': DateTime.now().toIso8601String(),
      'lastActiveAt': (lastActiveAt ?? DateTime.now()).toIso8601String(),
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
      'highestNetWorth': highestNetWorth,
      'netWorth': netWorth,
      'playerLevel': playerLevel,
      'playerTitle': playerTitle,
      'totalFacilitiesCount': ownedFacilities.length,
      'totalStoresCount': ownedStores.length,
    };
  }

  void loadFromSaveJson(Map<String, dynamic> data) {
    if (data.containsKey('lastActiveAt') && data['lastActiveAt'] != null) {
      lastActiveAt = DateTime.tryParse(data['lastActiveAt'].toString()) ?? lastActiveAt;
    }
    if (data.containsKey('highestNetWorth') && data['highestNetWorth'] != null) {
      highestNetWorth = (data['highestNetWorth'] as num).toDouble();
    }
    if (data.containsKey('cash') && data['cash'] != null) {
      cash = (data['cash'] as num).toDouble();
    }
    if (data.containsKey('bankSavings') && data['bankSavings'] != null) {
      bankSavings = (data['bankSavings'] as num).toDouble();
    }
    if (data.containsKey('maxWarehouseCapacity') && data['maxWarehouseCapacity'] != null) {
      maxWarehouseCapacity = (data['maxWarehouseCapacity'] as num).toDouble();
      if (maxWarehouseCapacity < 5000.0) {
        maxWarehouseCapacity = 5000.0;
      }
    } else {
      maxWarehouseCapacity = 5000.0;
    }
    if (data.containsKey('isDarkMode')) {
      isDarkMode = data['isDarkMode'] as bool? ?? isDarkMode;
      themeModeNotifier.value = isDarkMode;
    }

    if (data['currentLoan'] != null && data['currentLoan'] is Map) {
      try {
        currentLoan = BankLoan.fromJson(Map<String, dynamic>.from(data['currentLoan'] as Map));
      } catch (e) {
        debugPrint('Error loading currentLoan: $e');
      }
    } else if (data.containsKey('currentLoan') && data['currentLoan'] == null) {
      currentLoan = null;
    }

    if (data['warehouse'] != null && data['warehouse'] is Map) {
      warehouse.clear();
      final wh = Map<String, dynamic>.from(data['warehouse'] as Map);
      wh.forEach((k, v) {
        final cnt = (v as num?)?.toInt() ?? 0;
        if (cnt > 0) warehouse[k] = cnt;
      });
    }

    if (data['marketItems'] != null && data['marketItems'] is Map) {
      final mItems = Map<String, dynamic>.from(data['marketItems'] as Map);
      mItems.forEach((k, v) {
        if (v is Map && marketItems.containsKey(k)) {
          try {
            marketItems[k] = MarketItem.fromJson(Map<String, dynamic>.from(v as Map));
          } catch (_) {}
        }
      });
    }

    if (data['ownedFacilities'] != null && data['ownedFacilities'] is List) {
      final rawList = data['ownedFacilities'] as List;
      final loaded = <ProductionFacility>[];
      for (var f in rawList) {
        try {
          if (f is Map) {
            final facMap = Map<String, dynamic>.from(f);
            final fac = ProductionFacility.fromJson(facMap);
            if (fac != null) loaded.add(fac);
          }
        } catch (e) {
          debugPrint('Error loading facility: $e');
        }
      }
      if (loaded.isNotEmpty || rawList.isEmpty) {
        ownedFacilities.clear();
        ownedFacilities.addAll(loaded);
      }
    }

    if (data['ownedStores'] != null && data['ownedStores'] is List) {
      final rawList = data['ownedStores'] as List;
      final loaded = <RetailStore>[];
      for (var s in rawList) {
        try {
          if (s is Map) {
            final storeMap = Map<String, dynamic>.from(s);
            final store = RetailStore.fromJson(storeMap);
            if (store != null) loaded.add(store);
          }
        } catch (e) {
          debugPrint('Error loading store: $e');
        }
      }
      if (loaded.isNotEmpty || rawList.isEmpty) {
        ownedStores.clear();
        ownedStores.addAll(loaded);
      }
    }

    if (data['activeListings'] != null && data['activeListings'] is List) {
      final rawList = data['activeListings'] as List;
      final loaded = <MarketListing>[];
      for (var l in rawList) {
        try {
          if (l is Map) {
            loaded.add(MarketListing.fromJson(Map<String, dynamic>.from(l)));
          }
        } catch (e) {
          debugPrint('Error loading activeListing: $e');
        }
      }
      if (loaded.isNotEmpty || rawList.isEmpty) {
        activeListings.clear();
        activeListings.addAll(loaded);
      }
    }

    if (data['communityListings'] != null && data['communityListings'] is List) {
      final rawList = data['communityListings'] as List;
      final loaded = <MarketListing>[];
      for (var c in rawList) {
        try {
          if (c is Map) {
            final listing = MarketListing.fromJson(Map<String, dynamic>.from(c));
            // Sadece resmi piyasa rezervleri veya gerçek kayıtlı oyuncuların ilanları alınır
            if (listing.isOfficialReserve || (listing.sellerId != null && listing.sellerId != 'SYSTEM' && !listing.id.startsWith('comm_'))) {
              loaded.add(listing);
            }
          }
        } catch (e) {
          debugPrint('Error loading communityListing: $e');
        }
      }
      if (loaded.isNotEmpty) {
        communityListings.clear();
        communityListings.addAll(loaded);
      }
    }

    if (data['offers'] != null && data['offers'] is List) {
      final rawList = data['offers'] as List;
      final loaded = <MarketOffer>[];
      for (var o in rawList) {
        try {
          if (o is Map) {
            loaded.add(MarketOffer.fromJson(Map<String, dynamic>.from(o)));
          }
        } catch (e) {
          debugPrint('Error loading offer: $e');
        }
      }
      if (loaded.isNotEmpty || rawList.isEmpty) {
        offers.clear();
        offers.addAll(loaded);
      }
    }

    if (data['limitBuyOrders'] != null && data['limitBuyOrders'] is List) {
      final rawList = data['limitBuyOrders'] as List;
      final loaded = <LimitBuyOrder>[];
      for (var ord in rawList) {
        try {
          if (ord is Map) {
            loaded.add(LimitBuyOrder.fromJson(Map<String, dynamic>.from(ord)));
          }
        } catch (e) {
          debugPrint('Error loading limitBuyOrder: $e');
        }
      }
      if (loaded.isNotEmpty || rawList.isEmpty) {
        limitBuyOrders.clear();
        limitBuyOrders.addAll(loaded);
      }
    }

    if (netWorth > highestNetWorth) {
      highestNetWorth = netWorth;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    saveState();
    _gameLoopTimer?.cancel();
    _cloudMarketSub?.cancel();
    themeModeNotifier.dispose();
    super.dispose();
  }
}
