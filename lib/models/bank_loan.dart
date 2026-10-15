class LoanInstallment {
  final int installmentNumber;
  final double principalAmount; // Anapara payı
  final double interestAmount;  // Faiz payı
  final double totalAmount;     // Taksit toplamı
  final double remainingBalanceAfter; // Kalan toplam borç
  bool isPaid;

  LoanInstallment({
    required this.installmentNumber,
    required this.principalAmount,
    required this.interestAmount,
    required this.totalAmount,
    required this.remainingBalanceAfter,
    this.isPaid = false,
  });

  Map<String, dynamic> toJson() => {
    'installmentNumber': installmentNumber,
    'principalAmount': principalAmount,
    'interestAmount': interestAmount,
    'totalAmount': totalAmount,
    'remainingBalanceAfter': remainingBalanceAfter,
    'isPaid': isPaid,
  };

  static LoanInstallment fromJson(Map<String, dynamic> json) {
    return LoanInstallment(
      installmentNumber: (json['installmentNumber'] as num).toInt(),
      principalAmount: (json['principalAmount'] as num).toDouble(),
      interestAmount: (json['interestAmount'] as num).toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      remainingBalanceAfter: (json['remainingBalanceAfter'] as num).toDouble(),
      isPaid: json['isPaid'] as bool? ?? false,
    );
  }
}

class BankLoan {
  final String id;
  final String title;
  final double principal; // Çekilen toplam anapara
  final double interestRate; // Taksit/Döngü başı faiz oranı (Örn: 0.012 = %1.2)
  final int totalInstallments; // Toplam gün/taksit sayısı
  int paidInstallments;
  double remainingPrincipal;
  double remainingInterest;
  final DateTime takenAt;
  final List<LoanInstallment> schedule;
  double nextInstallmentTimer; // Bir sonraki taksit sayacı (saniye)

  static const double installmentInterval = 45.0; // Her 45 saniyede bir gün/taksit döngüsü

  BankLoan({
    required this.id,
    required this.title,
    required this.principal,
    required this.interestRate,
    required this.totalInstallments,
    this.paidInstallments = 0,
    required this.remainingPrincipal,
    required this.remainingInterest,
    required this.takenAt,
    required this.schedule,
    this.nextInstallmentTimer = 0.0,
  });

  double get totalLoanCost => principal + (principal * interestRate * totalInstallments);
  double get totalInterestCost => principal * interestRate * totalInstallments;
  double get remainingTotal => remainingPrincipal + remainingInterest;
  double get singleInstallmentAmount => schedule.isNotEmpty ? schedule.first.totalAmount : 0.0;
  bool get isFullyPaid => remainingTotal <= 0.05 || paidInstallments >= totalInstallments;
  double get paymentProgress => totalInstallments > 0 ? (paidInstallments / totalInstallments).clamp(0.0, 1.0) : 0.0;
  int get remainingInstallmentsCount => totalInstallments - paidInstallments;

  // Statik hesaplama yardımcısı (Ödeme Planı Simülatörü)
  static List<LoanInstallment> generateSchedule({
    required double principal,
    required double interestRatePerPeriod,
    required int installments,
  }) {
    List<LoanInstallment> result = [];
    double principalPerInstallment = principal / installments;
    double interestPerInstallment = principal * interestRatePerPeriod;
    double installmentAmount = principalPerInstallment + interestPerInstallment;
    double totalPayable = installmentAmount * installments;
    double currentRemaining = totalPayable;

    for (int i = 1; i <= installments; i++) {
      currentRemaining -= installmentAmount;
      if (currentRemaining < 0) currentRemaining = 0.0;

      result.add(
        LoanInstallment(
          installmentNumber: i,
          principalAmount: double.parse(principalPerInstallment.toStringAsFixed(2)),
          interestAmount: double.parse(interestPerInstallment.toStringAsFixed(2)),
          totalAmount: double.parse(installmentAmount.toStringAsFixed(2)),
          remainingBalanceAfter: double.parse(currentRemaining.toStringAsFixed(2)),
        ),
      );
    }

    return result;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'principal': principal,
    'interestRate': interestRate,
    'totalInstallments': totalInstallments,
    'paidInstallments': paidInstallments,
    'remainingPrincipal': remainingPrincipal,
    'remainingInterest': remainingInterest,
    'takenAt': takenAt.toIso8601String(),
    'schedule': schedule.map((i) => i.toJson()).toList(),
    'nextInstallmentTimer': nextInstallmentTimer,
  };

  static BankLoan fromJson(Map<String, dynamic> json) {
    return BankLoan(
      id: json['id'] as String,
      title: json['title'] as String,
      principal: (json['principal'] as num).toDouble(),
      interestRate: (json['interestRate'] as num).toDouble(),
      totalInstallments: (json['totalInstallments'] as num).toInt(),
      paidInstallments: (json['paidInstallments'] as num?)?.toInt() ?? 0,
      remainingPrincipal: (json['remainingPrincipal'] as num).toDouble(),
      remainingInterest: (json['remainingInterest'] as num).toDouble(),
      takenAt: DateTime.tryParse(json['takenAt'] as String? ?? '') ?? DateTime.now(),
      schedule: (json['schedule'] as List<dynamic>? ?? [])
          .map((i) => LoanInstallment.fromJson(i as Map<String, dynamic>))
          .toList(),
      nextInstallmentTimer: (json['nextInstallmentTimer'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
