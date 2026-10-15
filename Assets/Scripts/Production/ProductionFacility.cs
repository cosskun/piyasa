using System;
using Piyasa.Core;

namespace Piyasa.Production
{
    public enum FacilityType
    {
        Agriculture, // Tarla, Bahçe, Çiftlik (Girdi gerektirmez veya sadece tohum ister)
        Factory      // Değirmen, Dokuma, İmalathane (Hammaddeyi işleyip mamule çevirir)
    }

    [Serializable]
    public class ProductionFacility
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public string Description { get; set; }
        public FacilityType Type { get; set; }
        public ProductionRecipe Recipe { get; set; }
        
        public int Level { get; set; } = 1;
        public decimal PurchaseCost { get; set; }
        public decimal BaseUpgradeCost { get; set; }
        
        public float CurrentCycleProgress { get; set; } = 0f; // 0.0 - 1.0
        public bool IsProducing { get; set; } = true;
        public string LastStatusMessage { get; set; } = "Hazır";

        public ProductionFacility() { }

        public ProductionFacility(string id, string name, string description, FacilityType type, 
                                  ProductionRecipe recipe, decimal purchaseCost, decimal baseUpgradeCost)
        {
            Id = id;
            Name = name;
            Description = description;
            Type = type;
            Recipe = recipe;
            PurchaseCost = purchaseCost;
            BaseUpgradeCost = baseUpgradeCost;
            Level = 1;
            CurrentCycleProgress = 0f;
            IsProducing = true;
        }

        public decimal GetUpgradeCost()
        {
            return BaseUpgradeCost * (decimal)Math.Pow(1.6, Level - 1);
        }

        public float GetAdjustedProductionTime()
        {
            // Her seviye üretim süresini %10 kısaltır (Minimum taban %30'a kadar)
            float reductionFactor = (float)Math.Max(0.3, 1.0 - ((Level - 1) * 0.10));
            return Recipe.ProductionTimeSeconds * reductionFactor;
        }

        public int GetAdjustedOutputAmount()
        {
            // Seviye 3'ten sonra her seviye ekstra %20 verim bonusu
            if (Level <= 2) return Recipe.OutputAmount;
            return (int)Math.Round(Recipe.OutputAmount * (1.0 + (Level - 2) * 0.20));
        }

        /// <summary>
        /// Üretim tesisinin zaman adımı
        /// </summary>
        public void Tick(float deltaSeconds, Inventory inventory)
        {
            if (!IsProducing) return;

            // 1. Girdi kontrolü (Fabrika ise ve döngü yeni başlıyorsa)
            if (CurrentCycleProgress == 0f && Recipe.Inputs.Count > 0)
            {
                foreach (var input in Recipe.Inputs)
                {
                    if (!inventory.HasItem(input.ItemId, input.Amount))
                    {
                        var missingItem = ItemRegistry.Get(input.ItemId);
                        LastStatusMessage = $"Hammadde Eksik: {missingItem?.Name ?? input.ItemId} gerekiyor!";
                        return; // Hammadde yoksa bekle
                    }
                }
            }

            // 2. Çıktı için depoda yer var mı kontrolü
            int outputAmount = GetAdjustedOutputAmount();
            if (!inventory.CanAdd(Recipe.OutputItemId, outputAmount))
            {
                LastStatusMessage = "Depoda Yer Yok! Üretim durdu.";
                return;
            }

            // 3. İlerleme
            float cycleDuration = GetAdjustedProductionTime();
            CurrentCycleProgress += deltaSeconds / cycleDuration;
            LastStatusMessage = $"Üretim devam ediyor (%{(int)(CurrentCycleProgress * 100)})";

            // 4. Döngü tamamlandı mı?
            if (CurrentCycleProgress >= 1.0f)
            {
                CompleteCycle(inventory, outputAmount);
            }
        }

        private void CompleteCycle(Inventory inventory, int outputAmount)
        {
            // Girdileri depodan tüket
            if (Recipe.Inputs.Count > 0)
            {
                foreach (var input in Recipe.Inputs)
                {
                    inventory.RemoveItem(input.ItemId, input.Amount);
                }
            }

            // Çıktıyı depoya ekle
            inventory.AddItem(Recipe.OutputItemId, outputAmount);
            CurrentCycleProgress = 0f;

            var outItem = ItemRegistry.Get(Recipe.OutputItemId);
            LastStatusMessage = $"{outputAmount} adet {outItem?.Name ?? Recipe.OutputItemId} başarıyla üretildi!";
        }

        public bool Upgrade(EconomyManager economy)
        {
            decimal cost = GetUpgradeCost();
            if (!economy.CanAfford(cost)) return false;

            economy.Spend(cost, $"{Name} Seviye {Level + 1} geliştirmesi");
            Level++;
            return true;
        }
    }
}
