class OfflineCatchUpReport {
  final Duration elapsedDuration;
  final Map<String, int> producedItems;
  final bool warehouseFull;
  final int retailItemsSold;
  final double retailRevenue;
  final int marketItemsSold;
  final double marketRevenue;
  final int incomingOffersCount;
  final double bankInterestEarned;
  final int loanInstallmentsPaid;
  final int loanInstallmentsOverdue;
  final double loanPenaltiesIncurred;
  final double totalLoanPaidAmount;
  final double startingCash;
  final double endingCash;

  OfflineCatchUpReport({
    required this.elapsedDuration,
    required this.producedItems,
    this.warehouseFull = false,
    this.retailItemsSold = 0,
    this.retailRevenue = 0.0,
    this.marketItemsSold = 0,
    this.marketRevenue = 0.0,
    this.incomingOffersCount = 0,
    this.bankInterestEarned = 0.0,
    this.loanInstallmentsPaid = 0,
    this.loanInstallmentsOverdue = 0,
    this.loanPenaltiesIncurred = 0.0,
    this.totalLoanPaidAmount = 0.0,
    required this.startingCash,
    required this.endingCash,
  });

  double get netCashChange => endingCash - startingCash;

  int get totalProductionCount =>
      producedItems.values.fold(0, (sum, count) => sum + count);

  bool get hasAnyActivity =>
      elapsedDuration.inSeconds >= 10 &&
      (totalProductionCount > 0 ||
          retailItemsSold > 0 ||
          marketItemsSold > 0 ||
          incomingOffersCount > 0 ||
          bankInterestEarned > 0 ||
          loanInstallmentsPaid > 0 ||
          loanInstallmentsOverdue > 0 ||
          warehouseFull);

  String get formattedDuration {
    final hours = elapsedDuration.inHours;
    final minutes = elapsedDuration.inMinutes % 60;
    final seconds = elapsedDuration.inSeconds % 60;

    if (hours > 0) {
      return '$hours sa ${minutes > 0 ? '$minutes dk' : ''}';
    } else if (minutes > 0) {
      return '$minutes dk ${seconds > 0 ? '$seconds sn' : ''}';
    } else {
      return '$seconds saniye';
    }
  }
}
