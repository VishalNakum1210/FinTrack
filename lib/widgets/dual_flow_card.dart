import 'package:fin_track/utils/currency_helper.dart';
import 'package:fin_track/widgets/sparkline_painter.dart';
import 'package:flutter/material.dart';

/// Elevated card displaying total inflow, outflow, net savings, and a mini 7-day spend sparkline.
class DualFlowCard extends StatelessWidget {
  final double totalInflow;
  final double totalOutflow;
  final double netSaved;
  final List<double> weeklySparks;
  final String title;
  final String subtitle;

  const DualFlowCard({
    super.key,
    required this.totalInflow,
    required this.totalOutflow,
    required this.netSaved,
    this.weeklySparks = const [],
    this.title = "Net Saved:",
    this.subtitle = "7-day spending activity",
  });

  @override
  Widget build(BuildContext context) {
    final defaultSparks = [12.0, 24.0, 18.0, 32.0, 22.0, 40.0, 28.0];
    final sparkData = weeklySparks.length >= 2 ? weeklySparks : defaultSparks;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dual pills: Inflow & Outflow
          Row(
            children: [
              // Inflow Pill
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.arrow_downward_rounded, size: 13, color: Color(0xFF2E7D32)),
                          SizedBox(width: 4),
                          Text(
                            "Total Inflow",
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "+${totalInflow.toINR()}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Outflow Pill
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.arrow_upward_rounded, size: 13, color: Color(0xFFC62828)),
                          SizedBox(width: 4),
                          Text(
                            "Total Outflow",
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFFC62828),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "-${totalOutflow.toINR()}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC62828),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Net Savings & Sparkline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        netSaved >= 0 ? netSaved.toINR() : "-${netSaved.abs().toINR()}",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: netSaved >= 0 ? const Color(0xFF1E293B) : const Color(0xFFC62828),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Sparkline chart
              SizedBox(
                width: 110,
                height: 38,
                child: CustomPaint(
                  painter: MiniSparklinePainter(
                    data: sparkData,
                    lineColor: const Color(0xFF8BC24A),
                    fillColor: const Color(0xFF8BC24A).withValues(alpha: 0.15),
                    strokeWidth: 2.2,
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
