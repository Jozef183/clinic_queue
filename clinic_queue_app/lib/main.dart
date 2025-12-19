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

  int? _activeSlotNumber() {
    final index = slots.indexOf(SlotStatus.active);
    if (index == -1) return null;
    return index + 1;
  }

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
@override
Widget build(BuildContext context) {
  final activeNumber = _activeSlotNumber();

  return Scaffold(
    appBar: AppBar(
      title: const Text('Čakáreň'),
      centerTitle: true,
    ),
    body: Column(
      children: [
        // ======================
        // AKTUÁLNE VYŠETROVANÉ
        // ======================
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          color: Colors.black87,
          child: Column(
            children: [
              const Text(
                'Aktuálne sa vyšetruje',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                activeNumber?.toString() ?? '—',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: activeNumber != null
                      ? Colors.orange
                      : Colors.white38,
                ),
              ),
            ],
          ),
        ),

        // ======================
        // ZOZNAM PORADÍ
        // ======================
        Expanded(
          child: Padding(
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
        ),
      ],
    ),
  );
  }
}

/* =======================
   JEDEN SLOT (ČÍSLO)
   ======================= */
class SlotTile extends StatefulWidget {
  final int number;
  final SlotStatus status;

  const SlotTile({
    super.key,
    required this.number,
    required this.status,
  });

  @override
  State<SlotTile> createState() => _SlotTileState();
}

class _SlotTileState extends State<SlotTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.status == SlotStatus.active) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant SlotTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.status == SlotStatus.active) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _colorForStatus() {
    switch (widget.status) {
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
    switch (widget.status) {
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
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: _colorForStatus(),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.number.toString(),
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
      ),
    );
  }
}
