import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/item.dart';
import '../models/market_item.dart';
import '../models/facility.dart';
import '../models/store.dart';

class GameController extends ChangeNotifier {
  // Finans
  double cash = 25000.0;
  double bankSavings = 0.0;
  double activeLoan = 0.0;
  double maxWarehouseCapacity = 1500.0; // kg

  // Depo (Hammadde ve Ürünler)
  final Map<String, int> warehouse = {};

  // Borsa ve Toptan Pazar
  final Map<String, MarketItem> marketItems = {};

  // Mülkler
  final List<ProductionFacility> ownedFacilities = [];
  final List<RetailStore> ownedStores = [];

  // Sayaçlar ve Simülasyon
  Timer? _gameLoopTimer;
  final Random _random = Random();
  double _marketTickTimer = 0.0;
  double _bankTickTimer = 0.0;
  double _statsHourlyRevenue = 0.0;

  GameController() {
    _initializeMarket();
    // Başlangıçta oyuncuya 1 adet hazır Buğday Tarlası hediye verelim ki oyunu hemen anlayabilsin!
    final defaultFarm = ProductionFacility.getBlueprints().first.copy();
    ownedFacilities.add(defaultFarm);

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

      // Girdi kontrolü (Fabrika ise ve döngü başıysa)
      if (fac.progress == 0.0 && fac.recipe.inputs.isNotEmpty) {
        bool hasAllInputs = true;
        fac.recipe.inputs.forEach((inId, needCount) {
          if ((warehouse[inId] ?? 0) < needCount) {
            hasAllInputs = false;
          }
        });

        if (!hasAllInputs) {
          fac.statusMessage = 'Hammadde Bekleniyor';
          continue;
        }
      }

      // Çıktı için depoda yer var mı?
      int outCount = fac.effectiveOutput;
      var outItem = ItemRegistry.get(fac.recipe.outputItemId)!;
      double neededWeight = outCount * outItem.weight;

      if (currentWarehouseWeight + neededWeight > maxWarehouseCapacity) {
        fac.statusMessage = 'Depo Dolu!';
        continue;
      }

      // İlerleme
      fac.progress += dt / fac.effectiveDuration;
      fac.statusMessage = 'Üretiliyor (%${(fac.progress * 100).toInt()})';

      if (fac.progress >= 1.0) {
        fac.progress = 0.0;

        // Girdileri depodan düş
        fac.recipe.inputs.forEach((inId, needCount) {
          warehouse[inId] = (warehouse[inId] ?? 0) - needCount;
          if (warehouse[inId]! <= 0) warehouse.remove(inId);
        });

        // Çıktıyı depoya ekle
        warehouse[fac.recipe.outputItemId] = (warehouse[fac.recipe.outputItemId] ?? 0) + outCount;
        fac.statusMessage = 'Hasat/Üretim Tamamlandı! (+$outCount)';
      }
    }

    // 2. Perakende Dükkanlar
    for (var store in ownedStores) {
      // Rafta yer varsa ve otomatik doldurma açıksa depodan çek
      if (store.autoRestock && store.shelfStock < store.shelfCapacity * 0.4) {
        int need = store.shelfCapacity - store.shelfStock;
        int inWarehouse = warehouse[store.productItemId] ?? 0;
        if (inWarehouse > 0) {
          int take = min(need, inWarehouse);
          warehouse[store.productItemId] = inWarehouse - take;
          if (warehouse[store.productItemId]! <= 0) warehouse.remove(store.productItemId);
          store.shelfStock += take;
        }
      }

      // Raf boşsa bekle
      if (store.shelfStock <= 0) {
        store.statusMessage = 'Raf Boş! Ürün bekleniyor';
        store.timerProgress = 0.0;
        continue;
      }

      // Müşteri satışı
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

    // 3. Borsa Fiyat Dalgalanması (Her 15 saniyede bir)
    _marketTickTimer += dt;
    if (_marketTickTimer >= 15.0) {
      _marketTickTimer = 0.0;
      for (var item in marketItems.values) {
        item.updatePrice(rnd: _random);
      }
    }

    // 4. Banka Faiz Döngüsü (Her 60 saniyede bir)
    _bankTickTimer += dt;
    if (_bankTickTimer >= 60.0) {
      _bankTickTimer = 0.0;
      if (bankSavings > 0) {
        bankSavings += bankSavings * 0.005; // %0.5 saatlik faiz
      }
      if (activeLoan > 0) {
        activeLoan += activeLoan * 0.012; // %1.2 kredi faiz masrafı
      }
    }

    notifyListeners();
  }

  // === DEPONUN AĞIRLIĞI VE HESAPLAR ===
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
    mItem.updatePrice(bias: 0.02, rnd: _random); // Talep fiyatı yükseltir
    notifyListeners();
    return null; // Başarılı
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

    double totalEarnings = mItem.wholesaleSellPrice * qty;
    warehouse[itemId] = currentStock - qty;
    if (warehouse[itemId]! <= 0) warehouse.remove(itemId);

    cash += totalEarnings;
    mItem.updatePrice(bias: -0.02, rnd: _random); // Arz fiyatı düşürür
    notifyListeners();
    return null; // Başarılı
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
