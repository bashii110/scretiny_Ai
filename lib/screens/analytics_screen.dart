import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/app_color.dart';
import '../provider/analytics_provider.dart';


// ─────────────────────────────────────────────────────────────────────────────
// analytics_screen.dart
//
// Sections:
//   1. Range toggle (Week / Month)
//   2. Summary stats row (avg, best, worst, check-ins)
//   3. Stress trend line chart
//   4. Weekday average bar chart
//   5. Mood calendar (current month)
//   6. Sleep quality sparkline
//   7. Top triggers chips
// ─────────────────────────────────────────────────────────────────────────────

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(analyticsRangeProvider);
    final reportAsync = ref.watch(stressAnalyticsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App bar ──────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Analytics',
                    style: Theme.of(context).textTheme.titleLarge),
                Text('Your stress & wellness trends',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textLight)),
              ],
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Range Toggle ────────────────────────────────────────
                _RangeToggle(selected: range),
                const SizedBox(height: 20),

                // ── Content ─────────────────────────────────────────────
                reportAsync.when(
                  data: (report) => report.logs.isEmpty
                      ? const _EmptyState()
                      : _ReportBody(report: report, range: range),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(60),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text('Could not load analytics.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textLight)),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Range Toggle
// ─────────────────────────────────────────────────────────────────────────────

class _RangeToggle extends ConsumerWidget {
  final String selected;
  const _RangeToggle({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: ['week', 'month'].map((r) {
          final isSelected = r == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () =>
              ref.read(analyticsRangeProvider.notifier).state = r,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color:
                  isSelected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                    )
                  ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    r == 'week' ? 'This Week' : 'This Month',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textLight,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Report Body
// ─────────────────────────────────────────────────────────────────────────────

class _ReportBody extends ConsumerWidget {
  final StressAnalyticsReport report;
  final String range;
  const _ReportBody({required this.report, required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Summary stats ──────────────────────────────────────────────
        _SummaryRow(report: report),
        const SizedBox(height: 20),

        // ── Stress trend line chart ────────────────────────────────────
        _SectionTitle(
            title: range == 'week' ? '7-Day Stress Trend' : '30-Day Stress Trend'),
        const SizedBox(height: 12),
        _StressTrendChart(points: report.dailyPoints),
        const SizedBox(height: 24),

        // ── Weekday averages ───────────────────────────────────────────
        const _SectionTitle(title: 'Average by Day of Week'),
        const SizedBox(height: 12),
        _WeekdayBarChart(averages: report.weekdayAverages),
        const SizedBox(height: 24),

        // ── Mood calendar ──────────────────────────────────────────────
        const _SectionTitle(title: 'Mood Calendar'),
        const SizedBox(height: 12),
        const _MoodCalendar(),
        const SizedBox(height: 24),

        // ── Sleep quality ──────────────────────────────────────────────
        const _SectionTitle(title: 'Sleep Quality (14 days)'),
        const SizedBox(height: 12),
        const _SleepQualityChart(),
        const SizedBox(height: 24),

        // ── Top triggers ───────────────────────────────────────────────
        const _SectionTitle(title: 'Top Stress Triggers'),
        const SizedBox(height: 12),
        const _TopTriggers(),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Title
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: Theme.of(context).textTheme.titleMedium);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary Row
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final StressAnalyticsReport report;
  const _SummaryRow({required this.report});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Avg Stress',
            value: report.avgScore.toStringAsFixed(0),
            color: AppColors.stressColor(report.avgScore),
            icon: Icons.analytics_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Best Day',
            value: report.bestDay,
            color: AppColors.stressLow,
            icon: Icons.thumb_up_outlined,
            isText: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Worst Day',
            value: report.worstDay,
            color: AppColors.stressHigh,
            icon: Icons.thumb_down_outlined,
            isText: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Logs',
            value: '${report.totalCheckins}',
            color: AppColors.secondary,
            icon: Icons.checklist_rounded,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool isText;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.isText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: isText ? 11 : 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textLight),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stress Trend Line Chart
// ─────────────────────────────────────────────────────────────────────────────

class _StressTrendChart extends StatelessWidget {
  final List<DailyStressPoint> points;
  const _StressTrendChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return _ChartPlaceholder(message: 'No stress data yet');
    }

    final spots = points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.score);
    }).toList();

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.border,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 25,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.textLight),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (points.length / 5).ceilToDouble(),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i >= 0 && i < points.length) {
                    final d = points[i].date;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${d.day}/${d.month}',
                        style: const TextStyle(
                            fontSize: 9, color: AppColors.textLight),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppColors.primary,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) =>
                    FlDotCirclePainter(
                      radius: 3,
                      color: AppColors.stressColor(spot.y),
                      strokeWidth: 1.5,
                      strokeColor: Colors.white,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withOpacity(0.2),
                    AppColors.primary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekday Bar Chart
// ─────────────────────────────────────────────────────────────────────────────

class _WeekdayBarChart extends StatelessWidget {
  final Map<int, double> averages; // 1=Mon…7=Sun
  const _WeekdayBarChart({required this.averages});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    if (averages.isEmpty) {
      return _ChartPlaceholder(message: 'Not enough data yet');
    }

    final groups = List.generate(7, (i) {
      final weekday = i + 1;
      final score = averages[weekday] ?? 0;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: score,
            color: AppColors.stressColor(score),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 100,
              color: AppColors.border.withOpacity(0.5),
            ),
          ),
        ],
      );
    });

    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: BarChart(
        BarChartData(
          maxY: 100,
          barGroups: groups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.border,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _days[v.toInt()],
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textLight),
                  ),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 25,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.textLight),
                ),
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                rod.toY.toStringAsFixed(0),
                const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mood Calendar
