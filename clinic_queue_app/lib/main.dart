import 'package:flutter/material.dart';

void main() {
  runApp(const ClinicQueueApp());
}

/* =======================
   HLAVNÁ APLIKÁCIA
   ======================= */
class ClinicQueueApp extends StatelessWidget {
  const ClinicQueueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clinic Queue',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const QueueScreen(),
    );
  }
}

/* =======================
   STAVY SLOTOV
   ======================= */
enum SlotStatus {
  free,
  reserved,
  active,
  absent,
  done,
}

/* =======================
   HLAVNÁ OBRAZOVKA
   ======================= */
class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  static const int totalSlots = 30;

  final List<SlotStatus> slots =
      List.generate(totalSlots, (_) => SlotStatus.free);

  void _nextStatus(int index) {
    setState(() {
      switch (slots[index]) {
        case SlotStatus.free:
          slots[index] = SlotStatus.reserved;
          break;
        case SlotStatus.reserved:
          slots[index] = SlotStatus.active;
          break;
        case SlotStatus.active:
          slots[index] = SlotStatus.absent;
          break;
        case SlotStatus.absent:
          slots[index] = SlotStatus.done;
          break;
        case SlotStatus.done:
          slots[index] = SlotStatus.free;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Čakáreň – simulácia'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: totalSlots,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _nextStatus(index),
              child: SlotTile(
                number: index + 1,
                status: slots[index],
              ),
            );
          },
        ),
      ),
    );
  }
}

/* =======================
   JEDEN SLOT (ČÍSLO)
   ======================= */
class SlotTile extends StatelessWidget {
  final int number;
  final SlotStatus status;

  const SlotTile({
    super.key,
    required this.number,
    required this.status,
  });

  Color _colorForStatus() {
    switch (status) {
      case SlotStatus.free:
        return Colors.green;
      case SlotStatus.reserved:
        return Colors.blue;
      case SlotStatus.active:
        return Colors.orange;
      case SlotStatus.absent:
        return Colors.red;
      case SlotStatus.done:
        return Colors.grey;
    }
  }

  String _labelForStatus() {
    switch (status) {
      case SlotStatus.free:
        return 'Voľné';
      case SlotStatus.reserved:
        return 'Rezervované';
      case SlotStatus.active:
        return 'Vyšetruje sa';
      case SlotStatus.absent:
        return 'Neprítomný';
      case SlotStatus.done:
        return 'Hotovo';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _colorForStatus(),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            number.toString(),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _labelForStatus(),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
