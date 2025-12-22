import 'package:flutter/material.dart';

void main() {
  runApp(const ClinicQueueApp());
}

class ReservationFormData {
  int slotNumber;
  String name;
  String personalId;
  String note;

  ReservationFormData({
    required this.slotNumber,
    this.name = '',
    this.personalId = '',
    this.note = '',
  });
}

/* =======================
   HLAVNÁ APLIKÁCIA
   ======================= */
class ClinicQueueApp extends StatefulWidget {
  const ClinicQueueApp({super.key});

  @override
  State<ClinicQueueApp> createState() => _ClinicQueueAppState();
}

class _ClinicQueueAppState extends State<ClinicQueueApp> {
  AppMode? mode;

  final List<SlotStatus> slots =
      List.generate(30, (_) => SlotStatus.free);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: mode == null
          ? ModeSelectionScreen(onSelect: _setMode)
          : _buildModeScreen(),
    );
  }

  void _setMode(AppMode m) {
    setState(() => mode = m);
  }

  Widget _buildModeScreen() {
    switch (mode) {
      case AppMode.patient:
        return PatientReservationScreen(slots: slots,
        onBackToMenu: () => setState(() => mode = null),
        );

      case AppMode.waitingRoom:
        return WaitingRoomSelectionScreen(slots: slots,
        onBackToMenu: () => setState(() => mode = null),
        );

      case AppMode.doctor:
        return DoctorQueueScreen(slots: slots, 
        onBackToMenu: () => setState(() => mode = null),);

      case AppMode.tv:
        return QueueScreen(isTvMode: true, slots: slots,
        onBackToMenu: () => setState(() => mode = null),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}


class ModeSelectionScreen extends StatelessWidget {
  final void Function(AppMode mode) onSelect;

  const ModeSelectionScreen({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Režim aplikácie')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _modeButton('Pacient', AppMode.patient),
            _modeButton('Čakáreň', AppMode.waitingRoom),
            _modeButton('Lekár', AppMode.doctor),
            _modeButton('TV panel', AppMode.tv),
          ],
        ),
      ),
    );
  }

  Widget _modeButton(String label, AppMode mode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton(
        onPressed: () => onSelect(mode),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(220, 56),
        ),
        child: Text(label, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

/* =======================
   STAVY SLOTOV
   ======================= */
enum SlotStatus { free, reserved, active, absent, done }

enum AppMode {  patient,  waitingRoom,  doctor,  tv }

/* =======================
   HLAVNÁ OBRAZOVKA
   ======================= */
class QueueScreen extends StatefulWidget {
  final bool isTvMode;
  final List<SlotStatus> slots;
  final VoidCallback onBackToMenu;

  const QueueScreen({
    super.key,
    required this.isTvMode,
    required this.slots,
    required this.onBackToMenu,
  });

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  static const int totalSlots = 30;

  List<SlotStatus> get slots => widget.slots;

  bool get isTvMode => widget.isTvMode;
  // List<SlotStatus> get slots => widget.slots;


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
          break;
      }
    });
  }

