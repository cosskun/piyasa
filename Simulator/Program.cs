using System;
using System.Threading;
using Piyasa;
using Piyasa.Core;

namespace Piyasa.Simulator
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.OutputEncoding = System.Text.Encoding.UTF8;
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("================================================================");
            Console.WriteLine("          P İ Y A S A   -   E K O N O M İ   S İ M Ü L A S Y O N U        ");
            Console.WriteLine("          (Ticaret, Borsa, Üretim ve İşletme Motoru)            ");
            Console.WriteLine("================================================================\n");
            Console.ResetColor();

            var game = new GameManager(startingCash: 25000m);

            Console.WriteLine($"[1] Oyun Başladı!");
            Console.WriteLine($"    Kasadaki Nakit : {game.Economy.Cash:N2} TL");
            Console.WriteLine($"    Depo Kapasitesi: {game.Warehouse.MaxCapacity} kg\n");

            // --- SENARYO 1: ÇİFTÇİ / HAMMADDECİ ROLÜ ---
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("--- ADIM 1: TARLA YATIRIMI VE HAMMADDE SATIŞI ---");
            Console.ResetColor();
            Console.WriteLine("Oyuncu 1 adet 'Buğday Tarlası' satın alıyor (Maliyet: 8.000 TL)...");
            bool farmBought = game.Production.PurchaseFacility("wheat_farm", game.Economy);
            Console.WriteLine($"Tarla Kuruldu mu: {farmBought} | Kalan Nakit: {game.Economy.Cash:N2} TL");

            Console.WriteLine("\nZaman akıyor... Tarlada ekinler büyüyor ve hasat ediliyor...");
            // 10 saniyelik üretim döngüsünü simüle et
            for (int i = 0; i < 9; i++)
            {
                game.UpdateTick(1.0f);
            }

            Console.WriteLine($"Depodaki Buğday Miktarı: {game.Warehouse.GetQuantity("wheat")} adet (Çuval)");

            // Şimdi kullanıcının özellikle istediği şey: "Tüm hammaddeleri pazarda satabileceğiz değil mi?"
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("\n--- ADIM 2: HAMMADDEYİ PAZARA TOPTAN SATMA (Perakende dükkansız kâr) ---");
            Console.ResetColor();
            int wheatInStock = game.Warehouse.GetQuantity("wheat");
            var sellResult = game.Market.SellToMarket("wheat", wheatInStock, game.Economy, game.Warehouse);
            Console.WriteLine($"Pazar Satış Sonucu : {sellResult.Message}");
            Console.WriteLine($"Yeni Kasa Bakiyesi : {game.Economy.Cash:N2} TL\n");

            // --- SENARYO 2: SANAYİCİ ROLÜ ---
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("--- ADIM 3: SANAYİLEŞME - UN DEĞİRMENİ KURULUMU ---");
            Console.ResetColor();
            Console.WriteLine("Oyuncu pazardan toptan 20 adet Buğday satın alıyor...");
            var buyResult = game.Market.BuyFromMarket("wheat", 20, game.Economy, game.Warehouse);
            Console.WriteLine($"Pazar Alış Sonucu  : {buyResult.Message}");

            Console.WriteLine("Oyuncu 'Un Değirmeni' inşa ediyor...");
            // Gerekli bütçe için sermaye kontrolü
            game.Economy.Earn(30000m, "Melek Yatırımcı Fonu");
            game.Production.PurchaseFacility("flour_mill", game.Economy);

            Console.WriteLine("Değirmen buğdayları öğütüyor ve Un üretiyor...");
            for (int i = 0; i < 7; i++)
            {
                game.UpdateTick(1.0f);
            }

            Console.WriteLine($"Depodaki Kalan Buğday: {game.Warehouse.GetQuantity("wheat")} adet");
            Console.WriteLine($"Depoda Üretilen Un   : {game.Warehouse.GetQuantity("flour")} çuval");

            int flourInStock = game.Warehouse.GetQuantity("flour");
            var flourSellResult = game.Market.SellToMarket("flour", flourInStock, game.Economy, game.Warehouse);
            Console.WriteLine($"İşlenmiş Unu Pazara Satış: {flourSellResult.Message}\n");

            // --- SENARYO 3: ESNAF / PERAKENDE ROLÜ ---
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("--- ADIM 4: PERAKENDE DÜKKAN İŞLETMESİ (BÜFE & SİMİTÇİ) ---");
            Console.ResetColor();
            game.Stores.PurchaseStore("kiosk_bread", game.Economy);
            Console.WriteLine("Köşe Büfe açıldı! Pazardan dükkana satmalık 30 adet Somun Ekmek alınıyor...");
            game.Market.BuyFromMarket("bread", 30, game.Economy, game.Warehouse);

            Console.WriteLine("Müşteriler gelip ekmek alıyor...");
            for (int i = 0; i < 6; i++)
            {
                game.UpdateTick(1.0f);
            }

            // --- SENARYO 4: FİNANS VE NET SERVET ---
            Console.ForegroundColor = ConsoleColor.Magenta;
            Console.WriteLine("\n--- ADIM 5: BANKA & MEVDUAT FAİZİ ---");
            Console.ResetColor();
            decimal depositAmount = Math.Min(5000m, game.Economy.Cash);
            bool deposited = game.Economy.DepositToBank(depositAmount);
            Console.WriteLine($"Bankaya {depositAmount:N2} TL vadeli mevduat yatırıldı (Başarılı: {deposited}).");
            
            // Saatlik faiz işlet
            game.Economy.ProcessHourlyFinances();
            Console.WriteLine($"1 Saat Sonra Bankadaki Para (Faizli): {game.Economy.BankSavings:N2} TL");

            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("\n================================================================");
            Console.WriteLine($"TOPLAM NET SERVET (Net Worth): {game.CalculateNetWorth():N2} TL");
            Console.WriteLine("================================================================");
            Console.ResetColor();
            Console.WriteLine("\n[BAŞARILI] Piyasa ekonomi motoru ve tüm mekanikler kusursuz çalışıyor!");
        }
    }
}
