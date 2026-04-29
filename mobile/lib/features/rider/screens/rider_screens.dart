import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';

class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  Map<String, dynamic> _stats = {};
  List _recentActivity = [];
  Map<String, dynamic> _earningsData = {};
  List _goals = [];
  bool _loading = true;
  String _status = 'available';
  DateTime? _earningsFrom;
  DateTime? _earningsTo;
  List _earningsReport = [];
  bool _loadingEarningsReport = false;
  List _notifications = [];
  bool _loadingNotifications = false;
  List<FlSpot> _earningsChartData = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.get('/api/rider/dashboard'),
        ApiService.get('/api/rider/deliveries?status=recent&per_page=5'),
        ApiService.get('/api/rider/earnings'),
        ApiService.get('/api/account/profile'),
        ApiService.get('/api/notifications'),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0]['stats'] ?? {};
          _recentActivity = results[1]['deliveries'] ?? [];
          _earningsData = results[2] ?? {};
          _status = results[3]['user']?['status'] ?? 'available';
          _notifications = results[4]['notifications'] ?? [];
          _loading = false;
        });
        _calculateGoals();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _calculateGoals() {
    setState(() {
      final todayEarnings = (_earningsData['today_earnings'] ?? 0) as num;
      final targetEarnings = 500.0; // Daily target
      final deliveriesCompleted = _stats['today_deliveries'] ?? 0;
      final targetDeliveries = 20; // Daily target
      
      _goals = [
        {
          'title': 'Today\'s Earnings',
          'current': todayEarnings,
          'target': targetEarnings,
          'percentage': (todayEarnings / targetEarnings * 100).clamp(0.0, 100.0),
          'color': AppTheme.primary,
          'icon': Icons.wallet,
        },
        {
          'title': 'Deliveries Today',
          'current': deliveriesCompleted,
          'target': targetDeliveries,
          'percentage': (deliveriesCompleted / targetDeliveries * 100).clamp(0.0, 100.0),
          'color': AppTheme.success,
          'icon': Icons.check_circle,
        },
      ];
    });
  }

  Widget _buildEnhancedStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
    required String trend,
    bool isCompact = false,
  }) {
    double padding = isCompact ? 12 : 16;
    double iconSize = isCompact ? 40 : 56;
    double iconPadding = isCompact ? 8 : 12;
    double fontSize = isCompact ? 16 : 20;
    double labelFontSize = isCompact ? 10 : 12;
    double subtitleFontSize = isCompact ? 8 : 10;
    
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Row(
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
                  ),
                  child: Icon(icon, color: Colors.white, size: isCompact ? 18 : 24),
                ),
                if (!isCompact) const Spacer(),
                if (!isCompact)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: trend == 'up' ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          trend == 'up' ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 10,
                          color: trend == 'up' ? AppTheme.success : AppTheme.error,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          trend == 'up' ? 'up' : 'down',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: trend == 'up' ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: iconPadding),
          Text(
            label,
            style: TextStyle(
              fontSize: labelFontSize,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
                maxLines: 1,
              ),
            ),
          ),
          if (!isCompact) ...[
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: subtitleFontSize,
                  color: AppTheme.success,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Goals',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textDark),
          ),
          const SizedBox(height: 12),
          ..._goals.map((goal) => _buildGoalItem(goal)).toList(),
        ],
      ),
    );
  }

  Widget _buildGoalItem(Map<String, dynamic> goal) {
    final color = goal['color'] as Color;
    final percentage = (goal['percentage'] as num).toDouble();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(goal['icon'] as IconData, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  goal['title'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textDark),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'delivered':
      case 'completed':
        return AppTheme.success;
      case 'in_transit':
        return AppTheme.info;
      case 'picked_up':
        return AppTheme.warning;
      case 'assigned':
      case 'accepted_by_rider':
        return AppTheme.primary;
      default:
        return AppTheme.textMuted;
    }
  }

  Widget _buildActivityTableRow(Map<String, dynamic> activity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(activity['order_number'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          Expanded(flex: 3, child: Text(activity['status'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          Expanded(flex: 4, child: Text(activity['delivery_address'] ?? 'N/A', style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(child: Text('₱${((activity['amount'] ?? 0) as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          Expanded(flex: 2, child: Text(_formatDate(activity['created_at']), style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }

  Future<void> _loadEarningsReport() async {
    if (_earningsFrom == null || _earningsTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date range'), backgroundColor: AppTheme.warning),
      );
      return;
    }
    setState(() => _loadingEarningsReport = true);
    try {
      final fromStr = _earningsFrom!.toIso8601String().split('T')[0];
      final toStr = _earningsTo!.toIso8601String().split('T')[0];
      final res = await ApiService.get('/api/rider/earnings/report?from=$fromStr&to=$toStr');
      if (mounted) {
        final report = res['report'] ?? [];
        setState(() {
          _earningsReport = report;
          _earningsChartData = _prepareChartData(report);
          _loadingEarningsReport = false;
        });
      }
    } catch (e) {
      print('Error loading earnings report: $e');
      if (mounted) setState(() => _loadingEarningsReport = false);
    }
  }

  List<FlSpot> _prepareChartData(List report) {
    List<FlSpot> spots = [];
    for (int i = 0; i < report.length; i++) {
      final item = report[i];
      final earnings = (item['total_earnings'] ?? 0) as num;
      spots.add(FlSpot(i.toDouble(), earnings.toDouble()));
    }
    return spots;
  }

  void _showEarningsReport() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Earnings Report'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _earningsFrom ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => _earningsFrom = date);
                            setDialogState(() {});
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: AppTheme.textMuted),
                              const SizedBox(width: 8),
                              Text(
                                _earningsFrom == null ? 'From' : '${_earningsFrom!.month}/${_earningsFrom!.day}/${_earningsFrom!.year}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('to', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _earningsTo ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => _earningsTo = date);
                            setDialogState(() {});
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: AppTheme.textMuted),
                              const SizedBox(width: 8),
                              Text(
                                _earningsTo == null ? 'To' : '${_earningsTo!.month}/${_earningsTo!.day}/${_earningsTo!.year}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadingEarningsReport ? null : () {
                    _loadEarningsReport().then((_) {
                      setDialogState(() {});
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  child: _loadingEarningsReport
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Load Report', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(height: 12),
                if (_earningsReport.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 50,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: AppTheme.border.withValues(alpha: 0.3),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= 0 && value.toInt() < _earningsReport.length) {
                                  return Text(
                                    _earningsReport[value.toInt()]['date']?.substring(5) ?? '',
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                  );
                                }
                                return const Text('');
                              },
                              reservedSize: 30,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value % 100 == 0 && value > 0) {
                                  return Text(
                                    '₱${value.toInt()}',
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                  );
                                }
                                return const Text('');
                              },
                              reservedSize: 40,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (_earningsReport.length - 1).toDouble().clamp(0, double.infinity),
                        minY: 0,
                        maxY: _earningsChartData.isEmpty ? 100 : _earningsChartData.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _earningsChartData,
                            isCurved: true,
                            color: AppTheme.primary,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                radius: 4,
                                color: AppTheme.primary,
                                strokeWidth: 0,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppTheme.primary.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _earningsReport.length,
                      itemBuilder: (_, i) {
                        final item = _earningsReport[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: Text(item['date'] ?? '', style: const TextStyle(fontSize: 11))),
                              Expanded(flex: 1, child: Text('${item['deliveries'] ?? 0}', style: const TextStyle(fontSize: 11))),
                              Expanded(flex: 2, child: Text('₱${((item['total_earnings'] ?? 0) as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadNotifications() async {
    setState(() => _loadingNotifications = true);
    try {
      final res = await ApiService.get('/api/notifications');
      if (mounted) {
        setState(() {
          _notifications = res['notifications'] ?? [];
          _loadingNotifications = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) setState(() => _loadingNotifications = false);
    }
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Notifications'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_notifications.isEmpty && !_loadingNotifications)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.notifications_none, size: 40, color: AppTheme.textMuted),
                        SizedBox(height: 12),
                        Text('No notifications', style: TextStyle(color: AppTheme.textMuted)),
                        SizedBox(height: 4),
                        Text('You have no new notifications', style: TextStyle(color: AppTheme.textMuted)),
                      ],
                    ),
                  )
                else if (_loadingNotifications)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _notifications.length,
                      itemBuilder: (_, i) {
                        final notif = _notifications[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notif['title'] ?? 'Notification',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notif['message'] ?? '',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(notif['created_at']),
                                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                              ),
                            ],
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
              onPressed: () {
                Navigator.pop(context);
                _loadNotifications();
              },
              child: const Text('Refresh'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Rider Dashboard'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _showNotifications,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'profile') Navigator.pushNamed(context, '/rider/profile');
              if (value == 'earnings') Navigator.pushNamed(context, '/rider/earnings');
              if (value == 'history') Navigator.pushNamed(context, '/rider/history');
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'profile', child: Text('Profile')),
              const PopupMenuItem(value: 'earnings', child: Text('Earnings')),
              const PopupMenuItem(value: 'history', child: Text('History')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _load,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 10, color: _status == 'available' ? AppTheme.success : _status == 'busy' ? AppTheme.warning : AppTheme.textMuted),
                          const SizedBox(width: 8),
                          Text('Status: ${_status[0].toUpperCase()}${_status.substring(1)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Enhanced Stats Grid (matching web app)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Adjust grid based on screen width
                        int crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                        double childAspectRatio = constraints.maxWidth > 600 ? 1.2 : 1.45;
                        
                        return GridView.count(
                          crossAxisCount: crossAxisCount, 
                          shrinkWrap: true, 
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 8, 
                          mainAxisSpacing: 8, 
                          childAspectRatio: childAspectRatio,
                          children: [
                            _buildEnhancedStatCard(
                              label: 'Active',
                              value: '${_stats['active_deliveries'] ?? 0}',
                              icon: Icons.route,
                              color: AppTheme.success,
                              subtitle: 'Ready for pickup',
                              trend: 'up',
                              isCompact: constraints.maxWidth <= 400,
                            ),
                            _buildEnhancedStatCard(
                              label: 'Completed',
                              value: '${_stats['today_deliveries'] ?? 0}',
                              icon: Icons.check_circle,
                              color: AppTheme.info,
                              subtitle: 'Deliveries completed',
                              trend: 'up',
                              isCompact: constraints.maxWidth <= 400,
                            ),
                            _buildEnhancedStatCard(
                              label: 'Earnings',
                              value: '₱${((_stats['today_earnings'] ?? 0) as num).toStringAsFixed(0)}',
                              icon: Icons.wallet,
                              color: AppTheme.warning,
                              subtitle: 'Today\'s earnings',
                              trend: 'up',
                              isCompact: constraints.maxWidth <= 400,
                            ),
                            _buildEnhancedStatCard(
                              label: 'Rating',
                              value: '${((_stats['average_rating'] ?? 5.0) as num).toStringAsFixed(1)} ⭐',
                              icon: Icons.star,
                              color: AppTheme.primary,
                              subtitle: 'Customer feedback',
                              trend: 'up',
                              isCompact: constraints.maxWidth <= 400,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Daily Goals Section (matching web app)
                    const SectionHeader(
                      title: 'Daily Goals',
                      subtitle: 'Track your daily performance targets',
                    ),
                    const SizedBox(height: 12),
                    _buildGoalsSection(),
                    const SizedBox(height: 20),

                    // Quick Actions (responsive)
                    const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Adjust button layout based on screen width
                        if (constraints.maxWidth > 500) {
                          // 2 columns for larger screens
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _actionBtn(Icons.search, 'Available Orders', AppTheme.primary, () => Navigator.pushNamed(context, '/rider/available'))),
                                  const SizedBox(width: 8),
                                  Expanded(child: _actionBtn(Icons.route, 'My Deliveries', AppTheme.success, () => Navigator.pushNamed(context, '/rider/deliveries'))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _actionBtn(Icons.history, 'History', AppTheme.info, () => Navigator.pushNamed(context, '/rider/history'))),
                                  const SizedBox(width: 8),
                                  Expanded(child: _actionBtn(Icons.account_balance_wallet, 'Earnings', AppTheme.warning, () => Navigator.pushNamed(context, '/rider/earnings'))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _actionBtn(Icons.assessment, 'Earnings Report', AppTheme.primary, () => _showEarningsReport())),
                                  const SizedBox(width: 8),
                                  Expanded(child: _actionBtn(Icons.notifications_active, 'Notifications', AppTheme.info, () => _showNotifications())),
                                ],
                              ),
                            ],
                          );
                        } else {
                          // Single column for smaller screens
                          return Column(
                            children: [
                              _actionBtn(Icons.search, 'Available Orders', AppTheme.primary, () => Navigator.pushNamed(context, '/rider/available')),
                              const SizedBox(height: 8),
                              _actionBtn(Icons.route, 'My Deliveries', AppTheme.success, () => Navigator.pushNamed(context, '/rider/deliveries')),
                              const SizedBox(height: 8),
                              _actionBtn(Icons.history, 'History', AppTheme.info, () => Navigator.pushNamed(context, '/rider/history')),
                              const SizedBox(height: 8),
                              _actionBtn(Icons.account_balance_wallet, 'Earnings', AppTheme.warning, () => Navigator.pushNamed(context, '/rider/earnings')),
                              const SizedBox(height: 8),
                              _actionBtn(Icons.assessment, 'Earnings Report', AppTheme.primary, () => _showEarningsReport()),
                              const SizedBox(height: 8),
                              _actionBtn(Icons.notifications_active, 'Notifications', AppTheme.info, () => _showNotifications()),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Enhanced Recent Activity (responsive)
                    SectionHeader(
                      title: 'Recent Activity',
                      subtitle: 'Your latest delivery updates',
                      action: TextButton(onPressed: () => Navigator.pushNamed(context, '/rider/history'), child: Text('View All', style: TextStyle(color: AppTheme.primary))),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 600) {
                          // Table view for larger screens
                          return Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              children: [
                                // Table Header
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Expanded(flex: 2, child: Text('Order', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                      Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                      Expanded(flex: 3, child: Text('Address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                      Expanded(child: Text('Amount', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                      Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                    ],
                                  ),
                                ),
                                // Table Content
                                if (_recentActivity.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 30),
                                    child: const Column(
                                      children: [
                                        Icon(Icons.history, size: 40, color: AppTheme.textMuted),
                                        SizedBox(height: 12),
                                        Text('No recent activity', style: TextStyle(color: AppTheme.textMuted)),
                                        SizedBox(height: 4),
                                        Text('Your delivery activities will appear here', style: TextStyle(color: AppTheme.textMuted)),
                                      ],
                                    ),
                                  )
                                else
                                  ..._recentActivity.map((d) => _buildActivityTableRow(d)).toList(),
                              ],
                            ),
                          );
                        } else {
                          // Card view for smaller screens
                          return Column(
                            children: [
                              if (_recentActivity.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: const Column(
                                    children: [
                                      Icon(Icons.history, size: 40, color: AppTheme.textMuted),
                                      SizedBox(height: 12),
                                      Text('No recent activity', style: TextStyle(color: AppTheme.textMuted)),
                                      SizedBox(height: 4),
                                      Text('Your delivery activities will appear here', style: TextStyle(color: AppTheme.textMuted)),
                                    ],
                                  ),
                                )
                              else
                                ..._recentActivity.map((d) => _buildActivityCard(d)).toList(),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color))),
            Icon(Icons.chevron_right, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  activity['order_number'] ?? 'N/A',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(activity['status']).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  activity['status']?.toString().toUpperCase() ?? 'PENDING',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(activity['status']),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  activity['delivery_address'] ?? 'N/A',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '₱${((activity['amount'] ?? 0) as num).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const Spacer(),
              Text(
                _formatDate(activity['created_at']),
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AvailableDeliveriesScreen extends StatefulWidget {
  const AvailableDeliveriesScreen({super.key});

  @override
  State<AvailableDeliveriesScreen> createState() => _AvailableDeliveriesScreenState();
}

class _AvailableDeliveriesScreenState extends State<AvailableDeliveriesScreen> {
  List _deliveries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/api/rider/deliveries/available');
      if (mounted) setState(() { _deliveries = res['deliveries'] ?? []; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept(int deliveryId, String orderNumber) async {
    final res = await ApiService.post('/api/rider/deliveries/$deliveryId/accept', {});
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery accepted!'), backgroundColor: AppTheme.success));
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'] ?? 'Failed'), backgroundColor: AppTheme.error));
    }
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            delivery['order_number'] ?? '',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            delivery['customer_address'] ?? '',
            style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Text(
            '₱${((delivery['amount'] ?? 0) as num).toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _accept(delivery['id'], delivery['order_number']),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Accept Delivery', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Available Deliveries'), backgroundColor: AppTheme.primaryDark, foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: _deliveries.length,
                itemBuilder: (_, i) => _buildDeliveryCard(_deliveries[i]),
              ),
            ),
    );
  }
}

class MyDeliveriesScreen extends StatefulWidget {
  const MyDeliveriesScreen({super.key});

  @override
  State<MyDeliveriesScreen> createState() => _MyDeliveriesScreenState();
}

class _MyDeliveriesScreenState extends State<MyDeliveriesScreen> {
  List _deliveries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/api/rider/deliveries');
      if (mounted) setState(() { _deliveries = res['deliveries'] ?? []; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(int deliveryId, String orderNumber, String status) async {
    final res = await ApiService.put('/api/rider/deliveries/$deliveryId/status', {'status': status});
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated!'), backgroundColor: AppTheme.success));
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'] ?? 'Failed'), backgroundColor: AppTheme.error));
    }
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            delivery['order_number'] ?? '',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            delivery['customer_address'] ?? '',
            style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Text(
            '₱${((delivery['amount'] ?? 0) as num).toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _updateStatus(delivery['id'], delivery['order_number'], 'picked_up'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warning,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Pick Up', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _updateStatus(delivery['id'], delivery['order_number'], 'delivered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Deliver', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Deliveries'), backgroundColor: AppTheme.primaryDark, foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: _deliveries.length,
                itemBuilder: (_, i) => _buildDeliveryCard(_deliveries[i]),
              ),
            ),
    );
  }
}

class RiderEarningsScreen extends StatefulWidget {
  const RiderEarningsScreen({super.key});

  @override
  State<RiderEarningsScreen> createState() => _RiderEarningsScreenState();
}

class _RiderEarningsScreenState extends State<RiderEarningsScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/api/rider/earnings');
      if (mounted) setState(() { _data = res; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings'), backgroundColor: AppTheme.primaryDark, foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Today's Earnings
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.primaryDark]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text('Today\'s Earnings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 8),
                        Text('₱${((_data['today_earnings'] ?? 0) as num).toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stats Grid
                  GridView.count(
                    crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.45,
                    children: [
                      StatCard(label: "Today's Earnings", value: '₱${((_data['today_earnings'] ?? 0) as num).toStringAsFixed(2)}', icon: Icons.today, color: AppTheme.primary),
                      StatCard(label: 'This Week', value: '₱${((_data['week_earnings'] ?? 0) as num).toStringAsFixed(2)}', icon: Icons.date_range, color: AppTheme.success),
                      StatCard(label: 'This Month', value: '₱${((_data['month_earnings'] ?? 0) as num).toStringAsFixed(2)}', icon: Icons.calendar_month, color: AppTheme.info),
                      StatCard(label: 'Total Deliveries', value: '${_data['total_deliveries'] ?? 0}', icon: Icons.delivery_dining, color: AppTheme.warning),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Recent Earnings Table
                  const Text('Recent Earnings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        // Table Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                          ),
                          child: const Row(
                            children: [
                              Expanded(flex: 2, child: Text("Today's Earnings", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                              Expanded(flex: 3, child: Text('This Week', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                              Expanded(child: Text('This Month', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                            ],
                          ),
                        ),
                        // Table Content
                        if ((_data['recent'] as List?)?.isEmpty ?? true)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            child: const Column(
                              children: [
                                Icon(Icons.history, size: 44, color: AppTheme.textMuted),
                                SizedBox(height: 8),
                                Text('No recent earnings', style: TextStyle(color: AppTheme.textMuted)),
                                SizedBox(height: 4),
                                Text('Your earning activities will appear here', style: TextStyle(color: AppTheme.textMuted)),
                              ],
                            ),
                          )
                        else
                          ...((_data['recent'] as List?) ?? []).map((e) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.delivery_dining, color: AppTheme.success, size: 20)),
                            title: Text(e['order_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: Text(e['date'] ?? '', style: const TextStyle(fontSize: 11)),
                            trailing: Text('₱${((e['amount'] ?? 0) as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.success)),
                          )).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class RiderProfileScreen extends StatelessWidget {
  const RiderProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), backgroundColor: AppTheme.primaryDark, foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(leading: const Icon(Icons.person_outline, color: AppTheme.primary), title: const Text('Edit Profile'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pushNamed(context, '/profile')),
          ListTile(leading: const Icon(Icons.lock_outline, color: AppTheme.primary), title: const Text('Change Password'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pushNamed(context, '/profile')),
          ListTile(leading: const Icon(Icons.history, color: AppTheme.primary), title: const Text('Delivery History'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pushNamed(context, '/rider/history')),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.error),
            title: const Text('Logout', style: TextStyle(color: AppTheme.error)),
            onTap: () => Navigator.pushReplacementNamed(context, '/logout'),
          ),
        ],
      ),
    );
  }
}

class RiderMainScreen extends StatefulWidget {
  const RiderMainScreen({super.key});

  @override
  State<RiderMainScreen> createState() => _RiderMainScreenState();
}

class _RiderMainScreenState extends State<RiderMainScreen> {
  int _index = 0;

  final List<Widget> _screens = [
    const RiderDashboardScreen(),
    const AvailableDeliveriesScreen(),
    const MyDeliveriesScreen(),
    const RiderEarningsScreen(),
    const RiderProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textMuted,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.surface,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.search_outlined), activeIcon: Icon(Icons.search), label: 'Available'),
          BottomNavigationBarItem(icon: Icon(Icons.route_outlined), activeIcon: Icon(Icons.route), label: 'My Deliveries'),
          BottomNavigationBarItem(icon: Icon(Icons.wallet_outlined), activeIcon: Icon(Icons.wallet), label: 'Earnings'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outlined), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