@override
  @override
  Widget build(BuildContext context) {
    final activeNumber = _activeSlotNumber();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isTvMode
          ? null
          : AppBar(title: const Text('Čakáreň'), centerTitle: true,
          leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBackToMenu,
        ),
      ),
      body: Column(
        children: [
          _buildHeader(activeNumber),
          Expanded(child: _buildGrid()),
        ],
      ),
    );
  }

  Widget _buildHeader(int? activeNumber) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: isTvMode ? 40 : 24),
      child: Column(
        children: [
          if (!isTvMode)
            const Text(
              'Aktuálne sa vyšetruje',
              style: TextStyle(fontSize: 20, color: Colors.white70),
            ),
          const SizedBox(height: 12),
          Text(
            activeNumber?.toString() ?? '—',
            style: TextStyle(
              fontSize: isTvMode ? 120 : 64,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isTvMode ? 6 : 5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isTvMode ? 1.4 : 1.2,
        ),
        itemCount: totalSlots,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: isTvMode ? null : () => _nextStatus(index),
            child: SlotTile(number: index + 1, status: slots[index]),
          );
        },
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

  const SlotTile({super.key, required this.number, required this.status});

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

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

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
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(_labelForStatus(), style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class PatientReservationScreen extends StatefulWidget {
  final List<SlotStatus> slots;
  final VoidCallback onBackToMenu;

  const PatientReservationScreen({super.key, required this.slots, required this.onBackToMenu, });

  @override
  State<PatientReservationScreen> createState() =>
      _PatientReservationScreenState();
}

class _PatientReservationScreenState
    extends State<PatientReservationScreen> {
  final _formKey = GlobalKey<FormState>();
  int? selectedSlot;

  final nameCtrl = TextEditingController();
  final pidCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rezervácia termínu'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBackToMenu,
                ),
              ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildSlotSelector(),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Meno a priezvisko'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Povinné pole' : null,
              ),
              TextFormField(
                controller: pidCtrl,
                decoration: const InputDecoration(labelText: 'Rodné číslo'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Povinné pole' : null,
              ),
              TextFormField(
                controller: noteCtrl,
                decoration:
                    const InputDecoration(labelText: 'Poznámka pre lekára'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Rezervovať'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotSelector() {
    return Wrap(
      spacing: 8,
      children: List.generate(widget.slots.length, (i) {
        if (widget.slots[i] != SlotStatus.free) return const SizedBox.shrink();
        final num = i + 1;
        return ChoiceChip(
          label: Text(num.toString()),
          selected: selectedSlot == num,
          onSelected: (_) => setState(() => selectedSlot = num),
        );
      }),
    );
  }

  void _submit() {
    if (selectedSlot == null) return;
    if (_formKey.currentState!.validate()) {
      // tu neskôr pôjde API / WebSocket
      Navigator.pop(context);
    }
  }
}

class WaitingRoomSelectionScreen extends StatelessWidget {
  final List<SlotStatus> slots;
  final VoidCallback onBackToMenu;

  const WaitingRoomSelectionScreen({super.key, required this.slots, required this.onBackToMenu, });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vyber poradia'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBackToMenu,
                ),
              ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: slots.length,
        itemBuilder: (context, i) {
          final num = i + 1;
          final isVisible =
              num <= 8 || slots[i] == SlotStatus.free;

          if (!isVisible) return const SizedBox.shrink();

          return ElevatedButton(
            onPressed: slots[i] == SlotStatus.free
                ? () {
                    // rezervácia bez osobných údajov
                  }
                : null,
            child: Text(
              num.toString(),
              style: const TextStyle(fontSize: 32),
            ),
          );
        },
      ),
    );
  }
}

class DoctorQueueScreen extends StatefulWidget {
  final List<SlotStatus> slots;
  final VoidCallback onBackToMenu;

  const DoctorQueueScreen({super.key, required this.slots, required this.onBackToMenu, });

  @override
  State<DoctorQueueScreen> createState() => _DoctorQueueScreenState();
}

class _DoctorQueueScreenState extends State<DoctorQueueScreen> {
  void _setStatus(int index, SlotStatus status) {
    setState(() {
      widget.slots[index] = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lekár – poradie'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBackToMenu,
                ),
              ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: widget.slots.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _showActions(context, index),
            child: SlotTile(
              number: index + 1,
              status: widget.slots[index],
            ),
          );
        },
      ),
    );
  }

  void _showActions(BuildContext context, int index) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Wrap(
        children: [
          _action(index, 'Vyšetruje sa', SlotStatus.active),
          _action(index, 'Neprítomný', SlotStatus.absent),
          _action(index, 'Hotovo', SlotStatus.done),
        ],
      ),
    );
  }


Widget _action(int index, String label, SlotStatus status) {
  return ListTile(
    title: Text(label),
    onTap: () {
      Navigator.pop(context);
      _setStatus(index, status);
    },
  );
}

}
