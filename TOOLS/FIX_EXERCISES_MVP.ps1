[CmdletBinding()]
param(
  [string]$Repo = "C:\SIMON\simon_physio"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Backup-File($p) {
  if (Test-Path $p) {
    $bak = "$p.bak_{0}" -f (Get-Date -Format "yyyyMMdd_HHmmss")
    Copy-Item $p $bak -Force
    Write-Host "[OK] Backup: $bak"
  }
}

function Write-Utf8($p, $content) {
  New-Item -ItemType Directory -Force -Path (Split-Path $p) | Out-Null
  Set-Content -Path $p -Value $content -Encoding UTF8
  Write-Host "[OK] Wrote: $p"
}

$exFile = Join-Path $Repo "lib\premium\screens\exercises_screen.dart"
Backup-File $exFile

# --- WORKING Exercises module (no dead taps) ---
$exDart = @"
import 'package:flutter/material.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class ExerciseItem {
  final String id;
  String name;
  String region;    // e.g., Upper, Lower, Core, Full
  String equipment; // e.g., None, Band, Dumbbell
  String difficulty; // Easy/Med/Hard
  String steps;
  String safety;

  ExerciseItem({
    required this.id,
    required this.name,
    required this.region,
    required this.equipment,
    required this.difficulty,
    required this.steps,
    required this.safety,
  });
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final TextEditingController _search = TextEditingController();

  String _region = "All";
  String _difficulty = "All";
  String _equipment = "All";

  final List<ExerciseItem> _items = [
    ExerciseItem(
      id: "ex_001",
      name: "Sit-to-Stand",
      region: "Lower",
      equipment: "None",
      difficulty: "Easy",
      steps: "1) Sit tall on a chair.\n2) Feet hip-width.\n3) Stand up slowly.\n4) Sit down with control.\nReps: 812.",
      safety: "Stop if sharp pain, dizziness, or knee giving-way. Use chair arms if needed.",
    ),
    ExerciseItem(
      id: "ex_002",
      name: "Wall Shoulder Slides",
      region: "Upper",
      equipment: "None",
      difficulty: "Easy",
      steps: "1) Back to wall.\n2) Elbows at 90.\n3) Slide arms up.\n4) Keep ribs down.\nReps: 810.",
      safety: "Avoid pinching. Reduce range if painful.",
    ),
    ExerciseItem(
      id: "ex_003",
      name: "Glute Bridge",
      region: "Core",
      equipment: "None",
      difficulty: "Med",
      steps: "1) Lie on back.\n2) Knees bent.\n3) Lift hips.\n4) Pause 1s.\nReps: 812.",
      safety: "No lumbar arching. Stop if back pain increases.",
    ),
  ];

  List<ExerciseItem> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _items.where((e) {
      final matchQ = q.isEmpty || e.name.toLowerCase().contains(q);
      final matchR = _region == "All" || e.region == _region;
      final matchD = _difficulty == "All" || e.difficulty == _difficulty;
      final matchE = _equipment == "All" || e.equipment == _equipment;
      return matchQ && matchR && matchD && matchE;
    }).toList();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openAddEdit({ExerciseItem? edit}) async {
    final name = TextEditingController(text: edit?.name ?? "");
    final steps = TextEditingController(text: edit?.steps ?? "");
    final safety = TextEditingController(text: edit?.safety ?? "");

    String region = edit?.region ?? "Lower";
    String difficulty = edit?.difficulty ?? "Easy";
    String equipment = edit?.equipment ?? "None";

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(edit == null ? "Add Exercise" : "Edit Exercise"),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: "Name"),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _drop("Region", region, ["Upper","Lower","Core","Full"], (v){ region=v; })),
                    const SizedBox(width: 12),
                    Expanded(child: _drop("Difficulty", difficulty, ["Easy","Med","Hard"], (v){ difficulty=v; })),
                  ],
                ),
                const SizedBox(height: 12),
                _drop("Equipment", equipment, ["None","Band","Dumbbell","Cable","Machine"], (v){ equipment=v; }),
                const SizedBox(height: 12),
                TextField(
                  controller: steps,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: "Steps / Coaching"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: safety,
                  minLines: 2,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: "Safety Notes"),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context,true),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (ok == true) {
      final n = name.text.trim();
      if (n.isEmpty) return;
      setState(() {
        if (edit == null) {
          final id = "ex_" + DateTime.now().millisecondsSinceEpoch.toString();
          _items.insert(0, ExerciseItem(
            id: id,
            name: n,
            region: region,
            equipment: equipment,
            difficulty: difficulty,
            steps: steps.text.trim(),
            safety: safety.text.trim(),
          ));
        } else {
          edit.name = n;
          edit.region = region;
          edit.equipment = equipment;
          edit.difficulty = difficulty;
          edit.steps = steps.text.trim();
          edit.safety = safety.text.trim();
        }
      });
    }
  }

  Widget _drop(String label, String value, List<String> items, void Function(String) onChange) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items.map((x)=>DropdownMenuItem(value:x, child: Text(x))).toList(),
      onChanged: (v){ if(v!=null) setState(()=>onChange(v)); },
    );
  }

  void _openDetail(ExerciseItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ExerciseDetail(
          item: item,
          onEdit: () => _openAddEdit(edit: item),
          onDelete: () {
            setState(()=> _items.removeWhere((x)=>x.id==item.id));
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Exercises"),
        actions: [
          IconButton(
            tooltip: "Add",
            onPressed: () => _openAddEdit(),
            icon: const Icon(Icons.add),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddEdit(),
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (_)=>setState((){}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: "Search exercises",
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    value: _region,
                    decoration: const InputDecoration(labelText: "Region"),
                    items: ["All","Upper","Lower","Core","Full"]
                        .map((x)=>DropdownMenuItem(value:x, child: Text(x))).toList(),
                    onChanged: (v){ if(v!=null) setState(()=>_region=v); },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    value: _difficulty,
                    decoration: const InputDecoration(labelText: "Difficulty"),
                    items: ["All","Easy","Med","Hard"]
                        .map((x)=>DropdownMenuItem(value:x, child: Text(x))).toList(),
                    onChanged: (v){ if(v!=null) setState(()=>_difficulty=v); },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    value: _equipment,
                    decoration: const InputDecoration(labelText: "Equipment"),
                    items: ["All","None","Band","Dumbbell","Cable","Machine"]
                        .map((x)=>DropdownMenuItem(value:x, child: Text(x))).toList(),
                    onChanged: (v){ if(v!=null) setState(()=>_equipment=v); },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text("No exercises match your filters."))
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final e = list[i];
                        return InkWell(
                          onTap: () => _openDetail(e),
                          borderRadius: BorderRadius.circular(12),
                          child: Card(
                            child: ListTile(
                              title: Text(e.name),
                              subtitle: Text("${e.region}  ${e.difficulty}  ${e.equipment}"),
                              trailing: IconButton(
                                tooltip: "Edit",
                                icon: const Icon(Icons.edit),
                                onPressed: () => _openAddEdit(edit: e),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseDetail extends StatelessWidget {
  final ExerciseItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExerciseDetail({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: [
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
              ],
            ),
            const SizedBox(height: 16),
            const Text("Steps / Coaching", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText(item.steps.isEmpty ? "" : item.steps),
            const SizedBox(height: 16),
            const Text("Safety Notes", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText(item.safety.isEmpty ? "" : item.safety),
            const SizedBox(height: 24),
            const Text(
              "Disclaimer: Educational guidance only. Stop if symptoms worsen and consult a clinician.",
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
"@

Write-Utf8 $exFile $exDart

# --- Patch premium shell/router to ensure Exercises uses the real screen ---
# We don't know your exact structure, so we do a safe, minimal replace:
# If your premium_shell_scaffold.dart references ExercisesScreen as Placeholder or missing import, we fix it.
$shell = Join-Path $Repo "lib\premium\widgets\premium_shell_scaffold.dart"
if (Test-Path $shell) {
  $raw = Get-Content $shell -Raw
  $changed = $false
  Backup-File $shell

  if ($raw -notmatch "exercises_screen\.dart") {
    # Insert import near top after other premium screen imports
    $raw = $raw -replace "(?m)^(import\s+['""][^'""]+['""];\s*)", "`$1"
    # Best-effort: add import after first import line
    $raw = $raw -replace "(?m)^(import\s+['""][^'""]+['""];\s*)", "`$1`r`nimport 'package:simon_physio/premium/screens/exercises_screen.dart';"
    $changed = $true
  }

  # Replace common placeholder patterns
  if ($raw -match "ExercisesScreen\(\)\s*=>\s*const\s+Placeholder") {
    $raw = $raw -replace "ExercisesScreen\(\)\s*=>\s*const\s+Placeholder\([^)]*\)\s*;?", "ExercisesScreen() => const ExercisesScreen();"
    $changed = $true
  }

  # If there is a widget list/tab list that uses Placeholder for Exercises, replace "const Placeholder()" with "const ExercisesScreen()"
  if ($raw -match "(?s)(Exercises|Exercise).*Placeholder\(" -or $raw -match "(?s)label:\s*['""]Exercises['""][\s\S]{0,300}Placeholder") {
    $raw = $raw -replace "(?s)(label:\s*['""]Exercises['""][\s\S]{0,300}?)(const\s+Placeholder\([^)]*\))", "`$1const ExercisesScreen()"
    $changed = $true
  }

  if ($changed) {
    Set-Content $shell $raw -Encoding UTF8
    Write-Host "[OK] Patched: $shell"
  } else {
    Write-Host "[INFO] Shell patch skipped (pattern not found). If Exercises still dead, well patch router file next."
  }
} else {
  Write-Host "[WARN] premium_shell_scaffold.dart not found at expected path: $shell"
}

Write-Host ""
Write-Host "NEXT:"
Write-Host "1) Build (Windows Release):"
Write-Host '   $flutter = "$env:USERPROFILE\.puro\envs\stable\flutter\bin\flutter.bat"'
Write-Host '   cd C:\SIMON\simon_physio'
Write-Host '   & $flutter build windows --release'
Write-Host ""
Write-Host "2) Copy to RUN_TEST and launch:"
Write-Host '   $release="C:\SIMON\simon_physio\build\windows\x64\runner\Release"'
Write-Host '   Remove-Item "C:\SIMON\RUN_TEST" -Recurse -Force -ErrorAction SilentlyContinue'
Write-Host '   New-Item -ItemType Directory -Force -Path "C:\SIMON\RUN_TEST" | Out-Null'
Write-Host '   robocopy $release "C:\SIMON\RUN_TEST" /E /NFL /NDL /NJH /NJS /NP | Out-Null'
Write-Host '   Start-Process "C:\SIMON\RUN_TEST\simon_physio.exe"'
