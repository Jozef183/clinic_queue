import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:flutter/foundation.dart';

// import 'package:clinic_queue_app/app_state.dart';

/* =======================
   STAVY SLOTOV
   ======================= */
enum SlotStatus { free, reserved, active, absent, done }

enum AppMode { patient, waitingRoom, doctor, tv }

class QueueSlot {
  SlotStatus status;
  String? name;
  String? personalId;
  String? note;

  QueueSlot({
    this.status = SlotStatus.free,
    this.name,
    this.personalId,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'name': name,
    'personalId': personalId,
    'note': note,
  };

  static QueueSlot fromJson(Map<String, dynamic> json) {
    return QueueSlot(
      status: SlotStatus.values.firstWhere((e) => e.name == json['status']),
      name: json['name'],
      personalId: json['personalId'],
      note: json['note'],
    );
  }

  void clear() {
    status = SlotStatus.free;
    name = null;
    personalId = null;
    note = null;
  }
}

class AppState extends ChangeNotifier {
  AppMode? mode;

  final List<QueueSlot> slots = List.generate(30, (_) => QueueSlot());

  late WebSocketChannel _channel;

  AppState() {
    _connectWs();
  }

  void _connectWs() {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:8000/ws/queue'),
    );

    _channel.stream.listen(
      (data) {
        debugPrint("WS RECEIVED: $data");

        final payload = jsonDecode(data);

        if (payload['type'] == 'slots') {
          final index = payload['index'] as int;
          final slotData = payload['slot'];

          slots[index] = QueueSlot.fromJson(slotData);
          notifyListeners();
        }
      },
      onError: (e) => debugPrint("WS ERROR: $e"),
      onDone: () => debugPrint('WS CLOSED'),
    );
  }

  void setMode(AppMode? newMode) {
    mode = newMode;
    notifyListeners();
  }

  // 🔹 REZERVÁCIA PACIENTOM
  void reserveSlot(
    int index, {
    required String name,
    required String personalId,
    String? note,
  }) {
    final slot = slots[index];
    if (slot.status != SlotStatus.free) return;

    slot.status = SlotStatus.reserved;
    slot.name = name;
    slot.personalId = personalId;
    slot.note = note;

    notifyListeners();
    _sendSlotUpdate(index);
  }

  // 🔹 ZMENA STAVU LEKÁROM
  void setSlotStatus(int index, SlotStatus status) {
    final slot = slots[index];
    slot.status = status;

    if (status == SlotStatus.done) {
      slot.clear();
    }

    notifyListeners();
    _sendSlotUpdate(index);
  }

  void advanceSlotStatus(int index) {
    switch (slots[index].status) {
      case SlotStatus.free:
        break;
      case SlotStatus.reserved:
        setSlotStatus(index, SlotStatus.active);
        break;
      case SlotStatus.active:
        setSlotStatus(index, SlotStatus.absent);
        break;
      case SlotStatus.absent:
        setSlotStatus(index, SlotStatus.done);
        break;
      case SlotStatus.done:
        break;
    }
  }

  void _sendSlotUpdate(int index) {
    _channel.sink.add(
      jsonEncode({
        'type': 'slots',
        'index': index,
        'slot': slots[index].toJson(),
      }),
    );
  }

  void updateSlot(int index, QueueSlot updatedSlot) {
  slots[index] = updatedSlot;
  notifyListeners();

  _channel.sink.add(jsonEncode({
    'type': 'slots',
    'index': index,
    'slot': updatedSlot.toJson(),
  }));
}

}

/* =======================
   HLAVNÁ APLIKÁCIA
   ======================= */
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const ClinicQueueApp(),
    ),
  );
}

class ClinicQueueApp extends StatelessWidget {
  const ClinicQueueApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: app.mode == null
          ? ModeSelectionScreen(
              onSelect: (mode) => context.read<AppState>().setMode(mode),
            )
          : _buildModeScreen(app),
    );
  }

  Widget _buildModeScreen(AppState app) {
    switch (app.mode) {
      case AppMode.patient:
        return PatientReservationScreen();
      case AppMode.waitingRoom:
        return WaitingRoomSelectionScreen();
      case AppMode.doctor:
        return DoctorQueueScreen();
      case AppMode.tv:
        return QueueScreen(isTvMode: true);
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
            _modeButton('Pacient', AppMode.patient, context),
            _modeButton('Čakáreň', AppMode.waitingRoom, context),
            _modeButton('Lekár', AppMode.doctor, context),
            _modeButton('TV panel', AppMode.tv, context),
          ],
        ),
      ),
    );
  }

  Widget _modeButton(String label, AppMode mode, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton(
        onPressed: () => context.read<AppState>().setMode(mode),
        style: ElevatedButton.styleFrom(minimumSize: const Size(220, 56)),
        child: Text(label, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

/* =======================
   HLAVNÁ OBRAZOVKA
   ======================= */
class QueueScreen extends StatefulWidget {
  final bool isTvMode;

  const QueueScreen({super.key, required this.isTvMode});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  static const int totalSlots = 30;

  List<QueueSlot> get slots => context.watch<AppState>().slots;
  bool get isTvMode => widget.isTvMode;

  int? _activeSlotNumber() {
    final index = slots.indexWhere((slot) => slot.status == SlotStatus.active);
    if (index == -1) return null;
    return index + 1;
  }

  void _nextStatus(int index) {
    context.read<AppState>().advanceSlotStatus(index);
  }

  @override
  Widget build(BuildContext context) {
    final activeNumber = _activeSlotNumber();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Čakáreň'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.read<AppState>().setMode(null),
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
            child: SlotTile(
              number: index + 1,
              slot: slots[index], // ⬅️ CELÝ SLOT
            ),
          );
        },
      ),
    );
  }
}

