import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../models/item.dart';

class InventorySheet extends StatelessWidget {
  final GameController controller;

  const InventorySheet({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat("#,##0", "tr_TR");
    final usedWeight = controller.currentWarehouseWeight;
    final maxWeight = controller.maxWarehouseCapacity;
    final ratio = (usedWeight / maxWeight).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.70,
      decoration: const BoxDecoration(
        color: Color(0xFF141926),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('📦', style: TextStyle(fontSize: 26)),
                  SizedBox(width: 8),
                  Text(
                    'Merkezi Silo ve Depom',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Doluluk Barı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Doluluk: ${usedWeight.toStringAsFixed(0)} / ${maxWeight.toStringAsFixed(0)} kg (%${(ratio * 100).toInt()})',
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
              TextButton.icon(
                onPressed: () {
                  final err = controller.expandWarehouse();
                  if (err != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                  }
                },
                icon: const Icon(Icons.upgrade, size: 16),
                label: const Text('+500 kg Kapasite Al'),
                style: TextButton.styleFrom(foregroundColor: Colors.amberAccent),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.black26,
              valueColor: AlwaysStoppedAnimation<Color>(
                ratio > 0.85 ? Colors.redAccent : Colors.amberAccent,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Stok Listesi
          Expanded(
            child: controller.warehouse.isEmpty
                ? const Center(
                    child: Text(
                      'Deponuz şu an tamamen boş.\nTarlalarınızdan hasat toplayabilir veya pazardan toptan mal çekebilirsiniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView(
                    children: controller.warehouse.entries.map((entry) {
                      final item = ItemRegistry.get(entry.key);
                      final count = entry.value;
                      final mItem = controller.marketItems[entry.key];
                      final unitVal = mItem?.wholesaleSellPrice ?? item?.basePrice ?? 0.0;
                      final totalVal = unitVal * count;

                      return Card(
                        color: const Color(0xFF1E283E),
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: Text(item?.emoji ?? '📦', style: const TextStyle(fontSize: 26)),
                          title: Text(
                            item?.name ?? entry.key,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          subtitle: Text(
                            'Toplam Ağırlık: ${(count * (item?.weight ?? 1.0)).toStringAsFixed(1)} kg',
                            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$count Adet',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amberAccent,
                                ),
                              ),
                              Text(
                                'Borsa Değeri: ${currencyFmt.format(totalVal)} ₺',
                                style: const TextStyle(fontSize: 11, color: Colors.greenAccent),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
