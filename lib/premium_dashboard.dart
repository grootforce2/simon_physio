import 'package:flutter/material.dart';

class PremiumDashboard extends StatefulWidget {
  const PremiumDashboard({super.key});
  @override
  State<PremiumDashboard> createState() => _PremiumDashboardState();
}

class _PremiumDashboardState extends State<PremiumDashboard> {
  double pain = 2;
  int currentStep = 0;

  final List<_Exercise> plan = const [
    _Exercise("Warm up mobility", "3 min", Icons.self_improvement_rounded),
    _Exercise("Neck / shoulder release", "2 x 10 reps", Icons.accessibility_new_rounded),
    _Exercise("Thoracic opener", "2 x 8 reps", Icons.air_rounded),
    _Exercise("Core bracing", "3 x 20 sec", Icons.shield_rounded),
    _Exercise("Cool down breathing", "2 min", Icons.spa_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
  // ASSET_SMOKETEST_BANNER
  body: Column(
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 8, left: 12, right: 12),
        child: Row(
          children: const [
            SizedBox(
              width: 28,
              height: 28,
              child: Image(image: AssetImage('assets/images/app_icon.png')),
            ),
            SizedBox(width: 10),
            Text('Assets OK', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child:
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopBar(cs: cs),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _PlanCard(
                          cs: cs,
                          plan: plan,
                          currentIndex: currentStep,
                          onStart: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Session started")),
                            );
                          },
                          onSelect: (i) => setState(() => currentStep = i),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _SessionCard(
                              cs: cs,
                              current: plan[currentStep],
                              progress: (currentStep + 1) / plan.length,
                              onNext: () => setState(() => currentStep = (currentStep + 1).clamp(0, plan.length - 1)),
                              onBack: () => setState(() => currentStep = (currentStep - 1).clamp(0, plan.length - 1)),
                            ),
                            const SizedBox(height: 16),
                            _PainCard(
                              cs: cs,
                              value: pain,
                              onChanged: (v) => setState(() => pain = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BrandMark(cs: cs),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Simon Physio", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              SizedBox(height: 2),
              Text("Your plan for today", style: TextStyle(fontSize: 14, color: Colors.black54)),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: () {
                      // Auto-wired by SIMON_ONECLICK_AUTOFIX_BUTTONS_AND_BUILD.ps1
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coming soonÃƒÆ’¢Ãƒ¢Ã¢â‚¬Å¡¬¦')),
                      );
                    },
          icon: const Icon(Icons.settings_rounded, size: 18),
          label: const Text("Settings"),
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [cs.primary, cs.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(blurRadius: 18, offset: Offset(0, 10), color: Color(0x22000000)),
        ],
      ),
      child: const Icon(Icons.health_and_safety_rounded, color: Colors.white),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.cs,
    required this.plan,
    required this.currentIndex,
    required this.onStart,
    required this.onSelect,
  });

  final ColorScheme cs;
  final List<_Exercise> plan;
  final int currentIndex;
  final VoidCallback onStart;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Todays session", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text("Follow the steps. Keep it simple. Track pain honestly.",
                        style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text("Start session"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _Pill(label: "1215 min"),
              _Pill(label: "Mobility + Strength"),
              _Pill(label: "Low equipment"),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          ...List.generate(plan.length, (i) {
            final ex = plan[i];
            final selected = i == currentIndex;
            return InkWell(
              onTap: () => onSelect(i),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: selected ? cs.primaryContainer.withOpacity(0.55) : const Color(0xFFF7F8FC),
                  border: Border.all(color: selected ? cs.primary.withOpacity(0.35) : const Color(0x11000000)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: selected ? cs.primary : Colors.white,
                      ),
                      child: Icon(ex.icon, color: selected ? Colors.white : Colors.black87, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ex.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(ex.detail, style: const TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: selected ? cs.primary : Colors.black38),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.cs,
    required this.current,
    required this.progress,
    required this.onNext,
    required this.onBack,
  });

  final ColorScheme cs;
  final _Exercise current;
  final double progress;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Now playing", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [cs.primary.withOpacity(0.10), cs.primaryContainer.withOpacity(0.55)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: cs.primary.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: cs.primary,
                  ),
                  child: Icon(current.icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(current.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(current.detail, style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: progress, minHeight: 10),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text("Back"),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.skip_next_rounded),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text("Next step"),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PainCard extends StatelessWidget {
  const _PainCard({required this.cs, required this.value, required this.onChanged});
  final ColorScheme cs;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Pain check-in", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text("0 = none ÃƒÆ’Ã¢â‚¬Å¡· 10 = worst", style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text("0"),
              Expanded(
                child: Slider(
                  value: value,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: value.round().toString(),
                  onChanged: onChanged,
                ),
              ),
              const Text("10"),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: cs.primaryContainer.withOpacity(0.65),
                  border: Border.all(color: cs.primary.withOpacity(0.20)),
                ),
                child: Text("\/10", style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(blurRadius: 24, offset: Offset(0, 14), color: Color(0x14000000)),
        ],
        border: Border.all(color: const Color(0x11000000)),
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFFF2F4FA),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _Exercise {
  final String title;
  final String detail;
  final IconData icon;
  const _Exercise(this.title, this.detail, this.icon);
}

