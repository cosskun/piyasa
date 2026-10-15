using System;
using System.IO;
using System.Text.Json;

namespace Piyasa.Core
{
    [Serializable]
    public class PlayerSaveData
    {
        public decimal Cash { get; set; }
        public decimal BankSavings { get; set; }
        public decimal ActiveLoan { get; set; }
        public float PlayTimeSeconds { get; set; }
        public string SavedAtUtc { get; set; }
    }

    public static class SaveSystem
    {
        private static string GetSavePath()
        {
            string folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "PiyasaGame");
            if (!Directory.Exists(folder))
            {
                Directory.CreateDirectory(folder);
            }
            return Path.Combine(folder, "savegame.json");
        }

        public static bool Save(GameManager game)
        {
            try
            {
                var data = new PlayerSaveData
                {
                    Cash = game.Economy.Cash,
                    BankSavings = game.Economy.BankSavings,
                    ActiveLoan = game.Economy.ActiveLoan,
                    PlayTimeSeconds = game.TotalPlayTimeSeconds,
                    SavedAtUtc = DateTime.UtcNow.ToString("o")
                };

                string json = JsonSerializer.Serialize(data, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(GetSavePath(), json);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Kayıt hatası: {ex.Message}");
                return false;
            }
        }

        public static PlayerSaveData Load()
        {
            try
            {
                string path = GetSavePath();
                if (!File.Exists(path)) return null;

                string json = File.ReadAllText(path);
                return JsonSerializer.Deserialize<PlayerSaveData>(json);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Yükleme hatası: {ex.Message}");
                return null;
            }
        }
    }
}
