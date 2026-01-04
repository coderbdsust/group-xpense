// lib/services/export_import_service.dart

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
      'version': '2.0',
      'exportDate': DateTime.now().toIso8601String(),
      'group': {
        'id': group.id,
        'name': group.name,
        'description': group.description,
        'createdAt': group.createdAt.toIso8601String(),
        'members': group.members.map((m) => m.toMap()).toList(),
      },
      'expenses': expenses.map((e) {
        return {
          'id': e.id,
          'groupId': e.groupId,
          'description': e.description,
          'amount': e.amount,
          'payers': e.payers.map((payer) {
            return {'person': payer.person.toMap(), 'amount': payer.amount};
          }).toList(),
          'participants': e.participants.map((p) => p.toMap()).toList(),
          'splits': e.splits,
          'date': e.date.toIso8601String(),
          'category': e.category,
          'notes': e.notes,
          'isSettlement': e.isSettlement,
        };
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
      'version': '2.0',
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

  // Export and share
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

  // Import group from JSON - returns result message
  static Future<String> importGroupFromJson(Map<String, dynamic> data) async {
    try {
      // Support both version 1.0 and 2.0
      final version = data['version'] as String;
      if (version != '1.0' && version != '2.0') {
        throw Exception('Unsupported backup version: $version');
      }

      final groupData = data['group'] as Map<String, dynamic>;
      final expensesData = data['expenses'] as List;

      // Check if group already exists - SKIP if it does
      final existingGroup = await _db.getGroup(groupData['id'] as String);

      if (existingGroup != null) {
        return 'skipped:${groupData['name']}';
      }

      // Parse members
      final membersData = groupData['members'] as List;
      final members = membersData.map((m) {
        final memberMap = m as Map<String, dynamic>;
        return Person(
          id: memberMap['id'] as String,
          name: memberMap['name'] as String,
          email: memberMap['email'] as String?,
          avatar: memberMap['avatar'] as String?,
        );
      }).toList();

      // Create group
      final group = Group(
        id: groupData['id'] as String,
        name: groupData['name'] as String,
        description: groupData['description'] as String?,
        members: members,
        createdAt: DateTime.parse(groupData['createdAt'] as String),
      );

      await _db.insertGroup(group);

      // Import expenses
      int successCount = 0;
      int skipCount = 0;

      for (var expenseData in expensesData) {
        try {
          final expenseMap = expenseData as Map<String, dynamic>;

          // Parse payers (support both v1.0 and v2.0)
          List<PayerShare> payers = [];

          if (version == '2.0' && expenseMap.containsKey('payers')) {
            // Version 2.0: Multiple payers
            final payersData = expenseMap['payers'] as List;
            payers = payersData.map((payerData) {
              final payerMap = payerData as Map<String, dynamic>;
              final personMap = payerMap['person'] as Map<String, dynamic>;

              final person = members.firstWhere(
                (m) => m.id == personMap['id'],
                orElse: () => Person(
                  id: personMap['id'] as String,
                  name: personMap['name'] as String,
                  email: personMap['email'] as String?,
                  avatar: personMap['avatar'] as String?,
                ),
              );

              return PayerShare(
                person: person,
                amount: (payerMap['amount'] as num).toDouble(),
              );
            }).toList();
          } else if (expenseMap.containsKey('paidBy')) {
            // Version 1.0: Single payer (backward compatibility)
            final paidByMap = expenseMap['paidBy'] as Map<String, dynamic>;
            final paidBy = members.firstWhere(
              (m) => m.id == paidByMap['id'],
              orElse: () => Person(
                id: paidByMap['id'] as String,
                name: paidByMap['name'] as String,
                email: paidByMap['email'] as String?,
                avatar: paidByMap['avatar'] as String?,
              ),
            );
            payers = [
              PayerShare(
                person: paidBy,
                amount: (expenseMap['amount'] as num).toDouble(),
              ),
            ];
          }

          // Parse participants
          final participantsData = expenseMap['participants'] as List;
          final participants = participantsData.map((p) {
            final pMap = p as Map<String, dynamic>;
            return members.firstWhere(
              (m) => m.id == pMap['id'],
              orElse: () => Person(
                id: pMap['id'] as String,
                name: pMap['name'] as String,
                email: pMap['email'] as String?,
                avatar: pMap['avatar'] as String?,
              ),
            );
          }).toList();

          // Parse splits
          final splitsMap = expenseMap['splits'] as Map<String, dynamic>;
          final splits = <String, double>{};
          splitsMap.forEach((key, value) {
            splits[key] = (value as num).toDouble();
          });

          final expense = Expense(
            id: expenseMap['id'] as String,
            groupId: expenseMap['groupId'] as String,
            description: expenseMap['description'] as String,
            amount: (expenseMap['amount'] as num).toDouble(),
            payers: payers,
            participants: participants,
            splits: splits,
            date: DateTime.parse(expenseMap['date'] as String),
            category: expenseMap['category'] as String?,
            notes: expenseMap['notes'] as String?,
            isSettlement: expenseMap['isSettlement'] == true,
          );

          await _db.insertExpense(expense);
          successCount++;
        } catch (e) {
          print('Skipped expense: $e');
          skipCount++;
          continue;
        }
      }

      if (successCount > 0) {
        return 'success:${groupData['name']}';
      } else {
        return 'error:${groupData['name']}';
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
      if (version != '1.0' && version != '2.0') {
        throw Exception('Unsupported backup version: $version');
      }

      final groupsData = data['groups'] as List;
      int successCount = 0;
      int skippedCount = 0;
      int errorCount = 0;

      for (var groupData in groupsData) {
        try {
          final result = await importGroupFromJson(
            groupData as Map<String, dynamic>,
          );

          if (result.startsWith('success:')) {
            successCount++;
          } else if (result.startsWith('skipped:')) {
            skippedCount++;
          } else if (result.startsWith('error:')) {
            errorCount++;
          }
        } catch (e) {
          print('Error importing group: $e');
          errorCount++;
        }
      }

      final messages = <String>[];

      if (successCount > 0) {
        messages.add(
          'Imported $successCount group${successCount > 1 ? 's' : ''}',
        );
      }

      if (skippedCount > 0) {
        messages.add(
          'Skipped $skippedCount duplicate${skippedCount > 1 ? 's' : ''}',
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
      if (version != '1.0' && version != '2.0') {
        print('Invalid version: $version');
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
        'Invalid backup file. Please select a valid Group Xpense backup JSON file.',
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

        final hasMultiPayers =
            version == '2.0' &&
            expensesData.any((e) {
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
