import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/group.dart';
import '../models/person.dart';
import '../models/expense.dart';
import '../services/database_helper.dart';

class ExportImportService {
  static final DatabaseHelper _db = DatabaseHelper.instance;

  // Export single group to JSON
  static Future<Map<String, dynamic>> exportGroupToJson(String groupId) async {
    final group = await _db.getGroup(groupId);
    if (group == null) {
      throw Exception('Group not found');
    }

    final expenses = await _db.getGroupExpenses(groupId);

    return {
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'group': {
        'id': group.id,
        'name': group.name,
        'description': group.description,
        'createdAt': group.createdAt.toIso8601String(),
        'members': group.members.map((m) => {
          'id': m.id,
          'name': m.name,
          'email': m.email,
          'avatar': m.avatar,
        }).toList(),
      },
      'expenses': expenses.map((e) => {
        'id': e.id,
        'groupId': e.groupId,
        'description': e.description,
        'amount': e.amount,
        'paidBy': {
          'id': e.paidBy.id,
          'name': e.paidBy.name,
          'email': e.paidBy.email,
          'avatar': e.paidBy.avatar,
        },
        'participants': e.participants.map((p) => {
          'id': p.id,
          'name': p.name,
          'email': p.email,
          'avatar': p.avatar,
        }).toList(),
        'splits': e.splits,
        'date': e.date.toIso8601String(),
        'category': e.category,
      }).toList(),
    };
  }

  // Export all groups to JSON
  static Future<Map<String, dynamic>> exportAllGroupsToJson() async {
    final groups = await _db.getAllGroups();
    final allGroupsData = <Map<String, dynamic>>[];

    for (var group in groups) {
      final groupData = await exportGroupToJson(group.id);
      allGroupsData.add(groupData);
    }

    return {
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'appName': 'Group Xpense',
      'totalGroups': groups.length,
      'groups': allGroupsData,
    };
  }

  // Save JSON to file and share
  static Future<File> saveAndShareJson(Map<String, dynamic> data, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    await file.writeAsString(jsonString);

    return file;
  }

  // Export and share single group
  static Future<void> exportAndShareGroup(String groupId, String groupName) async {
    final data = await exportGroupToJson(groupId);
    final fileName = '${groupName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = await saveAndShareJson(data, fileName);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Group Xpense - $groupName',
      text: 'Export from Group Xpense app',
    );
  }

  // Export and share all groups
  static Future<void> exportAndShareAllGroups() async {
    final data = await exportAllGroupsToJson();
    final fileName = 'group_xpense_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = await saveAndShareJson(data, fileName);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Group Xpense - Complete Backup',
      text: 'Complete backup from Group Xpense app',
    );
  }

  // Import group from JSON
  static Future<void> importGroupFromJson(Map<String, dynamic> data) async {
    // Validate version
    if (data['version'] != '1.0') {
      throw Exception('Unsupported backup version');
    }

    final groupData = data['group'];
    final expensesData = data['expenses'] as List;

    // Create members
    final members = (groupData['members'] as List).map((m) => Person(
      id: m['id'],
      name: m['name'],
      email: m['email'],
      avatar: m['avatar'],
    )).toList();

    // Create group
    final group = Group(
      id: groupData['id'],
      name: groupData['name'],
      description: groupData['description'],
      members: members,
      createdAt: DateTime.parse(groupData['createdAt']),
    );

    // Check if group already exists
    final existingGroup = await _db.getGroup(group.id);
    if (existingGroup != null) {
      throw Exception('Group "${group.name}" already exists. Please delete it first or rename the imported group.');
    }

    // Insert group
    await _db.insertGroup(group);

    // Insert expenses
    for (var expenseData in expensesData) {
      final paidBy = members.firstWhere((m) => m.id == expenseData['paidBy']['id']);

      final participantIds = (expenseData['participants'] as List).map((p) => p['id'] as String).toList();
      final participants = members.where((m) => participantIds.contains(m.id)).toList();

      final expense = Expense(
        id: expenseData['id'],
        groupId: expenseData['groupId'],
        description: expenseData['description'],
        amount: expenseData['amount'],
        paidBy: paidBy,
        participants: participants,
        splits: Map<String, double>.from(expenseData['splits']),
        date: DateTime.parse(expenseData['date']),
        category: expenseData['category'],
      );

      await _db.insertExpense(expense);
    }
  }

  // Import all groups from JSON
  static Future<void> importAllGroupsFromJson(Map<String, dynamic> data) async {
    if (data['version'] != '1.0') {
      throw Exception('Unsupported backup version');
    }

    final groupsData = data['groups'] as List;

    for (var groupData in groupsData) {
      try {
        await importGroupFromJson(groupData);
      } catch (e) {
        // Continue with next group if one fails
        print('Failed to import group: $e');
      }
    }
  }

  // Pick and import JSON file
  static Future<String> pickAndImportJsonFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) {
      throw Exception('No file selected');
    }

    final file = File(result.files.single.path!);
    final jsonString = await file.readAsString();
    final data = json.decode(jsonString);

    // Check if it's a single group or all groups backup
    if (data.containsKey('groups')) {
      // All groups backup
      await importAllGroupsFromJson(data);
      final groupCount = (data['groups'] as List).length;
      return 'Successfully imported $groupCount group(s)';
    } else if (data.containsKey('group')) {
      // Single group backup
      await importGroupFromJson(data);
      return 'Successfully imported group: ${data['group']['name']}';
    } else {
      throw Exception('Invalid backup file format');
    }
  }
}