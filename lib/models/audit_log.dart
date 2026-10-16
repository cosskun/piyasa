import 'package:cloud_firestore/cloud_firestore.dart';

enum LogCategory {
  trade,    // Borsa, Pazar Alımı, Satımı, İlan, Teklif
  facility, // Fabrika/Çiftlik kurulumu, yükseltme, satış
  retail,   // Dükkan açılışı, raf satışı, fiyat değişimi
  finance,  // Banka kredisi, taksit, faiz geliri
  auth,     // Kayıt, giriş, çıkış, misafir
  system,   // Seviye atlama, çevrimdışı kazançlar
}

class AuditLog {
  final String id;
  final DateTime timestamp;
  final String playerId;
  final String username;
  final LogCategory category;
  final String action;
  final String title;
  final String description;
  final double? amountChange; // Pozitif: Gelir, Negatif: Gider, null: Parasal olmayan işlem
  final double cashAfter;
  final Map<String, dynamic> details;

  AuditLog({
    required this.id,
    required this.timestamp,
    required this.playerId,
    required this.username,
    required this.category,
    required this.action,
    required this.title,
    required this.description,
    this.amountChange,
    required this.cashAfter,
    this.details = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'playerId': playerId,
      'username': username,
      'category': category.name,
      'action': action,
      'title': title,
      'description': description,
      'amountChange': amountChange,
      'cashAfter': cashAfter,
      'details': details,
    };
  }

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    LogCategory cat = LogCategory.system;
    try {
      cat = LogCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => LogCategory.system,
      );
    } catch (_) {}

    return AuditLog(
      id: json['id'] as String? ?? 'log_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      playerId: json['playerId'] as String? ?? 'guest',
      username: json['username'] as String? ?? 'Oyuncu',
      category: cat,
      action: json['action'] as String? ?? 'UNKNOWN',
      title: json['title'] as String? ?? 'İşlem',
      description: json['description'] as String? ?? '',
      amountChange: json['amountChange'] != null
          ? (json['amountChange'] as num).toDouble()
          : null,
      cashAfter: (json['cashAfter'] as num?)?.toDouble() ?? 0.0,
      details: json['details'] is Map ? Map<String, dynamic>.from(json['details'] as Map) : {},
    );
  }

  /// Cloud Firestore için sunucu zaman damgalı format
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'serverTimestamp': FieldValue.serverTimestamp(),
      'timestamp': timestamp.toIso8601String(),
      'playerId': playerId,
      'username': username,
      'category': category.name,
      'action': action,
      'title': title,
      'description': description,
      'amountChange': amountChange,
      'cashAfter': cashAfter,
      'details': details,
    };
  }
}
