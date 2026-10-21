class TenderContract {
  final String id;
  final String agency;
  final String agencyEmoji;
  final String title;
  final String description;
  final String itemId;
  final int requiredAmount;
  final double rewardCash;
  final int rewardPrestige;
  bool isCompleted;
  DateTime? completedAt;

  TenderContract({
    required this.id,
    required this.agency,
    required this.agencyEmoji,
    required this.title,
    required this.description,
    required this.itemId,
    required this.requiredAmount,
    required this.rewardCash,
    required this.rewardPrestige,
    this.isCompleted = false,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'agency': agency,
    'agencyEmoji': agencyEmoji,
    'title': title,
    'description': description,
    'itemId': itemId,
    'requiredAmount': requiredAmount,
    'rewardCash': rewardCash,
    'rewardPrestige': rewardPrestige,
    'isCompleted': isCompleted,
    'completedAt': completedAt?.toIso8601String(),
  };

  static TenderContract fromJson(Map<String, dynamic> json) {
    return TenderContract(
      id: json['id'] as String,
      agency: json['agency'] as String? ?? 'Kamu İdaresi',
      agencyEmoji: json['agencyEmoji'] as String? ?? '🏛️',
      title: json['title'] as String? ?? 'Kamu Tedarik İhalesi',
      description: json['description'] as String? ?? '',
      itemId: json['itemId'] as String? ?? 'bread',
      requiredAmount: (json['requiredAmount'] as num?)?.toInt() ?? 1000,
      rewardCash: (json['rewardCash'] as num?)?.toDouble() ?? 50000.0,
      rewardPrestige: (json['rewardPrestige'] as num?)?.toInt() ?? 100,
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt'] as String) : null,
    );
  }

  static List<TenderContract> getDefaultTenders() {
    return [
      TenderContract(
        id: 'tender_ibb_bread',
        agency: 'İstanbul Büyükşehir Belediyesi',
        agencyEmoji: '🏛️',
        title: '2.500 Adet Somun Ekmek Tedariği',
        description: 'Halk ekmek büfeleri ve aşevleri için fırınlardan toplu somun ekmek alım sözleşmesi.',
        itemId: 'bread',
        requiredAmount: 2500,
        rewardCash: 75000.0,
        rewardPrestige: 300,
      ),
      TenderContract(
        id: 'tender_saglik_milk',
        agency: 'Sağlık Bakanlığı & Hastaneler',
        agencyEmoji: '🏥',
        title: '1.200 Adet Taze Yoğurt / Süt Tedariği',
        description: 'Şehir hastaneleri ve sağlık personeli yemekhaneleri için kaliteli mandıra yoğurdu alımı.',
        itemId: 'yogurt',
        requiredAmount: 1200,
        rewardCash: 52000.0,
        rewardPrestige: 250,
      ),
      TenderContract(
        id: 'tender_tsk_leather',
        agency: 'Milli Savunma & Emniyet Lojistiği',
        agencyEmoji: '🛡️',
        title: '500 Adet Hakiki Deri Ceket Tedariği',
        description: 'Özel harekat ve güvenlik personeli kışlık dayanıklı deri mont ihalesi.',
        itemId: 'leather_jacket',
        requiredAmount: 500,
        rewardCash: 240000.0,
        rewardPrestige: 750,
      ),
      TenderContract(
        id: 'tender_tcdd_furniture',
        agency: 'Devlet Demiryolları (TCDD)',
        agencyEmoji: '🚆',
        title: '400 Adet Masif Ahşap Yemek Masası',
        description: 'Yüksek hızlı tren garları ve istasyon bekleme salonları için masif ahşap masa tefrişatı.',
        itemId: 'furniture_table',
        requiredAmount: 400,
        rewardCash: 320000.0,
        rewardPrestige: 900,
      ),
      TenderContract(
        id: 'tender_meb_laptop',
        agency: 'Milli Eğitim Bakanlığı (MEB)',
        agencyEmoji: '💻',
        title: '250 Adet Dizüstü Bilgisayar (Laptop)',
        description: 'Okulların bilişim sınıfları ve genç mucitler atölyeleri için yüksek performanslı laptop alımı.',
        itemId: 'laptop',
        requiredAmount: 250,
        rewardCash: 480000.0,
        rewardPrestige: 1500,
      ),
    ];
  }
}
