using System;

namespace Piyasa.Core
{
    public enum ItemCategory
    {
        RawMaterial,     // Tarladan/bahçeden çıkan ham madde (Buğday, Pamuk vb.)
        Intermediate,    // Fabrikadan çıkan ara madde (Un, Kumaş vb.)
        FinishedGood     // Dükkanda müşteriye satılan nihai mamul (Ekmek, Kıyafet, Kahve vb.)
    }

    [Serializable]
    public class ItemData
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public string Description { get; set; }
        public ItemCategory Category { get; set; }
        
        // Piyasa & Fiyatlandırma
        public decimal BasePrice { get; set; }        // Ortalama baz fiyat (TL)
        public decimal MinPrice { get; set; }         // Pazardaki en düşük taban fiyat
        public decimal MaxPrice { get; set; }         // Pazardaki en yüksek tavan fiyat
        public decimal RetailSuggestedPrice { get; set; } // Perakende dükkan satış tavsiye fiyatı
        
        // Depolama
        public float WeightPerUnit { get; set; }      // Birim başına depo ağırlığı/hacmi

        public ItemData() { }

        public ItemData(string id, string name, string description, ItemCategory category, 
                        decimal basePrice, decimal minPrice, decimal maxPrice, decimal retailSuggestedPrice, float weight = 1.0f)
        {
            Id = id;
            Name = name;
            Description = description;
            Category = category;
            BasePrice = basePrice;
            MinPrice = minPrice;
            MaxPrice = maxPrice;
            RetailSuggestedPrice = retailSuggestedPrice;
            WeightPerUnit = weight;
        }
    }
}
