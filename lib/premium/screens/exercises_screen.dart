import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
enum _SortMode { recentlyEdited, az, difficulty }

class ExerciseItem {
  final String id;
  final String name;
  final String region;
  final String equipment;
  final String difficulty;
  final String steps;
  final String safety;

  final List<String> contraindications;
  final int painStopAt;

  final String videoUrl;
  final List<String> imageLinks;
  final List<String> cues;

  final bool isTemplate;

  final DateTime createdAt;
  final DateTime updatedAt;

  ExerciseItem({
    required this.id,
    required this.name,
    required this.region,
    required this.equipment,
    required this.difficulty,
    required this.steps,
    required this.safety,
    this.contraindications = const [],
    this.painStopAt = 6,
    this.videoUrl = '',
    this.imageLinks = const [],
    this.cues = const [],
    this.isTemplate = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ExerciseItem copyWith({
    String? id,
    String? name,
    String? region,
    String? equipment,
    String? difficulty,
    String? steps,
    String? safety,
    List<String>? contraindications,
    int? painStopAt,
    String? videoUrl,
    List<String>? imageLinks,
    List<String>? cues,
    bool? isTemplate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExerciseItem(
      id: id ?? this.id,
      name: name ?? this.name,
      region: region ?? this.region,
      equipment: equipment ?? this.equipment,
      difficulty: difficulty ?? this.difficulty,
      steps: steps ?? this.steps,
      safety: safety ?? this.safety,
      contraindications: contraindications ?? this.contraindications,
      painStopAt: painStopAt ?? this.painStopAt,
      videoUrl: videoUrl ?? this.videoUrl,
      imageLinks: imageLinks ?? this.imageLinks,
      cues: cues ?? this.cues,
      isTemplate: isTemplate ?? this.isTemplate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'region': region,
        'equipment': equipment,
        'difficulty': difficulty,
        'steps': steps,
        'safety': safety,
        'contraindications': contraindications,
        'painStopAt': painStopAt,
        'videoUrl': videoUrl,
        'imageLinks': imageLinks,
        'cues': cues,
        'isTemplate': isTemplate,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static ExerciseItem fromJson(Map<String, dynamic> j) {
    return ExerciseItem(
      id: j['id'] as String,
      name: (j['name'] ?? '') as String,
      region: (j['region'] ?? 'Full') as String,
      equipment: (j['equipment'] ?? 'Bodyweight') as String,
      difficulty: (j['difficulty'] ?? 'Easy') as String,
      steps: (j['steps'] ?? '') as String,
      safety: (j['safety'] ?? '') as String,
      contraindications:
          (j['contraindications'] as List?)?.map((x) => '$x').toList() ??
              const [],
      painStopAt: (j['painStopAt'] as num?)?.toInt() ?? 6,
      videoUrl: (j['videoUrl'] ?? '') as String,
      imageLinks:
          (j['imageLinks'] as List?)?.map((x) => '$x').toList() ?? const [],
      cues: (j['cues'] as List?)?.map((x) => '$x').toList() ?? const [],
      isTemplate: (j['isTemplate'] as bool?) ?? false,
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((j['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}

class ExerciseAssignment {
  final String id;
  final String exerciseId;
  final String clientName;

  final int sets;
  final int reps;
  final String frequency;
  final int restSeconds;
  final String notes;

  final DateTime? startDate;
  final DateTime? endDate;

  final DateTime createdAt;
  final DateTime updatedAt;

  ExerciseAssignment({
    required this.id,
    required this.exerciseId,
    required this.clientName,
    required this.sets,
    required this.reps,
    required this.frequency,
    required this.restSeconds,
    required this.notes,
    this.startDate,
    this.endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ExerciseAssignment copyWith({
    String? id,
    String? exerciseId,
    String? clientName,
    int? sets,
    int? reps,
    String? frequency,
    int? restSeconds,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExerciseAssignment(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      clientName: clientName ?? this.clientName,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      frequency: frequency ?? this.frequency,
      restSeconds: restSeconds ?? this.restSeconds,
      notes: notes ?? this.notes,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'exerciseId': exerciseId,
        'clientName': clientName,
        'sets': sets,
        'reps': reps,
        'frequency': frequency,
        'restSeconds': restSeconds,
        'notes': notes,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static ExerciseAssignment fromJson(Map<String, dynamic> j) {
    DateTime? d(String? s) =>
        (s == null || s.trim().isEmpty) ? null : DateTime.tryParse(s);
    return ExerciseAssignment(
      id: j['id'] as String,
      exerciseId: (j['exerciseId'] ?? '') as String,
      clientName: (j['clientName'] ?? '') as String,
      sets: (j['sets'] as num?)?.toInt() ?? 3,
      reps: (j['reps'] as num?)?.toInt() ?? 10,
      frequency: (j['frequency'] ?? '3x/week') as String,
      restSeconds: (j['restSeconds'] as num?)?.toInt() ?? 60,
      notes: (j['notes'] ?? '') as String,
      startDate: d(j['startDate']?.toString()),
      endDate: d(j['endDate']?.toString()),
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((j['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();
}

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen>
    with SingleTickerProviderStateMixin {
  static const _kExercises = 'premium_exercises_items_v3';
  static const _kFavs = 'premium_exercises_favs_v3';
  static const _kRecent = 'premium_exercises_recent_v3';
  static const _kAssignments = 'premium_exercises_assignments_v3';

  // Sticky UX keys
  static const _kUiTab = 'premium_exercises_ui_tab';
  static const _kUiSearch = 'premium_exercises_ui_search';
  static const _kUiRegion = 'premium_exercises_ui_filter_region';
  static const _kUiDiff = 'premium_exercises_ui_filter_difficulty';
  static const _kUiEquip = 'premium_exercises_ui_filter_equipment';
  static const _kUiSort = 'premium_exercises_ui_sort';

  final TextEditingController _search = TextEditingController();

  late final TabController _tabs;

  bool _loading = true;

  final List<String> _regions = const [
    'Full',
    'Upper',
    'Lower',
    'Core',
    'Shoulder',
    'Knee',
    'Hip',
    'Back',
    'Neck'
  ];
  final List<String> _difficulties = const ['Easy', 'Medium', 'Hard'];
  final List<String> _equipment = const [
    'Bodyweight',
    'Band',
    'Dumbbell',
    'Barbell',
    'Machine',
    'Ball',
    'Other'
  ];
  final List<String> _contraList = const [
    'Acute fracture',
    'Post-op (early)',
    'Severe pain',
    'Nerve symptoms',
    'Dizziness/vertigo',
    'Uncontrolled BP',
    'Pregnancy caution',
  ];

  String? _filterRegion;
  String? _filterDifficulty;
  String? _filterEquipment;
  _SortMode _sort = _SortMode.recentlyEdited;

  final List<ExerciseItem> _items = <ExerciseItem>[];
  final Set<String> _favIds = <String>{};
  final List<String> _recentIds = <String>[];

  final List<ExerciseAssignment> _assignments = <ExerciseAssignment>[];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();

    // Sticky UI
    final tab = prefs.getInt(_kUiTab) ?? 0;
    _tabs.index = tab.clamp(0, 1);
    _search.text = prefs.getString(_kUiSearch) ?? '';
    _filterRegion = prefs.getString(_kUiRegion);
    _filterDifficulty = prefs.getString(_kUiDiff);
    _filterEquipment = prefs.getString(_kUiEquip);
    final sortIdx = prefs.getInt(_kUiSort) ?? 0;
    _sort = _SortMode.values[sortIdx.clamp(0, _SortMode.values.length - 1)];

    // Data
    final rawItems = prefs.getString(_kExercises);
    final rawFavs = prefs.getStringList(_kFavs) ?? const <String>[];
    final rawRecent = prefs.getStringList(_kRecent) ?? const <String>[];
    final rawAssign = prefs.getString(_kAssignments);

    _favIds
      ..clear()
      ..addAll(rawFavs);
    _recentIds
      ..clear()
      ..addAll(rawRecent);

    _items.clear();
    if (rawItems != null && rawItems.trim().isNotEmpty) {
      final list = (jsonDecode(rawItems) as List).cast<dynamic>();
      for (final x in list) {
        if (x is Map) {
          _items.add(ExerciseItem.fromJson(Map<String, dynamic>.from(x)));
        }
      }
    } else {
      // First run: seed a few templates as real items (premium feel)
      _items.addAll(_seedDefaults());
    }

    _assignments.clear();
    if (rawAssign != null && rawAssign.trim().isNotEmpty) {
      final list = (jsonDecode(rawAssign) as List).cast<dynamic>();
      for (final x in list) {
        if (x is Map) {
          _assignments
              .add(ExerciseAssignment.fromJson(Map<String, dynamic>.from(x)));
        }
      }
    }

    // persist seed if we added
    await _save();

    setState(() => _loading = false);

    // keep sticky tab updated
    _tabs.addListener(() async {
      if (_tabs.indexIsChanging) return;
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kUiTab, _tabs.index);
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    // sticky UI
    await prefs.setInt(_kUiTab, _tabs.index);
    await prefs.setString(_kUiSearch, _search.text);
    if (_filterRegion == null) {
      await prefs.remove(_kUiRegion);
    } else {
      await prefs.setString(_kUiRegion, _filterRegion!);
    }
    if (_filterDifficulty == null) {
      await prefs.remove(_kUiDiff);
    } else {
      await prefs.setString(_kUiDiff, _filterDifficulty!);
    }
    if (_filterEquipment == null) {
      await prefs.remove(_kUiEquip);
    } else {
      await prefs.setString(_kUiEquip, _filterEquipment!);
    }
    await prefs.setInt(_kUiSort, _sort.index);

    // data
    final itemsJson = jsonEncode(_items.map((e) => e.toJson()).toList());
    final aJson = jsonEncode(_assignments.map((a) => a.toJson()).toList());

    await prefs.setString(_kExercises, itemsJson);
    await prefs.setStringList(_kFavs, _favIds.toList());
    await prefs.setStringList(_kRecent, _recentIds);
    await prefs.setString(_kAssignments, aJson);
  }

  List<ExerciseItem> _seedDefaults() {
    final now = DateTime.now();
    return [
      ExerciseItem(
        id: ExerciseItem._newId(),
        name: 'Wall Sit',
        region: 'Lower',
        equipment: 'Bodyweight',
        difficulty: 'Easy',
        steps:
            'Back against wall. Slide down to 6090 knees. Hold. Keep knees tracking over toes.',
        safety: 'Stop if knee pain increases. Avoid deep angles early rehab.',
        contraindications: const ['Acute fracture', 'Severe pain'],
        painStopAt: 6,
        cues: const [
          'Neutral spine',
          'Even weight both feet',
          'Breathe (no breath-holding)'
        ],
        createdAt: now,
        updatedAt: now,
      ),
      ExerciseItem(
        id: ExerciseItem._newId(),
        name: 'Band Row (Seated)',
        region: 'Upper',
        equipment: 'Band',
        difficulty: 'Easy',
        steps:
            'Band around feet. Sit tall. Pull elbows back, squeeze shoulder blades, slow return.',
        safety: 'Avoid shoulder pinch. Keep neck relaxed.',
        contraindications: const ['Nerve symptoms', 'Severe pain'],
        painStopAt: 6,
        videoUrl: '',
        cues: const [
          'Elbows close to ribs',
          'No shrugging',
          'Control the return'
        ],
        createdAt: now,
        updatedAt: now,
      ),
      ExerciseItem(
        id: ExerciseItem._newId(),
        name: 'Dead Bug (Core)',
        region: 'Core',
        equipment: 'Bodyweight',
        difficulty: 'Medium',
        steps:
            'On back, brace core. Lower opposite arm/leg without arching. Return and alternate.',
        safety: 'Stop if back pain increases. Reduce range if needed.',
        contraindications: const ['Severe pain'],
        painStopAt: 5,
        cues: const [
          'Ribs down',
          'Slow tempo',
          'Small range beats sloppy range'
        ],
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  List<ExerciseItem> _templates() {
    // keep templates separate from items (picker adds copies)
    return [
      ExerciseItem(
        id: 't1',
        name: 'Glute Bridge',
        region: 'Hip',
        equipment: 'Bodyweight',
        difficulty: 'Easy',
        steps:
            'Feet flat. Drive through heels. Lift hips to neutral. Pause. Lower slowly.',
        safety: 'Avoid arching. Stop if hamstring crampsshorten range.',
        contraindications: const ['Severe pain', 'Post-op (early)'],
        painStopAt: 6,
        cues: const [
          'Brace core',
          'Squeeze glutes at top',
          'Knees track over toes'
        ],
        isTemplate: true,
      ),
      ExerciseItem(
        id: 't2',
        name: 'Calf Raise',
        region: 'Lower',
        equipment: 'Bodyweight',
        difficulty: 'Easy',
        steps: 'Stand tall. Rise onto toes. Pause. Lower under control.',
        safety: 'Hold support if balance limited.',
        contraindications: const ['Acute fracture', 'Severe pain'],
        painStopAt: 6,
        cues: const ['Slow down phase', 'Full range if pain-free'],
        isTemplate: true,
      ),
      ExerciseItem(
        id: 't3',
        name: 'Shoulder External Rotation (Band)',
        region: 'Shoulder',
        equipment: 'Band',
        difficulty: 'Medium',
        steps: 'Elbow at side 90. Rotate outward against band. Slow return.',
        safety: 'Avoid pain pinch. Keep wrist neutral.',
        contraindications: const ['Severe pain', 'Nerve symptoms'],
        painStopAt: 5,
        cues: const ['Elbow glued to ribs', 'Small pain-free range first'],
        isTemplate: true,
      ),
    ];
  }

  List<ExerciseItem> get _filtered {
    final q = _search.text.trim().toLowerCase();
    final list = _items.where((e) {
      if (_filterRegion != null && e.region != _filterRegion) return false;
      if (_filterDifficulty != null && e.difficulty != _filterDifficulty)
        return false;
      if (_filterEquipment != null && e.equipment != _filterEquipment)
        return false;

      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) ||
          e.region.toLowerCase().contains(q) ||
          e.equipment.toLowerCase().contains(q);
    }).toList();

    switch (_sort) {
      case _SortMode.az:
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _SortMode.recentlyEdited:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case _SortMode.difficulty:
        int rank(String d) => d == 'Easy' ? 1 : (d == 'Medium' ? 2 : 3);
        list.sort((a, b) {
          final rd = rank(a.difficulty).compareTo(rank(b.difficulty));
          if (rd != 0) return rd;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
    }

    // keep favorites "float" without losing sort meaning too much
    list.sort((a, b) {
      final af = _favIds.contains(a.id) ? 0 : 1;
      final bf = _favIds.contains(b.id) ? 0 : 1;
      return af.compareTo(bf);
    });

    return list;
  }

  void _touchRecent(String id) {
    _recentIds.remove(id);
    _recentIds.insert(0, id);
    if (_recentIds.length > 20) _recentIds.removeRange(20, _recentIds.length);
  }

  Future<void> _toggleFav(ExerciseItem item) async {
    setState(() {
      if (_favIds.contains(item.id)) {
        _favIds.remove(item.id);
      } else {
        _favIds.add(item.id);
      }
    });
    await _save();
  }

  Future<void> _addOrEditExercise({ExerciseItem? existing}) async {
    final result = await showDialog<ExerciseItem>(
      context: context,
      builder: (_) => _ExerciseEditorDialog(
        existing: existing,
        regions: _regions,
        difficulties: _difficulties,
        equipment: _equipment,
        contraList: _contraList,
      ),
    );

    if (result == null) return;

    setState(() {
      if (existing == null) {
        _items.insert(0, result.copyWith(isTemplate: false));
      } else {
        final i = _items.indexWhere((e) => e.id == existing.id);
        if (i >= 0) _items[i] = result.copyWith(isTemplate: false);
      }
    });

    await _save();
  }

  Future<void> _deleteExercise(ExerciseItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete exercise?'),
        content: Text(
            'This will delete "${item.name}". Assignments remain in Prescriptions (you can tidy them later).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (ok != true) return;

    setState(() {
      _items.removeWhere((e) => e.id == item.id);
      _favIds.remove(item.id);
      _recentIds.remove(item.id);
    });

    await _save();
  }

  Future<void> _importTemplates() async {
    final imported = await showDialog<List<ExerciseItem>>(
      context: context,
      builder: (_) =>
          _TemplatePickerDialog(templates: _templates(), favIds: _favIds),
    );

    if (imported == null || imported.isEmpty) return;

    setState(() {
      // ensure unique ids per import
      for (final t in imported) {
        _items.insert(
          0,
          ExerciseItem(
            id: ExerciseItem._newId(),
            name: t.name,
            region: t.region,
            equipment: t.equipment,
            difficulty: t.difficulty,
            steps: t.steps,
            safety: t.safety,
            contraindications: List<String>.from(t.contraindications),
            painStopAt: t.painStopAt,
            videoUrl: t.videoUrl,
            imageLinks: List<String>.from(t.imageLinks),
            cues: List<String>.from(t.cues),
            isTemplate: false,
          ),
        );
      }
    });

    await _save();
  }

  Future<void> _assignToClient(ExerciseItem item) async {
    final a = await showDialog<ExerciseAssignment>(
      context: context,
      builder: (_) =>
          _AssignmentDialog(exerciseName: item.name, exerciseId: item.id),
    );
    if (a == null) return;

    setState(() {
      _assignments.insert(0, a);
    });

    await _save();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assigned "${item.name}" to ${a.clientName}')),
      );
      _tabs.animateTo(1);
    }
  }

  List<ExerciseAssignment> _assignmentsForExercise(String exerciseId) {
    final list = _assignments.where((a) => a.exerciseId == exerciseId).toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<ExerciseAssignment> get _sortedAssignments {
    final list = List<ExerciseAssignment>.from(_assignments);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<void> _deleteAssignment(ExerciseAssignment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete prescription?'),
        content: Text('Remove assignment for ${a.clientName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _assignments.removeWhere((x) => x.id == a.id));
    await _save();
  }

  Future<void> _launchUrl(String url) async {
    final u = Uri.tryParse(url.trim());
    if (u == null) return;
    if (!await launchUrl(u, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  Widget _chipRow() {
    Widget chip(String label, String? value, List<String> options,
        void Function(String? v) setFilter) {
      return PopupMenuButton<String?>(
        tooltip: 'Filter: $label',
        onSelected: (v) async {
          setState(() => setFilter(v));
          await _save();
        },
        itemBuilder: (_) => [
          PopupMenuItem<String?>(value: null, child: Text('All $label')),
          const PopupMenuDivider(),
          ...options
              .map((o) => PopupMenuItem<String?>(value: o, child: Text(o))),
        ],
        child: Chip(
          label: Text(value ?? label),
          avatar: Icon(
            value == null ? Icons.filter_alt_off : Icons.filter_alt,
            size: 18,
          ),
          onDeleted: value == null
              ? null
              : () async {
                  setState(() => setFilter(null));
                  await _save();
                },
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('Region', _filterRegion, _regions, (v) => _filterRegion = v),
        chip('Difficulty', _filterDifficulty, _difficulties,
            (v) => _filterDifficulty = v),
        chip('Equipment', _filterEquipment, _equipment,
            (v) => _filterEquipment = v),
        DropdownButtonHideUnderline(
          child: DropdownButton<_SortMode>(
            value: _sort,
            onChanged: (v) async {
              setState(() => _sort = v ?? _SortMode.recentlyEdited);
              await _save();
            },
            items: const [
              DropdownMenuItem(
                  value: _SortMode.recentlyEdited,
                  child: Text('Sort: Recently edited')),
              DropdownMenuItem(value: _SortMode.az, child: Text('Sort: AZ')),
              DropdownMenuItem(
                  value: _SortMode.difficulty, child: Text('Sort: Difficulty')),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercises'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Library', icon: Icon(Icons.fitness_center)),
            Tab(text: 'Prescriptions', icon: Icon(Icons.assignment_turned_in)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Import Templates',
            onPressed: _importTemplates,
            icon: const Icon(Icons.playlist_add),
          ),
          PopupMenuButton<String>(
            tooltip: 'Add',
            onSelected: (v) async {
              if (v == 'new') await _addOrEditExercise();
              if (v == 'template') await _importTemplates();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'new', child: Text('New exercise')),
              PopupMenuItem(
                  value: 'template', child: Text('Add from templates')),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.add_circle_outline),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                // LIBRARY TAB
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _search,
                        onChanged: (_) async => _save(),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Search (name / region / equipment)',
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () async {
                                    _search.clear();
                                    await _save();
                                  },
                                ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerLeft, child: _chipRow()),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _filtered.isEmpty
                            ? _EmptyState(
                                onAdd: _addOrEditExercise,
                                onTemplates: _importTemplates,
                              )
                            : ListView.separated(
                                itemCount: _filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final e = _filtered[i];
                                  final fav = _favIds.contains(e.id);
                                  final recentRank = _recentIds.indexOf(e.id);
                                  final isRecent =
                                      recentRank >= 0 && recentRank < 5;

                                  return Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                          color: theme.dividerColor
                                              .withOpacity(0.5)),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              e.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                          if (isRecent)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                color: theme.colorScheme.primary
                                                    .withOpacity(0.12),
                                              ),
                                              child: const Text('Recent',
                                                  style:
                                                      TextStyle(fontSize: 12)),
                                            ),
                                        ],
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            Chip(label: Text(e.region)),
                                            Chip(label: Text(e.difficulty)),
                                            Chip(label: Text(e.equipment)),
                                            if (_assignmentsForExercise(e.id)
                                                .isNotEmpty)
                                              Chip(
                                                label: Text(
                                                    'Assigned x${_assignmentsForExercise(e.id).length}'),
                                                avatar: const Icon(
                                                    Icons.assignment_turned_in,
                                                    size: 18),
                                              ),
                                          ],
                                        ),
                                      ),
                                      leading: IconButton(
                                        tooltip:
                                            fav ? 'Unfavorite' : 'Favorite',
                                        onPressed: () => _toggleFav(e),
                                        icon: Icon(fav
                                            ? Icons.star
                                            : Icons.star_border),
                                      ),
                                      trailing: PopupMenuButton<String>(
                                        onSelected: (v) async {
                                          if (v == 'open') {
                                            _touchRecent(e.id);
                                            await _save();
                                            if (mounted) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      _ExerciseDetail(
                                                    item: e,
                                                    isFav:
                                                        _favIds.contains(e.id),
                                                    assignments:
                                                        _assignmentsForExercise(
                                                            e.id),
                                                    onToggleFav: () =>
                                                        _toggleFav(e),
                                                    onEdit: () =>
                                                        _addOrEditExercise(
                                                            existing: e),
                                                    onDelete: () =>
                                                        _deleteExercise(e),
                                                    onAssign: () =>
                                                        _assignToClient(e),
                                                    onOpenUrl: _launchUrl,
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                          if (v == 'edit')
                                            await _addOrEditExercise(
                                                existing: e);
                                          if (v == 'assign')
                                            await _assignToClient(e);
                                          if (v == 'delete')
                                            await _deleteExercise(e);
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                              value: 'open',
                                              child: Text('Open')),
                                          PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Edit')),
                                          PopupMenuItem(
                                              value: 'assign',
                                              child: Text('Assign to client')),
                                          PopupMenuDivider(),
                                          PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete')),
                                        ],
                                      ),
                                      onTap: () async {
                                        _touchRecent(e.id);
                                        await _save();
                                        if (!mounted) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => _ExerciseDetail(
                                              item: e,
                                              isFav: _favIds.contains(e.id),
                                              assignments:
                                                  _assignmentsForExercise(e.id),
                                              onToggleFav: () => _toggleFav(e),
                                              onEdit: () => _addOrEditExercise(
                                                  existing: e),
                                              onDelete: () =>
                                                  _deleteExercise(e),
                                              onAssign: () =>
                                                  _assignToClient(e),
                                              onOpenUrl: _launchUrl,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),

                // PRESCRIPTIONS TAB
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _sortedAssignments.isEmpty
                      ? const Center(
                          child: Text(
                            'No prescriptions yet.\nAssign an exercise to a client from the Library tab.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          itemCount: _sortedAssignments.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final a = _sortedAssignments[i];
                            final ex = _items.firstWhere(
                              (e) => e.id == a.exerciseId,
                              orElse: () => ExerciseItem(
                                id: a.exerciseId,
                                name: '(Deleted exercise)',
                                region: 'Full',
                                equipment: 'Other',
                                difficulty: 'Easy',
                                steps: '',
                                safety: '',
                              ),
                            );

                            String dateRange() {
                              if (a.startDate == null && a.endDate == null)
                                return 'No dates';
                              final s = a.startDate == null
                                  ? '?'
                                  : _fmtDate(a.startDate!);
                              final e = a.endDate == null
                                  ? '?'
                                  : _fmtDate(a.endDate!);
                              return '$s  $e';
                            }

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                    color: Theme.of(context)
                                        .dividerColor
                                        .withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                title: Text('${a.clientName}    ${ex.name}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          '${a.sets} sets x ${a.reps} reps    ${a.frequency}    rest ${a.restSeconds}s'),
                                      const SizedBox(height: 6),
                                      Text('Dates: ${dateRange()}'),
                                      if (a.notes.trim().isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text('Notes: ${a.notes}'),
                                      ],
                                    ],
                                  ),
                                ),
                                trailing: IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deleteAssignment(a),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: const _ExercisesFooter(),
    );
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

class _ExercisesFooter extends StatelessWidget {
  const _ExercisesFooter();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Text(
          'Disclaimer: Educational guidance only. Stop if symptoms worsen and consult a clinician.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function({ExerciseItem? existing}) onAdd;
  final Future<void> Function() onTemplates;

  const _EmptyState({required this.onAdd, required this.onTemplates});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center, size: 52),
            const SizedBox(height: 12),
            const Text('No exercises found.'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => onAdd(),
                  icon: const Icon(Icons.add),
                  label: const Text('Create exercise'),
                ),
                OutlinedButton.icon(
                  onPressed: onTemplates,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Add from templates'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseDetail extends StatelessWidget {
  final ExerciseItem item;
  final bool isFav;
  final List<ExerciseAssignment> assignments;

  final VoidCallback onToggleFav;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAssign;
  final Future<void> Function(String url) onOpenUrl;

  const _ExerciseDetail({
    required this.item,
    required this.isFav,
    required this.assignments,
    required this.onToggleFav,
    required this.onEdit,
    required this.onDelete,
    required this.onAssign,
    required this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget sectionTitle(String t) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          IconButton(
            tooltip: isFav ? 'Unfavorite' : 'Favorite',
            onPressed: onToggleFav,
            icon: Icon(isFav ? Icons.star : Icons.star_border),
          ),
          IconButton(
              onPressed: onAssign, icon: const Icon(Icons.assignment_add)),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit)),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(item.region)),
                Chip(label: Text(item.difficulty)),
                Chip(label: Text(item.equipment)),
                Chip(label: Text('Stop if pain > ${item.painStopAt}/10')),
              ],
            ),
            if (item.videoUrl.trim().isNotEmpty) ...[
              sectionTitle('Video'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_circle_outline),
                title: Text(item.videoUrl),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => onOpenUrl(item.videoUrl),
              ),
            ],
                        if (item.imageLinks.isNotEmpty) ...[
              sectionTitle('Images'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: item.imageLinks.map((p) {
                  final isHttp = p.trim().toLowerCase().startsWith('http');
                  if (isHttp) {
                    return SizedBox(
                      width: 180,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: const [
                              Icon(Icons.link),
                              SizedBox(width: 8),
                              Expanded(child: Text('Link', overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final file = File(p);
                  if (!file.existsSync()) {
                    return SizedBox(
                      width: 180,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: const [
                              Icon(Icons.broken_image_outlined),
                              SizedBox(width: 8),
                              Expanded(child: Text('Missing file', overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 220,
                      height: 140,
                      child: Image.file(file, fit: BoxFit.cover),
                    ),
                  );
                }).toList(),
              ),
            ],
            sectionTitle('Key Coaching Cues'),
            if (item.cues.isEmpty)
              Text('',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.hintColor))
            else
              ...item.cues.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('  '),
                        Expanded(child: Text(c)),
                      ],
                    ),
                  )),
            sectionTitle('Steps / Coaching'),
            SelectableText(item.steps),
            sectionTitle('Safety Notes'),
            SelectableText(item.safety),
            sectionTitle('Contraindications'),
            if (item.contraindications.isEmpty)
              Text('None listed',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.hintColor))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: item.contraindications
                    .map((c) => Chip(label: Text(c)))
                    .toList(),
              ),
            if (assignments.isNotEmpty) ...[
              sectionTitle('Assignments'),
              ...assignments.map((a) {
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side:
                        BorderSide(color: theme.dividerColor.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    title: Text(a.clientName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${a.sets}x${a.reps}  ${a.frequency}  rest ${a.restSeconds}s\n${a.notes}'
                            .trim()),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExerciseEditorDialog extends StatefulWidget {
  final ExerciseItem? existing;
  final List<String> regions;
  final List<String> difficulties;
  final List<String> equipment;
  final List<String> contraList;

  const _ExerciseEditorDialog({
    required this.existing,
    required this.regions,
    required this.difficulties,
    required this.equipment,
    required this.contraList,
  });

  @override
  State<_ExerciseEditorDialog> createState() => _ExerciseEditorDialogState();
}

class _ExerciseEditorDialogState extends State<_ExerciseEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _steps;
  late final TextEditingController _safety;
  late final TextEditingController _video;
  late final TextEditingController _images;
  late final TextEditingController _cues;

  late String _region;
  late String _difficulty;
  late String _equipment;
  late int _painStopAt;

  final Set<String> _contra = <String>{};

  @override
  void initState() {
    super.initState();
    final e = widget.existing;

    _name = TextEditingController(text: e?.name ?? '');
    _steps = TextEditingController(text: e?.steps ?? '');
    _safety = TextEditingController(text: e?.safety ?? '');
    _video = TextEditingController(text: e?.videoUrl ?? '');
    _images =
        TextEditingController(text: (e?.imageLinks ?? const []).join('\n'));
    _cues = TextEditingController(text: (e?.cues ?? const []).join('\n'));

    _region = e?.region ?? widget.regions.first;
    _difficulty = e?.difficulty ?? widget.difficulties.first;
    _equipment = e?.equipment ?? widget.equipment.first;
    _painStopAt = e?.painStopAt ?? 6;

    _contra.addAll(e?.contraindications ?? const []);
  }

  @override
  void dispose() {
    _name.dispose();
    _steps.dispose();
    _safety.dispose();
    _video.dispose();
    _images.dispose();
    _cues.dispose();
    super.dispose();
  }

  
  Future<Directory> _ensureMediaDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('\\\SimonPhysio\\media\\exercises');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _pickAndAddImages() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (picked == null || picked.files.isEmpty) return;

    final dir = await _ensureMediaDir();

    final existing = _images.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    for (final f in picked.files) {
      final srcPath = f.path;
      if (srcPath == null || srcPath.trim().isEmpty) continue;

      final src = File(srcPath);
      if (!await src.exists()) continue;
      final safeName = "ex__";
      final dest = File('\\\$safeName');
      try {
        await src.copy(dest.path);
        existing.add(dest.path.replaceAll('\\\\', '/'));
      } catch (_) { }
    }

    _images.text = existing.join('\n');
    if (mounted) setState(() {});
  }


  /// GF_MEDIA_V15_START
  Future<void> _pickVideoLocal() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['mp4','mov','mkv','avi','webm'],
    );
    if (picked == null || picked.files.isEmpty) return;

    final f = picked.files.first;
    final srcPath = f.path;
    if (srcPath == null || srcPath.trim().isEmpty) return;

    final src = File(srcPath);
    if (!await src.exists()) return;

    // Your project uses _ensureMediaDir() with NO args (from backup)
    final baseDir = await _ensureMediaDir();

    // Make sure videos subfolder exists
    final videosDir = Directory('\\videos');
    if (!await videosDir.exists()) {
      await videosDir.create(recursive: true);
    }

    final safeName = "vid__";
    final dest = File('\\' + safeName);

    try {
      await src.copy(dest.path);
      _video.text = dest.path.replaceAll('\\', '/');
      if (mounted) setState(() {});
    } catch (_) {}
  }
  Future<void> _openPathExternal(String p) async {
    final path = p.trim();
    if (path.isEmpty) return;

    if (path.toLowerCase().startsWith('http')) {
      await launchUrl(Uri.parse(path), mode: LaunchMode.externalApplication);
      return;
    }

    final f = File(path);
    if (!f.existsSync()) return;
    await launchUrl(Uri.file(f.path), mode: LaunchMode.externalApplication);
  }
  /// GF_MEDIA_V15_END
@override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit exercise' : 'New exercise'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _dd('Region', _region, widget.regions,
                        (v) => setState(() => _region = v)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dd('Difficulty', _difficulty, widget.difficulties,
                        (v) => setState(() => _difficulty = v)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dd('Equipment', _equipment, widget.equipment,
                        (v) => setState(() => _equipment = v)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _steps,
                maxLines: 6,
                decoration: const InputDecoration(
                    labelText: 'Steps / Coaching',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _safety,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Safety notes', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Stop if pain > $_painStopAt/10',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Slider(
                value: _painStopAt.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                label: '$_painStopAt',
                onChanged: (v) => setState(() => _painStopAt = v.round()),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Contraindications (checklist)',
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: widget.contraList.map((c) {
                  final on = _contra.contains(c);
                  return FilterChip(
                    label: Text(c),
                    selected: on,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _contra.add(c);
                      } else {
                        _contra.remove(c);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _video,
                decoration: const InputDecoration(
                  labelText: 'Video link (YouTube/Vimeo/etc.)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              
              // GF_BTN_PICK_VIDEO_V15
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickVideoLocal,
                      icon: const Icon(Icons.video_file_outlined),
                      label: const Text('Pick video (local)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickAndAddImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Add images (local)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _images,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Image links/paths (one per line)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cues,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Key coaching cues (one per line)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;

            final cues = _cues.text
                .split('\n')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList(growable: false);

            final images = _images.text
                .split('\n')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList(growable: false);

            final existing = widget.existing;

            final item = (existing == null)
                ? ExerciseItem(
                    id: ExerciseItem._newId(),
                    name: name,
                    region: _region,
                    equipment: _equipment,
                    difficulty: _difficulty,
                    steps: _steps.text.trim(),
                    safety: _safety.text.trim(),
                    contraindications: _contra.toList(),
                    painStopAt: _painStopAt,
                    videoUrl: _video.text.trim(),
                    imageLinks: images,
                    cues: cues,
                    isTemplate: false,
                  )
                : existing.copyWith(
                    name: name,
                    region: _region,
                    equipment: _equipment,
                    difficulty: _difficulty,
                    steps: _steps.text.trim(),
                    safety: _safety.text.trim(),
                    contraindications: _contra.toList(),
                    painStopAt: _painStopAt,
                    videoUrl: _video.text.trim(),
                    imageLinks: images,
                    cues: cues,
                    isTemplate: false,
                  );

            Navigator.pop(context, item);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _dd(String label, String value, List<String> items,
      void Function(String v) onChanged) {
    return InputDecorator(
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: (v) => onChanged(v ?? value),
        ),
      ),
    );
  }
}

class _TemplatePickerDialog extends StatefulWidget {
  final List<ExerciseItem> templates;
  final Set<String> favIds;

  const _TemplatePickerDialog({required this.templates, required this.favIds});

  @override
  State<_TemplatePickerDialog> createState() => _TemplatePickerDialogState();
}

class _TemplatePickerDialogState extends State<_TemplatePickerDialog> {
  final Set<String> _selected = <String>{};
  final TextEditingController _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _q.text.trim().toLowerCase();

    final list = widget.templates.where((t) {
      if (query.isEmpty) return true;
      return t.name.toLowerCase().contains(query) ||
          t.region.toLowerCase().contains(query) ||
          t.equipment.toLowerCase().contains(query);
    }).toList();

    return AlertDialog(
      title: const Text('Add from templates'),
      content: SizedBox(
        width: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search templates',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final t = list[i];
                  final picked = _selected.contains(t.id);
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color:
                              Theme.of(context).dividerColor.withOpacity(0.5)),
                    ),
                    child: CheckboxListTile(
                      value: picked,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(t.id);
                        } else {
                          _selected.remove(t.id);
                        }
                      }),
                      title: Text(t.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text(t.region)),
                          Chip(label: Text(t.difficulty)),
                          Chip(label: Text(t.equipment)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final chosen = widget.templates
                .where((t) => _selected.contains(t.id))
                .toList();
            Navigator.pop(context, chosen);
          },
          child: Text('Add (${_selected.length})'),
        ),
      ],
    );
  }
}

class _AssignmentDialog extends StatefulWidget {
  final String exerciseName;
  final String exerciseId;

  const _AssignmentDialog(
      {required this.exerciseName, required this.exerciseId});

  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  final TextEditingController _client = TextEditingController();
  final TextEditingController _frequency =
      TextEditingController(text: '3x/week');
  final TextEditingController _notes = TextEditingController();

  int _sets = 3;
  int _reps = 10;
  int _rest = 60;

  DateTime? _start;
  DateTime? _end;

  @override
  void dispose() {
    _client.dispose();
    _frequency.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final initial = start ? (_start ?? now) : (_end ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );

    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String fmt(DateTime? d) {
      if (d == null) return 'Select date';
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '$y-$m-$day';
    }

    return AlertDialog(
      title: Text('Assign: ${widget.exerciseName}'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _client,
                decoration: const InputDecoration(
                  labelText: 'Client name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _numBox(
                          'Sets', _sets, (v) => setState(() => _sets = v))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _numBox(
                          'Reps', _reps, (v) => setState(() => _reps = v))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _numBox('Rest (sec)', _rest,
                          (v) => setState(() => _rest = v))),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _frequency,
                decoration: const InputDecoration(
                  labelText: 'Frequency (e.g. 3x/week)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(start: true),
                      icon: const Icon(Icons.calendar_today),
                      label: Text('Start: ${fmt(_start)}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(start: false),
                      icon: const Icon(Icons.calendar_today),
                      label: Text('End: ${fmt(_end)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes (pain rules, regressions, form cues)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final client = _client.text.trim();
            if (client.isEmpty) return;

            final a = ExerciseAssignment(
              id: ExerciseAssignment.newId(),
              exerciseId: widget.exerciseId,
              clientName: client,
              sets: _sets,
              reps: _reps,
              frequency: _frequency.text.trim().isEmpty
                  ? '3x/week'
                  : _frequency.text.trim(),
              restSeconds: _rest,
              notes: _notes.text.trim(),
              startDate: _start,
              endDate: _end,
            );

            Navigator.pop(context, a);
          },
          child: const Text('Assign'),
        ),
      ],
    );
  }

  Widget _numBox(String label, int value, void Function(int v) onChanged) {
    return InputDecorator(
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      child: Row(
        children: [
          IconButton(
            onPressed: () => onChanged(value > 0 ? value - 1 : 0),
            icon: const Icon(Icons.remove),
          ),
          Expanded(
            child: Center(
              child: Text(
                '$value',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          IconButton(
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}







