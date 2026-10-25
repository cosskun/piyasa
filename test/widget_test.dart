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
import 'package:piyasa/views/session_terminated_dialog.dart';
import 'package:piyasa/views/game_loading_screen.dart';
import 'package:piyasa/views/leaderboard_view.dart';
import 'package:piyasa/services/leaderboard_service.dart';
import 'package:piyasa/models/leaderboard_entry.dart';
import 'package:piyasa/models/market_listing.dart';
import 'package:piyasa/views/profile_screen.dart';
import 'package:piyasa/views/headquarters_tender_dialog.dart';
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

    // Verify ownedFacilities now has 1 facility and cash is 5,000 TL (10000 - 5000, minus slight opex during pump)
    expect(controller.ownedFacilities.length, 1);
    expect(controller.cash, closeTo(5000.0, 1.0));

    // Verify the list shows Tesislerim (1) and total capacity
    expect(find.text('Tesislerim (1)'), findsOneWidget);
    expect(find.textContaining('Toplam Üretim Kapasitesi'), findsOneWidget);

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
          body: RetailTab(controller: controller, initialViewMode: 1),
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

    // Verify facility removed and cash updated (2500 + 5250 = 7750, minus slight opex)
    expect(controller.ownedFacilities.isEmpty, true);
    expect(controller.cash, closeTo(7750.0, 1.0));

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
          body: RetailTab(controller: controller, initialViewMode: 1),
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

    // Verify store removed, cash refunded (5500 + 3150 = 8650, minus slight opex), and 15 breads in warehouse
    expect(controller.ownedStores.isEmpty, true);
    expect(controller.cash, closeTo(8650.0, 1.0));
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
          body: RetailTab(controller: controller, initialViewMode: 1),
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

    // No sales should occur while store is paused (idle opex deducted, no revenue added)
    expect(slot.shelfStock, stockWhenPaused);
    expect(controller.cash, closeTo(cashWhenPaused, 2.0));
    expect(controller.cash <= cashWhenPaused, true);

    // 3. Verify in RetailTab UI that "Satışı Başlat" button and status are shown, and tapping resumes
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RetailTab(controller: controller, initialViewMode: 1),
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
      expect(tester.takeException(), isNull, reason: 'Failed on screen size $size for Tab 0 (Ana Sayfa)');

      // Switch to Tesislerim (Tab 1)
      await tester.tap(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('Tesislerim')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Failed on screen size $size for Tab 1 (Tesislerim)');

      // Switch to Depo (Tab 2)
      await tester.tap(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('Depo')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Failed on screen size $size for Tab 2 (Depo)');

      // Switch to Borsa & Pazar (Tab 3)
      await tester.tap(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('Borsa & Pazar')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Failed on screen size $size for Tab 3 (Borsa & Pazar)');

      // Switch to Dükkanlarım (Tab 4)
      await tester.tap(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('Dükkanlarım')));
      await tester.pumpAndSettle();
      // Switch back to Ana Sayfa (Tab 0) and open BankDialog
      await tester.tap(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('Ana Sayfa')));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Banka & Kredi').first);
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

  testWidgets('ProductionFacility toggleProducing pauses and resumes facility and updates UI', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameController();
    final farm = ProductionFacility.getBlueprints().firstWhere((f) => f.id == 'wheat_farm').copy();
    controller.ownedFacilities.add(farm);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionTab(controller: controller),
        ),
      ),
    );

    // Initial state: facility is producing
    expect(farm.isProducing, isTrue);
    expect(find.text('Durdur'), findsOneWidget);

    // Tap Durdur
    await tester.tap(find.text('Durdur'));
    await tester.pumpAndSettle();

    expect(farm.isProducing, isFalse);
    expect(farm.statusMessage, contains('Durduruldu'));
    expect(find.text('Başlat'), findsOneWidget);
    expect(find.textContaining('Durduruldu'), findsWidgets);

    // Tap Başlat
    await tester.tap(find.text('Başlat'));
    await tester.pumpAndSettle();

    expect(farm.isProducing, isTrue);
    expect(find.text('Durdur'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('RetailTab allows product slot selling pause/resume and opens store detail sheet', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameController();
    final grocery = RetailStore.getBlueprints().firstWhere((b) => b.id == 'kiosk_bread').copy();
    grocery.level = 2;
    grocery.productSlots.clear();
    grocery.productSlots.add(StoreProductSlot(
      itemId: 'bread',
      shelfCapacity: 50,
      shelfStock: 30,
      retailPrice: 20.0,
      isSelling: true,
    ));
    grocery.productSlots.add(StoreProductSlot(
      itemId: 'flour',
      shelfCapacity: 50,
      shelfStock: 20,
      retailPrice: 25.0,
      isSelling: true,
    ));
    controller.ownedStores.add(grocery);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RetailTab(controller: controller, initialViewMode: 1),
        ),
      ),
    );

    // Verify slot toggle buttons are visible
    expect(find.text('Satışta'), findsNWidgets(2));

    // Tap to pause the first product slot (bread)
    await tester.tap(find.text('Satışta').first);
    await tester.pumpAndSettle();

    expect(grocery.productSlots[0].isSelling, isFalse);
    expect(grocery.productSlots[1].isSelling, isTrue);
    expect(find.text('Durduruldu'), findsOneWidget);

    // Tap store title or hint to open detail sheet
    await tester.tap(find.textContaining('Satılabilen ürünleri ve detayları gör'));
    await tester.pumpAndSettle();

    // Verify detail sheet opened with store name and active shelves
    expect(find.text('Köşe Büfe & Fırın'), findsWidgets);
    expect(find.textContaining('Aktif Satış Rafları'), findsOneWidget);

    // Scroll down inside the sheet's ListView to bring catalog into view
    await tester.drag(find.byType(ListView).last, const Offset(0, -350));
    await tester.pumpAndSettle();

    expect(find.textContaining('Satılabilen Tüm Ürünler Kataloğu'), findsOneWidget);
    expect(find.textContaining('Borsa Maliyeti'), findsWidgets);
    expect(find.textContaining('Perakende Satış'), findsWidgets);
    expect(find.textContaining('Adet Başı Kâr'), findsWidgets);

    controller.dispose();
  });

  testWidgets('LeaderboardService streams, ranks, and sorts players by net worth and metrics', (WidgetTester tester) async {
    final controller = GameController();
    controller.cash = 1500000.0;
    controller.bankSavings = 500000.0;

    final stream = LeaderboardService().streamLeaderboard(
      controller: controller,
      sortMode: LeaderboardSortMode.netWorth,
    );

    final list = await stream.first;
    expect(list, isNotEmpty);

    // Current player should be in the list
    final me = list.firstWhere((e) => e.isCurrentUser);
    expect(me.cash, 1500000.0);
    expect(me.bankSavings, 500000.0);
    expect(me.netWorth, greaterThanOrEqualTo(2000000.0));

    // Verify list is sorted in descending order
    for (int i = 0; i < list.length - 1; i++) {
      expect(list[i].netWorth, greaterThanOrEqualTo(list[i + 1].netWorth));
      expect(list[i].rank, i + 1);
    }

    // Verify next rank target helper
    final target = LeaderboardService().getNextRankTarget(
      rankedList: list,
      sortMode: LeaderboardSortMode.netWorth,
    );
    if (me.rank > 1) {
      expect(target.aheadPlayer, isNotNull);
      expect(target.difference, greaterThan(0));
    }

    controller.dispose();
  });

  testWidgets('LeaderboardView renders podium, search, filter chips, and player portfolio sheet', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 950);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameController();
    controller.cash = 3000000.0;

    final fb = FirebaseService();
    await fb.saveLocalAccount({
      'uid': 'ply_test_rival_1',
      'username': 'ahmet_holding',
      'companyName': 'Ahmet Holding A.Ş.',
      'netWorth': 5000000.0,
      'cash': 1500000.0,
      'isOnline': true,
    });
    await fb.saveLocalAccount({
      'uid': 'ply_test_rival_2',
      'username': 'mehmet_sanayi',
      'companyName': 'Mehmet Sanayi Ltd.',
      'netWorth': 2000000.0,
      'cash': 500000.0,
      'isOnline': false,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LeaderboardView(controller: controller),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title and Period Tabs
    expect(find.text('PİYASA LİDERLİK TABLOSU'), findsOneWidget);
    expect(find.text('Haftanın En Çok Kazananı'), findsOneWidget);
    expect(find.text('Ayın En Çok Kazananı'), findsOneWidget);
    expect(find.text('Tüm Zamanlar'), findsWidgets);

    // Verify Criteria Chips (Sub-categories)
    expect(find.text('Mal Varlığı'), findsWidgets);
    expect(find.text('Nakti'), findsOneWidget);
    expect(find.text('Mülk Sayısı'), findsOneWidget);

    // Initial default period is weekly
    expect(find.text('HAFTANIN EN ÇOK KAZANANLARI'), findsOneWidget);

    // Switch to Tüm Zamanlar
    await tester.tap(find.text('Tüm Zamanlar').first);
    await tester.pumpAndSettle();
    expect(find.text('TİCARETİN ZİRVE LİDERLERİ'), findsOneWidget);

    // Podium ranks
    expect(find.text('#1'), findsWidgets);
    expect(find.text('#2'), findsWidgets);
    expect(find.text('#3'), findsWidgets);

    // Sticky bottom bar
    expect(find.textContaining('Şirketiniz:'), findsOneWidget);

    // Test filter chip switching to Nakti
    await tester.ensureVisible(find.text('Nakti'));
    await tester.tap(find.text('Nakti'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Nakti'), findsWidgets);

    // Test search field filtering
    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'Koçer');
    await tester.pumpAndSettle();

    expect(find.textContaining('Koçer'), findsWidgets);

    // Clear search
    await tester.tap(find.byIcon(Icons.clear_rounded));
    await tester.pumpAndSettle();

    // Tap first rank card to view player portfolio modal sheet
    await tester.tap(find.text('#1').first);
    await tester.pumpAndSettle();

    expect(find.text('Net Mal Varlığı'), findsOneWidget);
    expect(find.text('Zirve Servet'), findsWidgets);
    expect(find.text('Kasadaki Nakit'), findsOneWidget);
    expect(find.text('Haftalık Kazanç'), findsOneWidget);
    expect(find.text('Aylık Kazanç'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('ProductionTab sorts same-type facilities adjacently with #badges and cluster headers, and category tabs filter properly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameController();
    final blueprints = ProductionFacility.getBlueprints();

    final wheatBp = blueprints.firstWhere((b) => b.id == 'wheat_farm');
    final flourBp = blueprints.firstWhere((b) => b.id == 'flour_mill');
    final dairyBp = blueprints.firstWhere((b) => b.id == 'dairy_farm');

    // Add facilities in interleaved (mixed) order
    controller.ownedFacilities.add(wheatBp.copy(newId: 'wheat_1'));
    controller.ownedFacilities.add(flourBp.copy(newId: 'flour_1'));
    controller.ownedFacilities.add(dairyBp.copy(newId: 'dairy_1'));
    controller.ownedFacilities.add(wheatBp.copy(newId: 'wheat_2'));
    controller.ownedFacilities.add(flourBp.copy(newId: 'flour_2'));

    expect(controller.ownedFacilities.length, 5);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionTab(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Header and Category Tabs
    expect(find.text('Tesislerim (5)'), findsOneWidget);
    expect(find.text('Tümü'), findsOneWidget);
    expect(find.text('🌾 Tarım & Kaynak'), findsOneWidget);
    expect(find.text('🏭 Fabrika & Sanayi'), findsOneWidget);

    // Verify Tab counts
    expect(find.text('5'), findsWidgets); // Total
    expect(find.text('3'), findsWidgets); // 2 wheat + 1 dairy = 3 agriculture
    expect(find.text('2'), findsWidgets); // 2 flour = 2 factory

    // 2. Verify Same-Type Grouping and Badges
    // Multiple instances should show cluster headers and #1, #2 badges
    expect(find.text('Buğday Tarlaları'), findsOneWidget);
    expect(find.text('(2 tarla)'), findsOneWidget);
    expect(find.text('Un Değirmenleri'), findsOneWidget);
    expect(find.text('(2 değirmen)'), findsOneWidget);
    expect(find.text('#1'), findsWidgets);
    expect(find.text('#2'), findsWidgets);

    // 3. Test Switching to Agriculture Tab
    await tester.ensureVisible(find.text('🌾 Tarım & Kaynak'));
    await tester.tap(find.text('🌾 Tarım & Kaynak'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Agriculture tab should show 3 facilities and capacity
    expect(find.textContaining('Tarım Üretim Kapasitesi'), findsOneWidget);
    expect(find.text('Buğday Tarlası'), findsWidgets);
    expect(find.text('Mandıra Çiftliği'), findsOneWidget);
    // Factories should be hidden
    expect(find.text('Un Değirmeni'), findsNothing);

    // 4. Test Switching to Factory Tab
    await tester.ensureVisible(find.text('🏭 Fabrika & Sanayi'));
    await tester.tap(find.text('🏭 Fabrika & Sanayi'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Factory tab should show 2 facilities and capacity
    expect(find.textContaining('Fabrika Üretim Kapasitesi'), findsOneWidget);
    expect(find.text('Un Değirmeni'), findsWidgets);
    expect(find.text('Buğday Tarlası'), findsNothing);
    expect(find.text('Mandıra Çiftliği'), findsNothing);

    // 5. Test Switching back to All Tab
    await tester.ensureVisible(find.text('Tümü'));
    await tester.tap(find.text('Tümü'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Buğday Tarlası'), findsWidgets);
    expect(find.text('Un Değirmeni'), findsWidgets);
    expect(find.text('Mandıra Çiftliği'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('Limit buy orders allow targetPrice >= currentPrice, match against community listings or market, and execute immediately', (WidgetTester tester) async {
    final controller = GameController(autoLoad: false);
    controller.cash = 100000.0;
    controller.warehouse.clear();
    controller.communityListings.clear();

    final mItem = controller.marketItems['wheat']!;
    final wheatPrice = mItem.currentPrice;

    // 1. Placing limit buy order at current price or higher is allowed (no error)
    final err = controller.placeLimitBuyOrder(
      itemId: 'wheat',
      targetPrice: wheatPrice + 2.0, // higher than current market price!
      quantity: 10,
    );
    expect(err, isNull);
    expect(controller.limitBuyOrders.length, 1);
    final order = controller.limitBuyOrders.first;
    // Because targetPrice >= currentPrice, it matches immediately!
    expect(order.isCompleted, isTrue);
    expect(order.executedPrice, wheatPrice);
    expect(controller.warehouse['wheat'], 10);
    // Reserved cost was (wheatPrice + 2.0) * 10, actual cost was wheatPrice * 10, so 20.0 refund returned to cash
    expect(controller.cash, 100000.0 - (wheatPrice * 10));

    // 2. Test matching against community listing cheaper than market
    controller.communityListings.add(
      MarketListing(
        id: 'test_comm_1',
        itemId: 'wheat',
        initialQuantity: 20,
        remainingQuantity: 20,
        pricePerUnit: double.parse((wheatPrice * 0.8).toStringAsFixed(2)), // 20% cheaper than market
        listedAt: DateTime.now(),
        sellerName: 'Simulated Farmer',
        isPlayerListing: false,
      ),
    );

    final initialCash = controller.cash;
    final err2 = controller.placeLimitBuyOrder(
      itemId: 'wheat',
      targetPrice: wheatPrice * 0.9, // Lower than borsa, but higher than the community listing!
      quantity: 5,
    );
    expect(err2, isNull);
    expect(controller.limitBuyOrders.length, 2);
    final order2 = controller.limitBuyOrders.first;
    expect(order2.isCompleted, isTrue);
    expect(order2.executedPrice, double.parse((wheatPrice * 0.8).toStringAsFixed(2)));
    expect(controller.warehouse['wheat'], 15); // 10 + 5
    expect(controller.cash, initialCash - (double.parse((wheatPrice * 0.8).toStringAsFixed(2)) * 5));

    // 3. UI Dialog: opening _showLimitBuyOrderDialog allows submitting when targetPrice >= currentPrice
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketTab(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify limit orders tab displays both completed orders
    await tester.ensureVisible(find.textContaining('Alış Emirlerim'));
    await tester.tap(find.textContaining('Alış Emirlerim'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Geçmiş Emirler (2)'), findsOneWidget);
    expect(find.text('10 Adet Buğday'), findsOneWidget);
    expect(find.text('5 Adet Buğday'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('WarehouseTab Hizli Sat dialog shows unit selling price, market price, and updates cash calculation', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameController(autoLoad: false);
    controller.warehouse['wheat'] = 20;

    final mItem = controller.marketItems['wheat']!;
    final quickPrice = mItem.quickSellPrice;
    final marketPrice = mItem.currentPrice;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WarehouseTab(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open Hızlı Sat dialog
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Hızlı Sat'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Hızlı Sat'));
    await tester.pumpAndSettle();

    // Verify dialog title and unit prices are shown
    expect(find.text('Buğday Hızlı Sat'), findsOneWidget);
    expect(find.text('Birim Satış Fiyatı:'), findsOneWidget);
    expect(find.text('${quickPrice.toStringAsFixed(2)} ₺'), findsOneWidget);
    expect(find.text('Anlık Borsa Değeri:'), findsOneWidget);
    expect(find.text('${marketPrice.toStringAsFixed(2)} ₺'), findsOneWidget);
    expect(find.text('Birim Fiyat:'), findsOneWidget);
    expect(find.text('${quickPrice.toStringAsFixed(2)} ₺ / adet'), findsOneWidget);

    // Verify total cash calculation for 20 units
    final expectedTotal = (20 * quickPrice).toStringAsFixed(2);
    expect(find.text('+$expectedTotal ₺'), findsOneWidget);

    controller.dispose();
  });

  test('FirebaseService local fallback handles registration, login, and credential validation properly', () async {
    final fb = FirebaseService();
    await fb.signOut();

    // 1. Register rumeysa with password 294511
    final regError = await fb.registerWithEmail(
      email: 'rumeysa@test.com',
      password: 'password294511',
      username: 'rumeysa',
      companyName: 'Rumeysa Holding',
    );
    expect(regError, isNull);

    // 2. Cannot re-register same username (case-insensitive)
    final dupError = await fb.registerWithEmail(
      email: 'rumeysa2@test.com',
      password: 'password294511',
      username: 'RUMEYSA',
    );
    expect(dupError, isNotNull);
    expect(dupError, contains('zaten kullanımda'));

    // 3. Login with wrong password fails
    final wrongPassError = await fb.loginWithEmailOrUsername(
      identifier: 'rumeysa',
      password: 'wrongpassword',
    );
    expect(wrongPassError, isNotNull);
    expect(wrongPassError, contains('hatalı'));

    // 4. Login with correct password succeeds
    final loginSuccess = await fb.loginWithEmailOrUsername(
      identifier: 'rumeysa',
      password: 'password294511',
    );
    expect(loginSuccess, isNull);
    expect(fb.username, 'rumeysa');
    expect(fb.companyName, 'Rumeysa Holding');
    expect(fb.isLoggedIn, isTrue);

    await fb.signOut();
  });

  testWidgets('AdminDashboardView players tab renders status tabs (Tümü, Çevrimiçi, Çevrimdışı, Yasaklı) and filters players', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fb = FirebaseService();
    await fb.signOut();

    // Create local test accounts
    await fb.saveLocalAccount({
      'uid': 'test_player_online',
      'username': 'OnlinePlayer',
      'username_lowercase': 'onlineplayer',
      'email': 'online@test.com',
      'companyName': 'Online Corp',
      'isOnline': true,
      'isBanned': false,
      'lastActiveAt': DateTime.now().toIso8601String(),
    });

    await fb.saveLocalAccount({
      'uid': 'test_player_banned',
      'username': 'BannedPlayer',
      'username_lowercase': 'bannedplayer',
      'email': 'banned@test.com',
      'companyName': 'Banned Corp',
      'isOnline': false,
      'isBanned': true,
      'banReason': 'Hile kullanımı',
      'lastActiveAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: AdminDashboardView(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify all 4 tabs are present
    expect(find.text('Tümü'), findsOneWidget);
    expect(find.text('Çevrimiçi'), findsOneWidget);
    expect(find.text('Çevrimdışı'), findsOneWidget);
    expect(find.text('Yasaklı'), findsOneWidget);

    // 2. In "Tümü", both players are visible
    expect(find.text('OnlinePlayer'), findsOneWidget);
    expect(find.text('BannedPlayer'), findsOneWidget);

    // 3. Switch to "Çevrimiçi" tab
    await tester.ensureVisible(find.text('Çevrimiçi'));
    await tester.tap(find.text('Çevrimiçi'));
    await tester.pumpAndSettle();
    expect(find.text('OnlinePlayer'), findsOneWidget);
    expect(find.text('BannedPlayer'), findsNothing);

    // 4. Switch to "Yasaklı" tab
    await tester.ensureVisible(find.text('Yasaklı'));
    await tester.tap(find.text('Yasaklı'));
    await tester.pumpAndSettle();
    expect(find.text('OnlinePlayer'), findsNothing);
    expect(find.text('BannedPlayer'), findsOneWidget);

    // 5. Switch to "Çevrimdışı" tab
    await tester.ensureVisible(find.text('Çevrimdışı'));
    await tester.tap(find.text('Çevrimdışı'));
    await tester.pumpAndSettle();
    expect(find.text('OnlinePlayer'), findsNothing);

    // Switch back to "Tümü"
    await tester.ensureVisible(find.text('Tümü'));
    await tester.tap(find.text('Tümü'));
    await tester.pumpAndSettle();
    expect(find.text('OnlinePlayer'), findsOneWidget);
    expect(find.text('BannedPlayer'), findsOneWidget);
  });

  testWidgets('MarketTab community listings categorization, search, sort, and official reserve test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameController(autoLoad: false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketTab(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Switch to Oyuncu Pazarı
    await tester.tap(find.text('Oyuncu Pazarı'));
    await tester.pumpAndSettle();

    // 2. Verify search bar and category chips are rendered
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Tümü'), findsWidgets);
    expect(find.text('🌾 Hammadde'), findsOneWidget);
    expect(find.text('🏭 Ara Mamul'), findsOneWidget);
    expect(find.text('🥖 Nihai Ürün'), findsOneWidget);
    expect(find.text('🏛️ Piyasa Rezervi'), findsOneWidget);
    expect(find.text('👤 Oyuncular'), findsOneWidget);

    // 3. Verify official reserve listings have official badges
    expect(find.text('RESMİ PİYASA REZERVİ'), findsWidgets);
    expect(find.text('Hemen Satın Al'), findsWidgets);

    // 4. Test search functionality
    await tester.enterText(find.byType(TextField), 'Buğday');
    await tester.pumpAndSettle();
    expect(find.text('Buğday'), findsWidgets);

    // 5. Test clear search
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('RESMİ PİYASA REZERVİ'), findsWidgets);

    // 6. Test category filter tap (🏛️ Piyasa Rezervi)
    await tester.ensureVisible(find.text('🏛️ Piyasa Rezervi'));
    await tester.tap(find.text('🏛️ Piyasa Rezervi'));
    await tester.pumpAndSettle();
    expect(find.text('RESMİ PİYASA REZERVİ'), findsWidgets);

    controller.dispose();
  });

  testWidgets('Hybrid persistence preserves purchased facilities on reload and market has zero fake sellers', (WidgetTester tester) async {
    final controller = GameController(autoLoad: false);

    // 1. Verify community listings contain ZERO fake/simulated sellers (only official reserves)
    for (var l in controller.communityListings) {
      expect(l.isOfficialReserve, isTrue);
      expect(l.sellerId, equals('SYSTEM'));
      expect(l.id.startsWith('comm_'), isFalse);
    }

    // 2. Buy a facility (wheat farm)
    final blueprints = ProductionFacility.getBlueprints();
    final wheatFarm = blueprints.firstWhere((b) => b.id == 'wheat_farm');
    controller.cash = 20000.0;
    controller.buyFacility(wheatFarm);
    expect(controller.ownedFacilities.length, equals(1));

    // 3. Save state locally
    await SaveService().save(controller, playerId: 'test_player_persistence');

    // 4. Create a new controller instance simulating app update / restart
    final reloadedController = GameController(autoLoad: false);
    expect(reloadedController.ownedFacilities.length, equals(0));

    // 5. Load from storage for that player
    await reloadedController.loadFromStorage(playerId: 'test_player_persistence');

    // 6. Verify purchased facilities are completely preserved!
    expect(reloadedController.ownedFacilities.length, equals(1));
    expect(reloadedController.ownedFacilities.first.name, equals('Buğday Tarlası'));

    controller.dispose();
    reloadedController.dispose();
  });

  testWidgets('Performance optimization: GameController throttles ticks, auto-save interval backed off, and themeModeNotifier reacts independently', (WidgetTester tester) async {
    final controller = GameController(autoLoad: false);

    // 1. ThemeModeNotifier verification
    expect(controller.themeModeNotifier.value, isFalse);
    controller.toggleTheme();
    expect(controller.isDarkMode, isTrue);
    expect(controller.themeModeNotifier.value, isTrue);
    controller.toggleTheme();
    expect(controller.isDarkMode, isFalse);
    expect(controller.themeModeNotifier.value, isFalse);

    // 2. Idle tick throttling: With no facilities producing and no stores running, 100ms tick does not spam notifyListeners
    int notifyCount = 0;
    controller.addListener(() {
      notifyCount++;
    });

    // Run a 100ms tick with zero active facilities/stores
    controller.tickForTesting(0.1);
    expect(notifyCount, equals(0), reason: 'Idle ticks should not trigger notifyListeners');

    // 3. Event-driven immediate notification: When an actual harvest/production completes, stateChanged triggers immediately
    final blueprints = ProductionFacility.getBlueprints();
    final wheatFarm = blueprints.firstWhere((b) => b.id == 'wheat_farm');
    controller.cash = 20000.0;
    controller.buyFacility(wheatFarm);
    // Facility is newly bought and producing (wheat duration is 15s)
    expect(controller.ownedFacilities.first.isProducing, isTrue);

    // Set progress to almost done (0.99)
    controller.ownedFacilities.first.progress = 0.99;
    // Tick enough time to exceed 1.0 (completion event)
    controller.tickForTesting(1.0);
    // Production completed -> stateChanged triggered notifyListeners!
    expect(notifyCount, greaterThan(0), reason: 'Completion of production must immediately notify listeners');

    controller.dispose();
  });

  testWidgets('Profile & asset persistence: survives app restart, Firestore dynamic nested maps, and preserves facilities', (WidgetTester tester) async {
    SaveService().resetForTesting();
    SharedPreferences.setMockInitialValues({});

    final wheatFarm = ProductionFacility.getBlueprints().firstWhere((b) => b.id == 'wheat_farm');
    final potatoField = ProductionFacility.getBlueprints().firstWhere((b) => b.id == 'potato_field');

    // 1. Oyuncu oturum açar, tarlalar alır ve oyunu kaydeder
    final controller = GameController(autoLoad: false);
    controller.cash = 50000.0;
    controller.buyFacility(wheatFarm, quantity: 2);
    controller.buyFacility(potatoField, quantity: 1);
    controller.warehouse['wheat'] = 250;
    controller.warehouse['potato'] = 150;
    controller.highestNetWorth = 75000.0;

    expect(controller.ownedFacilities.length, 3);
    expect(controller.warehouse['wheat'], 250);

    const testPid = 'ply_test_cosskun_123';
    final savedData = controller.toSaveJson();
    await SaveService().saveDirectData(savedData, playerId: testPid);

    // 2. Uygulama tamamen kapatıldı ve yeni controller ile açıldı (Cold Boot)
    final freshController = GameController(autoLoad: false);
    expect(freshController.ownedFacilities.isEmpty, isTrue);

    // loadFromStorage çağrılır
    await freshController.loadFromStorage(playerId: testPid);

    expect(freshController.ownedFacilities.length, 3, reason: 'Tüm tarlalar restart sonrası korunmalıdır');
    expect(freshController.warehouse['wheat'], 250);
    expect(freshController.warehouse['potato'], 150);
    expect(freshController.cash, 50000.0 - (wheatFarm.purchaseCost * 2 + potatoField.purchaseCost));

    // 3. Firestore'dan gelen dynamic Object? tipindeki haritalar ile test (Crash & wipe engeli)
    // Cloud Firestore nested map'leri Map<dynamic, dynamic> olarak döner
    final firestoreRawData = <String, dynamic>{
      'cash': 85000.0,
      'highestNetWorth': 95000.0,
      'netWorth': 95000.0,
      'warehouse': <dynamic, dynamic>{'wheat': 500, 'flour': 100},
      'ownedFacilities': <dynamic>[
        <dynamic, dynamic>{
          'id': 'wheat_farm_100',
          'blueprintId': 'wheat_farm',
          'level': 2,
          'progress': 0.5,
          'isProducing': true,
        },
      ],
      'savedAt': DateTime.now().toIso8601String(),
    };

    // loadFromSaveJson bu haritayı sıfırlamadan veya çökmeden güvenle parse etmelidir
    freshController.loadFromSaveJson(firestoreRawData);
    expect(freshController.ownedFacilities.length, 1);
    expect(freshController.ownedFacilities.first.level, 2);
    expect(freshController.warehouse['wheat'], 500);

    // 4. Fallback save mekanizması: Eğer playerId bulunamazsa cihazdaki son aktif yedekten kurtarır
    final fallbackController = GameController(autoLoad: false);
    final fallbackData = await SaveService().getLastFallbackSaveData();
    expect(fallbackData, isNotNull, reason: 'Son aktif yedek diskte bulunmalıdır');
    fallbackController.loadFromSaveJson(fallbackData!);
    expect(fallbackController.ownedFacilities.isNotEmpty, isTrue);

    controller.dispose();
    freshController.dispose();
    fallbackController.dispose();
  });

  testWidgets('Session persistence: closing app and relaunching keeps user authenticated and avoids AuthScreen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final fb = FirebaseService();

    // 1. Oyuncu giriş yapar
    await fb.registerWithEmail(
      email: 'cosskun@piyasa.com',
      password: 'password123',
      username: 'COSSKUN',
      companyName: 'COSSKUN Holding',
    );
    final loginError = await fb.loginWithEmailOrUsername(identifier: 'COSSKUN', password: 'password123');
    expect(loginError, isNull);
    expect(fb.isAuthenticated, isTrue);
    expect(fb.username, 'COSSKUN');

    // 2. Uygulama tamamen kapatıldı ve telefon ana ekranından yeniden başlatıldı
    // initialize() SharedPreferences'tan oturumu okur
    await fb.initialize();

    // Oturumun ve profilin açık kaldığı doğrulanır
    expect(fb.isAuthenticated, isTrue, reason: 'Uygulama kapatılıp açıldığında oturum açık kalmalıdır');
    expect(fb.isLoggedIn, isTrue);
    expect(fb.username, 'COSSKUN');
    expect(fb.companyName, 'COSSKUN Holding');

    // 3. Widget ağacında doğrudan oyun yükleme/ana ekrana geçildiği, AuthScreen'in çıkmadığı test edilir
    final controller = GameController(autoLoad: false);
    await tester.pumpWidget(PiyasaApp(
      controller: controller,
      skipLoadingForTesting: true,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Giriş yap / Kayıt ol ekranı görünmemeli, doğrudan ana ekran (HomeScreen) açılmalıdır
    expect(find.byType(AuthScreen), findsNothing, reason: 'Kullanıcı oturumu açıkken asla AuthScreen açılmamalıdır');
    expect(find.byType(HomeScreen), findsOneWidget, reason: 'Oturumu açık kullanıcı doğrudan HomeScreen görmelidir');

    controller.dispose();
  });

  testWidgets('Cold boot offline progress: Closing app overnight, relaunching next morning simulates full production, retail sales, interest, and shows OfflineSummaryDialog', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 950);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const testPid = 'player_cold_boot_offline';

    // 1. Dün gece oynayan oyuncunun oyun durumu (1 buğday tarlası, 1 fırın büfesi, 10.000 TL mevduat)
    final initialController = GameController();
    initialController.cash = 10000.0;
    initialController.bankSavings = 10000.0;

    final farm = ProductionFacility.getBlueprints().firstWhere((f) => f.id == 'wheat_farm').copy();
    farm.level = 1;
    farm.isProducing = true;
    initialController.ownedFacilities.add(farm);

    final bakery = RetailStore.getBlueprints().firstWhere((s) => s.id == 'kiosk_bread').copy();
    bakery.level = 1;
    bakery.isSelling = true;
    bakery.productSlots[0].shelfStock = 25;
    bakery.productSlots[0].isSelling = true;
    bakery.productSlots[0].retailPrice = 18.0;
    initialController.ownedStores.add(bakery);

    // 8 saat önce (dün gece) oyundan çıkış yapıldı
    final eightHoursAgo = DateTime.now().subtract(const Duration(hours: 8));
    initialController.lastActiveAt = eightHoursAgo;

    final saveData = initialController.toSaveJson();
    // lastActiveAt ve savedAt 8 saat öncesine ayarlanır
    saveData['lastActiveAt'] = eightHoursAgo.toIso8601String();
    saveData['savedAt'] = eightHoursAgo.toIso8601String();
    await SaveService().saveDirectData(saveData, playerId: testPid);

    initialController.dispose();

    // 2. Sabah oldu: Uygulama sıfırdan soğuk açılış (Cold Boot) ile başlatılıyor
    final coldBootController = GameController(autoLoad: false);
    expect(coldBootController.ownedFacilities.isEmpty, isTrue);

    // loadFromStorage çağrılır
    final loaded = await coldBootController.loadFromStorage(playerId: testPid);
    expect(loaded, isTrue);

    // 3. Tarlaların çalıştığı ve hasatların depoya girdiği doğrulanır
    expect(coldBootController.ownedFacilities.length, 1);
    expect(coldBootController.latestOfflineReport, isNotNull, reason: '8 saat çevrimdışı kalındığında mutlaka çevrimdışı raporu oluşturulmalıdır');

    final report = coldBootController.latestOfflineReport!;
    expect(report.hasAnyActivity, isTrue);
    expect(report.producedItems['wheat'], isNotNull);
    expect(report.producedItems['wheat']!, greaterThan(0), reason: 'Buğday tarlası dün geceden bu sabaha buğday üretmiş olmalıdır');
    expect(coldBootController.warehouse['wheat'], greaterThan(0));

    // Perakende fırın satışları yapıldı
    expect(report.retailItemsSold, greaterThan(0));
    expect(report.retailRevenue, greaterThan(0));

    // Bankadaki mevduat gece boyunca faiz kazandı
    expect(report.bankInterestEarned, greaterThan(0));
    expect(coldBootController.bankSavings, greaterThan(10000.0));

    // 4. HomeScreen açıldığında OfflineSummaryDialog'un oyuncuya gösterildiği doğrulanır
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(controller: coldBootController),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byType(OfflineSummaryDialog), findsOneWidget, reason: 'Oyuncu oyunu açtığında Siz Yokken Şirketiniz Çalıştı diyaloğu çıkmalıdır');
    expect(find.text('Siz Yokken Şirketiniz Çalıştı!'), findsOneWidget);
    expect(find.textContaining('Buğday'), findsWidgets);

    // Diyalogdaki kapatma butonuna basıldığında kapanır
    final dismissBtn = find.textContaining('Harika');
    expect(dismissBtn, findsOneWidget);
    await tester.tap(dismissBtn);
    await tester.pumpAndSettle();

    expect(find.byType(OfflineSummaryDialog), findsNothing);

    coldBootController.dispose();
  });

  testWidgets('User Profile: Username uniqueness is strictly enforced and duplicate usernames are rejected', (WidgetTester tester) async {
    final fb = FirebaseService();
    await fb.initialize();

    // 1. Oyuncu 1 (ALPEREN) kayıt olur ve oturum açar
    final regErr1 = await fb.registerWithEmail(
      email: 'alperen@test.com',
      password: 'password123',
      username: 'ALPEREN',
      companyName: 'Alperen Holding',
    );
    expect(regErr1, isNull);

    // 2. Oyuncu 2 (BERKE) kayıt olur ve oturum açar
    final regErr2 = await fb.registerWithEmail(
      email: 'berke@test.com',
      password: 'password123',
      username: 'BERKE',
      companyName: 'Berke Lojistik',
    );
    expect(regErr2, isNull);

    // Berke olarak giriş yap
    final loginErr = await fb.loginWithEmailOrUsername(
      identifier: 'BERKE',
      password: 'password123',
    );
    expect(loginErr, isNull);
    expect(fb.username, 'BERKE');

    // 3. Berke kullanıcı adını ALPEREN (büyük-küçük harf farketmeksizin) yapmaya çalışır -> REDDEDİLMELİ!
    final dupErr = await fb.updateProfile(newUsername: 'alperen');
    expect(dupErr, isNotNull);
    expect(dupErr, contains('zaten başka bir oyuncu tarafından kullanılıyor'));

    // 4. Berke kendi kullanıcı adını (BERKE -> Berke_Pro) benzersiz yeni bir adla değiştirir -> BAŞARILI OLMALI!
    final okErr = await fb.updateProfile(
      newUsername: 'Berke_Pro',
      newCompanyName: 'Berke Global A.Ş.',
    );
    expect(okErr, isNull);
    expect(fb.username, 'Berke_Pro');
    expect(fb.companyName, 'Berke Global A.Ş.');

    // 5. Eski ad (BERKE) artık boşa çıktığından başkası alabilmeli
    final availableOld = await fb.isUsernameAvailable('BERKE');
    expect(availableOld, isTrue);

    // 6. Yanlış mevcut şifre ile şifre değiştirilememeli
    final wrongPassErr = await fb.updateProfile(
      currentPassword: 'wrong_password',
      newPassword: 'new_password123',
    );
    expect(wrongPassErr, isNotNull);
    expect(wrongPassErr, contains('Mevcut şifreniz hatalı'));

    // 7. Doğru mevcut şifre ile şifre güncellenmeli
    final passOk = await fb.updateProfile(
      currentPassword: 'password123',
      newPassword: 'new_password123',
    );
    expect(passOk, isNull);

    // 8. Yeni şifreyle çıkış yapıp tekrar giriş yapılabilmeli
    await fb.signOut();
    final reLoginErr = await fb.loginWithEmailOrUsername(
      identifier: 'Berke_Pro',
      password: 'new_password123',
    );
    expect(reLoginErr, isNull);
    expect(fb.username, 'Berke_Pro');
  });

  testWidgets('User Profile Page: ProfileScreen allows editing username, company name, changing password, and reflects updates', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fb = FirebaseService();
    await fb.initialize();

    // 1. Oyuncu kayıt olup oturum açar
    await fb.registerWithEmail(
      email: 'profile_test@test.com',
      password: 'secret_pass_123',
      username: 'TestUser1',
      companyName: 'İlk Şirketim Ltd.',
    );

    await fb.loginWithEmailOrUsername(
      identifier: 'TestUser1',
      password: 'secret_pass_123',
    );

    final controller = GameController(autoLoad: false);
    controller.cash = 45000.0;

    // 2. ProfileScreen ekrana yüklenir
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    // 3. Mevcut bilgilerin formda gösterildiği doğrulanır
    expect(find.text('Kullanıcı Profili'), findsOneWidget);
    expect(find.text('TestUser1'), findsWidgets);
    expect(find.text('İlk Şirketim Ltd.'), findsWidgets);

    // 4. Şirket adını ve kullanıcı adını değiştir
    final usernameField = find.widgetWithText(TextFormField, 'TestUser1');
    await tester.enterText(usernameField, 'TestUser_V2');

    final companyField = find.widgetWithText(TextFormField, 'İlk Şirketim Ltd.');
    await tester.enterText(companyField, 'Zirve Holding A.Ş.');

    // Şifre alanlarına yeni şifre gir
    final currentPassField = find.widgetWithText(TextFormField, 'Mevcut Şifreniz');
    await tester.enterText(currentPassField, 'secret_pass_123');

    final newPassField = find.widgetWithText(TextFormField, 'Yeni Şifre (en az 6 karakter)');
    await tester.enterText(newPassField, 'super_secret_456');

    final confirmPassField = find.widgetWithText(TextFormField, 'Yeni Şifre (Tekrar)');
    await tester.enterText(confirmPassField, 'super_secret_456');

    // 5. Değişiklikleri Kaydet butonuna tıkla
    final saveBtn = find.text('Değişiklikleri Kaydet');
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Başarı bildirimi çıkmalı
    expect(find.text('Profil bilgileriniz başarıyla güncellendi!'), findsOneWidget);

    // FirebaseService üzerinde bilgilerin güncellendiği doğrulanır
    expect(fb.username, 'TestUser_V2');
    expect(fb.companyName, 'Zirve Holding A.Ş.');

    controller.dispose();
  });

  testWidgets('Real Player-to-Player Offers: Offer arrives to real seller account, requires manual approval, prevents auto-acceptance timer, and buyer completes purchase', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final fb = FirebaseService();

    // 1. Satıcı 'rumeysa' olarak kayıt ol ve giriş yap
    await fb.registerWithEmail(
      email: 'rumeysa@test.com',
      password: 'password123',
      username: 'rumeysa',
      companyName: 'Rumeysa Tarım',
    );
    await fb.loginWithEmailOrUsername(
      identifier: 'rumeysa',
      password: 'password123',
    );

    final sellerController = GameController(autoLoad: false);
    sellerController.warehouse['wheat'] = 100;

    // Satıcı 100 buğdayı 5.00 TL'den pazara koyar
    sellerController.createListing('wheat', 100, 5.00);
    final sellerListing = sellerController.activeListings.firstWhere((l) => l.itemId == 'wheat');
    expect(sellerListing.remainingQuantity, 100);
    expect(sellerListing.sellerId, fb.playerId);

    // 2. Alıcı 'cosskun' olarak kayıt ol ve giriş yap
    await fb.registerWithEmail(
      email: 'cosskun@test.com',
      password: 'password123',
      username: 'cosskun',
      companyName: 'Cosskun Holding',
    );
    await fb.loginWithEmailOrUsername(
      identifier: 'cosskun',
      password: 'password123',
    );

    final buyerController = GameController(autoLoad: false);
    buyerController.cash = 10000.0;

    // Alıcı, rumeysa'nın ilanına 40 adet buğday için 4.00 TL teklif verir (Toplam 160 TL)
    final offerListing = MarketListing(
      id: sellerListing.id,
      itemId: 'wheat',
      initialQuantity: 100,
      remainingQuantity: 100,
      pricePerUnit: 5.00,
      listedAt: DateTime.now(),
      sellerName: 'Rumeysa Tarım',
      sellerId: sellerListing.sellerId,
      isPlayerListing: false,
    );

    final offerErr = buyerController.makeOfferOnListing(
      offerListing,
      40,
      4.00,
      message: '40 adet için 4 TL olur mu?',
    );
    expect(offerErr, isNull);

    // Alıcıda teklif oluşmalı ve durumu pending olmalı
    expect(buyerController.offers.length, 1);
    final outgoingOffer = buyerController.offers.first;
    expect(outgoingOffer.direction, OfferDirection.outgoing);
    expect(outgoingOffer.status, OfferStatus.pending);
    expect(outgoingOffer.buyerName, 'Cosskun Holding');
    expect(outgoingOffer.sellerName, 'Rumeysa Tarım');

    // 3. Simülasyon zamanı ilerletilse bile teklif ASLA otomatik onaylanmamalı!
    for (int i = 0; i < 10; i++) {
      buyerController.tickForTesting(1.0);
    }
    expect(outgoingOffer.status, OfferStatus.pending); // Hâlâ pending!

    // 4. Teklif satıcı rumeysa'nın havuzuna düşmeli
    final incomingOffers = await fb.getLocalOffers();
    final sellerOffer = incomingOffers.firstWhere((o) => o.id == outgoingOffer.id);
    expect(sellerOffer.sellerId, sellerListing.sellerId);
    expect(sellerOffer.status, OfferStatus.pending);

    // Satıcı rumeysa teklifi manuel onaylar
    final acceptErr = sellerController.acceptIncomingOffer(sellerOffer);
    expect(acceptErr, isNull);
    expect(sellerOffer.status, OfferStatus.accepted);

    // 5. Alıcı cosskun onay bildirimini alır ve satın almayı tamamlar
    outgoingOffer.status = OfferStatus.accepted;
    final buyErr = buyerController.buyAcceptedOffer(outgoingOffer);
    expect(buyErr, isNull);

    // Alıcının kasasından para düşmeli, buğday depoya eklenmeli
    expect(buyerController.cash, 10000.0 - 160.0);
    expect(buyerController.warehouse['wheat'], 40);
    expect(outgoingOffer.status, OfferStatus.completed);

    // 6. Kendi ilanına teklif verememe kuralı
    final ownOfferErr = buyerController.makeOfferOnListing(
      MarketListing(
        id: 'own_list_1',
        itemId: 'wheat',
        initialQuantity: 10,
        remainingQuantity: 10,
        pricePerUnit: 5.0,
        listedAt: DateTime.now(),
        sellerId: fb.playerId,
        sellerName: fb.companyName,
        isPlayerListing: true,
      ),
      5,
      4.0,
    );
    expect(ownOfferErr, contains('Kendi ilanınıza teklif veremezsiniz'));

    sellerController.dispose();
    buyerController.dispose();
  });

  testWidgets('Single Active Session Concurrency: Remote device login invalidates active session, renders SessionTerminatedDialog, and signs out', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fb = FirebaseService();
    await fb.signOut();

    // 1. Register and log in on Device A
    final regErr = await fb.registerWithEmail(
      email: 'deviceA@piyasa.com',
      password: 'password123',
      username: 'device_user',
      companyName: 'Device A Holding',
    );
    expect(regErr, isNull);

    final loginErr = await fb.loginWithEmailOrUsername(
      identifier: 'device_user',
      password: 'password123',
    );
    expect(loginErr, isNull);
    expect(fb.isLoggedIn, isTrue);
    expect(fb.currentSessionId, isNotNull);
    expect(fb.currentSessionId, isNotEmpty);

    final controller = GameController(autoLoad: false);
    controller.resetToNewGame();

    await tester.pumpWidget(
      PiyasaApp(
        controller: controller,
        skipAuthForTesting: true,
        skipLoadingForTesting: true,
      ),
    );
    await tester.pumpAndSettle();

    // Verify HomeScreen is rendered and session is healthy
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SessionTerminatedDialog), findsNothing);
    expect(fb.isSessionTerminatedNotifier.value, isFalse);

    // 2. Simulate Device B logging into the same account with a new session ID
    final remoteSessionId = 'sess_remote_device_b_999';
    final userAccounts = await fb.getLocalAccounts();
    final userAcc = Map<String, dynamic>.from(userAccounts['device_user']!);
    userAcc['currentSessionId'] = remoteSessionId;
    await fb.saveLocalAccount(userAcc);

    // Verify session termination notifier triggers
    expect(fb.isSessionTerminatedNotifier.value, isTrue);

    // Pump to let HomeScreen's listener present SessionTerminatedDialog
    await tester.pumpAndSettle();

    expect(find.byType(SessionTerminatedDialog), findsOneWidget);
    expect(find.text('OTURUMUNUZ KAPATILDI'), findsOneWidget);
    expect(find.text('Farklı Cihazdan Giriş Yapıldı'), findsOneWidget);
    expect(find.text('Giriş Ekranına Dön'), findsOneWidget);

    // 3. Tap "Giriş Ekranına Dön" button
    await tester.tap(find.text('Giriş Ekranına Dön'));
    await tester.pumpAndSettle();

    // Verify user is signed out and redirected to AuthScreen
    expect(fb.isLoggedIn, isFalse);
    expect(fb.currentSessionId, isNull);
    expect(find.byType(SessionTerminatedDialog), findsNothing);
    expect(find.byType(AuthScreen), findsOneWidget);

    controller.dispose();
  });

  testWidgets('Notification Permissions on First Auth: Requested only once upon initial user creation/login and persists state', (WidgetTester tester) async {
    final notif = NotificationService();
    await notif.resetPermissionRequestState();

    // 1. Initial state: Not requested yet
    expect(await notif.hasRequestedPermissionsBefore(), isFalse);

    // 2. First request triggers and marks requested state as true
    await notif.requestPermissionsOnFirstAuth();
    expect(await notif.hasRequestedPermissionsBefore(), isTrue);

    // 3. Second call skips and returns false
    final secondAttempt = await notif.requestPermissionsOnFirstAuth();
    expect(secondAttempt, isFalse);

    // 4. Reset on new registration clears state
    await notif.resetPermissionRequestState();
    expect(await notif.hasRequestedPermissionsBefore(), isFalse);

    // 5. AuthScreen guest login invokes requestPermissionsOnFirstAuth
    bool authenticated = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          onAuthenticated: () {
            authenticated = true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Hesapsız Hızlı Başla (Misafir Modu)'));
    await tester.pumpAndSettle();

    expect(authenticated, isTrue);
    expect(await notif.hasRequestedPermissionsBefore(), isTrue);
  });

  testWidgets('Warehouse Full Notifications: In-game trigger, background scheduling, and cancellation on empty/upgrade', (WidgetTester tester) async {
    final controller = GameController(autoLoad: false);
    final notif = NotificationService();
    notif.lastShownNotificationId = null;
    notif.lastShownTitle = null;
    notif.lastScheduledDelay = null;
    notif.hasScheduledWarehouseFullNotification = false;

    // 1. Initially warehouse is empty
    expect(controller.currentWarehouseWeight, 0.0);
    expect(controller.isWarehouseFull, isFalse);
    expect(controller.hasNotifiedWarehouseFull, isFalse);

    // 2. Add an active wheat farm
    final wheatFacility = ProductionFacility.getBlueprints().first.copy(newId: 'wheat_farm_1');
    controller.ownedFacilities.add(wheatFacility);
    expect(wheatFacility.isProducing, isTrue);

    // 3. Estimate time until warehouse full:
    // Capacity = 5000 kg. Wheat farm outputs 5 kg every 10 sec (0.5 kg/sec).
    // Should take approximately 10000 seconds to reach 5000 kg.
    final estimatedSeconds = controller.estimateSecondsUntilWarehouseFull();
    expect(estimatedSeconds, isNotNull);
    expect(estimatedSeconds, greaterThan(0));

    // 4. Backgrounding app when warehouse is not yet full schedules future notification
    controller.pauseGameLoop();
    expect(notif.hasScheduledWarehouseFullNotification, isTrue);
    expect(notif.lastScheduledDelay, isNotNull);

    // 5. Resuming app cancels scheduled background notification
    await controller.resumeGameLoop();
    expect(notif.hasScheduledWarehouseFullNotification, isFalse);

    // 6. Fill warehouse to 100% capacity
    controller.warehouse['wheat'] = 5000;
    expect(controller.currentWarehouseWeight, 5000.0);
    expect(controller.isWarehouseFull, isTrue);

    // Trigger tick/check
    controller.checkWarehouseFullStatusForTesting();
    expect(controller.hasNotifiedWarehouseFull, isTrue);
    expect(notif.lastShownNotificationId, NotificationService.warehouseFullNotificationId);
    expect(notif.lastShownTitle, '📦 Deponuz Tamamen Doldu!');
    expect(controller.latestNotificationToast, contains('Deponuz tamamen doldu'));

    // 7. Selling items from warehouse drops weight below threshold and resets notification state
    controller.sellToMarket('wheat', 500);
    expect(controller.currentWarehouseWeight, 4500.0);
    expect(controller.hasNotifiedWarehouseFull, isFalse);
    expect(controller.isWarehouseFull, isFalse);

    // 8. Backgrounding when already full triggers immediate notification
    controller.warehouse['wheat'] = 5000;
    controller.pauseGameLoop();
    expect(notif.lastShownNotificationId, NotificationService.warehouseFullNotificationId);

    controller.dispose();
  });

  testWidgets('Facility Dynamic Recipe Switching: Switch recipe on the fly, UI sheet selection, and persistence', (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final controller = GameController();

    // 1. Clear default facilities and add a Garment Atelier (Konfeksiyon Fabrikası)
    controller.ownedFacilities.clear();
    controller.cash = 500000.0;
    final allBlueprints = ProductionFacility.getBlueprints();
    final garmentBp = allBlueprints.firstWhere((b) => b.id == 'garment_atelier');
    controller.buyFacility(garmentBp);

    final atelier = controller.ownedFacilities.first;
    expect(atelier.availableRecipes.length, greaterThanOrEqualTo(5));
    expect(atelier.activeRecipeIndex, 0);
    expect(atelier.recipe.outputItemId, 'cotton_tshirt');

    // 2. Switch recipe directly via controller to Hakiki Deri Ceket (index 3)
    final leatherJacketIdx = atelier.availableRecipes.indexWhere((r) => r.outputItemId == 'leather_jacket');
    expect(leatherJacketIdx, isNonNegative);
    controller.setFacilityRecipe(atelier, leatherJacketIdx);

    expect(atelier.activeRecipeIndex, leatherJacketIdx);
    expect(atelier.recipe.outputItemId, 'leather_jacket');
    expect(atelier.recipe.name, 'Hakiki Deri Ceket Dikimi');

    // 3. Verify JSON serialization preserves activeRecipeIndex
    final json = atelier.toJson();
    expect(json['activeRecipeIndex'], leatherJacketIdx);
    final restored = ProductionFacility.fromJson(json);
    expect(restored?.activeRecipeIndex, leatherJacketIdx);
    expect(restored?.recipe.outputItemId, 'leather_jacket');

    // 4. UI interaction: Render ProductionTab and test modal recipe selection
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionTab(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify active recipe name is displayed in UI
    expect(find.text('Hakiki Deri Ceket Dikimi'), findsWidgets);
    expect(find.text('Reçete Seç ▾'), findsOneWidget);

    // Tap 'Reçete Seç ▾' to open bottom sheet
    await tester.tap(find.text('Reçete Seç ▾'));
    await tester.pumpAndSettle();

    // Verify modal sheet opened with facility title and available recipes
    expect(find.textContaining('Üretim Reçetesi'), findsWidgets);
    expect(find.text('Triko Kazak Örme'), findsOneWidget);

    // Tap on Triko Kazak Örme's switch button
    // It should switch recipe to wool_sweater
    final switchButtons = find.widgetWithText(ElevatedButton, 'Bu Reçeteye Geç');
    expect(switchButtons, findsWidgets);
    await tester.tap(switchButtons.first);
    await tester.pumpAndSettle();

    // Verify recipe was switched
    expect(atelier.recipe.outputItemId, isNot('leather_jacket'));

    controller.dispose();
  });

  testWidgets('Daily raw quota restricts raw commodity quick-selling while manufactured goods are unrestricted', (tester) async {
    final controller = GameController(autoLoad: false);
    controller.cash = 10000.0;

    // Stock warehouse with 1,000 wheat (raw material) and 1,000 bread (finished good)
    controller.warehouse['wheat'] = 1000;
    controller.warehouse['bread'] = 1000;

    // Net worth includes warehouse inventory (37,500 ₺ -> Player Level 2), so daily quota is 500 + 100 = 600
    expect(controller.playerLevel, 2);
    expect(controller.dailyRawQuickSellQuota, 600);
    expect(controller.remainingDailyRawQuota, 600);

    // 1. Sell 200 wheat (raw material)
    final err1 = controller.sellToMarket('wheat', 200);
    expect(err1, isNull);
    expect(controller.warehouse['wheat'], 800);
    expect(controller.dailyRawQuickSoldToday, 200);
    expect(controller.remainingDailyRawQuota, 400);

    // 2. Attempt to sell 500 wheat (exceeds remaining 400 quota)
    final err2 = controller.sellToMarket('wheat', 500);
    expect(err2, isNotNull);
    expect(err2, contains('kalan hammadde alım kotanız 400 adet'));
    expect(controller.warehouse['wheat'], 800);

    // 3. Sell exactly remaining 400 wheat
    final err3 = controller.sellToMarket('wheat', 400);
    expect(err3, isNull);
    expect(controller.warehouse['wheat'], 400);
    expect(controller.remainingDailyRawQuota, 0);

    // 4. Any further quick sale of raw material is blocked with the official state quota message
    final err4 = controller.sellToMarket('wheat', 10);
    expect(err4, isNotNull);
    expect(err4, contains('Devlet / Borsa bugünkü hammadde alım kotasını doldurdu'));

    // 5. Manufactured products (e.g. bread) have NO quota limitation
    final errBread = controller.sellToMarket('bread', 400);
    expect(errBread, isNull);
    expect(controller.warehouse['bread'], 600);

    controller.dispose();
  });

  testWidgets('Operating Expenses (OpEx) deduct active facility/store maintenance and apply idle pause discounts', (tester) async {
    final controller = GameController(autoLoad: false);
    controller.cash = 50000.0;

    // Buy 1 facility (wheat farm, base OpEx = 20 ₺/dk) and 1 store (bread kiosk, base OpEx = 30 ₺/dk)
    final farmBp = ProductionFacility.getBlueprints().firstWhere((b) => b.id == 'wheat_farm');
    final kioskBp = RetailStore.getBlueprints().firstWhere((b) => b.id == 'kiosk_bread');

    controller.buyFacility(farmBp);
    controller.buyStore(kioskBp);

    expect(controller.totalFacilityOpExPerMin, 20.0);
    expect(controller.totalStoreOpExPerMin, 30.0);
    expect(controller.totalOpExPerMin, 50.0);

    final cashBeforeTick = controller.cash;
    // Tick 60 seconds (1 minute): Should deduct ~50 ₺
    controller.tickForTesting(60.0);
    expect(controller.cash, closeTo(cashBeforeTick - 50.0, 1.0));

    // Pause facility and store: OpEx should decrease to idle discount (20% for facility, 20% for store)
    controller.toggleFacilityProducing(controller.ownedFacilities.first, false);
    controller.toggleStoreSelling(controller.ownedStores.first, false);

    expect(controller.totalFacilityOpExPerMin, 4.0); // 20 * 0.20
    expect(controller.totalStoreOpExPerMin, 8.0);   // (30 * 0.25).roundToDouble()
    expect(controller.totalOpExPerMin, 12.0);

    final cashBeforeIdleTick = controller.cash;
    controller.tickForTesting(60.0);
    expect(controller.cash, closeTo(cashBeforeIdleTick - 12.0, 0.5));

    controller.dispose();
  });

  testWidgets('Headquarters and Tenders: Upgrade building unlocks perks and quota bonus, tender fulfillment rewards cash and prestige', (tester) async {
    final controller = GameController(autoLoad: false);
    controller.cash = 15000000.0; // 15M TL capital -> Player Level 12

    // Level 0 Headquarters (15M net worth = Lv 12, base quota 500 + 1100 = 1600)
    expect(controller.hqLevel, 0);
    expect(controller.dailyRawQuickSellQuota, 1600);

    // 1. Upgrade to Level 1 (Cost: 2,500,000 ₺)
    final upErr1 = controller.upgradeHeadquarters();
    expect(upErr1, isNull);
    expect(controller.hqLevel, 1);
    expect(controller.cash, closeTo(12500000.0, 1.0));

    // 2. Upgrade to Level 2 (Cost: 7,500,000 ₺ -> +300 Quota Bonus)
    final upErr2 = controller.upgradeHeadquarters();
    expect(upErr2, isNull);
    expect(controller.hqLevel, 2);
    expect(controller.cash, closeTo(5000000.0, 1.0));
    expect(controller.dailyRawQuickSellQuota, 1900); // 1600 + 300 bonus

    // 3. Deliver a tender (e.g. İBB Somun Ekmek: 2,500 somun ekmek for 75,000 ₺ and 300 prestige)
    final ibbTender = controller.activeTenders.firstWhere((t) => t.id == 'tender_ibb_bread');
    expect(ibbTender.isCompleted, false);

    // Stock warehouse with 2,500 bread
    controller.warehouse['bread'] = 2500;
    final cashBeforeTender = controller.cash;
    final delErr = controller.deliverTender(ibbTender);
    expect(delErr, isNull);
    expect(ibbTender.isCompleted, true);
    expect(controller.warehouse['bread'], isNull); // Emptied
    expect(controller.cash, closeTo(cashBeforeTender + 75000.0, 1.0));
    expect(controller.totalPrestigePoints, 300);

    // Attempting to deliver again is blocked
    final delErr2 = controller.deliverTender(ibbTender);
    expect(delErr2, isNotNull);
    expect(delErr2, contains('daha önce başarıyla tamamlanmış'));

    // 4. Render HeadquartersTenderDialog in UI and verify both tabs
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeadquartersTenderDialog(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Holding & Kamu İhaleleri'), findsOneWidget);
    expect(find.text('Holding Genel Merkezi'), findsOneWidget);
    expect(find.textContaining('Kamu İhaleleri ('), findsOneWidget);

    controller.dispose();
  });

  testWidgets('RetailTab Kasaba Carsisi mode renders town avenue, building plots, shows branch count, and opens branch management sheet', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameController();
    controller.cash = 500000;
    final breadBp = RetailStore.getBlueprints().firstWhere((b) => b.id == 'kiosk_bread');
    controller.buyStore(breadBp); // 1 branch of kiosk_bread

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RetailTab(controller: controller), // defaults to Mode 0 (Kasaba)
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Kasaba Avenue Header and status legend
    expect(find.textContaining('Ticaret Bulvarı • 9 Parsel'), findsOneWidget);
    expect(find.text('Faal'), findsOneWidget);
    expect(find.text('Uyarı'), findsOneWidget);
    expect(find.text('Boş Arsa'), findsOneWidget);

    // 2. Verify Owned Building Card for Köşe Büfe & Fırın
    expect(find.text(breadBp.name), findsOneWidget);
    expect(find.text('1 Şube'), findsOneWidget);
    expect(find.text('Şubeleri Yönet'), findsOneWidget);

    // 3. Verify Unowned Plots are rendered (8 unowned plots with "İlk Şubeyi Aç")
    expect(find.textContaining('İlk Şubeyi Aç'), findsNWidgets(8));

    // 4. Tap "Şubeleri Yönet" to open Branch Management Sheet
    await tester.tap(find.text('Şubeleri Yönet'));
    await tester.pumpAndSettle();

    // 5. Verify Sheet contents: Header, Faal badge, Bulk action toolbar
    expect(find.text('1 Şube Faal'), findsOneWidget);
    expect(find.text('Tüm Rafları Doldur'), findsWidgets);
    expect(find.text('Tümünü Durdur'), findsWidgets);
    expect(find.textContaining('+ Yeni Şube Aç'), findsWidgets);

    // 6. Tap "+ Yeni Şube Aç" inside the sheet to purchase branch #2
    await tester.tap(find.textContaining('+ Yeni Şube Aç').first);
    await tester.pumpAndSettle();

    // Verify branch #2 is created
    expect(controller.ownedStores.where((s) => s.blueprintId == 'kiosk_bread').length, 2);
    expect(find.text('2 Şube Faal'), findsOneWidget);
    expect(find.text('Şube #2'), findsOneWidget);

    // Close the sheet
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();

    // Verify Kasaba avenue now shows "2 Şube"
    expect(find.text('2 Şube'), findsOneWidget);

    // 7. Test switching to Mode 1 (Liste)
    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dükkanı Devret / Sat'), findsWidgets);

    // 8. Test switching to Mode 2 (Matris)
    await tester.tap(find.text('Matris'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Raf: '), findsWidgets);

    // 9. Switch back to Kasaba
    await tester.tap(find.text('Kasaba'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ticaret Bulvarı • 9 Parsel'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('Retail shelf management: allow removing any shelf, changing shelf product, duplicate product shelves, and UI sheet', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameController();
    controller.cash = 100000.0;
    final bp = RetailStore.getBlueprints().firstWhere((s) => s.id == 'kiosk_bread');
    controller.buyStore(bp);
    final store = controller.ownedStores.first;
    expect(store.productSlots.length, 1);
    expect(store.productSlots.first.itemId, 'bread');

    // 1. Upgrade store to level 2 so it has 2 slots
    controller.upgradeStore(store);
    expect(store.maxProductSlots, 2);

    // 2. Test duplicate product shelf allocation: user can put 'bread' on shelf #2 as well
    controller.warehouse['bread'] = 40;
    final addErr = controller.addProductSlotToStore(store, 'bread');
    expect(addErr, isNull);
    expect(store.productSlots.length, 2);
    expect(store.productSlots[0].itemId, 'bread');
    expect(store.productSlots[1].itemId, 'bread');

    // 3. Test dynamic product change: swap slot #2 from 'bread' to 'flour'
    controller.warehouse['flour'] = 25;
    final swapErr = controller.changeStoreProductSlot(store, store.productSlots[1], 'flour');
    expect(swapErr, isNull);
    expect(store.productSlots[1].itemId, 'flour');
    expect(store.productSlots[1].shelfStock, 25); // auto-pulled from warehouse

    // 4. Test removing slot #2 (stock returned to warehouse)
    final flourSlot = store.productSlots[1];
    controller.removeProductSlotFromStore(store, flourSlot);
    expect(store.productSlots.length, 1);
    expect(controller.warehouse['flour'], 25);

    // 5. Test removing the ONLY remaining slot (previously blocked by >= 1 check)
    final breadSlot = store.productSlots.first;
    breadSlot.shelfStock = 10;
    final initialBreadWh = controller.warehouse['bread'] ?? 0;
    final removeLastErr = controller.removeProductSlotFromStore(store, breadSlot);
    expect(removeLastErr, isNull);
    expect(store.productSlots.isEmpty, isTrue);
    expect(controller.warehouse['bread'], initialBreadWh + 10);

    // 6. Test UI rendering with empty slots
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RetailTab(controller: controller, initialViewMode: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify empty slot message is displayed
    expect(find.textContaining('Bu mağazada şu an hiçbir ürün rafı yok'), findsOneWidget);
    expect(find.textContaining('Yeni Ürün Rafı Ekle'), findsOneWidget);

    // Add a slot back via controller
    controller.addProductSlotToStore(store, 'croissant');
    await tester.pumpAndSettle();
    expect(find.text('Kruvasan'), findsOneWidget);

    // Verify swap and remove icon tooltips are rendered
    expect(find.byTooltip('Ürünü Değiştir'), findsWidgets);
    expect(find.byTooltip('Rafı Kaldır'), findsWidgets);

    controller.dispose();
  });

  testWidgets('3 Starter Career Paths: apply each path, verify assets, and test StarterCareerDialog UI selection', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameController();

    // 1. Path 1: 🌾 Tahıl & Fırıncılık
    controller.applyStarterCareerPath('grain_bakery');
    expect(controller.hasChosenStarterPath, isTrue);
    expect(controller.cash, 5000.0);
    expect(controller.ownedFacilities.length, 1);
    expect(controller.ownedFacilities.first.blueprintId, 'wheat_farm');
    expect(controller.ownedStores.length, 1);
    expect(controller.ownedStores.first.blueprintId, 'kiosk_bread');
    expect(controller.ownedStores.first.productSlots.first.itemId, 'bread');
    expect(controller.ownedStores.first.productSlots.first.shelfStock, 15);
    expect(controller.warehouse['wheat'], 50);
    expect(controller.warehouse['bread'], 20);

    // 2. Path 2: 🐄 Mandıra & Şarküteri
    controller.applyStarterCareerPath('dairy_cheese');
    expect(controller.hasChosenStarterPath, isTrue);
    expect(controller.cash, 5000.0);
    expect(controller.ownedFacilities.length, 1);
    expect(controller.ownedFacilities.first.blueprintId, 'dairy_farm');
    expect(controller.ownedStores.length, 1);
    expect(controller.ownedStores.first.blueprintId, 'delicatessen_shop');
    expect(controller.ownedStores.first.productSlots.first.itemId, 'cheese');
    expect(controller.ownedStores.first.productSlots.first.shelfStock, 15);
    expect(controller.warehouse['milk'], 40);
    expect(controller.warehouse['cheese'], 20);

    // 3. Path 3: ☕ Kahve & Kafe Kültürü
    controller.applyStarterCareerPath('coffee_barista');
    expect(controller.hasChosenStarterPath, isTrue);
    expect(controller.cash, 5000.0);
    expect(controller.ownedFacilities.length, 1);
    expect(controller.ownedFacilities.first.blueprintId, 'coffee_plantation');
    expect(controller.ownedStores.length, 1);
    expect(controller.ownedStores.first.blueprintId, 'coffee_house');
    expect(controller.ownedStores.first.productSlots.first.itemId, 'coffee_cup');
    expect(controller.ownedStores.first.productSlots.first.shelfStock, 15);
    expect(controller.warehouse['coffee_bean'], 35);
    expect(controller.warehouse['coffee_cup'], 20);

    // 4. Test UI modal: reset to new game and pump ProductionTab with StarterCareerDialog
    controller.resetToNewGame();
    expect(controller.shouldPromptStarterPathSelection, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionTab(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify empty state shows the career selection button
    final careerButton = find.text('🎯 Başlangıç Kariyerini Seç (3 Yol)');
    expect(careerButton, findsOneWidget);

    // Tap to open StarterCareerDialog sheet
    await tester.tap(careerButton);
    await tester.pumpAndSettle();

    // Verify all 3 careers and sandbox option are present
    expect(find.text('Tahıl & Fırıncılık Yolu'), findsOneWidget);
    expect(find.text('Mandıra & Şarküteri Yolu'), findsOneWidget);
    expect(find.text('Kahve & Kafe Kültürü Yolu'), findsOneWidget);
    expect(find.textContaining('10.000 ₺ Serbest Başlangıç'), findsOneWidget);

    // Tap to select Tahıl & Fırıncılık
    final selectButtons = find.text('Bu Kariyer ile Başla');
    expect(selectButtons, findsNWidgets(3));
    await tester.tap(selectButtons.first);
    await tester.pumpAndSettle();

    // Verify career path is applied
    expect(controller.hasChosenStarterPath, isTrue);
    expect(controller.ownedFacilities.first.blueprintId, 'wheat_farm');
    expect(controller.ownedStores.first.blueprintId, 'kiosk_bread');
    expect(controller.cash, closeTo(5000.0, 10.0));

    controller.dispose();
  });
}




