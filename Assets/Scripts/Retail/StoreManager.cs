using System;
using System.Collections.Generic;
using Piyasa.Core;

namespace Piyasa.Retail
{
    [Serializable]
    public class StoreManager
    {
        public List<RetailStore> StoreBlueprints { get; private set; }
        public List<RetailStore> OwnedStores { get; private set; }

        public event Action OnStoresUpdated;

        public StoreManager()
        {
            StoreBlueprints = new List<RetailStore>();
            OwnedStores = new List<RetailStore>();
            InitializeBlueprints();
        }

        private void InitializeBlueprints()
        {
            StoreBlueprints.Add(new RetailStore(
                id: "kiosk_bread",
                name: "Köşe Büfe & Simitçi",
                description: "Hızlı ayaküstü atıştırmalık ve ekmek satışı. Başlangıç için en ideal nakit kapısı.",
                productItemId: "bread",
                purchaseCost: 5000m,
                baseUpgradeCost: 2500m,
                shelfCapacity: 60,
                retailPrice: 15.00m,
                saleIntervalSeconds: 2.5f
            ));

            StoreBlueprints.Add(new RetailStore(
                id: "juice_bar",
                name: "Vitamin Meyve Barı",
                description: "Taze sıkılmış meyve suyu satışı. Sağlıklı yaşam tutkunlarının uğrak noktası.",
                productItemId: "bottled_juice",
                purchaseCost: 15000m,
                baseUpgradeCost: 7500m,
                shelfCapacity: 50,
                retailPrice: 45.00m,
                saleIntervalSeconds: 3.5f
            ));

            StoreBlueprints.Add(new RetailStore(
                id: "coffee_house",
                name: "3. Nesil Kahveci",
                description: "Aromatik taze kahve servisi. Gençlerin ve çalışanların favori mekanı.",
                productItemId: "coffee_cup",
                purchaseCost: 28000m,
                baseUpgradeCost: 14000m,
                shelfCapacity: 40,
                retailPrice: 60.00m,
                saleIntervalSeconds: 4.0f
            ));

            StoreBlueprints.Add(new RetailStore(
                id: "clothing_boutique",
                name: "Moda & Giyim Butiği",
                description: "Kaliteli tekstil ve hazır giyim ürünleri. Yüksek kâr marjlı perakende mağazası.",
                productItemId: "clothes",
                purchaseCost: 50000m,
                baseUpgradeCost: 25000m,
                shelfCapacity: 30,
                retailPrice: 250.00m,
                saleIntervalSeconds: 6.0f
            ));
        }

        public bool PurchaseStore(string blueprintId, EconomyManager economy)
        {
            var bp = StoreBlueprints.Find(s => s.Id == blueprintId);
            if (bp == null) return false;

            if (!economy.CanAfford(bp.PurchaseCost)) return false;

            economy.Spend(bp.PurchaseCost, $"{bp.Name} dükkanı açılışı");

            var newStore = new RetailStore(
                $"{bp.Id}_{Guid.NewGuid().ToString().Substring(0, 5)}",
                bp.Name,
                bp.Description,
                bp.ProductItemId,
                bp.PurchaseCost,
                bp.BaseUpgradeCost,
                bp.ShelfCapacity,
                bp.RetailPrice,
                bp.SaleIntervalSeconds
            );

            OwnedStores.Add(newStore);
            OnStoresUpdated?.Invoke();
            return true;
        }

        public void TickAll(float deltaSeconds, EconomyManager economy, Inventory warehouse)
        {
            foreach (var store in OwnedStores)
            {
                store.Tick(deltaSeconds, economy, warehouse);
            }
        }
    }
}
