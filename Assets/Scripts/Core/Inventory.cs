using System;
using System.Collections.Generic;

namespace Piyasa.Core
{
    [Serializable]
    public class Inventory
    {
        public float MaxCapacity { get; set; } // Depo kapasitesi (kg / birim cinsinden)
        public Dictionary<string, int> Items { get; private set; }

        public event Action OnInventoryChanged;

        public Inventory(float maxCapacity = 1000f)
        {
            MaxCapacity = maxCapacity;
            Items = new Dictionary<string, int>();
        }

        public float GetCurrentWeight()
        {
            float total = 0;
            foreach (var kvp in Items)
            {
                var item = ItemRegistry.Get(kvp.Key);
                if (item != null)
                {
                    total += kvp.Value * item.WeightPerUnit;
                }
            }
            return total;
        }

        public float GetRemainingCapacity()
        {
            return Math.Max(0, MaxCapacity - GetCurrentWeight());
        }

        public int GetQuantity(string itemId)
        {
            return Items.TryGetValue(itemId, out int count) ? count : 0;
        }

        public bool HasItem(string itemId, int quantity)
        {
            return GetQuantity(itemId) >= quantity;
        }

        public bool CanAdd(string itemId, int quantity)
        {
            var item = ItemRegistry.Get(itemId);
            if (item == null) return false;
            float neededWeight = quantity * item.WeightPerUnit;
            return GetCurrentWeight() + neededWeight <= MaxCapacity;
        }

        public bool AddItem(string itemId, int quantity)
        {
            if (quantity <= 0) return false;
            if (!CanAdd(itemId, quantity)) return false;

            if (Items.ContainsKey(itemId))
                Items[itemId] += quantity;
            else
                Items[itemId] = quantity;

            OnInventoryChanged?.Invoke();
            return true;
        }

        public bool RemoveItem(string itemId, int quantity)
        {
            if (quantity <= 0) return false;
            if (!HasItem(itemId, quantity)) return false;

            Items[itemId] -= quantity;
            if (Items[itemId] <= 0)
            {
                Items.Remove(itemId);
            }

            OnInventoryChanged?.Invoke();
            return true;
        }

        public void ExpandCapacity(float extraCapacity)
        {
            if (extraCapacity > 0)
            {
                MaxCapacity += extraCapacity;
                OnInventoryChanged?.Invoke();
            }
        }
    }
}
