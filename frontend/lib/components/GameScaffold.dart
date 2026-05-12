import 'package:flutter/material.dart';

class GameColors {
  static const background = Color(0xFF07111F);
  static const backgroundAlt = Color(0xFF0B1628);
  static const panel = Color(0xFF101B2D);
  static const panelAlt = Color(0xFF142238);
  static const border = Color(0xFF263B57);
  static const textMuted = Color(0xFF9AA9BC);
  static const cyan = Color(0xFF38BDF8);
  static const emerald = Color(0xFF34D399);
  static const amber = Color(0xFFFBBF24);
  static const crimson = Color(0xFFFB7185);
  static const violet = Color(0xFFA78BFA);
}

class GameTheme extends StatelessWidget {
  final Widget child;

  const GameTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: GameColors.background,
        colorScheme: const ColorScheme.dark(
          primary: GameColors.cyan,
          secondary: GameColors.emerald,
          surface: GameColors.panel,
          error: GameColors.crimson,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: GameColors.background,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: GameColors.panelAlt,
          labelStyle: const TextStyle(color: GameColors.textMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: GameColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: GameColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: GameColors.cyan),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: GameColors.cyan,
            foregroundColor: GameColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: GameColors.cyan,
            side: const BorderSide(color: GameColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: GameColors.cyan),
        ),
        dividerColor: GameColors.border,
      ),
      child: child,
    );
  }
}

class GameScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget body;
  final List<Widget>? actions;

  const GameScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.body,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return GameTheme(
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(icon, color: GameColors.cyan),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: GameColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: actions,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                GameColors.background,
                Color(0xFF0B1224),
                GameColors.backgroundAlt,
              ],
            ),
          ),
          child: body,
        ),
      ),
    );
  }
}

class GameHero extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<GameStat> stats;

  const GameHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accent = GameColors.cyan,
    this.stats = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withOpacity(0.45)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(0.24),
            GameColors.panel,
            GameColors.backgroundAlt,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.12),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withOpacity(0.55)),
                ),
                child: Icon(icon, color: accent, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow.toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            style: const TextStyle(color: GameColors.textMuted, height: 1.4),
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: stats.map((stat) => GameStatPill(stat: stat)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class GamePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;

  const GamePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = GameColors.panel,
    this.borderColor = GameColors.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding,
      decoration: BoxDecoration(
        color: color.withOpacity(0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class GameStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const GameStat({
    required this.label,
    required this.value,
    required this.icon,
    this.color = GameColors.cyan,
  });
}

class GameStatPill extends StatelessWidget {
  final GameStat stat;

  const GameStatPill({super.key, required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: GameColors.background.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: stat.color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stat.icon, color: stat.color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                stat.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                stat.label,
                style: const TextStyle(
                  color: GameColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class GameSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const GameSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: GameColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class GameNotice extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const GameNotice({
    super.key,
    required this.icon,
    required this.message,
    this.color = GameColors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      borderColor: color.withOpacity(0.45),
      color: color.withOpacity(0.10),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class GameEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const GameEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      child: Row(
        children: [
          Icon(icon, color: GameColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: GameColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class GameProgressBar extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final Color color;

  const GameProgressBar({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.value,
    this.color = GameColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              valueLabel,
              style: const TextStyle(color: GameColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value.clamp(0, 1).toDouble(),
            minHeight: 10,
            backgroundColor: Colors.white10,
            color: color,
          ),
        ),
      ],
    );
  }
}
