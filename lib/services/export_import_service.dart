import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
        'members': group.members
            .map(
              (m) => {
            'id': m.id,
            'name': m.name,
            'email': m.email,
            'avatar': m.avatar,
          },
        )
            .toList(),
      },
      'expenses': expenses
          .map(
            (e) => {
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
          'participants': e.participants
              .map(
                (p) => {
              'id': p.id,
              'name': p.name,
              'email': p.email,
              'avatar': p.avatar,
            },
          )
              .toList(),
          'splits': e.splits,
          'date': e.date.toIso8601String(),
          'category': e.category,
        },
      )
          .toList(),
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

  // Get export directory
  static Future<Directory> getExportDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${directory.path}/GroupXpenseExports');

    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    return exportDir;
  }

  // Save JSON to local file system
  static Future<File> saveToLocalFileSystem(
      Map<String, dynamic> data,
      String fileName,
      ) async {
    final exportDir = await getExportDirectory();
    final file = File('${exportDir.path}/$fileName');

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    await file.writeAsString(jsonString);

    return file;
  }

  // Export single group to local file system
  static Future<File> exportGroupToFile(
      String groupId,
      String groupName,
      ) async {
    final data = await exportGroupToJson(groupId);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${groupName.replaceAll(' ', '_')}_$timestamp.json';

    return await saveToLocalFileSystem(data, fileName);
  }

  // Export all groups to local file system
  static Future<File> exportAllGroupsToFile() async {
    final data = await exportAllGroupsToJson();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'group_xpense_backup_$timestamp.json';

    return await saveToLocalFileSystem(data, fileName);
  }

  // Export and share (keep for sharing functionality)
  static Future<void> shareGroupFile(String groupId, String groupName) async {
    final file = await exportGroupToFile(groupId, groupName);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Group Xpense - $groupName',
      text: 'Export from Group Xpense app',
    );
  }

  // Export and share all
  static Future<void> shareAllGroupsFile() async {
    final file = await exportAllGroupsToFile();

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Group Xpense - Complete Backup',
      text: 'Complete backup from Group Xpense app',
    );
  }

  // Get all exported files
  static Future<List<File>> getExportedFiles() async {
    final exportDir = await getExportDirectory();

    if (!await exportDir.exists()) {
      return [];
    }

    final files = exportDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList();

    // Sort by modification time (newest first)
    files.sort(
          (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );

    return files;
  }

  // Delete exported file
  static Future<void> deleteExportedFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // Get file size
  static Future<String> getFileSize(String filePath) async {
    final file = File(filePath);
    final bytes = await file.length();

    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  // Import from file path with duplicate handling
  static Future<String> importFromFilePath(String filePath) async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    final data = json.decode(jsonString);

    if (data.containsKey('groups')) {
      final result = await importAllGroupsFromJson(data);
      return result;
    } else if (data.containsKey('group')) {
      final result = await importGroupFromJson(data);
      return result;
    } else {
      throw Exception('Invalid backup file format');
    }
  }

  // Import group from JSON - returns result message
  static Future<String> importGroupFromJson(Map<String, dynamic> data) async {
    if (data['version'] != '1.0') {
      throw Exception('Unsupported backup version');
    }

    final groupData = data['group'];
    final expensesData = data['expenses'] as List;

    // Check if group already exists - SKIP if it does
    final existingGroup = await _db.getGroup(groupData['id']);

    if (existingGroup != null) {
      // Silently skip this group
      return 'skipped:${groupData['name']}';
    }

    try {
      // Parse members
      final members = (groupData['members'] as List)
          .map(
            (m) => Person(
          id: m['id'],
          name: m['name'],
          email: m['email'],
          avatar: m['avatar'],
        ),
      )
          .toList();

      // Create group
      final group = Group(
        id: groupData['id'],
        name: groupData['name'],
        description: groupData['description'],
        members: members,
        createdAt: DateTime.parse(groupData['createdAt']),
      );

      await _db.insertGroup(group);

      // Import expenses
      for (var expenseData in expensesData) {
        try {
          final paidBy = members.firstWhere(
                (m) => m.id == expenseData['paidBy']['id'],
          );

          final participantIds = (expenseData['participants'] as List)
              .map((p) => p['id'] as String)
              .toList();
          final participants = members
              .where((m) => participantIds.contains(m.id))
              .toList();

          final expense = Expense(
            id: expenseData['id'],
            groupId: expenseData['groupId'],
            description: expenseData['description'],
            amount: (expenseData['amount'] as num).toDouble(),
            paidBy: paidBy,
            participants: participants,
            splits: Map<String, double>.from(expenseData['splits']),
            date: DateTime.parse(expenseData['date']),
            category: expenseData['category'],
          );

          await _db.insertExpense(expense);
        } catch (e) {
          // Skip individual expense if it fails (e.g., duplicate expense ID)
          print('Skipped expense in ${groupData['name']}: $e');
          continue;
        }
      }

      return 'success:${groupData['name']}';
    } catch (e) {
      // If group insert fails, return skip
      print('Failed to import group ${groupData['name']}: $e');
      return 'error:${groupData['name']}';
    }
  }

  // Import all groups from JSON with skip/count logic
  static Future<String> importAllGroupsFromJson(Map<String, dynamic> data) async {
    if (data['version'] != '1.0') {
      throw Exception('Unsupported backup version');
    }

    final groupsData = data['groups'] as List;
    int successCount = 0;
    int skippedCount = 0;
    int errorCount = 0;
    final skippedGroups = <String>[];
    final errorGroups = <String>[];

    for (var groupData in groupsData) {
      try {
        final result = await importGroupFromJson(groupData);

        if (result.startsWith('success:')) {
          successCount++;
        } else if (result.startsWith('skipped:')) {
          skippedCount++;
          final groupName = result.substring('skipped:'.length);
          skippedGroups.add(groupName);
        } else if (result.startsWith('error:')) {
          errorCount++;
          final groupName = result.substring('error:'.length);
          errorGroups.add(groupName);
        }
      } catch (e) {
        errorCount++;
        errorGroups.add(groupData['group']['name']);
        print('Error importing group: $e');
      }
    }

    // Build result message
    final messages = <String>[];

    if (successCount > 0) {
      messages.add('Imported $successCount group${successCount > 1 ? 's' : ''}');
    }

    if (skippedCount > 0) {
      messages.add('Skipped $skippedCount duplicate${skippedCount > 1 ? 's' : ''}');
    }

    if (errorCount > 0) {
      messages.add('$errorCount failed');
    }

    if (messages.isEmpty) {
      return 'No groups were imported';
    }

    return messages.join('. ');
  }

  static Future<List<FileSystemEntity>> getJsonFilesFromDocuments() async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${directory.path}/GroupXpenseExports');

    if (!await exportDir.exists()) {
      return [];
    }

    final files = exportDir
        .listSync()
        .where((file) => file.path.endsWith('.json'))
        .toList();

    files.sort((a, b) {
      final aStat = (a as File).statSync();
      final bStat = (b as File).statSync();
      return bStat.modified.compareTo(aStat.modified);
    });

    return files;
  }

  static Future<Map<String, dynamic>?> readAndValidateJson(
      String filePath,
      ) async {
    try {
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final data = json.decode(jsonString);

      // Validate structure
      if (data['version'] != '1.0') {
        return null;
      }

      // Check if it's a valid backup
      if (!data.containsKey('group') && !data.containsKey('groups')) {
        return null;
      }

      return data;
    } catch (e) {
      print('Error reading JSON: $e');
      return null;
    }
  }

  static Future<File?> pickFileFromDevice() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select Backup File',
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        return null;
      }

      return File(filePath);
    } catch (e) {
      print('File picker error: $e');
      return null;
    }
  }

  // Import from picked file
  static Future<String> importFromPickedFile() async {
    final file = await pickFileFromDevice();

    if (file == null) {
      throw Exception('No file selected');
    }

    // Validate file
    final preview = await readAndValidateJson(file.path);
    if (preview == null) {
      throw Exception(
        'Invalid backup file. Please select a valid Group Xpense backup JSON file.',
      );
    }

    // Import the file
    return await importFromFilePath(file.path);
  }

  static Future<File> copyFileToAppStorage(File sourceFile) async {
    final exportDir = await getExportDirectory();
    final fileName = sourceFile.path.split('/').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    var newFileName = fileName;
    var targetFile = File('${exportDir.path}/$newFileName');

    if (await targetFile.exists()) {
      final nameWithoutExt = fileName.replaceAll('.json', '');
      newFileName = '${nameWithoutExt}_$timestamp.json';
      targetFile = File('${exportDir.path}/$newFileName');
    }

    await sourceFile.copy(targetFile.path);
    return targetFile;
  }

  // Helper to check for duplicate groups before import
  static Future<List<String>> checkForDuplicates(String filePath) async {
    final data = await readAndValidateJson(filePath);
    if (data == null) return [];

    final duplicates = <String>[];

    if (data.containsKey('groups')) {
      for (var groupData in data['groups'] as List) {
        final groupId = groupData['group']['id'];
        final groupName = groupData['group']['name'];
        final existing = await _db.getGroup(groupId);
        if (existing != null) {
          duplicates.add(groupName);
        }
      }
    } else if (data.containsKey('group')) {
      final groupId = data['group']['id'];
      final groupName = data['group']['name'];
      final existing = await _db.getGroup(groupId);
      if (existing != null) {
        duplicates.add(groupName);
      }
    }

    return duplicates;
  }
}