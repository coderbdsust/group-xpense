import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';
import '../services/database_helper.dart';

class CategoryProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Category> _categories = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();

    try {
      _categories = await _dbHelper.getAllCategories();

      // Initialize with default categories if empty
      if (_categories.isEmpty && !_isInitialized) {
        await _initializeDefaultCategories();
        _categories = await _dbHelper.getAllCategories();
        _isInitialized = true;
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _initializeDefaultCategories() async {
    final defaultCategories = [
      Category(
        id: const Uuid().v4(),
        name: 'Food & Drinks',
        iconCodePoint: Icons.restaurant.codePoint.toString(),
        colorValue: Colors.orange.toARGB32().toString(),
        createdAt: DateTime.now(),
      ),
      Category(
        id: const Uuid().v4(),
        name: 'Transportation',
        iconCodePoint: Icons.directions_car.codePoint.toString(),
        colorValue: Colors.blue.toARGB32().toString(),
        createdAt: DateTime.now(),
      ),
      Category(
        id: const Uuid().v4(),
        name: 'Entertainment',
        iconCodePoint: Icons.movie.codePoint.toString(),
        colorValue: Colors.purple.toARGB32().toString(),
        createdAt: DateTime.now(),
      ),
      Category(
        id: const Uuid().v4(),
        name: 'Shopping',
        iconCodePoint: Icons.shopping_bag.codePoint.toString(),
        colorValue: Colors.pink.toARGB32().toString(),
        createdAt: DateTime.now(),
      ),
      Category(
        id: const Uuid().v4(),
        name: 'Utilities',
        iconCodePoint: Icons.electrical_services.codePoint.toString(),
        colorValue: Colors.amber.toARGB32().toString(),
        createdAt: DateTime.now(),
      ),
      Category(
        id: const Uuid().v4(),
        name: 'Rent',
        iconCodePoint: Icons.home.codePoint.toString(),
        colorValue: Colors.green.toARGB32().toString(),
        createdAt: DateTime.now(),
      ),
      Category(
        id: const Uuid().v4(),
        name: 'Other',
        iconCodePoint: Icons.receipt.codePoint.toString(),
        colorValue: Colors.teal.toARGB32().toString(),
        createdAt: DateTime.now(),
      ),
    ];

    for (var category in defaultCategories) {
      await _dbHelper.insertCategory(category);
    }
  }

  Future<void> addCategory(Category category) async {
    try {
      await _dbHelper.insertCategory(category);
      await loadCategories();
    } catch (e) {
      debugPrint('Error adding category: $e');
      rethrow;
    }
  }

  Future<void> updateCategory(Category category) async {
    try {
      await _dbHelper.updateCategory(category);
      await loadCategories();
    } catch (e) {
      debugPrint('Error updating category: $e');
      rethrow;
    }
  }

  Future<bool> deleteCategory(String categoryId, String categoryName) async {
    try {
      // Check if category is in use
      final isInUse = await _dbHelper.isCategoryInUse(categoryName);
      if (isInUse) {
        return false; // Cannot delete category that's in use
      }

      await _dbHelper.deleteCategory(categoryId);
      await loadCategories();
      return true;
    } catch (e) {
      debugPrint('Error deleting category: $e');
      rethrow;
    }
  }

  IconData getCategoryIcon(String? categoryName) {
    if (categoryName == null) return Icons.receipt;

    final category = _categories.firstWhere(
      (cat) => cat.name == categoryName,
      orElse: () => Category(
        id: '',
        name: '',
        iconCodePoint: Icons.receipt.codePoint.toString(),
        colorValue: Colors.teal.toARGB32().toString(),
        createdAt: DateTime.now(),
      ),
    );

    try {
      return IconData(
        int.parse(category.iconCodePoint),
        fontFamily: 'MaterialIcons',
      );
    } catch (e) {
      return Icons.receipt;
    }
  }

  Color getCategoryColor(String? categoryName) {
    if (categoryName == null) return Colors.teal;

    final category = _categories.firstWhere(
      (cat) => cat.name == categoryName,
      orElse: () => Category(
        id: '',
        name: '',
        iconCodePoint: Icons.receipt.codePoint.toString(),
        colorValue: Colors.teal.toARGB32().toString(),
        createdAt: DateTime.now(),
      ),
    );

    try {
      return Color(int.parse(category.colorValue));
    } catch (e) {
      return Colors.teal;
    }
  }

  Category? getCategoryByName(String name) {
    try {
      return _categories.firstWhere((cat) => cat.name == name);
    } catch (e) {
      return null;
    }
  }
}
