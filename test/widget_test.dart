import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piyasa/main.dart';
import 'package:piyasa/controllers/game_controller.dart';
import 'package:piyasa/views/market_tab.dart';
import 'package:piyasa/views/production_tab.dart';
import 'package:piyasa/views/retail_tab.dart';
import 'package:piyasa/models/market_offer.dart';
import 'package:piyasa/models/store.dart';
import 'package:piyasa/models/facility.dart';

void main() {
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

  testWidgets('ProductionTab shows starter packages, production rates per minute, and multiple purchasing', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameController();
    expect(controller.cash, 30000.0);
    expect(controller.ownedFacilities.isEmpty, true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionTab(controller: controller),
        ),
      ),
    );

    // Verify Welcome and 30,000 TL starting capital are shown
    expect(find.text('Girişimcilik Dünyasına Hoş Geldin!'), findsOneWidget);
    expect(find.textContaining('30.000 ₺'), findsWidgets);

    // Verify the starter packages with 3 facilities are visible
    expect(find.textContaining('Entegre Un & Fırın Sanayisi'), findsOneWidget);
    expect(find.textContaining('Çeşitli Tarım & Bahçe İmparatorluğu'), findsOneWidget);

    // Verify minute production rate information is present
    expect(find.textContaining('Dakikada:'), findsWidgets);

    // Tap on "Bu Paketi Kur 🚀" for Entegre Un & Fırın Sanayisi
    final packageButton = find.widgetWithText(ElevatedButton, 'Bu Paketi Kur 🚀').first;
    await tester.tap(packageButton);
    await tester.pumpAndSettle();

    // Verify confirmation dialog opens with 3 facilities breakdown and speeds
    expect(find.textContaining('Entegre Un & Fırın Sanayisi Kurulumu'), findsOneWidget);
    expect(find.textContaining('2 adet Buğday Tarlası'), findsOneWidget);
    expect(find.textContaining('1 adet Un Değirmeni'), findsOneWidget);

    // Confirm the package
    await tester.tap(find.text('Evet, Paketi Kur 🚀'));
    await tester.pumpAndSettle();

    // Verify ownedFacilities now has 3 facilities
    expect(controller.ownedFacilities.length, 3);
    expect(controller.cash, 8000.0); // 30000 - 22000

    // Verify the list shows Tesislerim (3) and total capacity
    expect(find.text('Tesislerim (3)'), findsOneWidget);
    expect(find.textContaining('Toplam Üretim Kapasitesi:'), findsOneWidget);
    expect(find.textContaining('⚡ Üretim Gücü:'), findsWidgets);

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
    
    // Starting cash: 30000. Buy wheat farm (cost: 5000)
    controller.buyFacility(wheatFarmBp);
    expect(controller.ownedFacilities.length, 1);
    expect(controller.cash, 25000.0);

    final fac = controller.ownedFacilities.first;
    expect(fac.level, 1);
    expect(fac.totalInvestedValue, 5000.0);
    expect(fac.resaleValue, 3500.0); // 70% of 5000

    // Upgrade facility to level 2 (cost: 2500)
    controller.upgradeFacility(fac);
    expect(fac.level, 2);
    expect(controller.cash, 22500.0);
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

    // Verify facility removed and cash updated (22500 + 5250 = 27750)
    expect(controller.ownedFacilities.isEmpty, true);
    expect(controller.cash, 27750.0);

    controller.dispose();
  });

  testWidgets('Store resale calculates 70% refund, returns shelf stock to warehouse and removes store', (tester) async {
    final controller = GameController();
    final kioskBp = RetailStore.getBlueprints().firstWhere((b) => b.id == 'kiosk_bread');
    
    // Buy bread kiosk (cost: 4500)
    controller.buyStore(kioskBp);
    expect(controller.ownedStores.length, 1);
    expect(controller.cash, 25500.0);

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

    // Verify store removed, cash refunded (25500 + 3150 = 28650), and 15 breads in warehouse
    expect(controller.ownedStores.isEmpty, true);
    expect(controller.cash, 28650.0);
    expect(controller.warehouse['bread'], 15);

    controller.dispose();
  });
}


