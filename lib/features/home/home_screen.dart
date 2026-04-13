// lib/features/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/route_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import '../../providers/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().authToken;
      if (token != null) {
        context.read<TodoProvider>().loadTodos(authToken: token);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme  = Theme.of(context).colorScheme;
    final user         = context.watch<AuthProvider>().user;
    final provider     = context.watch<TodoProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark       = themeProvider.isDark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Halo, ${user?.name ?? '—'} 👋',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Kelola todo-mu hari ini',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            ),
            tooltip: isDark ? 'Mode Terang' : 'Mode Gelap',
            onPressed: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final token = context.read<AuthProvider>().authToken;
          if (token != null) {
            await context.read<TodoProvider>().loadTodos(authToken: token);
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Statistik ──
            Row(
              children: [
                _StatCard(
                  label: 'Total',
                  value: provider.totalTodos,
                  color: colorScheme.primary,
                  icon: Icons.list_alt_rounded,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Selesai',
                  value: provider.doneTodos,
                  color: Colors.green,
                  icon: Icons.check_circle_rounded,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Belum',
                  value: provider.pendingTodos,
                  color: Colors.orange,
                  icon: Icons.pending_rounded,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Shortcut ke Todos ──
            Text(
              'Akses Cepat',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _QuickAccessCard(
              icon: Icons.checklist_rounded,
              title: 'Daftar Todo',
              subtitle: 'Lihat dan kelola semua todo-mu',
              color: colorScheme.primaryContainer,
              onTap: () => context.go(RouteConstants.todos),
            ),
            const SizedBox(height: 12),
            _QuickAccessCard(
              icon: Icons.add_task_rounded,
              title: 'Todo Baru',
              subtitle: 'Tambahkan todo baru',
              color: colorScheme.secondaryContainer,
              onTap: () => context.push(RouteConstants.todosAdd),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                '$value',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing:
        const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}