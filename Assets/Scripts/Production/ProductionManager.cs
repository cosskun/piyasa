using System;
using System.Collections.Generic;
using Piyasa.Core;

namespace Piyasa.Production
{
    [Serializable]
    public class ProductionManager
    {
        public List<ProductionFacility> AvailableBlueprints { get; private set; }
        public List<ProductionFacility> OwnedFacilities { get; private set; }

        public event Action OnFacilitiesUpdated;

        public ProductionManager()
        {
            AvailableBlueprints = new List<ProductionFacility>();
            OwnedFacilities = new List<ProductionFacility>();
            InitializeBlueprints();
        }

        private void InitializeBlueprints()
        {
            // === 1. TARIM VE HAMMADDE TESİSLERİ (Girdi gerektirmez) ===
            AvailableBlueprints.Add(new ProductionFacility(
                id: "wheat_farm",
                name: "Buğday Tarlası",
                description: "Verimli Anadolu toprağında buğday yetiştirir. Ekmek ve un zincirinin ilk adımı.",
                type: FacilityType.Agriculture,
                recipe: new ProductionRecipe("rec_wheat", "Buğday Hasadı", null, "wheat", 10, 8.0f),
                purchaseCost: 8000m,
                baseUpgradeCost: 4000m
            ));

            AvailableBlueprints.Add(new ProductionFacility(
                id: "cotton_field",
                name: "Pamuk Arazisi",
                description: "Güneydoğu ovalarında pamuk hasadı. Tekstil zincirinin ana hammaddesidir.",
                type: FacilityType.Agriculture,
                recipe: new ProductionRecipe("rec_cotton", "Pamuk Toplama", null, "cotton", 6, 12.0f),
                purchaseCost: 18000m,
                baseUpgradeCost: 9000m
            ));

            AvailableBlueprints.Add(new ProductionFacility(
                id: "fruit_orchard",
                name: "Meyve Bahçesi",
                description: "Taze narenciye ve elma bahçesi. Meyve suyu sanayisi ve pazara doğrudan satış için idealdir.",
                type: FacilityType.Agriculture,
                recipe: new ProductionRecipe("rec_fruit", "Meyve Hasadı", null, "fruit", 8, 10.0f),
                purchaseCost: 15000m,
                baseUpgradeCost: 7500m
            ));

            AvailableBlueprints.Add(new ProductionFacility(
                id: "dairy_farm",
                name: "Mandıra Çiftliği",
                description: "Sağmal inek çiftliği. Çiğ süt üretir, peynir ve şarküteri üreticilerine satılır.",
                type: FacilityType.Agriculture,
                recipe: new ProductionRecipe("rec_milk", "Süt Sağımı", null, "milk", 6, 9.0f),
                purchaseCost: 24000m,
                baseUpgradeCost: 12000m
            ));

            // === 2. SANAYİ VE İŞLEME FABRİKALARI (Hammaddeyi işler) ===
            AvailableBlueprints.Add(new ProductionFacility(
                id: "flour_mill",
                name: "Un Değirmeni",
                description: "2 çuval Buğdayı işleyip 1 çuval kaliteli Un üretir.",
                type: FacilityType.Factory,
                recipe: new ProductionRecipe("rec_flour", "Un Öğütme", 
                    new List<RecipeIngredient> { new RecipeIngredient("wheat", 2) }, 
                    "flour", 1, 6.0f),
                purchaseCost: 35000m,
                baseUpgradeCost: 18000m
            ));

            AvailableBlueprints.Add(new ProductionFacility(
                id: "weaving_factory",
                name: "Dokuma & İplik Fabrikası",
                description: "2 kilo Ham Pamuğu işleyip 1 metre kaliteli Kumaş üretir.",
                type: FacilityType.Factory,
                recipe: new ProductionRecipe("rec_fabric", "Kumaş Dokuma", 
                    new List<RecipeIngredient> { new RecipeIngredient("cotton", 2) }, 
                    "fabric", 1, 8.0f),
                purchaseCost: 55000m,
                baseUpgradeCost: 28000m
            ));

            AvailableBlueprints.Add(new ProductionFacility(
                id: "cheese_plant",
                name: "Peynir İmalathanesi",
                description: "3 litre Çiğ Sütü mayalayıp 1 kalıp sofralık Peynir üretir.",
                type: FacilityType.Factory,
                recipe: new ProductionRecipe("rec_cheese", "Peynir Mayalama", 
                    new List<RecipeIngredient> { new RecipeIngredient("milk", 3) }, 
                    "cheese", 1, 9.0f),
                purchaseCost: 65000m,
                baseUpgradeCost: 32000m
            ));
        }

        public bool PurchaseFacility(string blueprintId, EconomyManager economy)
        {
            var bp = AvailableBlueprints.Find(b => b.Id == blueprintId);
            if (bp == null) return false;

            if (!economy.CanAfford(bp.PurchaseCost)) return false;

            economy.Spend(bp.PurchaseCost, $"{bp.Name} yatırımı ve inşası");

            // Yeni kopyasını mülklerimize ekle
            var newFacility = new ProductionFacility(
                $"{bp.Id}_{Guid.NewGuid().ToString().Substring(0, 5)}",
                bp.Name,
                bp.Description,
                bp.Type,
                bp.Recipe,
                bp.PurchaseCost,
                bp.BaseUpgradeCost
            );

            OwnedFacilities.Add(newFacility);
            OnFacilitiesUpdated?.Invoke();
            return true;
        }

        public void TickAll(float deltaSeconds, Inventory inventory)
        {
            foreach (var facility in OwnedFacilities)
            {
                facility.Tick(deltaSeconds, inventory);
            }
        }
    }
}
