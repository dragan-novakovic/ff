import 'package:flutter/material.dart';

class InfoBox extends StatefulWidget {
  const InfoBox({super.key});

  @override
  State<InfoBox> createState() => _InfoBoxState();
}

class _InfoBoxState extends State<InfoBox> {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0F2136),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.campaign,
                    color: Color(0xFF67E8F9),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Command dispatch',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Latest connected gameplay systems',
                        style: TextStyle(color: Color(0xFFA8B3C7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _DispatchLine(
              icon: Icons.sync,
              text: 'Player stats now load from the backend.',
            ),
            const _DispatchLine(
              icon: Icons.flash_on,
              text: 'Daily work, training, and objectives are connected.',
            ),
            const _DispatchLine(
              icon: Icons.inventory_2,
              text:
                  'Inventory, research, and training now use game-style screens.',
            ),
          ],
        ),
      ),
    );
  }
}

class _DispatchLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DispatchLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF67E8F9), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white.withOpacity(0.72)),
            ),
          ),
        ],
      ),
    );
  }
}
