// lib/providers/todo_provider.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../data/models/todo_model.dart';
import '../data/services/todo_repository.dart';

enum TodoStatus { initial, loading, success, error }

class TodoProvider extends ChangeNotifier {
  TodoProvider({TodoRepository? repository})
      : _repository = repository ?? TodoRepository();

  final TodoRepository _repository;

  // ── State ────────────────────────────────────
  TodoStatus _status = TodoStatus.initial;
  List<TodoModel> _todos = [];
  TodoModel? _selectedTodo;
  String _errorMessage = '';
  String _searchQuery = '';

  // ── State Paginasi ───────────────────────────
  int _page = 1;
  final int _perPage = 10;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // ── Getters ──────────────────────────────────
  TodoStatus get status       => _status;
  TodoModel? get selectedTodo => _selectedTodo;
  String get errorMessage     => _errorMessage;

  bool get hasMore       => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  List<TodoModel> get todos {
    if (_searchQuery.isEmpty) return List.unmodifiable(_todos);
    return _todos
        .where((t) =>
        t.title.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  int get totalTodos   => _todos.length;
  int get doneTodos    => _todos.where((t) => t.isDone).length;
  int get pendingTodos => _todos.where((t) => !t.isDone).length;

  // ── Load All Todos (Dengan Refresh) ───────────
  Future<void> loadTodos({required String authToken, bool isRefresh = true}) async {
    if (isRefresh) {
      _page = 1;
      _hasMore = true;
      _setStatus(TodoStatus.loading);
    }

    final result = await _repository.getTodos(
      authToken: authToken,
      page: _page,
      perPage: _perPage,
    );

    if (result.success && result.data != null) {
      if (isRefresh) {
        _todos = result.data!;
      } else {
        _todos.addAll(result.data!);
      }
      // Cek apakah data yang diterima kurang dari perPage (berarti sudah di halaman terakhir)
      _hasMore = result.data!.length == _perPage;
      _setStatus(TodoStatus.success);
    } else {
      _errorMessage = result.message;
      _setStatus(TodoStatus.error);
    }
  }

  // ── Load More Todos (Untuk Paginasi) ──────────
  Future<void> loadMoreTodos({required String authToken}) async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    _page++;
    final result = await _repository.getTodos(
      authToken: authToken,
      page: _page,
      perPage: _perPage,
    );

    if (result.success && result.data != null) {
      _todos.addAll(result.data!);
      _hasMore = result.data!.length == _perPage;
    } else {
      _page--; // Kembalikan nomor page jika request gagal
      _errorMessage = result.message;
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  // ── Create Todo ───────────────────────────────
  Future<bool> addTodo({
    required String authToken,
    required String title,
    required String description,
  }) async {
    _setStatus(TodoStatus.loading);
    final result = await _repository.createTodo(
      authToken:   authToken,
      title:       title,
      description: description,
    );
    if (result.success) {
      // Reset ke halaman pertama agar data baru muncul di atas
      _page = 1;
      final listResult = await _repository.getTodos(
        authToken: authToken, page: _page, perPage: _perPage,
      );
      if (listResult.success && listResult.data != null) {
        _todos = listResult.data!;
        _hasMore = listResult.data!.length == _perPage;
      }
      _setStatus(TodoStatus.success);
      return true;
    }
    _errorMessage = result.message;
    _setStatus(TodoStatus.error);
    return false;
  }

  // ── Load Single Todo ──────────────────────────
  Future<void> loadTodoById({
    required String authToken,
    required String todoId,
  }) async {
    _setStatus(TodoStatus.loading);
    final result = await _repository.getTodoById(
        authToken: authToken, todoId: todoId);
    if (result.success && result.data != null) {
      _selectedTodo = result.data;
      _setStatus(TodoStatus.success);
    } else {
      _errorMessage = result.message;
      _setStatus(TodoStatus.error);
    }
  }

// ── Update Todo ───────────────────────────────
  Future<bool> editTodo({
    required String authToken,
    required String todoId,
    required String title,
    required String description,
    required bool isDone,
  }) async {
    _setStatus(TodoStatus.loading);
    final result = await _repository.updateTodo(
      authToken: authToken,
      todoId: todoId,
      title: title,
      description: description,
      isDone: isDone,
    );
    if (result.success) {
      _page = 1;
      // Gunakan tipe eksplisit untuk menghindari unsafe cast dari Future.wait
      final detailResult = await _repository.getTodoById(
        authToken: authToken,
        todoId: todoId,
      );
      final listResult = await _repository.getTodos(
        authToken: authToken,
        page: _page,
        perPage: _perPage,
      );

      if (detailResult.success && detailResult.data != null) {
        _selectedTodo = detailResult.data;
      }
      if (listResult.success && listResult.data != null) {
        _todos = listResult.data!;
        _hasMore = _todos.length == _perPage;
      }

      _setStatus(TodoStatus.success);
      return true;
    }
    _errorMessage = result.message;
    // PERBAIKAN: Kembalikan ke 'success' bukan 'error' agar list tidak hilang.
    // Error akan ditampilkan melalui SnackBar di UI layer.
    _setStatus(TodoStatus.success);
    return false;
  }

// ── Update Cover ──────────────────────────────
  Future<bool> updateCover({
    required String authToken,
    required String todoId,
    File? imageFile,
    Uint8List? imageBytes,
    String imageFilename = 'cover.jpg',
  }) async {
    _setStatus(TodoStatus.loading);
    final result = await _repository.updateTodoCover(
      authToken: authToken,
      todoId: todoId,
      imageFile: imageFile,
      imageBytes: imageBytes,
      imageFilename: imageFilename,
    );
    if (result.success) {
      _page = 1;
      final detailResult = await _repository.getTodoById(
        authToken: authToken,
        todoId: todoId,
      );
      final listResult = await _repository.getTodos(
        authToken: authToken,
        page: _page,
        perPage: _perPage,
      );

      if (detailResult.success && detailResult.data != null) {
        _selectedTodo = detailResult.data;
      }
      if (listResult.success && listResult.data != null) {
        _todos = listResult.data!;
        _hasMore = _todos.length == _perPage;
      }

      _setStatus(TodoStatus.success);
      return true;
    }
    _errorMessage = result.message;
    // PERBAIKAN: Kembalikan ke 'success' bukan 'error'.
    _setStatus(TodoStatus.success);
    return false;
  }

// ── Delete Todo ───────────────────────────────
  Future<bool> removeTodo({
    required String authToken,
    required String todoId,
  }) async {
    _setStatus(TodoStatus.loading);
    final result = await _repository.deleteTodo(
      authToken: authToken,
      todoId: todoId,
    );
    if (result.success) {
      _todos.removeWhere((t) => t.id == todoId);
      _selectedTodo = null;
      _setStatus(TodoStatus.success);
      return true;
    }
    _errorMessage = result.message;
    // PERBAIKAN: Kembalikan ke 'success' bukan 'error'.
    _setStatus(TodoStatus.success);
    return false;
  }

  // ── Search ────────────────────────────────────
  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSelectedTodo() {
    _selectedTodo = null;
    notifyListeners();
  }

  void _setStatus(TodoStatus status) {
    _status = status;
    notifyListeners();
  }
}