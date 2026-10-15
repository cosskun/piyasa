using System;

namespace Piyasa.Core
{
    [Serializable]
    public class EconomyManager
    {
        public decimal Cash { get; private set; }
        public decimal BankSavings { get; private set; }
        public decimal ActiveLoan { get; private set; }
        public decimal HourlyInterestRate { get; set; } = 0.005m; // Saatte %0.5 mevduat getirisi
        public decimal LoanHourlyInterestRate { get; set; } = 0.012m; // Saatte %1.2 kredi faiz maliyeti

        public event Action<decimal> OnCashChanged;
        public event Action OnBankChanged;

        public EconomyManager(decimal startingCash = 25000m)
        {
            Cash = startingCash;
            BankSavings = 0m;
            ActiveLoan = 0m;
        }

        public bool CanAfford(decimal amount)
        {
            return Cash >= amount;
        }

        public bool Spend(decimal amount, string reason = "")
        {
            if (amount < 0) return false;
            if (Cash < amount) return false;

            Cash -= amount;
            OnCashChanged?.Invoke(Cash);
            return true;
        }

        public void Earn(decimal amount, string source = "")
        {
            if (amount <= 0) return;
            Cash += amount;
            OnCashChanged?.Invoke(Cash);
        }

        // === BANKA MEVDUAT / FAİZ İŞLEMLERİ ===
        public bool DepositToBank(decimal amount)
        {
            if (amount <= 0 || Cash < amount) return false;
            Cash -= amount;
            BankSavings += amount;
            OnCashChanged?.Invoke(Cash);
            OnBankChanged?.Invoke();
            return true;
        }

        public bool WithdrawFromBank(decimal amount)
        {
            if (amount <= 0 || BankSavings < amount) return false;
            BankSavings -= amount;
            Cash += amount;
            OnCashChanged?.Invoke(Cash);
            OnBankChanged?.Invoke();
            return true;
        }

        // === KREDİ İŞLEMLERİ ===
        public bool TakeLoan(decimal amount, decimal maxAllowedLoan)
        {
            if (amount <= 0) return false;
            if (ActiveLoan + amount > maxAllowedLoan) return false;

            ActiveLoan += amount;
            Cash += amount;
            OnCashChanged?.Invoke(Cash);
            OnBankChanged?.Invoke();
            return true;
        }

        public bool RepayLoan(decimal amount)
        {
            if (amount <= 0 || ActiveLoan <= 0) return false;
            decimal payment = Math.Min(amount, ActiveLoan);
            if (Cash < payment) return false;

            Cash -= payment;
            ActiveLoan -= payment;
            OnCashChanged?.Invoke(Cash);
            OnBankChanged?.Invoke();
            return true;
        }

        // Saatlik döngüde banka faiz işletme
        public void ProcessHourlyFinances()
        {
            if (BankSavings > 0)
            {
                decimal interestEarned = BankSavings * HourlyInterestRate;
                BankSavings += interestEarned;
            }

            if (ActiveLoan > 0)
            {
                decimal loanInterest = ActiveLoan * LoanHourlyInterestRate;
                ActiveLoan += loanInterest;
            }

            OnBankChanged?.Invoke();
        }
    }
}
