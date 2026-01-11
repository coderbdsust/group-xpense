// lib/services/export_import_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/group.dart';
import '../models/expense.dart';
import '../services/database_helper.dart';
import '../utils/app_constants.dart';

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
      'version': AppConstants.appVersion,
      'exportDate': DateTime.now().toIso8601String(),
      'group': group.toJson(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
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
      'version': AppConstants.appVersion,
      'exportDate': DateTime.now().toIso8601String(),
      'appName': AppConstants.appName,
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
    // Use ISO 8601 date format: YYYY-MM-DDTHH-MM-SS
    final isoDate = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final fileName = '${groupName.replaceAll(' ', '_')}_$isoDate.json';

    return await saveToLocalFileSystem(data, fileName);
  }

  // Export all groups to local file system
  static Future<File> exportAllGroupsToFile() async {
    final data = await exportAllGroupsToJson();
    // Use ISO 8601 date format: YYYY-MM-DDTHH-MM-SS
    final isoDate = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final fileName = 'group_xpense_backup_$isoDate.json';

    return await saveToLocalFileSystem(data, fileName);
  }

  // Export and share
  static Future<void> shareGroupFile(String groupId, String groupName) async {
    final file = await exportGroupToFile(groupId, groupName);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '${AppConstants.appName} - $groupName',
      text: 'Export from ${AppConstants.appName} app',
    );
  }

  // Export and share all
  static Future<void> shareAllGroupsFile() async {
    final file = await exportAllGroupsToFile();

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '${AppConstants.appName} - Complete Backup',
      text: 'Complete backup from ${AppConstants.appName} app',
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
    try {
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final data = json.decode(jsonString) as Map<String, dynamic>;

      if (data.containsKey('groups')) {
        return await importAllGroupsFromJson(data);
      } else if (data.containsKey('group')) {
        return await importGroupFromJson(data);
      } else {
        throw Exception('Invalid backup file format');
      }
    } catch (e) {
      print('Import error: $e');
      throw Exception('Failed to import: ${e.toString()}');
    }
  }

  // Import group from JSON - Multi-payer only
  static Future<String> importGroupFromJson(Map<String, dynamic> data) async {
    try {
      final version = data['version'] as String;
      if (version != AppConstants.appVersion) {
        throw Exception(
          'Unsupported backup version: $version. Please use ${AppConstants.appName} v$version to import this backup.',
        );
      }

      final groupData = data['group'] as Map<String, dynamic>;
      final expensesData = data['expenses'] as List;

      // Parse group using fromJson
      final group = Group.fromJson(groupData);

      // Check if group already exists
      final existingGroup = await _db.getGroup(group.id);

      if (existingGroup != null) {
        // Group exists - update it instead of skipping
        await _db.updateGroup(group);
      } else {
        // Group doesn't exist - insert it
        await _db.insertGroup(group);
      }

      // Import expenses with multi-payer support
      int successCount = 0;

      for (var expenseData in expensesData) {
        try {
          final expenseMap = expenseData as Map<String, dynamic>;

          // Parse expense using fromJson
          final expense = Expense.fromJson(expenseMap);

          // Validate payers
          if (expense.payers.isEmpty) {
            print('Skipped expense: No payers found');
            continue;
          }

          // insertExpense now handles upsert automatically
          await _db.insertExpense(expense);
          successCount++;
        } catch (e) {
          print('Skipped expense: $e');
          continue;
        }
      }

      final action = existingGroup != null ? 'updated' : 'imported';
      if (successCount > 0) {
        return 'success:${group.name}:$action';
      } else {
        return 'error:${group.name}';
      }
    } catch (e) {
      print('Failed to import group: $e');
      return 'error:${data['group']?['name'] ?? 'Unknown'}';
    }
  }

  // Import all groups from JSON with skip/count logic
  static Future<String> importAllGroupsFromJson(
      Map<String, dynamic> data,
      ) async {
    try {
      final version = data['version'] as String;
      if (version != AppConstants.appVersion) {
        throw Exception(
          'Unsupported backup version: $version. Please use ${AppConstants.appName} v$version to import this backup.',
        );
      }

      final groupsData = data['groups'] as List;
      int importedCount = 0;
      int updatedCount = 0;
      int errorCount = 0;

      for (var groupData in groupsData) {
        try {
          final result = await importGroupFromJson(
            groupData as Map<String, dynamic>,
          );

          if (result.startsWith('success:')) {
            if (result.contains(':imported')) {
              importedCount++;
            } else if (result.contains(':updated')) {
              updatedCount++;
            } else {
              // Fallback for old format
              importedCount++;
            }
          } else if (result.startsWith('error:')) {
            errorCount++;
          }
        } catch (e) {
          print('Error importing group: $e');
          errorCount++;
        }
      }

      final messages = <String>[];

      if (importedCount > 0) {
        messages.add(
          'Imported $importedCount new group${importedCount > 1 ? 's' : ''}',
        );
      }

      if (updatedCount > 0) {
        messages.add(
          'Updated $updatedCount existing group${updatedCount > 1 ? 's' : ''}',
        );
      }

      if (errorCount > 0) {
        messages.add('$errorCount failed');
      }

      if (messages.isEmpty) {
        return 'No groups were imported';
      }

      return messages.join('. ');
    } catch (e) {
      print('Import all groups error: $e');
      throw Exception('Failed to import groups: ${e.toString()}');
    }
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
      final data = json.decode(jsonString) as Map<String, dynamic>;

      final version = data['version'] as String?;
      if (version != AppConstants.appVersion) {
        print('Invalid version: $version (expected ${AppConstants.appVersion})');
        return null;
      }

      if (!data.containsKey('group') && !data.containsKey('groups')) {
        print('Missing group/groups key');
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

  static Future<String> importFromPickedFile() async {
    final file = await pickFileFromDevice();

    if (file == null) {
      throw Exception('No file selected');
    }

    final preview = await readAndValidateJson(file.path);
    if (preview == null) {
      throw Exception(
        'Invalid backup file. Please select a valid ${AppConstants.appName} v${AppConstants.appVersion} backup JSON file.',
      );
    }

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

  static Future<List<String>> checkForDuplicates(String filePath) async {
    try {
      final data = await readAndValidateJson(filePath);
      if (data == null) return [];

      final duplicates = <String>[];

      if (data.containsKey('groups')) {
        final groupsData = data['groups'] as List;
        for (var groupData in groupsData) {
          final groupMap = groupData as Map<String, dynamic>;
          final group = groupMap['group'] as Map<String, dynamic>;
          final groupId = group['id'] as String;
          final groupName = group['name'] as String;
          final existing = await _db.getGroup(groupId);
          if (existing != null) {
            duplicates.add(groupName);
          }
        }
      } else if (data.containsKey('group')) {
        final groupMap = data['group'] as Map<String, dynamic>;
        final groupId = groupMap['id'] as String;
        final groupName = groupMap['name'] as String;
        final existing = await _db.getGroup(groupId);
        if (existing != null) {
          duplicates.add(groupName);
        }
      }

      return duplicates;
    } catch (e) {
      print('Check duplicates error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getBackupInfo(String filePath) async {
    try {
      final data = await readAndValidateJson(filePath);
      if (data == null) return null;

      final version = data['version'] as String;
      final exportDate = data['exportDate'] as String;

      if (data.containsKey('groups')) {
        final totalGroups = data['totalGroups'] as int;
        final groupsData = data['groups'] as List;

        return {
          'type': 'all_groups',
          'version': version,
          'exportDate': exportDate,
          'totalGroups': totalGroups,
          'groupNames': groupsData.map((g) {
            final groupMap = g as Map<String, dynamic>;
            final group = groupMap['group'] as Map<String, dynamic>;
            return group['name'];
          }).toList(),
        };
      } else if (data.containsKey('group')) {
        final groupMap = data['group'] as Map<String, dynamic>;
        final groupName = groupMap['name'] as String;
        final expensesData = data['expenses'] as List;

        final hasSettlements = expensesData.any((e) {
          final expenseMap = e as Map<String, dynamic>;
          return expenseMap['isSettlement'] == true;
        });

        final hasMultiPayers = expensesData.any((e) {
          final expenseMap = e as Map<String, dynamic>;
          if (expenseMap.containsKey('payers')) {
            final payers = expenseMap['payers'] as List;
            return payers.length > 1;
          }
          return false;
        });

        return {
          'type': 'single_group',
          'version': version,
          'exportDate': exportDate,
          'groupName': groupName,
          'expenseCount': expensesData.length,
          'hasSettlements': hasSettlements,
          'hasMultiPayers': hasMultiPayers,
        };
      }

      return null;
    } catch (e) {
      print('Get backup info error: $e');
      return null;
    }
  }
}