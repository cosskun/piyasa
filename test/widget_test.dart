import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piyasa/main.dart';
import 'package:piyasa/controllers/game_controller.dart';
import 'package:piyasa/views/market_tab.dart';
import 'package:piyasa/views/production_tab.dart';
import 'package:piyasa/views/retail_tab.dart';
import 'package:piyasa/views/warehouse_tab.dart';
import 'package:piyasa/models/market_offer.dart';
import 'package:piyasa/models/store.dart';
import 'package:piyasa/models/facility.dart';
import 'package:piyasa/models/bank_loan.dart';
import 'package:piyasa/models/offline_report.dart';
import 'package:piyasa/views/bank_dialog.dart';
import 'package:piyasa/views/home_screen.dart';
import 'package:piyasa/views/offline_summary_dialog.dart';
import 'package:piyasa/services/save_service.dart';
import 'package:piyasa/services/firebase_service.dart';
import 'package:piyasa/services/audit_log_service.dart';
import 'package:piyasa/services/notification_service.dart';
import 'package:piyasa/models/audit_log.dart';
import 'package:piyasa/views/auth_screen.dart';
import 'package:piyasa/views/ledger_dialog.dart';
import 'package:piyasa/views/admin_dashboard_view.dart';
import 'package:piyasa/views/banned_dialog.dart';
import 'package:piyasa/views/game_loading_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SaveService().resetForTesting();
    AuditLogService().resetForTesting();
  });

  testWidgets('Piyasa App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PiyasaApp());
    expect(find.text('PİYASA'), findsOneWidget);
  });

  testWidgets('MarketTab top tabs layout and badge containment test on narrow screens', (WidgetTester tester) async {
    // Set typical compact mobile screen size: 360 x 800
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketTab(controller: controller),
        ),
      ),
    );

    // Verify all 3 top tabs are rendered
    expect(find.text('Borsa'), findsOneWidget);
    expect(find.text('Oyuncu Pazarı'), findsOneWidget);
    expect(find.text('Teklifler'), findsOneWidget);

    // Verify Oyuncu Pazarı shows badge with communityListings count
    expect(find.text('${controller.communityListings.length}'), findsWidgets);

    // Tap on Oyuncu Pazarı tab
    await tester.tap(find.text('Oyuncu Pazarı'));
    await tester.pumpAndSettle();

    // Verify subtabs of Oyuncu Pazarı are shown without overflow
    expect(find.textContaining('Oyuncu İlanları'), findsOneWidget);

    // Tap on Teklifler tab
    await tester.tap(find.text('Teklifler'));
    await tester.pumpAndSettle();

    // Verify subtabs of Teklifler are shown without overflow
    expect(find.textContaining('Gelen Teklifler'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('ProductionTab shows empty state with 10.000 TL, opens facility catalog, shows production rates per minute, and allows purchasing facilities', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameController();
    expect(controller.cash, 10000.0);
    expect(controller.ownedFacilities.isEmpty, true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionTab(controller: controller),
        ),
      ),
    );

    // Verify empty state title and 10.000 TL starting capital are shown
    expect(find.text('Henüz bir üretim tesisiniz yok!'), findsOneWidget);
    expect(find.textContaining('10.000 ₺'), findsWidgets);

    // Verify "İlk Tesisini Satın Al" button is displayed
    final buyButton = find.text('🌾 İlk Tesisini Satın Al');
    expect(buyButton, findsOneWidget);

    // Tap on "İlk Tesisini Satın Al" button
    await tester.tap(buyButton);
    await tester.pumpAndSettle();

    // Verify facility catalog sheet opened
    expect(find.textContaining('Yeni Tesis Satın Al'), findsOneWidget);
    expect(find.textContaining('Dakikada:'), findsWidgets);

    // Tap on Buğday Tarlası card to purchase directly (1 unit without quantity selection)
    await tester.tap(find.text('Buğday Tarlası').first);
    await tester.pumpAndSettle();

    // Verify ownedFacilities now has 1 facility and cash is 5,000 TL (10000 - 5000)
    expect(controller.ownedFacilities.length, 1);
    expect(controller.cash, 5000.0);

    // Verify the list shows Tesislerim (1) and total capacity
    expect(find.text('Tesislerim (1)'), findsOneWidget);
    expect(find.textContaining('Toplam Üretim Kapasitesi:'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('MarketTab allows manually typing quantity and price in Pazara Cikar dialog', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameController();
    controller.warehouse['wheat'] = 100;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketTab(controller: controller),
        ),
      ),
    );

    // Tap on wheat item card to open commodity detail sheet
    await tester.tap(find.text('Buğday').first);
    await tester.pumpAndSettle();

    // Scroll to and tap on "Oyuncu Pazarına İlan Ver" tile
    await tester.ensureVisible(find.text('Oyuncu Pazarına İlan Ver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oyuncu Pazarına İlan Ver'));
    await tester.pumpAndSettle();

    // Verify dialog title is shown
    expect(find.textContaining('Buğday Pazara Çıkar'), findsOneWidget);

    // Verify there are 2 TextFields (one for quantity, one for price)
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));

    // Manually enter quantity '75'
    await tester.enterText(textFields.first, '75');
    await tester.pumpAndSettle();

    // Manually enter unit price '8.50'
    await tester.enterText(textFields.last, '8.50');
    await tester.pumpAndSettle();

    // Verify calculated total revenue: 75 * 8.50 = 637.50
    expect(find.textContaining('637.50 ₺'), findsOneWidget);

    // Submit listing
    await tester.tap(find.text('İlanı Pazara Çıkar'));
    await tester.pumpAndSettle();

    // Verify listing was created with 75 quantity and 8.50 price
    final listing = controller.activeListings.firstWhere((l) => l.isPlayerListing);
    expect(listing.initialQuantity, 75);
    expect(listing.pricePerUnit, 8.50);

    controller.dispose();
  });

  testWidgets('Incoming offers do not reserve inventory and auto-expire when listing sells at market price', (tester) async {
    final controller = GameController();
    controller.warehouse['wheat'] = 50;

    // Create listing for 50 wheat at 1.00 ₺ (cheap so it sells quickly in tick)
    controller.createListing('wheat', 50, 1.00);
    final listing = controller.activeListings.firstWhere((l) => l.itemId == 'wheat');
    expect(listing.remainingQuantity, 50);

    // Incoming offer arrives for 40 wheat at 0.80 ₺
    final incomingOffer = MarketOffer(
      id: 'inc_test_1',
      listingId: listing.id,
      itemId: 'wheat',
      buyerName: 'Ahmet Usta Fırıncılık',
      sellerName: 'Siz',
      quantity: 40,
      originalPricePerUnit: 1.00,
      offeredPricePerUnit: 0.80,
      direction: OfferDirection.incoming,
      status: OfferStatus.pending,
      createdAt: DateTime.now(),
    );
    controller.offers.insert(0, incomingOffer);

    expect(incomingOffer.status, OfferStatus.pending);

    // Render MarketTab
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => MarketTab(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Teklifler tab
    await tester.tap(find.textContaining('Teklifler'));
    await tester.pumpAndSettle();

    // Verify the unreserved disclaimer banner is displayed on the pending offer card
    expect(find.textContaining('Ürünler rezerve edilmez'), findsOneWidget);

    // Simulate market tick where goods sell out at normal listing price
    for (int t = 0; t < 10; t++) {
      listing.saleProgressTimer = 1.0;
      controller.tickForTesting(5.0);
    }

    // Listing sold out (or remaining < 40), offer must be auto-expired
    expect(incomingOffer.status, OfferStatus.expired);

    // Re-pump widget to verify expired card UI
    await tester.pumpAndSettle();
    expect(find.textContaining('Normal Fiyattan Başkasına Satıldı (Teklif Düştü)'), findsOneWidget);

    // Trying to accept expired offer returns graceful message
    final err = controller.acceptIncomingOffer(incomingOffer);
    expect(err, isNotNull);
    expect(err, contains('tam fiyattan satıldığı için'));

    controller.dispose();
  });

  testWidgets('RetailTab renders store card with separated level badge and upgrade button', (tester) async {
    final controller = GameController();
    final blueprint = RetailStore.getBlueprints().first;
    controller.cash = 100000;
    controller.buyStore(blueprint);
    expect(controller.ownedStores.length, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RetailTab(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(blueprint.name), findsOneWidget);
    expect(find.text('Sv. 1'), findsOneWidget);
    expect(find.textContaining('₺'), findsWidgets);

    controller.dispose();
  });

  testWidgets('Facility resale calculates 70% refund of invested capital and removes facility', (tester) async {
    final controller = GameController();
    final wheatFarmBp = ProductionFacility.getBlueprints().firstWhere((b) => b.id == 'wheat_farm');
    
    // Starting cash: 10000. Buy wheat farm (cost: 5000)
    controller.buyFacility(wheatFarmBp);
    expect(controller.ownedFacilities.length, 1);
    expect(controller.cash, 5000.0);

    final fac = controller.ownedFacilities.first;
    expect(fac.level, 1);
    expect(fac.totalInvestedValue, 5000.0);
    expect(fac.resaleValue, 3500.0); // 70% of 5000

    // Upgrade facility to level 2 (cost: 2500)
    controller.upgradeFacility(fac);
    expect(fac.level, 2);
    expect(controller.cash, 2500.0);
    expect(fac.totalInvestedValue, 7500.0); // 5000 + 2500
    expect(fac.resaleValue, 5250.0); // 70% of 7500

    // Render ProductionTab
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionTab(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify "Tesisi Sat (5.250 ₺)" button is displayed
    final sellButton = find.textContaining('Tesisi Sat (5.250 ₺)');
    expect(sellButton, findsOneWidget);

    // Tap sell button to open confirmation dialog
    await tester.tap(sellButton);
    await tester.pumpAndSettle();

    // Verify dialog content
    expect(find.textContaining('Satılsın mı?'), findsOneWidget);
    expect(find.textContaining('7.500 ₺'), findsWidgets); // Total invested
    expect(find.textContaining('-%30 (Amortisman)'), findsOneWidget);
    expect(find.textContaining('+5.250 ₺'), findsOneWidget); // Refund amount

    // Confirm sale
    await tester.tap(find.text('Evet, Tesisi Sat'));
    await tester.pumpAndSettle();

    // Verify facility removed and cash updated (2500 + 5250 = 7750)
    expect(controller.ownedFacilities.isEmpty, true);
    expect(controller.cash, 7750.0);

    controller.dispose();
  });

  testWidgets('Store resale calculates 70% refund, returns shelf stock to warehouse and removes store', (tester) async {
    final controller = GameController();
    final kioskBp = RetailStore.getBlueprints().firstWhere((b) => b.id == 'kiosk_bread');
    
    // Buy bread kiosk (cost: 4500)
    controller.buyStore(kioskBp);
    expect(controller.ownedStores.length, 1);
    expect(controller.cash, 5500.0);

    final store = controller.ownedStores.first;
    expect(store.totalInvestedValue, 4500.0);
    expect(store.resaleValue, 3150.0); // 70% of 4500

    // Put 15 breads on the shelf
    store.shelfStock = 15;
    expect(controller.warehouse['bread'] ?? 0, 0);

    // Render RetailTab
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RetailTab(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify "Dükkanı Devret / Sat" button
    final sellButton = find.textContaining('Dükkanı Devret / Sat (3.150 ₺)');
    expect(sellButton, findsOneWidget);

    // Tap sell button to open confirmation dialog
    await tester.tap(sellButton);
    await tester.pumpAndSettle();

    // Verify dialog content
    expect(find.textContaining('Devredilsin mi?'), findsOneWidget);
    expect(find.textContaining('4.500 ₺'), findsWidgets);
    expect(find.textContaining('+3.150 ₺'), findsOneWidget);
    expect(find.textContaining('15 adet ürün deponuza geri aktarılacak'), findsOneWidget);

    // Confirm sale
    await tester.tap(find.text('Evet, Dükkanı Sat'));
    await tester.pumpAndSettle();

    // Verify store removed, cash refunded (5500 + 3150 = 8650), and 15 breads in warehouse
    expect(controller.ownedStores.isEmpty, true);
    expect(controller.cash, 8650.0);
    expect(controller.warehouse['bread'], 15);

    controller.dispose();
  });

  testWidgets('Game persistence saves state on actions and restores completely upon reload', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final controller1 = GameController(autoLoad: false);
    final wheatFarmBp = ProductionFacility.getBlueprints().firstWhere((b) => b.id == 'wheat_farm');
    final kioskBp = RetailStore.getBlueprints().firstWhere((b) => b.id == 'kiosk_bread');

    // Perform game actions
    controller1.cash = 30000.0;
    controller1.buyFacility(wheatFarmBp);
    controller1.buyStore(kioskBp);
    controller1.warehouse['wheat'] = 120;
    controller1.warehouse['flour'] = 45;
    controller1.depositToBank(5000.0);
    controller1.createListing('wheat', 40, 9.50);
    controller1.toggleTheme();

    // Verify state in controller 1
    expect(controller1.ownedFacilities.length, 1);
    expect(controller1.ownedStores.length, 1);
    expect(controller1.warehouse['wheat'], 120); // Pazara koyulduğunda depodan düşmez, satıldıkça düşer
    expect(controller1.warehouse['flour'], 45);
    expect(controller1.bankSavings, 5000.0);
    expect(controller1.activeListings.length, 1);
    expect(controller1.isDarkMode, true);

    // Explicitly ensure save has run
    await SaveService().save(controller1);

    // Simulate closing app and reopening with fresh controller
    final controller2 = GameController(autoLoad: false);
    // Before loading, fresh controller has starting defaults
    expect(controller2.ownedFacilities.isEmpty, true);
    expect(controller2.ownedStores.isEmpty, true);
    expect(controller2.warehouse.isEmpty, true);
    expect(controller2.bankSavings, 0.0);
    expect(controller2.isDarkMode, false);

    // Load from storage
    final loaded = await SaveService().load(controller2);
    expect(loaded, true);

    // Verify that ALL progress was restored!
    expect(controller2.cash, controller1.cash);
    expect(controller2.bankSavings, 5000.0);
    expect(controller2.isDarkMode, true);
    expect(controller2.ownedFacilities.length, 1);
    expect(controller2.ownedFacilities.first.name, 'Buğday Tarlası');
    expect(controller2.ownedStores.length, 1);
    expect(controller2.ownedStores.first.name, 'Köşe Büfe & Fırın');
    expect(controller2.warehouse['wheat'], 120);
    expect(controller2.warehouse['flour'], 45);
    expect(controller2.activeListings.length, 1);
    expect(controller2.activeListings.first.pricePerUnit, 9.50);

    // Test reset progress
    await controller2.resetProgress();
    expect(controller2.ownedFacilities.isEmpty, true);
    expect(controller2.ownedStores.isEmpty, true);
    expect(controller2.warehouse.isEmpty, true);
    expect(controller2.bankSavings, 0.0);
    expect(controller2.cash, 10000.0);

    controller1.dispose();
    controller2.dispose();
  });

  testWidgets('Retail store multi-product shelf capacity scales with level up to max 5 products and sells concurrently', (tester) async {
    final controller = GameController();
    controller.cash = 100000.0;

    final deliBp = RetailStore.getBlueprints().firstWhere((b) => b.id == 'delicatessen_shop');
    controller.buyStore(deliBp);
    expect(controller.ownedStores.length, 1);

    final store = controller.ownedStores.first;
    expect(store.level, 1);
    expect(store.maxProductSlots, 1);
    expect(store.productSlots.length, 1);
    expect(store.productSlots.first.itemId, 'cheese');

    // Attempting to add 2nd product at Level 1 should be rejected (max 1 slot at Lv1)
    final err1 = controller.addProductSlotToStore(store, 'milk');
    expect(err1, isNotNull);
    expect(err1, contains('en fazla 1 ürün satabilir'));

    // Upgrade to Level 2
    final upErr = controller.upgradeStore(store);
    expect(upErr, isNull);
    expect(store.level, 2);
    expect(store.maxProductSlots, 2);

    // Now adding 2nd product slot (milk) succeeds
    controller.warehouse['milk'] = 50;
    final addErr = controller.addProductSlotToStore(store, 'milk');
    expect(addErr, isNull);
    expect(store.productSlots.length, 2);
    expect(store.productSlots.map((s) => s.itemId), containsAll(['cheese', 'milk']));

    // Stock was auto-transferred from warehouse
    expect(store.productSlots.firstWhere((s) => s.itemId == 'milk').shelfStock > 0, true);

    // Upgrade to Level 5 and fill to max 5 slots
    controller.cash = 500000.0;
    controller.upgradeStore(store); // Lv3 -> max 3
    controller.addProductSlotToStore(store, 'bread');
    controller.upgradeStore(store); // Lv4 -> max 4
    controller.addProductSlotToStore(store, 'gourmet_chocolate');
    controller.upgradeStore(store); // Lv5 -> max 5
    controller.addProductSlotToStore(store, 'fruit');

    expect(store.level, 5);
    expect(store.maxProductSlots, 5);
    expect(store.productSlots.length, 5);

    // Upgrade to Level 6: maxProductSlots must remain capped at 5
    controller.upgradeStore(store); // Lv6
    expect(store.level, 6);
    expect(store.maxProductSlots, 5);

    // Trying to add 6th slot must be rejected
    final errMax = controller.addProductSlotToStore(store, 'wheat');
    expect(errMax, isNotNull);

    // Verify removing a slot returns inventory to warehouse
    final fruitSlot = store.productSlots.firstWhere((s) => s.itemId == 'fruit');
    fruitSlot.shelfStock = 12;
    final initialFruitWh = controller.warehouse['fruit'] ?? 0;
    controller.removeProductSlotFromStore(store, fruitSlot);
    expect(store.productSlots.any((s) => s.itemId == 'fruit'), false);
    expect(controller.warehouse['fruit'], initialFruitWh + 12);

    controller.dispose();
  });

  testWidgets('WarehouseTab renders Hammaddeler and Urunler sub-tabs and allows managing warehouse stock', (tester) async {
    final controller = GameController();
    controller.warehouse['wheat'] = 80;
    controller.warehouse['cheese'] = 25;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WarehouseTab(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Warehouse HUD displays capacity and title
    expect(find.text('Merkezi Depo & Silolarım'), findsOneWidget);
    expect(find.textContaining('kg'), findsWidgets);

    // Verify both sub-tabs exist
    expect(find.text('🌾 Hammaddeler'), findsOneWidget);
    expect(find.text('📦 Ürünler'), findsOneWidget);

    // By default, Hammaddeler sub-tab is active (index 0)
    // Buğday (raw material) must be visible in stocked items
    expect(find.text('Buğday'), findsOneWidget);
    expect(find.text('80 Adet'), findsOneWidget);

    // Tap on 'Ürünler' sub-tab
    await tester.tap(find.text('📦 Ürünler'));
    await tester.pumpAndSettle();

    // Now Kalıp Peynir (processed product) must be visible in stocked items
    expect(find.text('Kalıp Peynir'), findsOneWidget);
    expect(find.text('25 Adet'), findsOneWidget);

    // Verify Pazara Çıkar dialog works from Depo tab
    await tester.tap(find.text('Pazara Çıkar').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Pazara Çıkar'), findsWidgets);

    controller.dispose();
  });

  testWidgets('Retail store pricing allows custom prices; higher prices decrease demand and lower prices increase demand and sale speed', (WidgetTester tester) async {
    final controller = GameController();
    final kioskBp = RetailStore.getBlueprints().firstWhere((b) => b.id == 'kiosk_bread');
    controller.cash = 50000;
    controller.buyStore(kioskBp);
    final store = controller.ownedStores.first;
    final slot = store.productSlots.first;
    expect(slot.itemId, 'bread');

    final refPrice = controller.getMarketRetailPrice('bread');
    expect(refPrice > 0, true);

    // 1. When price equals market reference price, demand ratio is ~1.0 (100%)
    controller.setStoreSlotRetailPrice(store, slot, refPrice);
    final baseDemand = controller.getProductDemandRatio('bread', slot.retailPrice);
    expect((baseDemand - 1.0).abs() < 0.05, true);

    // 2. When price is raised above market (+50%), demand drops significantly
    final highPrice = (refPrice * 1.5).roundToDouble();
    controller.setStoreSlotRetailPrice(store, slot, highPrice);
    final lowDemand = controller.getProductDemandRatio('bread', highPrice);
    expect(lowDemand < baseDemand, true);
    expect(lowDemand < 0.6, true);

    // 3. When price is discounted (-30%), demand surges significantly
    final cheapPrice = (refPrice * 0.7).roundToDouble();
    controller.setStoreSlotRetailPrice(store, slot, cheapPrice);
    final highDemand = controller.getProductDemandRatio('bread', cheapPrice);
    expect(highDemand > baseDemand, true);
    expect(highDemand > 1.5, true);

    // 4. Verify in UI that price editing dialog opens and allows updating price
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RetailTab(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify demand badge is visible
    expect(find.textContaining('Yüksek Talep'), findsWidgets);

    // Tap price button to open dialog
    await tester.tap(find.text('${cheapPrice.toStringAsFixed(0)} ₺'));
    await tester.pumpAndSettle();

    // Verify dialog shows title and live demand info
    expect(find.textContaining('Satış Fiyatı'), findsWidgets);
    expect(find.textContaining('Piyasa Perakende Fiyatı:'), findsOneWidget);
    expect(find.textContaining('Talep: %'), findsOneWidget);
    expect(find.text('Fiyatı Onayla'), findsOneWidget);

    // Tap Piyasa preset chip to test "⚡ Dengeli Piyasa Talebi" rendering
    final piyasaChip = find.textContaining('⚖️ Piyasa');
    expect(piyasaChip, findsOneWidget);
    await tester.tap(piyasaChip);
    await tester.pumpAndSettle();

    expect(find.text('⚡ Dengeli Piyasa Talebi'), findsOneWidget);
    expect(find.textContaining('Talep: %'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('Bank loan auto deduction, overdue penalty accumulation, and UI reflection test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameController();
    controller.cash = 250000.0;

    // Take loan: 10.000 TL, 10 installments (requires Level 5 Sanayici)
    final err = controller.takeDetailedLoan(principal: 10000.0, installments: 10, title: 'Test Kredisi');
    expect(err, isNull);
    expect(controller.currentLoan, isNotNull);
    final loan = controller.currentLoan!;
    expect(loan.totalInstallments, 10);
    expect(loan.paidInstallments, 0);
    expect(loan.hasOverdueInstallment, false);
    expect(loan.totalPenalty, 0.0);

    final singleInstallmentAmount = loan.singleInstallmentAmount;

    // 1. When cash is sufficient and timer reaches interval, installment is auto-paid
    final initialCash = controller.cash;
    loan.nextInstallmentTimer = BankLoan.installmentInterval;
    controller.tickForTesting(0.1);

    expect(loan.paidInstallments, 1);
    expect(loan.hasOverdueInstallment, false);
    expect(controller.cash, closeTo(initialCash - singleInstallmentAmount, 0.1));

    // 2. When cash is insufficient (0 TL), installment becomes overdue and penalty compounds
    controller.cash = 0.0;
    loan.nextInstallmentTimer = BankLoan.installmentInterval;
    controller.tickForTesting(0.1);

    expect(loan.paidInstallments, 1); // Not paid
    expect(loan.hasOverdueInstallment, true);
    expect(loan.currentDueInstallment!.isOverdue, true);
    expect(loan.currentDueInstallment!.penaltyAmount > 0, true);
    expect(loan.totalPenalty > 0, true);

    // Verify UI displays overdue warning and penalty
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BankDialog(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Kredi & Ödeme Planı tab
    await tester.tap(find.text('Kredi & Ödeme Planı'));
    await tester.pumpAndSettle();

    // Verify overdue banner and penalty text are shown
    expect(find.textContaining('Gecikmiş Taksit!'), findsOneWidget);
    expect(find.textContaining('Gecikme Cezası'), findsWidgets);
    expect(find.textContaining('Geciken Taksiti Öde'), findsOneWidget);

    // 3. When player receives cash, next interval auto-pays overdue installment with penalty
    controller.cash = 10000.0;
    final overdueDueAmount = loan.currentDueInstallment!.effectiveTotalAmount;
    final cashBeforeSettle = controller.cash;
    loan.nextInstallmentTimer = BankLoan.installmentInterval;
    controller.tickForTesting(0.1);

    expect(loan.paidInstallments, 2);
    expect(loan.hasOverdueInstallment, false);
    expect(controller.cash, closeTo(cashBeforeSettle - overdueDueAmount, 0.1));

    controller.dispose();
  });

  testWidgets('Retail store pause and resume sales test for store and individual product slots', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameController();
    controller.cash = 50000.0;
    final bp = RetailStore.getBlueprints().firstWhere((b) => b.id == 'kiosk_bread');
    controller.buyStore(bp);
    final store = controller.ownedStores.first;
    final slot = store.productSlots.first;
    slot.shelfStock = 20;

    expect(store.isSelling, true);
    expect(slot.isSelling, true);

    // 1. Normal state: ticking sells items and increases revenue
    final initialCash = controller.cash;
    slot.saleTimerProgress = 0.99;
    controller.tickForTesting(0.5);
    expect(slot.shelfStock < 20, true);
    expect(controller.cash > initialCash, true);

    // 2. Pause store sales via controller
    controller.toggleStoreSelling(store, false);
    expect(store.isSelling, false);
    expect(store.statusMessage, 'Satışlar Durduruldu');

    final stockWhenPaused = slot.shelfStock;
    final cashWhenPaused = controller.cash;
    slot.saleTimerProgress = 0.99;
    controller.tickForTesting(5.0);

    // No sales should occur while store is paused
    expect(slot.shelfStock, stockWhenPaused);
    expect(controller.cash, cashWhenPaused);

    // 3. Verify in RetailTab UI that "Satışı Başlat" button and status are shown, and tapping resumes
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RetailTab(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Satışı Başlat'), findsOneWidget);
    expect(find.textContaining('Satışlar Durduruldu'), findsWidgets);

    // Tap "Satışı Başlat" button in UI
    await tester.tap(find.text('Satışı Başlat'));
    await tester.pumpAndSettle();

    expect(store.isSelling, true);
    expect(find.text('Satışı Durdur'), findsOneWidget);

    // 4. Test individual product slot pause
    controller.toggleStoreSlotSelling(store, slot, false);
    expect(slot.isSelling, false);

    final stockBeforeSlotPause = slot.shelfStock;
    slot.saleTimerProgress = 0.99;
    controller.tickForTesting(5.0);
    expect(slot.shelfStock, stockBeforeSlotPause);

    // Resume slot
    controller.toggleStoreSlotSelling(store, slot, true);
    expect(slot.isSelling, true);

    controller.dispose();
  });

  testWidgets('Player level progression based on net worth, Level 5 bank loan gate, and loan limit scaling test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameController();
    
    // 1. Initial State: 10.000 TL cash -> Level 1 (Yeni Girişimci)
    expect(controller.netWorth, 10000.0);
    expect(controller.playerLevel, 1);
    expect(controller.playerTitle, 'Yeni Girişimci');
    expect(controller.canTakeBankLoan, false);
    expect(controller.maxLoanLimit, 0.0);
    expect(controller.netWorthNeededForLoan, 190000.0);

    // Cannot take loan below Level 5
    final errLvl1 = controller.takeDetailedLoan(principal: 10000.0, installments: 10);
    expect(errLvl1, contains('en az Seviye 5 (Sanayici) olmalısınız'));

    // Verify BankDialog shows locked card for Level 1 player
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BankDialog(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Kredi tab
    await tester.tap(find.text('Kredi & Ödeme Planı'));
    await tester.pumpAndSettle();

    expect(find.text('Banka Kredisi Kilitli'), findsOneWidget);
    expect(find.textContaining('Seviye 5 (Sanayici)'), findsWidgets);
    expect(find.textContaining('Mevcut Seviyeniz:'), findsOneWidget);

    // 2. Progression through levels
    // Level 2 (Esnaf) -> 25.000 TL
    controller.cash = 25000.0;
    expect(controller.playerLevel, 2);
    expect(controller.playerTitle, 'Esnaf');
    expect(controller.canTakeBankLoan, false);

    // Level 3 (Tüccar) -> 50.000 TL
    controller.cash = 50000.0;
    expect(controller.playerLevel, 3);
    expect(controller.playerTitle, 'Tüccar');
    expect(controller.canTakeBankLoan, false);

    // Level 4 (KOBİ Sahibi) -> 100.000 TL
    controller.cash = 100000.0;
    expect(controller.playerLevel, 4);
    expect(controller.playerTitle, 'KOBİ Sahibi');
    expect(controller.canTakeBankLoan, false);

    // 3. Level 5 (Sanayici) -> 200.000 TL: Bank loan UNLOCKS!
    controller.cash = 200000.0;
    expect(controller.playerLevel, 5);
    expect(controller.playerTitle, 'Sanayici');
    expect(controller.canTakeBankLoan, true);
    expect(controller.maxLoanLimit > 100000.0, true);
    final lvl5Limit = controller.maxLoanLimit;

    // Pump dialog again to verify unlocked loan UI
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BankDialog(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kredi & Ödeme Planı'));
    await tester.pumpAndSettle();

    expect(find.text('Banka Kredisi Kilitli'), findsNothing);
    expect(find.textContaining('Seviye 5 Kredi Limitiniz:'), findsOneWidget);
    expect(find.text('Kademeli Kredi Paketleri:'), findsOneWidget);

    // Taking loan at Level 5 works within limit
    final errLvl5 = controller.takeDetailedLoan(principal: 50000.0, installments: 10, title: 'Sanayi Test Kredisi');
    expect(errLvl5, isNull);
    expect(controller.currentLoan, isNotNull);

    // Repay loan to test higher levels
    controller.cash = 500000.0;
    controller.repayEntireLoanEarly();
    expect(controller.currentLoan, isNull);

    // 4. Scaling loan limits with Level 6 (İş İnsanı: 400.000 TL)
    controller.cash = 400000.0;
    expect(controller.playerLevel, 6);
    expect(controller.playerTitle, 'İş İnsanı');
    final lvl6Limit = controller.maxLoanLimit;
    expect(lvl6Limit > lvl5Limit, true);

    // Level 7 (Holding Sahibi: 800.000 TL)
    controller.cash = 800000.0;
    expect(controller.playerLevel, 7);
    expect(controller.playerTitle, 'Holding Sahibi');
    final lvl7Limit = controller.maxLoanLimit;
    expect(lvl7Limit > lvl6Limit, true);

    // 5. Verify HomeScreen displays level badge and progress bar
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('⭐ Sv. 7'), findsOneWidget);
    expect(find.text('Holding Sahibi'), findsOneWidget);
    expect(find.text('🏦 Kredi Açık'), findsOneWidget);

    // Tap level row to open level progression dialog
    await tester.tap(find.text('⭐ Sv. 7'));
    await tester.pumpAndSettle();

    expect(find.text('Oyuncu Seviyeleri ve Ünvanlar'), findsOneWidget);
    expect(find.textContaining('Seviye Kademeleri'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('Multi-device responsive layout test across compact phones, standard iPhones, Androids, and tablets without any RenderFlex overflow', (WidgetTester tester) async {
    final testSizes = [
      const Size(320, 568),  // iPhone SE 1st gen / ultra-compact Android
      const Size(360, 640),  // Common budget Android (Samsung Galaxy A series)
      const Size(390, 844),  // Standard iPhone 14/15/16
      const Size(412, 915),  // Flagship Android (Google Pixel 8, Galaxy S24)
      const Size(768, 1024), // Tablet / iPad
    ];

    for (final size in testSizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      final controller = GameController();
      controller.cash = 250000.0; // Level 5 player with some funds

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check for zero RenderFlex overflows
      expect(tester.takeException(), isNull, reason: 'Failed on screen size $size for Tab 0');

      // Switch to Depo (Tab 1)
      await tester.tap(find.text('Depo'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Failed on screen size $size for Tab 1');

      // Switch to Borsa & Pazar (Tab 2)
      await tester.tap(find.text('Borsa & Pazar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Failed on screen size $size for Tab 2');

      // Switch to Dükkanlarım (Tab 3)
      await tester.tap(find.text('Dükkanlarım'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Failed on screen size $size for Tab 3');

      // Open BankDialog
      await tester.tap(find.text('Banka'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Failed on screen size $size for BankDialog');

      // Switch to Kredi tab in BankDialog
      await tester.tap(find.text('Kredi & Ödeme Planı'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Failed on screen size $size for BankDialog Kredi tab');

      // Close dialog
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      controller.dispose();
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Offline Catch-Up Engine: Facilities produce, stores sell, bank earns interest, loans auto-pay while game is closed', (tester) async {
    final controller = GameController();

    // 1. Setup Wheat Farm
    final farm = ProductionFacility.getBlueprints().firstWhere((f) => f.id == 'wheat_farm').copy();
    farm.level = 1;
    farm.isProducing = true;
    controller.ownedFacilities.add(farm);

    // 2. Setup Bakery store with initial shelf stock
    final bakery = RetailStore.getBlueprints().firstWhere((s) => s.id == 'kiosk_bread').copy();
    bakery.level = 1;
    bakery.isSelling = true;
    bakery.productSlots[0].shelfStock = 20;
    bakery.productSlots[0].isSelling = true;
    bakery.productSlots[0].retailPrice = 18.0;
    controller.ownedStores.add(bakery);

    // 3. Bank deposit
    controller.bankSavings = 10000.0;

    // 4. Setup Bank Loan
    controller.currentLoan = BankLoan(
      id: 'loan_offline_test',
      title: 'İşletme Kredisi',
      principal: 10000.0,
      interestRate: 0.01,
      totalInstallments: 10,
      remainingPrincipal: 10000.0,
      remainingInterest: 1000.0,
      takenAt: DateTime.now().subtract(const Duration(hours: 1)),
      schedule: BankLoan.generateSchedule(
        principal: 10000.0,
        interestRatePerPeriod: 0.01,
        installments: 10,
      ),
    );

    final pastTime = DateTime.now().subtract(const Duration(minutes: 10));

    // Simulate 10 minutes offline
    final report = controller.processOfflineCatchUp(pastTime);

    expect(report.hasAnyActivity, isTrue);
    expect(report.producedItems['wheat'], isNotNull);
    expect(report.producedItems['wheat']!, greaterThan(0));
    expect(controller.warehouse['wheat'], greaterThan(0));

    // Bakery retail sales happened
    expect(report.retailItemsSold, greaterThan(0));
    expect(report.retailRevenue, greaterThan(0));

    // Bank interest compounded
    expect(report.bankInterestEarned, greaterThan(0));
    expect(controller.bankSavings, greaterThan(10000.0));

    // Loan installments processed
    expect(report.loanInstallmentsPaid, greaterThan(0));

    // Controller holds latestOfflineReport
    expect(controller.latestOfflineReport, isNotNull);
    expect(controller.latestOfflineReport, equals(report));

    controller.dispose();
  });

  testWidgets('OfflineSummaryDialog renders all offline earnings and dismisses smoothly', (tester) async {
    tester.view.physicalSize = const Size(400, 950);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final report = OfflineCatchUpReport(
      elapsedDuration: const Duration(hours: 2, minutes: 15),
      producedItems: {'wheat': 120, 'bread': 40},
      warehouseFull: false,
      retailItemsSold: 45,
      retailRevenue: 4500.0,
      marketItemsSold: 30,
      marketRevenue: 3000.0,
      incomingOffersCount: 2,
      bankInterestEarned: 250.0,
      loanInstallmentsPaid: 2,
      loanInstallmentsOverdue: 0,
      loanPenaltiesIncurred: 0.0,
      totalLoanPaidAmount: 4200.0,
      startingCash: 10000.0,
      endingCash: 13550.0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => OfflineSummaryDialog.show(ctx, report),
              child: const Text('Raporu Aç'),
            ),
          ),
        ),
      ),
    );

    // Tap to open dialog
    await tester.tap(find.text('Raporu Aç'));
    await tester.pumpAndSettle();

    // Verify dialog content
    expect(find.text('Siz Yokken Şirketiniz Çalıştı!'), findsOneWidget);
    expect(find.textContaining('2 sa 15 dk'), findsOneWidget);
    expect(find.text('Üretim Tesisleri'), findsOneWidget);
    expect(find.text('Perakende Dükkanlarım'), findsOneWidget);
    expect(find.text('Oyuncu Pazarı & Teklifler'), findsOneWidget);
    expect(find.text('Banka & Krediler'), findsOneWidget);
    expect(find.textContaining('Şirketi Yönetmeye Devam Et'), findsOneWidget);

    // Tap to close dialog
    await tester.tap(find.textContaining('Şirketi Yönetmeye Devam Et'));
    await tester.pumpAndSettle();

    expect(find.text('Siz Yokken Şirketiniz Çalıştı!'), findsNothing);
  });

  testWidgets('AuthScreen renders login and registration tabs and toggles between them', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(onAuthenticated: () {}),
      ),
    );

    // Initial Login tab is selected
    expect(find.text('Giriş Yap'), findsWidgets);
    expect(find.text('Kayıt Ol'), findsWidgets);
    expect(find.text('Kullanıcı Adı veya E-posta'), findsOneWidget);
    expect(find.text('Oyuna Giriş Yap ›'), findsOneWidget);
    expect(find.text('Hesapsız Hızlı Başla (Misafir Modu)'), findsOneWidget);

    // Switch to Register tab
    await tester.tap(find.text('Kayıt Ol'));
    await tester.pumpAndSettle();

    // Register fields are present
    expect(find.text('Kullanıcı Adı (Benzersiz)'), findsOneWidget);
    expect(find.text('Şirket Adı (İsteğe Bağlı)'), findsOneWidget);
    expect(find.text('E-posta Adresi (Benzersiz)'), findsOneWidget);
    expect(find.text('Şifre Tekrarı'), findsOneWidget);
    expect(find.text('Şirketini Kur & Kayıt Ol ›'), findsOneWidget);
  });

  testWidgets('AuthScreen registration form validates fields and password matching', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(onAuthenticated: () {}),
      ),
    );

    // Switch to Register tab
    await tester.tap(find.text('Kayıt Ol'));
    await tester.pumpAndSettle();

    final registerBtn = find.text('Şirketini Kur & Kayıt Ol ›');
    await tester.ensureVisible(registerBtn);

    // Tap register with empty inputs
    await tester.tap(registerBtn);
    await tester.pumpAndSettle();

    expect(find.text('Kullanıcı adı boş bırakılamaz.'), findsOneWidget);
    expect(find.text('E-posta adresi boş bırakılamaz.'), findsOneWidget);
    expect(find.text('Şifre boş bırakılamaz.'), findsOneWidget);

    // Enter short username (< 3 chars)
    final usernameFinder = find.widgetWithText(TextFormField, 'Kullanıcı Adı (Benzersiz)');
    await tester.enterText(usernameFinder, 'ab');
    await tester.tap(registerBtn);
    await tester.pumpAndSettle();
    expect(find.text('En az 3 karakter olmalıdır.'), findsOneWidget);

    // Enter invalid username with symbols
    await tester.enterText(usernameFinder, 'user#test!');
    await tester.tap(registerBtn);
    await tester.pumpAndSettle();
    expect(find.text('Yalnızca harf, rakam, nokta ve alt çizgi kullanılabilir.'), findsOneWidget);

    // Enter invalid email
    final emailFinder = find.widgetWithText(TextFormField, 'E-posta Adresi (Benzersiz)');
    await tester.enterText(emailFinder, 'invalidemail');
    await tester.tap(registerBtn);
    await tester.pumpAndSettle();
    expect(find.text('Lütfen geçerli bir e-posta adresi girin.'), findsOneWidget);

    // Enter mismatching passwords
    final passwordFinder = find.widgetWithText(TextFormField, 'Şifre');
    final confirmFinder = find.widgetWithText(TextFormField, 'Şifre Tekrarı');
    await tester.enterText(passwordFinder, '123456');
    await tester.enterText(confirmFinder, '654321');
    await tester.tap(registerBtn);
    await tester.pumpAndSettle();
    expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
  });

  testWidgets('AuthScreen guest mode triggers onAuthenticated callback', (WidgetTester tester) async {
    bool authenticated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(onAuthenticated: () {
          authenticated = true;
        }),
      ),
    );

    await tester.tap(find.text('Hesapsız Hızlı Başla (Misafir Modu)'));
    await tester.pumpAndSettle();

    expect(authenticated, isTrue);
  });

  test('FirebaseService username format validation and registration logic', () async {
    final fb = FirebaseService();

    // Username length checks
    final tooShort = await fb.registerWithEmail(
      email: 'test@example.com',
      password: 'password123',
      username: 'yo',
    );
    expect(tooShort, contains('3 ile 20 karakter'));

    // Username characters check
    final invalidChars = await fb.registerWithEmail(
      email: 'test@example.com',
      password: 'password123',
      username: 'bad*name!',
    );
    expect(invalidChars, contains('harf, rakam, nokta'));

    // Password length check
    final shortPass = await fb.registerWithEmail(
      email: 'test@example.com',
      password: '123',
      username: 'good_user',
    );
    expect(shortPass, contains('en az 6 karakter'));

    // Successful local registration does NOT auto-login
    final success = await fb.registerWithEmail(
      email: 'valid@example.com',
      password: 'password123',
      username: 'valid_trader',
      companyName: 'Anadolu Ticaret',
    );
    expect(success, isNull);
    expect(fb.username, isNull);
    expect(fb.isAuthenticated, isFalse);

    // Duplicate username attempt must be strictly rejected
    final dupUsername = await fb.registerWithEmail(
      email: 'different@example.com',
      password: 'password123',
      username: 'valid_trader',
    );
    expect(dupUsername, contains('zaten kullanımda'));

    // Duplicate email attempt must be strictly rejected
    final dupEmail = await fb.registerWithEmail(
      email: 'valid@example.com',
      password: 'password123',
      username: 'different_trader',
    );
    expect(dupEmail, contains('zaten kayıtlı'));

    // Manual login with registered credentials succeeds
    final loginErr = await fb.loginWithEmailOrUsername(
      identifier: 'valid_trader',
      password: 'password123',
    );
    expect(loginErr, isNull);
    expect(fb.username, equals('valid_trader'));
    expect(fb.companyName, equals('Anadolu Ticaret'));
    expect(fb.isGuest, isFalse);
    expect(fb.isAuthenticated, isTrue);
  });

  test('AuditLogService records granular logs, calculates income/expense, and filters by category', () async {
    final service = AuditLogService();
    service.resetForTesting();

    await service.log(
      category: LogCategory.trade,
      action: 'MARKET_BUY',
      title: 'Borsa Alımı: Buğday',
      description: '50 adet Buğday 12 ₺ fiyattan alındı.',
      amountChange: -600.0,
      cashAfter: 9400.0,
      details: {'item': 'Bugday', 'qty': 50, 'unitPrice': 12.0},
    );

    await service.log(
      category: LogCategory.trade,
      action: 'MARKET_SELL',
      title: 'Borsa Satışı: Ekmek',
      description: '100 adet Ekmek 20 ₺ fiyattan satıldı.',
      amountChange: 2000.0,
      cashAfter: 11400.0,
      details: {'item': 'Ekmek', 'qty': 100, 'unitPrice': 20.0},
    );

    await service.log(
      category: LogCategory.finance,
      action: 'LOAN_TAKEN',
      title: 'Kredi Çekildi',
      description: '50.000 ₺ işletme kredisi onaylandı.',
      amountChange: 50000.0,
      cashAfter: 61400.0,
      details: {'principal': 50000.0},
    );

    expect(service.logs.length, 3);
    expect(service.totalIncome, 52000.0);
    expect(service.totalExpense, 600.0);
    expect(service.netFlow, 51400.0);

    final tradeLogs = service.getLogsFiltered(category: LogCategory.trade);
    expect(tradeLogs.length, 2);

    final searchLogs = service.getLogsFiltered(query: 'kredi');
    expect(searchLogs.length, 1);
    expect(searchLogs.first.action, 'LOAN_TAKEN');
  });

  testWidgets('LedgerDialog renders summary cards, filter chips, and log items', (WidgetTester tester) async {
    final service = AuditLogService();
    service.resetForTesting();

    await service.log(
      category: LogCategory.trade,
      action: 'MARKET_BUY',
      title: 'Borsa Alımı: Pamuk',
      description: '20 adet Pamuk satın alındı.',
      amountChange: -400.0,
      cashAfter: 9600.0,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LedgerDialog(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Şirket Defteri & İşlem Logları'), findsOneWidget);
    expect(find.text('Toplam Gelir'), findsOneWidget);
    expect(find.text('Toplam Gider'), findsOneWidget);
    expect(find.text('Net Akış'), findsOneWidget);
    expect(find.text('🛒 Borsa & Pazar'), findsOneWidget);
    expect(find.text('Borsa Alımı: Pamuk'), findsOneWidget);

    // Tap on log item to open detail sheet
    await tester.tap(find.text('Borsa Alımı: Pamuk'));
    await tester.pumpAndSettle();

    expect(find.text('Açıklama:'), findsOneWidget);
    expect(find.text('20 adet Pamuk satın alındı.'), findsWidgets);
    expect(find.text('Kapat'), findsOneWidget);

    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();
  });

  test('GameController actions automatically append to AuditLogService', () async {
    final controller = GameController();
    final service = AuditLogService();
    service.resetForTesting();

    // 1. Buy from market
    controller.cash = 10000.0;
    final errBuy = controller.buyFromMarket('wheat', 10);
    expect(errBuy, isNull);
    expect(service.logs.any((l) => l.action == 'MARKET_BUY'), isTrue);

    // 2. Sell to market
    final errSell = controller.sellToMarket('wheat', 5);
    expect(errSell, isNull);
    expect(service.logs.any((l) => l.action == 'MARKET_SELL'), isTrue);

    // 3. Deposit to bank
    final errDep = controller.depositToBank(1000.0);
    expect(errDep, isNull);
    expect(service.logs.any((l) => l.action == 'BANK_DEPOSIT'), isTrue);
  });

  test('Admin credentials and role authorization test', () {
    expect(FirebaseService.adminEmail, 'furkanc28@gmail.com');
    expect(FirebaseService.adminUsername, 'COSSKUN');

    final fb = FirebaseService();
    // Default guest is not admin
    expect(fb.isAdmin, isFalse);
  });

  testWidgets('BannedDialog renders suspension warning, reason, and logout button', (WidgetTester tester) async {
    bool loggedOutCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BannedDialog(
            reason: 'Pazar manipülasyonu ve hile tespiti',
            onLoggedOut: () {
              loggedOutCalled = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HESABINIZ ASKIYA ALINDI'), findsOneWidget);
    expect(find.text('Erişim Kısıtlaması & Güvenlik Uyarısı'), findsOneWidget);
    expect(find.text('Pazar manipülasyonu ve hile tespiti'), findsOneWidget);
    expect(find.text('İtiraz: furkanc28@gmail.com'), findsOneWidget);
    expect(find.text('Oturumu Kapat'), findsOneWidget);

    await tester.tap(find.text('Oturumu Kapat'));
    await tester.pumpAndSettle();
    expect(loggedOutCalled, isTrue);
  });

  testWidgets('AdminDashboardView renders tabs, player search, and anti-cheat radar', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: AdminDashboardView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('YÖNETİCİ & GÜVENLİK PANELİ'), findsOneWidget);
    expect(find.text('COSSKUN (furkanc28@gmail.com)'), findsOneWidget);
    expect(find.text('Oyuncular'), findsOneWidget);
    expect(find.text('Global Defter'), findsOneWidget);
    expect(find.text('Hile Radarı'), findsOneWidget);

    // Switch to Global Defter tab
    await tester.tap(find.text('Global Defter'));
    await tester.pumpAndSettle();
    expect(find.text('Tüm İşlemler'), findsOneWidget);

    // Switch to Hile Radarı tab
    await tester.tap(find.text('Hile Radarı'));
    await tester.pumpAndSettle();
    expect(find.text('OTOMATİK HİLE & ANOMALİ RADARI'), findsOneWidget);

    // Switch back to Oyuncular tab
    await tester.tap(find.text('Oyuncular'));
    await tester.pumpAndSettle();

    // Swipe left from Oyuncular to Global Defter
    await tester.drag(find.byType(TabBarView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    // Swipe left from Global Defter to Hile Radarı
    await tester.drag(find.byType(TabBarView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    // Swipe right back
    await tester.drag(find.byType(TabBarView), const Offset(400, 0));
    await tester.pumpAndSettle();
  });

  testWidgets('AuthScreen does not auto-login upon registration, switches to login tab, pre-fills username, and displays success snackbar', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool authenticatedCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthScreen(
            onAuthenticated: () {
              authenticatedCalled = true;
            },
          ),
        ),
      ),
    );

    // Switch to Register tab
    await tester.tap(find.text('Kayıt Ol'));
    await tester.pumpAndSettle();

    // Fill valid registration fields
    final usernameFinder = find.widgetWithText(TextFormField, 'Kullanıcı Adı (Benzersiz)');
    final emailFinder = find.widgetWithText(TextFormField, 'E-posta Adresi (Benzersiz)');
    final passFinder = find.widgetWithText(TextFormField, 'Şifre');
    final confirmFinder = find.widgetWithText(TextFormField, 'Şifre Tekrarı');

    await tester.enterText(usernameFinder, 'yeni_oyuncu');
    await tester.enterText(emailFinder, 'yeni@piyasa.com');
    await tester.enterText(passFinder, '123456');
    await tester.enterText(confirmFinder, '123456');

    final registerBtn = find.text('Şirketini Kur & Kayıt Ol ›');
    await tester.ensureVisible(registerBtn);
    await tester.tap(registerBtn);
    await tester.pumpAndSettle();

    // CRITICAL: onAuthenticated must NOT have been called!
    expect(authenticatedCalled, isFalse);

    // Success snackbar is displayed
    expect(find.text('Kayıt başarılı! Lütfen belirlediğiniz şifrenizle giriş yapınız.'), findsOneWidget);

    // Switched to Login tab
    expect(find.text('Oyuna Giriş Yap ›'), findsOneWidget);

    // Username is prefilled in login field
    expect(find.text('yeni_oyuncu'), findsOneWidget);
  });

  test('Multi-user profile isolation: Player A and Player B have completely independent company saves, facilities, cash, and audit logs', () async {
    final fb = FirebaseService();

    // 1. Register Player A
    await fb.registerWithEmail(
      email: 'playerA@piyasa.com',
      password: 'passwordA',
      username: 'playerA',
      companyName: 'A Holding',
    );
    await fb.loginWithEmailOrUsername(identifier: 'playerA', password: 'passwordA');
    final playerAUid = fb.playerId;

    final controllerA = GameController(autoLoad: false);
    await controllerA.loadFromStorage(playerId: playerAUid);
    expect(controllerA.cash, 10000.0);
    expect(controllerA.ownedFacilities.isEmpty, isTrue);

    // Player A buys a facility and earns money
    final wheatFarmBp = ProductionFacility.getBlueprints().firstWhere((b) => b.id == 'wheat_farm');
    controllerA.buyFacility(wheatFarmBp);
    controllerA.cash = 95000.0;
    controllerA.warehouse['wheat'] = 250;
    controllerA.saveState(targetPlayerId: playerAUid);

    await AuditLogService().initializeForPlayer(playerAUid);
    await AuditLogService().log(
      category: LogCategory.trade,
      action: 'ACTION_A',
      title: 'A İşlemi',
      description: 'Player A işlem yaptı',
      cashAfter: 95000.0,
    );
    expect(AuditLogService().logs.length, 1);
    expect(AuditLogService().logs.first.title, 'A İşlemi');

    // Player A logs out
    await fb.signOut();
    controllerA.resetToNewGame();
    AuditLogService().clearInProcess();
    expect(controllerA.cash, 10000.0);
    expect(controllerA.ownedFacilities.isEmpty, isTrue);
    expect(AuditLogService().logs.isEmpty, isTrue);

    // 2. Register Player B
    await fb.registerWithEmail(
      email: 'playerB@piyasa.com',
      password: 'passwordB',
      username: 'playerB',
      companyName: 'B Holding',
    );
    await fb.loginWithEmailOrUsername(identifier: 'playerB', password: 'passwordB');
    final playerBUid = fb.playerId;
    expect(playerBUid, isNot(equals(playerAUid)));

    final controllerB = GameController(autoLoad: false);
    await controllerB.loadFromStorage(playerId: playerBUid);

    // Player B MUST start fresh! No facilities from Player A, 10000 TL starter cash, empty warehouse!
    expect(controllerB.cash, 10000.0);
    expect(controllerB.ownedFacilities.isEmpty, isTrue);
    expect(controllerB.warehouse.isEmpty, isTrue);

    await AuditLogService().initializeForPlayer(playerBUid);
    expect(AuditLogService().logs.isEmpty, isTrue); // Player B has no logs from Player A!

    // Player B buys a bakery store and logs
    final kioskBp = RetailStore.getBlueprints().firstWhere((b) => b.id == 'kiosk_bread');
    controllerB.buyStore(kioskBp);
    controllerB.saveState(targetPlayerId: playerBUid);
    await AuditLogService().log(
      category: LogCategory.trade,
      action: 'ACTION_B',
      title: 'B İşlemi',
      description: 'Player B işlem yaptı',
      cashAfter: 6000.0,
    );

    // 3. Switch back to Player A: Player A's data must remain intact!
    await fb.signOut();
    await fb.loginWithEmailOrUsername(identifier: 'playerA', password: 'passwordA');
    final controllerAReload = GameController(autoLoad: false);
    await controllerAReload.loadFromStorage(playerId: playerAUid);
    await AuditLogService().initializeForPlayer(playerAUid);

    expect(controllerAReload.cash, 95000.0);
    expect(controllerAReload.ownedFacilities.length, 1);
    expect(controllerAReload.ownedFacilities.first.name, 'Buğday Tarlası');
    expect(controllerAReload.ownedStores.isEmpty, isTrue); // Store was bought by B, not A!
    expect(controllerAReload.warehouse['wheat'], 250);
    expect(AuditLogService().logs.length, 1);
    expect(AuditLogService().logs.first.title, 'A İşlemi');

    controllerA.dispose();
    controllerB.dispose();
    controllerAReload.dispose();
  });

  testWidgets('GameLoadingScreen renders animated sliding cards, pulse logo, dynamic stages, and invokes onLoaded callback', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool loadedInvoked = false;
    final controller = GameController(autoLoad: false);

    await tester.pumpWidget(
      MaterialApp(
        home: GameLoadingScreen(
          controller: controller,
          minDuration: const Duration(milliseconds: 300),
          onLoaded: () {
            loadedInvoked = true;
          },
        ),
      ),
    );

    // Initial loading screen rendered
    expect(find.text('PİYASA'), findsOneWidget);
    expect(find.text('DÜNYANIZ HAZIRLANIYOR'), findsOneWidget);
    expect(find.text('Tarlalar'), findsWidgets);
    expect(find.text('Fabrikalar'), findsWidgets);
    expect(find.text('Marketler'), findsWidgets);

    // Pump past the 300ms minDuration + completion delay
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 250));

    expect(loadedInvoked, isTrue);
    controller.dispose();
  });

  testWidgets('Market listing retains stock in warehouse until sold, and starting capacity is 5000 kg', (WidgetTester tester) async {
    final controller = GameController();
    // 1. Initial capacity is 5000 kg
    expect(controller.maxWarehouseCapacity, 5000.0);

    // 2. Put 100 wheat in warehouse
    controller.warehouse['wheat'] = 100;
    expect(controller.warehouse['wheat'], 100);

    // 3. Create listing for 40 wheat: warehouse MUST NOT decrease immediately
    final err = controller.createListing('wheat', 40, 1.00);
    expect(err, isNull);
    expect(controller.warehouse['wheat'], 100); // Goods remain in warehouse!

    // 4. Over-listing check: attempting to list 70 wheat when only 60 are unlisted fails
    final errOver = controller.createListing('wheat', 70, 1.00);
    expect(errOver, isNotNull);
    expect(errOver, contains('boşta'));

    // 5. Simulate market purchase tick: goods sell and are deducted from warehouse
    final listing = controller.activeListings.firstWhere((l) => l.itemId == 'wheat');
    listing.saleProgressTimer = 1.0;
    controller.tickForTesting(5.0);

    // After tick, some batch was sold and deducted from warehouse
    expect(controller.warehouse['wheat']!, lessThan(100));
    expect(controller.warehouse['wheat'], listing.remainingQuantity + (100 - 40));

    // 6. Canceling listing does not duplicate stock into warehouse
    final stockBeforeCancel = controller.warehouse['wheat']!;
    controller.cancelListing(listing);
    expect(controller.warehouse['wheat'], stockBeforeCancel); // Did not re-add!

    controller.dispose();
  });

  testWidgets('Foreground notification suppression, online/offline status, and unified audit logs test', (WidgetTester tester) async {
    // 1. Foreground suppression
    final notif = NotificationService();
    notif.setAppInForeground(true);
    expect(notif.isAppInForeground, isTrue);

    // Calling notification in foreground completes silently without exceptions
    await notif.showIncomingOfferNotification(
      buyerName: 'Ahmet Usta',
      itemName: 'Buğday',
      quantity: 20,
      price: 5.0,
    );

    // 2. Online / Offline status
    final fb = FirebaseService();
    await fb.setPlayerOnlineStatus(isOnline: true);
    final accounts = await fb.getLocalAccounts();
    expect(accounts, isNotNull);

    await fb.setPlayerOnlineStatus(isOnline: false);

    // 3. Unified audit logs
    final logsStream = fb.streamGlobalAuditLogs(limit: 50);
    expect(logsStream, isNotNull);
    final logsList = await logsStream.first;
    expect(logsList, isA<List<AuditLog>>());
  });

  testWidgets('App backgrounding pauses game loop, preserves lastActiveAt, and resuming triggers offline catchup and dialog feedback', (WidgetTester tester) async {
    final controller = GameController();

    // Add a wheat farm (duration: 6 seconds, output: 10 wheat)
    final farm = ProductionFacility.getBlueprints().firstWhere((f) => f.id == 'wheat_farm').copy();
    farm.level = 1;
    farm.isProducing = true;
    controller.ownedFacilities.add(farm);

    // 1. Simulate app backgrounding
    expect(controller.isGameLoopPaused, isFalse);
    controller.pauseGameLoop();
    expect(controller.isGameLoopPaused, isTrue);

    // 2. Simulate 12 seconds passing while in background
    controller.lastActiveAt = DateTime.now().subtract(const Duration(seconds: 12));

    // 3. Simulate returning to foreground (resumeGameLoop)
    await controller.resumeGameLoop();
    expect(controller.isGameLoopPaused, isFalse);

    // 4. Verify offline report was generated and production happened!
    expect(controller.latestOfflineReport, isNotNull);
    final report = controller.latestOfflineReport!;
    expect(report.hasAnyActivity, isTrue);
    expect(report.producedItems['wheat'], isNotNull);
    expect(report.producedItems['wheat']!, greaterThanOrEqualTo(10));
    expect(controller.warehouse['wheat'], greaterThanOrEqualTo(10));

    // 5. Test without facilities gives informative toast
    final freshController = GameController();
    freshController.pauseGameLoop();
    freshController.lastActiveAt = DateTime.now().subtract(const Duration(seconds: 10));
    await freshController.resumeGameLoop();
    expect(freshController.latestNotificationToast, isNotNull);
    expect(freshController.latestNotificationToast, contains('Tekrar hoş geldiniz'));

    controller.dispose();
    freshController.dispose();
  });

  testWidgets('PiyasaApp renders GameLoadingScreen upon app launch when user is already authenticated', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameController(autoLoad: false);

    // Launch app with user already authenticated
    await tester.pumpWidget(
      PiyasaApp(
        controller: controller,
        skipAuthForTesting: true,
      ),
    );

    // Verify loading screen is shown first with its badges and status
    expect(find.byType(GameLoadingScreen), findsOneWidget);
    expect(find.text('DÜNYANIZ HAZIRLANIYOR'), findsOneWidget);
    expect(find.text('Tarlalar'), findsWidgets);
    expect(find.text('Fabrikalar'), findsWidgets);

    // Pump past minDuration and completion delay
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify loading screen has finished and HomeScreen is now rendered
    expect(find.byType(GameLoadingScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);

    controller.dispose();
  });
}



