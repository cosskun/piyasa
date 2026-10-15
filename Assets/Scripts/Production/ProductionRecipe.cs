using System;
using System.Collections.Generic;

namespace Piyasa.Production
{
    [Serializable]
    public class RecipeIngredient
    {
        public string ItemId { get; set; }
        public int Amount { get; set; }

        public RecipeIngredient(string itemId, int amount)
        {
            ItemId = itemId;
            Amount = amount;
        }
    }

    [Serializable]
    public class ProductionRecipe
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public List<RecipeIngredient> Inputs { get; set; } // Girdi hammaddeler (Tarla için boş olabilir!)
        public string OutputItemId { get; set; }           // Çıkan mamul
        public int OutputAmount { get; set; }              // Çıkan adet
        public float ProductionTimeSeconds { get; set; }   // Üretim döngü süresi (saniye)

        public ProductionRecipe(string id, string name, List<RecipeIngredient> inputs, 
                                string outputItemId, int outputAmount, float timeSeconds)
        {
            Id = id;
            Name = name;
            Inputs = inputs ?? new List<RecipeIngredient>();
            OutputItemId = outputItemId;
            OutputAmount = outputAmount;
            ProductionTimeSeconds = timeSeconds;
        }
    }
}