// ─────────────────────────────────────────────────────────────────────────────

class _MoodCalendar extends ConsumerWidget {
  const _MoodCalendar();

  static const _moodEmoji = ['', '😫', '😔', '😐', '🙂', '😊'];
  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(moodCalendarProvider);
    final now = DateTime.now();
    final daysInMonth =
        DateTime(now.year, now.month + 1, 0).day;
    final firstWeekday =
        DateTime(now.year, now.month, 1).weekday; // 1=Mon

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_months[now.month]} ${now.year}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          // Day headers
          Row(
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          calendarAsync.when(
            data: (moodMap) => _CalendarGrid(
              daysInMonth: daysInMonth,
              firstWeekday: firstWeekday,
              moodMap: moodMap,
              today: now.day,
              moodEmoji: _moodEmoji,
            ),
            loading: () => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final int daysInMonth;
  final int firstWeekday;
  final Map<int, int> moodMap;
  final int today;
  final List<String> moodEmoji;

  const _CalendarGrid({
    required this.daysInMonth,
    required this.firstWeekday,
    required this.moodMap,
    required this.today,
    required this.moodEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final totalCells = daysInMonth + (firstWeekday - 1);
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          children: List.generate(7, (col) {
            final cellIndex = row * 7 + col;
            final day = cellIndex - (firstWeekday - 2);
            if (day < 1 || day > daysInMonth) {
              return const Expanded(child: SizedBox(height: 36));
            }
            final mood = moodMap[day];
            final isToday = day == today;

            return Expanded(
              child: Container(
                height: 36,
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: isToday
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isToday
                      ? Border.all(
                      color: AppColors.primary.withOpacity(0.4))
                      : null,
                ),
                child: Center(
                  child: mood != null
                      ? Text(moodEmoji[mood],
                      style: const TextStyle(fontSize: 18))
                      : Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 12,
                      color: isToday
                          ? AppColors.primary
                          : AppColors.textLight,
                      fontWeight: isToday
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sleep Quality Chart
// ─────────────────────────────────────────────────────────────────────────────

class _SleepQualityChart extends ConsumerWidget {
  const _SleepQualityChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleepAsync = ref.watch(sleepQualityHistoryProvider);

    return sleepAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return _ChartPlaceholder(message: 'No sleep data yet');
        }

        final spots = entries.asMap().entries.map((e) {
          return FlSpot(e.key.toDouble(), e.value.value.toDouble());
        }).toList();

        return Container(
          height: 140,
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: LineChart(
            LineChartData(
              minY: 1,
              maxY: 5,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: AppColors.border, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 24,
                    getTitlesWidget: (v, _) {
                      final label = switch (v) {
                        1.0 => '😫',
                        3.0 => '😐',
                        5.0 => '😊',
                        _   => '',
                      };
                      return Text(label, style: const TextStyle(fontSize: 12));
                    },
                  ),
                ),
                bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.secondary,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.secondary.withOpacity(0.2),
                        AppColors.secondary.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox(
          height: 140,
          child: Center(child: CircularProgressIndicator())),
      error: (_, __) => _ChartPlaceholder(message: 'Could not load sleep data'),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Triggers
// ─────────────────────────────────────────────────────────────────────────────

class _TopTriggers extends ConsumerWidget {
  const _TopTriggers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triggersAsync = ref.watch(topTriggersProvider);

    return triggersAsync.when(
      data: (triggers) {
        if (triggers.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text(
                'No triggers logged yet.\nAdd them during stress scans.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textLight, fontSize: 13),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: triggers.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.stressHigh.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.stressHigh.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.stressHigh.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.value}x',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.stressHigh,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('📊', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 20),
            Text('No data yet',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Complete check-ins and stress scans\nto see your analytics.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chart Placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _ChartPlaceholder extends StatelessWidget {
  final String message;
  const _ChartPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
              color: AppColors.textLight, fontSize: 13),
        ),
      ),
    );
  }
}