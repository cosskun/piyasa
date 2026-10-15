using System;
using System.Collections.Generic;
using Piyasa.Core;

namespace Piyasa.Market
{
    [Serializable]
    public class MarketItem
    {
        public string ItemId { get; set; }
        public decimal CurrentPrice { get; set; }
        public int MarketSupply { get; set; } // Pazardaki toplam havuz/stok
        public List<decimal> PriceHistory { get; set; }

        public MarketItem()
        {
            PriceHistory = new List<decimal>();
        }

        public MarketItem(string itemId, decimal initialPrice, int initialSupply = 5000)
        {
            ItemId = itemId;
            CurrentPrice = initialPrice;
            MarketSupply = initialSupply;
            PriceHistory = new List<decimal> { initialPrice };
        }

        // Oyuncunun pazardan toptan mal ALIRKEN ödediği fiyat (Küçük bir komisyon/makas payı ile)
        public decimal GetWholesaleBuyPrice()
        {
            return Math.Round(CurrentPrice * 1.03m, 2); // %3 borsa işlem masrafı
        }

        // Oyuncunun pazara toptan mal SATARKEN kazandığı fiyat
        public decimal GetWholesaleSellPrice()
        {
            return Math.Round(CurrentPrice * 0.97m, 2); // %3 borsa komisyon kesintisi
        }

        // Fiyatı arz-talep ve rastgele piyasa hareketlerine göre güncelle
        public void UpdatePrice(float supplyDemandFactor, Random rnd)
        {
            var itemData = ItemRegistry.Get(ItemId);
            if (itemData == null) return;

            // -%5 ile +%5 arasında doğal piyasa dalgalanması
            double randomFluctuation = (rnd.NextDouble() * 0.10) - 0.05;
            
            // Arz faktörü: Çok arz varsa fiyat düşer, talep çoksa fiyat artar
            decimal newPrice = CurrentPrice * (decimal)(1.0 + randomFluctuation + supplyDemandFactor);

            // Taban ve tavan sınırları koru
            if (newPrice < itemData.MinPrice) newPrice = itemData.MinPrice;
            if (newPrice > itemData.MaxPrice) newPrice = itemData.MaxPrice;

            CurrentPrice = Math.Round(newPrice, 2);

            PriceHistory.Add(CurrentPrice);
            if (PriceHistory.Count > 30) // Son 30 fiyat hareketini sakla
            {
                PriceHistory.RemoveAt(0);
            }
        }
    }
}
