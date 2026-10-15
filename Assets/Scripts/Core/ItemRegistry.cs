using System.Collections.Generic;

namespace Piyasa.Core
{
    public static class ItemRegistry
    {
        private static readonly Dictionary<string, ItemData> _items = new Dictionary<string, ItemData>();

        static ItemRegistry()
        {
            InitializeDefaultItems();
        }

        private static void InitializeDefaultItems()
        {
            // === 1. TARIMSAL HAM MADDELER (Tarlalar / Bahçeler / Çiftlikler) ===
            Register(new ItemData(
                id: "wheat",
                name: "Buğday",
                description: "Tarlalardan hasat edilen temel tahıl. Değirmende una dönüştürülür.",
                category: ItemCategory.RawMaterial,
                basePrice: 8.00m,
                minPrice: 5.00m,
                maxPrice: 14.00m,
                retailSuggestedPrice: 10.00m,
                weight: 1.0f
            ));

            Register(new ItemData(
                id: "cotton",
                name: "Ham Pamuk",
                description: "Tekstil sanayisinin can damarı. Dokuma fabrikasında kumaşa dönüştürülür.",
                category: ItemCategory.RawMaterial,
                basePrice: 18.00m,
                minPrice: 12.00m,
                maxPrice: 28.00m,
                retailSuggestedPrice: 22.00m,
                weight: 0.8f
            ));

            Register(new ItemData(
                id: "fruit",
                name: "Taze Meyve (Portakal/Elma)",
                description: "Meyve bahçelerinden toplanan sulu taze meyveler.",
                category: ItemCategory.RawMaterial,
                basePrice: 12.00m,
                minPrice: 7.00m,
                maxPrice: 20.00m,
                retailSuggestedPrice: 16.00m,
                weight: 1.0f
            ));

            Register(new ItemData(
                id: "milk",
                name: "Çiğ Süt",
                description: "Mandıra çiftliklerinden sağılan taze süt.",
                category: ItemCategory.RawMaterial,
                basePrice: 15.00m,
                minPrice: 10.00m,
                maxPrice: 24.00m,
                retailSuggestedPrice: 19.00m,
                weight: 1.0f
            ));

            Register(new ItemData(
                id: "coffee_bean",
                name: "Çiğ Kahve Çekirdeği",
                description: "Kahve plantasyonlarından toplanan aromatik çekirdekler.",
                category: ItemCategory.RawMaterial,
                basePrice: 35.00m,
                minPrice: 22.00m,
                maxPrice: 55.00m,
                retailSuggestedPrice: 42.00m,
                weight: 0.5f
            ));

            // === 2. ARA SANAYİ ÜRÜNLERİ (Fabrikalar & Değirmenler) ===
            Register(new ItemData(
                id: "flour",
                name: "Un (Çuval)",
                description: "Buğdayın değirmende öğütülmesiyle üretilen un. Ekmek yapımında kullanılır.",
                category: ItemCategory.Intermediate,
                basePrice: 22.00m,
                minPrice: 15.00m,
                maxPrice: 34.00m,
                retailSuggestedPrice: 28.00m,
                weight: 1.0f
            ));

            Register(new ItemData(
                id: "fabric",
                name: "İşlenmiş Kumaş (Metre)",
                description: "Pamuğun dokunmasıyla üretilen kaliteli tekstil kumaşı.",
                category: ItemCategory.Intermediate,
                basePrice: 50.00m,
                minPrice: 35.00m,
                maxPrice: 75.00m,
                retailSuggestedPrice: 62.00m,
                weight: 0.6f
            ));

            Register(new ItemData(
                id: "cheese",
                name: "Kalıp Peynir",
                description: "Çiğ sütün mayalanıp işlenmesiyle elde edilen sofralık peynir.",
                category: ItemCategory.Intermediate,
                basePrice: 85.00m,
                minPrice: 60.00m,
                maxPrice: 130.00m,
                retailSuggestedPrice: 105.00m,
                weight: 1.0f
            ));

            // === 3. NİHAİ PERAKENDE MAMULLERİ (Dükkanlar ve Tüketici Satışı) ===
            Register(new ItemData(
                id: "bread",
                name: "Somun Ekmek",
                description: "Fırınlarda pişirilen taze ekmek. Büfe ve marketlerin 1 numaralı hızlı satış ürünü.",
                category: ItemCategory.FinishedGood,
                basePrice: 10.00m,
                minPrice: 8.00m,
                maxPrice: 16.00m,
                retailSuggestedPrice: 15.00m,
                weight: 0.3f
            ));

            Register(new ItemData(
                id: "clothes",
                name: "Hazır Giyim (Gömlek/Pantolon)",
                description: "Tekstil atölyelerinde dikilen kaliteli giysiler.",
                category: ItemCategory.FinishedGood,
                basePrice: 180.00m,
                minPrice: 120.00m,
                maxPrice: 280.00m,
                retailSuggestedPrice: 250.00m,
                weight: 0.5f
            ));

            Register(new ItemData(
                id: "bottled_juice",
                name: "Şişe Meyve Suyu",
                description: "Taze meyvelerden sıkılıp şişelenmiş ferahlatıcı meyve suyu.",
                category: ItemCategory.FinishedGood,
                basePrice: 30.00m,
                minPrice: 20.00m,
                maxPrice: 48.00m,
                retailSuggestedPrice: 45.00m,
                weight: 0.5f
            ));

            Register(new ItemData(
                id: "coffee_cup",
                name: "Taze Çekilmiş Kahve",
                description: "Kafelerde müşterilere servis edilen sıcacık taze filtre kahve.",
                category: ItemCategory.FinishedGood,
                basePrice: 40.00m,
                minPrice: 28.00m,
                maxPrice: 65.00m,
                retailSuggestedPrice: 60.00m,
                weight: 0.2f
            ));
        }

        public static void Register(ItemData item)
        {
            if (!_items.ContainsKey(item.Id))
            {
                _items.Add(item.Id, item);
            }
        }

        public static ItemData Get(string id)
        {
            return _items.TryGetValue(id, out var item) ? item : null;
        }

        public static IEnumerable<ItemData> GetAll()
        {
            return _items.Values;
        }
    }
}
