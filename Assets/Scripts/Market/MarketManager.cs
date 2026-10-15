using System;
using System.Collections.Generic;
using Piyasa.Core;

namespace Piyasa.Market
{
    public class MarketTransactionResult
    {
        public bool Success { get; set; }
        public string Message { get; set; }
        public decimal TotalAmount { get; set; }
        public int Quantity { get; set; }
    }

    [Serializable]
    public class MarketManager
    {
        public Dictionary<string, MarketItem> MarketItems { get; private set; }
        private readonly Random _random = new Random();

        public event Action OnMarketUpdated;
        public event Action<string, MarketTransactionResult> OnTransactionCompleted;

        public MarketManager()
        {
            MarketItems = new Dictionary<string, MarketItem>();
            InitializeMarket();
        }

        private void InitializeMarket()
        {
            foreach (var item in ItemRegistry.GetAll())
            {
                MarketItems[item.Id] = new MarketItem(item.Id, item.BasePrice);
            }
        }

        public MarketItem GetMarketItem(string itemId)
        {
            return MarketItems.TryGetValue(itemId, out var mItem) ? mItem : null;
        }

        /// <summary>
        /// Oyuncu pazardan toptan mal satın alır (Fabrikasına hammadde veya dükkanına satmalık ürün çeker).
        /// </summary>
        public MarketTransactionResult BuyFromMarket(string itemId, int quantity, EconomyManager economy, Inventory inventory)
        {
            var result = new MarketTransactionResult();

            if (quantity <= 0)
            {
                result.Success = false;
                result.Message = "Geçersiz adet miktarı.";
                return result;
            }

            var marketItem = GetMarketItem(itemId);
            var itemData = ItemRegistry.Get(itemId);

            if (marketItem == null || itemData == null)
            {
                result.Success = false;
                result.Message = "Ürün pazarda bulunamadı.";
                return result;
            }

            if (marketItem.MarketSupply < quantity)
            {
                result.Success = false;
                result.Message = $"Pazarda yeterli stok yok! Mevcut: {marketItem.MarketSupply} adet.";
                return result;
            }

            decimal unitPrice = marketItem.GetWholesaleBuyPrice();
            decimal totalCost = unitPrice * quantity;

            if (!economy.CanAfford(totalCost))
            {
                result.Success = false;
                result.Message = $"Yetersiz nakit! Gereken: {totalCost:N2} TL, Kasa: {economy.Cash:N2} TL.";
                return result;
            }

            if (!inventory.CanAdd(itemId, quantity))
            {
                result.Success = false;
                result.Message = "Deponuzda bu miktarda mal için yeterli yer yok!";
                return result;
            }

            // İşlemi gerçekleştir
            economy.Spend(totalCost, $"Pazardan {quantity} adet {itemData.Name} alımı");
            inventory.AddItem(itemId, quantity);
            marketItem.MarketSupply -= quantity;

            // Talep oluştuğu için fiyat hafif yukarı yönlü baskı görür
            marketItem.UpdatePrice(0.015f, _random);

            result.Success = true;
            result.Message = $"{quantity} adet {itemData.Name} toplam {totalCost:N2} TL tutarla depoya alındı.";
            result.TotalAmount = totalCost;
            result.Quantity = quantity;

            OnTransactionCompleted?.Invoke(itemId, result);
            OnMarketUpdated?.Invoke();
            return result;
        }

        /// <summary>
        /// Oyuncu tarlasından/fabrikasından çıkan malı pazara toptan satar (Sıcak paraya çevirir).
        /// </summary>
        public MarketTransactionResult SellToMarket(string itemId, int quantity, EconomyManager economy, Inventory inventory)
        {
            var result = new MarketTransactionResult();

            if (quantity <= 0)
            {
                result.Success = false;
                result.Message = "Geçersiz adet miktarı.";
                return result;
            }

            var marketItem = GetMarketItem(itemId);
            var itemData = ItemRegistry.Get(itemId);

            if (marketItem == null || itemData == null)
            {
                result.Success = false;
                result.Message = "Ürün pazarda tanınmıyor.";
                return result;
            }

            if (!inventory.HasItem(itemId, quantity))
            {
                result.Success = false;
                result.Message = $"Deponuzda yeterli {itemData.Name} yok! Mevcut: {inventory.GetQuantity(itemId)} adet.";
                return result;
            }

            decimal unitPrice = marketItem.GetWholesaleSellPrice();
            decimal totalEarnings = unitPrice * quantity;

            // İşlemi gerçekleştir
            inventory.RemoveItem(itemId, quantity);
            economy.Earn(totalEarnings, $"Pazara {quantity} adet {itemData.Name} satışı");
            marketItem.MarketSupply += quantity;

            // Piyasaya mal pompalandığı için fiyat hafif gevşer
            marketItem.UpdatePrice(-0.015f, _random);

            result.Success = true;
            result.Message = $"{quantity} adet {itemData.Name} pazara satıldı! Kasaya {totalEarnings:N2} TL girdi.";
            result.TotalAmount = totalEarnings;
            result.Quantity = quantity;

            OnTransactionCompleted?.Invoke(itemId, result);
            OnMarketUpdated?.Invoke();
            return result;
        }

        /// <summary>
        /// Belirli periyotlarda (örneğin 1 dakikada bir) piyasa fiyatlarının ve stoklarının dalgalanması
        /// </summary>
        public void TickMarket()
        {
            foreach (var kvp in MarketItems)
            {
                // Doğal piyasa arz-talep salınımı
                kvp.Value.UpdatePrice(0f, _random);

                // Düşük stoklu ürünleri toparla
                if (kvp.Value.MarketSupply < 1000)
                {
                    kvp.Value.MarketSupply += _random.Next(100, 300);
                }
            }

            OnMarketUpdated?.Invoke();
        }
    }
}
