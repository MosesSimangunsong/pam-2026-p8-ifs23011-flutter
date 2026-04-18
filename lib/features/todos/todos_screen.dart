// lib/features/todos/todos_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/route_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/error_widget.dart';
import '../../shared/widgets/loading_widget.dart';
import '../../shared/widgets/top_app_bar_widget.dart';
import '../../data/models/todo_model.dart';

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  String _selectedFilter = 'all';

  // ── Tambahan: ScrollController untuk Paginasi ──
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Tambahkan listener untuk mendeteksi scroll
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Jangan lupa di-dispose untuk mencegah memory leak
    super.dispose();
  }

  // ── Fungsi untuk mengecek posisi scroll ──
  void _onScroll() {
    // PERBAIKAN: Cek hasClients terlebih dahulu untuk menghindari StateError
    // jika controller belum atau sudah tidak ter-attach ke scroll view manapun.
    if (!_scrollController.hasClients) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      final token = context.read<AuthProvider>().authToken;
      final provider = context.read<TodoProvider>();

      if (token != null && provider.hasMore && !provider.isLoadingMore) {
        provider.loadMoreTodos(authToken: token);
      }
    }
  }

  void _loadData() {
    final token = context.read<AuthProvider>().authToken;
    if (token != null) context.read<TodoProvider>().loadTodos(authToken: token);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodoProvider>();
    final token    = context.read<AuthProvider>().authToken ?? '';

    // ── Logika Filtering Data ──
    var displayTodos = provider.todos;
    if (_selectedFilter == 'done') {
      displayTodos = displayTodos.where((t) => t.isDone).toList();
    } else if (_selectedFilter == 'pending') {
      displayTodos = displayTodos.where((t) => !t.isDone).toList();
    }

    return Scaffold(
      appBar: TopAppBarWidget(
        title: 'Todo Saya',
        withSearch: true,
        searchHint: 'Cari todo...',
        onSearchChanged: (query) {
          context.read<TodoProvider>().updateSearchQuery(query);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context
            .push(RouteConstants.todosAdd)
            .then((_) => _loadData()),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: Column(
        children: [
          // ── Widget Filter (SegmentedButton) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('Semua')),
                  ButtonSegment(value: 'done', label: Text('Selesai')),
                  ButtonSegment(value: 'pending', label: Text('Belum')),
                ],
                selected: {_selectedFilter},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _selectedFilter = newSelection.first;
                  });
                },
              ),
            ),
          ),

          // ── Daftar Todo ──
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _loadData(),
              child: switch (provider.status) {
                TodoStatus.loading || TodoStatus.initial =>
                const LoadingWidget(message: 'Memuat todo...'),
                TodoStatus.error =>
                    AppErrorWidget(message: provider.errorMessage, onRetry: _loadData),
                _ => displayTodos.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        _selectedFilter == 'all'
                            ? 'Belum ada todo.\nKetuk + untuk menambahkan.'
                            : 'Tidak ada todo pada filter ini.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                    : ListView.separated(
                  controller: _scrollController, // Pasang ScrollController di sini
                  padding: const EdgeInsets.all(16),
                  // Tambah 1 ke itemCount jika hasMore true untuk tempat indikator loading
                  itemCount: displayTodos.length + (provider.hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    // Jika index sama dengan jumlah data, berarti ini item terakhir (indikator loading)
                    if (i == displayTodos.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final todo = displayTodos[i];
                    return _TodoCard(
                      todo: todo,
                      onTap: () => context
                          .push(RouteConstants.todosDetail(todo.id))
                          .then((_) => _loadData()),
                      onToggle: () async {
                        final success = await provider.editTodo(
                          authToken:   token,
                          todoId:      todo.id,
                          title:       todo.title,
                          description: todo.description,
                          isDone:      !todo.isDone,
                        );
                        if (!success && mounted) {
                          showAppSnackBar(context,
                              message: provider.errorMessage,
                              type: SnackBarType.error);
                        }
                      },
                    );
                  },
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoCard extends StatelessWidget {
  const _TodoCard({
    required this.todo,
    required this.onTap,
    required this.onToggle,
  });

  final TodoModel todo; // ← PERBAIKAN: Anotasi tipe eksplisit
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: GestureDetector(
          onTap: onToggle,
          child: Icon(
            todo.isDone
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: todo.isDone ? Colors.green : colorScheme.outline,
            size: 28,
          ),
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            decoration: todo.isDone ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          todo.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      ),
    );
  }
}