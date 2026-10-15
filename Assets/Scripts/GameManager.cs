using System;
using System.IO;
using Piyasa.Core;
using Piyasa.Market;
using Piyasa.Production;
using Piyasa.Retail;

namespace Piyasa
{
    [Serializable]
    public class GameManager
    {
        public static GameManager Instance { get; private set; }

        public EconomyManager Economy { get; private set; }
        public Inventory Warehouse { get; private set; }
        public MarketManager Market { get; private set; }
        public ProductionManager Production { get; private set; }
        public StoreManager Stores { get; private set; }

        public float TotalPlayTimeSeconds { get; set; } = 0f;
        private float _marketTickTimer = 0f;
        private float _hourlyFinanceTimer = 0f;

        public event Action OnStateUpdated;

        public GameManager(decimal startingCash = 25000m)
        {
            Instance = this;
            Economy = new EconomyManager(startingCash);
            Warehouse = new Inventory(maxCapacity: 1500f); // 1.5 ton başlangıç depo kapasitesi
            Market = new MarketManager();
            Production = new ProductionManager();
            Stores = new StoreManager();
        }

        public decimal CalculateNetWorth()
        {
            decimal net = Economy.Cash + Economy.BankSavings - Economy.ActiveLoan;

            // Depodaki malların güncel piyasa değeri
            foreach (var kvp in Warehouse.Items)
            {
                var marketItem = Market.GetMarketItem(kvp.Key);
                if (marketItem != null)
                {
                    net += marketItem.GetWholesaleSellPrice() * kvp.Value;
                }
            }

            // Sahip olunan üretim tesislerinin değeri
            foreach (var fac in Production.OwnedFacilities)
            {
                net += fac.PurchaseCost + (fac.GetUpgradeCost() * 0.5m);
            }

            // Sahip olunan dükkanların değeri
            foreach (var store in Stores.OwnedStores)
            {
                net += store.PurchaseCost;
            }

            return Math.Round(net, 2);
        }

        public void UpdateTick(float deltaSeconds)
        {
            TotalPlayTimeSeconds += deltaSeconds;

            // 1. Tarlaları ve Fabrikaları işlet
            Production.TickAll(deltaSeconds, Warehouse);

            // 2. Perakende dükkanları işlet
            Stores.TickAll(deltaSeconds, Economy, Warehouse);

            // 3. Pazar dalgalanması (her 15 saniyede bir fiyatlar nefes alsın)
            _marketTickTimer += deltaSeconds;
            if (_marketTickTimer >= 15.0f)
            {
                _marketTickTimer = 0f;
                Market.TickMarket();
            }

            // 4. Saatlik banka faizleri ve finans döngüsü (Oyun içi hızlı simülasyon: her 60 saniyede bir saatlik finans)
            _hourlyFinanceTimer += deltaSeconds;
            if (_hourlyFinanceTimer >= 60.0f)
            {
                _hourlyFinanceTimer = 0f;
                Economy.ProcessHourlyFinances();
            }

            OnStateUpdated?.Invoke();
        }
    }
}
