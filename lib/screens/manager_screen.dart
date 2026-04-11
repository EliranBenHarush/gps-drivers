import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/driver.dart';
import '../models/route_stop.dart';
import '../services/firestore_service.dart';
import '../services/mapbox_service.dart';

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  Driver? _selectedDriver;
  List<RouteStop> _stops = [];

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  List<Map<String, dynamic>> _suggestions = [];
  bool _searching = false;
  bool _saving = false;
  final _uuid = const Uuid();

  Timer? _debounce;
  int _searchId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ─── פעולות על כתובות ─────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() { _suggestions = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 200), () => _doSearch(query.trim()));
  }

  Future<void> _doSearch(String query) async {
    final id = ++_searchId;
    final results = await MapboxService.geocode(query);
    if (mounted && id == _searchId) {
      setState(() { _suggestions = results; _searching = false; });
    }
  }

  Future<void> _addStop(Map<String, dynamic> place) async {
    _debounce?.cancel();
    setState(() {
      _suggestions = [];
      _searchCtrl.clear();
      _searching = false;
    });
    _searchFocus.unfocus();

    final details = await _showStopDetailsDialog(
      title: 'פרטי עצירה',
      subtitle: place['name'] as String,
    );
    if (details == null) return;

    final stop = RouteStop(
      id: _uuid.v4(),
      address: place['name'] as String,
      lat: place['lat'] as double,
      lng: place['lng'] as double,
      order: _stops.length,
      phone1: details['phone1'] ?? '',
      phone2: details['phone2'] ?? '',
      balance: details['balance'] ?? '',
    );
    setState(() => _stops.add(stop));
  }

  void _removeStop(int index) {
    setState(() {
      _stops.removeAt(index);
      for (int i = 0; i < _stops.length; i++) {
        _stops[i] = _stops[i].copyWith(order: i);
      }
    });
  }

  void _reorderStop(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _stops.removeAt(oldIndex);
      _stops.insert(newIndex, item);
      for (int i = 0; i < _stops.length; i++) {
        _stops[i] = _stops[i].copyWith(order: i);
      }
    });
  }

  Future<void> _editStop(int index) async {
    final stop = _stops[index];
    final details = await _showStopDetailsDialog(
      title: 'עריכת פרטים',
      subtitle: stop.address,
      initial: {
        'phone1': stop.phone1,
        'phone2': stop.phone2,
        'balance': stop.balance,
      },
    );
    if (details == null) return;
    setState(() {
      _stops[index] = stop.copyWith(
        phone1: details['phone1'],
        phone2: details['phone2'],
        balance: details['balance'],
      );
    });
  }

  Future<Map<String, String>?> _showStopDetailsDialog({
    required String title,
    String? subtitle,
    Map<String, String>? initial,
  }) async {
    final phone1Ctrl = TextEditingController(text: initial?['phone1'] ?? '');
    final phone2Ctrl = TextEditingController(text: initial?['phone2'] ?? '');
    final balanceCtrl = TextEditingController(text: initial?['balance'] ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (subtitle != null)
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailField(phone1Ctrl, 'טלפון 1', Icons.phone, TextInputType.phone),
                const SizedBox(height: 12),
                _detailField(phone2Ctrl, 'טלפון 2', Icons.phone_android, TextInputType.phone),
                const SizedBox(height: 12),
                _detailField(balanceCtrl, 'יתרה לגבייה (₪)', Icons.attach_money, TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, {
                'phone1': phone1Ctrl.text.trim(),
                'phone2': phone2Ctrl.text.trim(),
                'balance': balanceCtrl.text.trim(),
              }),
              child: const Text('אישור'),
            ),
          ],
        ),
      ),
    );

    phone1Ctrl.dispose();
    phone2Ctrl.dispose();
    balanceCtrl.dispose();
    return result;
  }

  Widget _detailField(TextEditingController ctrl, String label, IconData icon,
      TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Future<void> _saveRoute() async {
    if (_selectedDriver == null) {
      _snack('בחר נהג תחילה', isError: true);
      return;
    }
    if (_stops.isEmpty) {
      _snack('הוסף לפחות כתובת אחת למסלול', isError: true);
      return;
    }
    setState(() => _saving = true);
    await FirestoreService.saveRoute(_selectedDriver!.id, _stops);
    if (mounted) {
      setState(() => _saving = false);
      _snack('המסלול נשמר בהצלחה!');
    }
  }

  Future<void> _clearRoute() async {
    if (_selectedDriver == null) return;
    final ok = await _confirm('נקה מסלול?', 'האם למחוק את כל עצירות הנהג?');
    if (!ok) return;
    await FirestoreService.clearRoute(_selectedDriver!.id);
    setState(() => _stops = []);
    _snack('המסלול נמחק');
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(title),
              content: Text(body),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('ביטול')),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('מחק', style: TextStyle(color: Colors.white))),
              ],
            ),
          ),
        ) ??
        false;
  }

  // ─── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('ניהול מסלולים'),
          centerTitle: true,
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            if (_stops.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'נקה מסלול',
                onPressed: _clearRoute,
              ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.save_rounded),
                tooltip: 'שמור מסלול',
                onPressed: _saveRoute,
              ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                _buildDriverSelector(),
                _buildSearchBar(),
                Expanded(child: _buildStopsList()),
              ],
            ),
            // Suggestions float above the list
            if (_suggestions.isNotEmpty || _searching)
              Positioned(
                top: 124,
                left: 16,
                right: 16,
                child: _buildSuggestions(),
              ),
          ],
        ),
        floatingActionButton: _stops.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _saveRoute,
                icon: const Icon(Icons.save_rounded),
                label: Text('שמור מסלול · ${_stops.length} עצירות'),
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              )
            : null,
      ),
    );
  }

  Widget _buildDriverSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: StreamBuilder<List<Driver>>(
        stream: FirestoreService.watchDrivers(),
        builder: (context, snapshot) {
          final drivers = snapshot.data ?? [];
          return Row(
            children: [
              const Icon(Icons.person, color: Color(0xFF1565C0), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<Driver>(
                  value: _selectedDriver != null &&
                          drivers.any((d) => d.id == _selectedDriver!.id)
                      ? drivers.firstWhere((d) => d.id == _selectedDriver!.id)
                      : null,
                  hint: const Text('בחר נהג'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  items: drivers
                      .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
                      .toList(),
                  onChanged: (d) async {
                    setState(() {
                      _selectedDriver = d;
                      _stops = [];
                    });
                    if (d != null) {
                      final existing = await FirestoreService.watchRoute(d.id).first;
                      if (mounted) setState(() => _stops = List.from(existing));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              _iconBtn(Icons.person_add_alt_1, 'הוסף נהג', _showAddDriverDialog),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        decoration: InputDecoration(
          hintText: 'חפש כתובת להוספה...',
          prefixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : const Icon(Icons.search),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _debounce?.cancel();
                    _searchCtrl.clear();
                    setState(() { _suggestions = []; _searching = false; });
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildSuggestions() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _searching && _suggestions.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('מחפש...'),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: _suggestions
                    .map((s) => InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _addStop(s),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, color: Color(0xFF1565C0), size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(s['name'] as String,
                                      style: const TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              ),
      ),
    );
  }

  Widget _buildStopsList() {
    if (_stops.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _selectedDriver == null
                  ? 'בחר נהג ותוסיף כתובות'
                  : 'חפש כתובת להוספה למסלול',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            'עצירות (${_stops.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            itemCount: _stops.length,
            onReorder: _reorderStop,
            itemBuilder: (ctx, i) {
              final stop = _stops[i];
              final hasDetails = stop.phone1.isNotEmpty ||
                  stop.phone2.isNotEmpty ||
                  stop.balance.isNotEmpty;
              return Card(
                key: ValueKey(stop.id),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: i == _stops.length - 1
                          ? Colors.red
                          : const Color(0xFF1565C0),
                      child: i == _stops.length - 1
                          ? const Icon(Icons.flag, color: Colors.white, size: 18)
                          : Text('${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(stop.address, style: const TextStyle(fontSize: 13)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (i == 0)
                          const Text('נקודת התחלה',
                              style: TextStyle(color: Color(0xFF2E7D32), fontSize: 11))
                        else if (i == _stops.length - 1)
                          const Text('נקודת סיום',
                              style: TextStyle(color: Colors.red, fontSize: 11)),
                        if (hasDetails)
                          Wrap(
                            spacing: 8,
                            children: [
                              if (stop.phone1.isNotEmpty)
                                _miniChip(Icons.phone, stop.phone1),
                              if (stop.phone2.isNotEmpty)
                                _miniChip(Icons.phone_android, stop.phone2),
                              if (stop.balance.isNotEmpty)
                                _miniChip(Icons.attach_money, '₪${stop.balance}',
                                    color: Colors.green),
                            ],
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: Color(0xFF1565C0), size: 20),
                          tooltip: 'ערוך פרטים',
                          onPressed: () => _editStop(i),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          onPressed: () => _removeStop(i),
                        ),
                        const Icon(Icons.drag_handle, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _miniChip(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color ?? Colors.grey[600]),
        const SizedBox(width: 2),
        Text(text,
            style: TextStyle(fontSize: 11, color: color ?? Colors.grey[700])),
      ],
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: const Color(0xFF1565C0)),
        ),
      ),
    );
  }

  void _showAddDriverDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('הוסף נהג חדש'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'שם הנהג',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (_) => _submitAddDriver(ctrl, ctx),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ביטול')),
            ElevatedButton(
                onPressed: () => _submitAddDriver(ctrl, ctx),
                child: const Text('הוסף')),
          ],
        ),
      ),
    );
  }

  Future<void> _submitAddDriver(TextEditingController ctrl, BuildContext ctx) async {
    if (ctrl.text.trim().isEmpty) return;
    await FirestoreService.addDriver(ctrl.text.trim());
    if (ctx.mounted) Navigator.pop(ctx);
  }
}
