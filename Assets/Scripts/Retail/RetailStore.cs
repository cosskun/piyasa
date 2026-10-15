using System;
using Piyasa.Core;

namespace Piyasa.Retail
{
    [Serializable]
    public class RetailStore
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public string Description { get; set; }
        public string ProductItemId { get; set; } // Bu dükkanda satılan ürün (Örn: "bread", "clothes")
        
        public int Level { get; set; } = 1;
        public decimal PurchaseCost { get; set; }
        public decimal BaseUpgradeCost { get; set; }
        
        public int ShelfCapacity { get; set; } = 50;  // Rafta durabilecek maksimum ürün adedi
        public int ShelfStock { get; set; } = 0;      // Raftaki güncel ürün
        public decimal RetailPrice { get; set; }      // Müşteriye satış fiyatı
        
        public float SaleIntervalSeconds { get; set; } = 3.0f; // Müşteri gelme ve satış sıklığı
        public float TimerProgress { get; set; } = 0f;
        public bool AutoRestockFromWarehouse { get; set; } = true; // Depodan rafa otomatik doldurma

        public decimal TotalRevenueGenerated { get; set; } = 0m;
        public string StatusMessage { get; set; } = "Müşteri Bekleniyor";

        public RetailStore() { }

        public RetailStore(string id, string name, string description, string productItemId, 
                           decimal purchaseCost, decimal baseUpgradeCost, int shelfCapacity, 
                           decimal retailPrice, float saleIntervalSeconds)
        {
            Id = id;
            Name = name;
            Description = description;
            ProductItemId = productItemId;
            PurchaseCost = purchaseCost;
            BaseUpgradeCost = baseUpgradeCost;
            ShelfCapacity = shelfCapacity;
            RetailPrice = retailPrice;
            SaleIntervalSeconds = saleIntervalSeconds;
            ShelfStock = 0;
            Level = 1;
        }

        public decimal GetUpgradeCost()
        {
            return BaseUpgradeCost * (decimal)Math.Pow(1.5, Level - 1);
        }

        public void RestockFromWarehouse(Inventory warehouse, int amount)
        {
            int spaceLeft = ShelfCapacity - ShelfStock;
            int toTake = Math.Min(spaceLeft, amount);

            if (toTake > 0 && warehouse.HasItem(ProductItemId, toTake))
            {
                warehouse.RemoveItem(ProductItemId, toTake);
                ShelfStock += toTake;
                StatusMessage = $"Rafa {toTake} adet ürün dizildi.";
            }
        }

        public void Tick(float deltaSeconds, EconomyManager economy, Inventory warehouse)
        {
            // 1. Raf boşsa depodan otomatik çekmeyi dene
            if (AutoRestockFromWarehouse && ShelfStock < ShelfCapacity * 0.3f)
            {
                int need = ShelfCapacity - ShelfStock;
                int available = warehouse.GetQuantity(ProductItemId);
                if (available > 0)
                {
                    int take = Math.Min(need, available);
                    warehouse.RemoveItem(ProductItemId, take);
                    ShelfStock += take;
                }
            }

            // 2. Satış yapacak mal var mı?
            if (ShelfStock <= 0)
            {
                var prod = ItemRegistry.Get(ProductItemId);
                StatusMessage = $"Raf Boş! Satılacak {prod?.Name ?? ProductItemId} bekleniyor.";
                TimerProgress = 0f;
                return;
            }

            // 3. Müşteri akışı
            float effectiveInterval = Math.Max(0.5f, SaleIntervalSeconds - ((Level - 1) * 0.2f));
            TimerProgress += deltaSeconds / effectiveInterval;

            if (TimerProgress >= 1.0f)
            {
                TimerProgress = 0f;
                // Satış gerçekleşti
                ShelfStock--;
                economy.Earn(RetailPrice, $"{Name} perakende satışı");
                TotalRevenueGenerated += RetailPrice;

                var prod = ItemRegistry.Get(ProductItemId);
                StatusMessage = $"Müşteriye 1 adet {prod?.Name} satıldı! (+{RetailPrice:N2} TL)";
            }
            else
            {
                StatusMessage = $"Müşteri dükkanda (Raf: {ShelfStock}/{ShelfCapacity})";
            }
        }

        public bool Upgrade(EconomyManager economy)
        {
            decimal cost = GetUpgradeCost();
            if (!economy.CanAfford(cost)) return false;

            economy.Spend(cost, $"{Name} Seviye {Level + 1} geliştirmesi");
            Level++;
            ShelfCapacity += 25; // Her seviye raf kapasitesini artırır
            return true;
        }
    }
}