/* =======================
   JEDEN SLOT (ČÍSLO)
   ======================= */
class SlotTile extends StatelessWidget {
  final int number;
  final QueueSlot slot;

  const SlotTile({super.key, required this.number, required this.slot});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _colorForStatus(slot.status),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            number.toString(),
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(_labelForStatus(slot.status)),
          if (slot.name != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                slot.name!,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Color _colorForStatus(SlotStatus status) {
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

  String _labelForStatus(SlotStatus status) {
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
}

class PatientReservationScreen extends StatefulWidget {
  const PatientReservationScreen({super.key, AppMode? mode});

  @override
  State<PatientReservationScreen> createState() =>
      _PatientReservationScreenState();
}

class _PatientReservationScreenState extends State<PatientReservationScreen> {
  final _formKey = GlobalKey<FormState>();
  int? selectedSlot;

  final nameCtrl = TextEditingController();
  final pidCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  @override
  void dispose() {
    nameCtrl.dispose();
    pidCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rezervácia termínu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.read<AppState>().setMode(null),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vyberte číslo (od 5 vyššie)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildSlotSelector(),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Meno a priezvisko',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Povinné pole' : null,
              ),
              TextFormField(
                controller: pidCtrl,
                decoration: const InputDecoration(
                  labelText: 'Rodné číslo',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Povinné pole' : null,
              ),
              TextFormField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Poznámka pre lekára',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Rezervovať'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotSelector() {
    final appState = context.watch<AppState>();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(appState.slots.length, (i) {
        final slotNumber = i + 1;

        // 🔒 pacient môže iba 5+
        if (slotNumber < 5) return const SizedBox.shrink();

        if (appState.slots[i].status != SlotStatus.free) {
          return const SizedBox.shrink();
        }

        return ChoiceChip(
          label: Text(slotNumber.toString()),
          selected: selectedSlot == slotNumber,
          onSelected: (_) {
            setState(() => selectedSlot = slotNumber);
          },
        );
      }),
    );
  }

  void _submit() {
    if (selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vyberte číslo')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final index = selectedSlot! - 1;
    final app = context.read<AppState>();

    final current = app.slots[index];

    if (current.status != SlotStatus.free) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slot už nie je voľný')),
      );
      return;
    }

    // ✅ POSIELAME CELÝ SLOT
    app.updateSlot(
      index,
      QueueSlot(
        status: SlotStatus.reserved,
        name: nameCtrl.text.trim(),
        personalId: pidCtrl.text.trim(),
        note: noteCtrl.text.trim(),
      ),
    );

    // návrat do menu
    app.setMode(null);
  }
}

class WaitingRoomSelectionScreen extends StatelessWidget {
  const WaitingRoomSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vyber poradia'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.read<AppState>().setMode(null),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: appState.slots.length,
        itemBuilder: (context, i) {
          final num = i + 1;
          final isVisible =
              num <= 8 || appState.slots[i].status == SlotStatus.free;

          if (!isVisible) return const SizedBox.shrink();

          return ElevatedButton(
            onPressed: appState.slots[i].status == SlotStatus.free
                ? () {
                    // rezervácia bez osobných údajov
                  }
                : null,
            child: Text(num.toString(), style: const TextStyle(fontSize: 32)),
          );
        },
      ),
    );
  }
}

class DoctorQueueScreen extends StatelessWidget {
  const DoctorQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lekár – poradie'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.read<AppState>().setMode(null),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: appState.slots.length,
        itemBuilder: (context, index) {
          final slot = appState.slots[index];

          return GestureDetector(
            onTap: () => _showActions(context, index),
            child: SlotTile(
              number: index + 1,
              slot: slot, // ✅ celé QueueSlot
            ),
          );
        },
      ),
    );
  }

  void _showActions(BuildContext context, int index) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        final slot = context.read<AppState>().slots[index];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pacient', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(slot.name ?? '—'),
              Text(slot.personalId ?? ''),
              if (slot.note != null && slot.note!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Poznámka: ${slot.note}'),
                ),
              const Divider(height: 24),
              _action(context, index, 'Vyšetruje sa', SlotStatus.active),
              _action(context, index, 'Neprítomný', SlotStatus.absent),
              _action(context, index, 'Hotovo', SlotStatus.done),
            ],
          ),
        );
      },
    );
  }

  Widget _action(
    BuildContext context,
    int index,
    String label,
    SlotStatus status,
  ) {
    return ListTile(
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        context.read<AppState>().setSlotStatus(index, status);
      },
    );
  }
}
