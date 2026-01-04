import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../services/export_import_service.dart';
import '../providers/expense_provider.dart';
import '../models/group.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/app_constants.dart';

class ExportImportScreen extends StatefulWidget {
  const ExportImportScreen({super.key});

  @override
  State<ExportImportScreen> createState() => _ExportImportScreenState();
}

class _ExportImportScreenState extends State<ExportImportScreen> {
  List<File> _exportedFiles = [];
  bool _loadingFiles = false;

  @override
  void initState() {
    super.initState();
    _loadExportedFiles();
  }

  Future<void> _loadExportedFiles() async {
    if (!mounted) return;
    setState(() => _loadingFiles = true);

    try {
      final files = await ExportImportService.getExportedFiles();
      if (mounted) {
        setState(() {
          _exportedFiles = files;
          _loadingFiles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingFiles = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load files: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        actions: [
          IconButton(
            icon: const Icon(Icons.drive_folder_upload),
            tooltip: 'Import from Device',
            onPressed: _importFromDevice,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildExportSection(context),
          const SizedBox(height: 16),
          _buildExportedFilesSection(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.teal[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.teal[700]),
                const SizedBox(width: 8),
                const Text(
                  'About Backup & Restore',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '• Export groups as JSON files\n'
              '• Files saved to app documents\n'
              '• Import from anywhere on device\n'
              '• Share via any app or import later\n'
              '• All data stored locally',
              style: TextStyle(color: Colors.grey[700], height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportSection(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create New Backup',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE0F2F1),
                  child: Icon(Icons.backup, color: Colors.teal),
                ),
                title: const Text('Backup All Groups'),
                subtitle: const Text('Save all groups to file'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _exportAllGroups(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE0F2F1),
                  child: Icon(Icons.folder, color: Colors.teal),
                ),
                title: const Text('Backup Single Group'),
                subtitle: const Text('Save a specific group'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _showGroupSelectionDialog(context, provider.groups),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExportedFilesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Saved Backups',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Card(
          color: Colors.blue[50],
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.drive_folder_upload, color: Colors.white),
            ),
            title: const Text(
              'Import from Device',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Browse and select a backup file from Downloads, Drive, etc.',
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.blue),
            onTap: _importFromDevice,
          ),
        ),

        const SizedBox(height: 16),

        if (_loadingFiles)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_exportedFiles.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No backup files found',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a backup or import from device',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          for (var file in _exportedFiles) _buildFileCard(file),
      ],
    );
  }

  Widget _buildFileCard(File file) {
    final fileName = file.path.split('/').last;
    final stats = file.statSync();
    final modifiedDate = DateFormat(
      'MMM dd, yyyy HH:mm',
    ).format(stats.modified);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE0F2F1),
          child: Icon(Icons.insert_drive_file, color: Colors.teal),
        ),
        title: Text(
          fileName,
          style: const TextStyle(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: FutureBuilder<String>(
          future: ExportImportService.getFileSize(file.path),
          builder: (context, snapshot) {
            final size = snapshot.data ?? 'Loading...';
            return Text('$modifiedDate • $size');
          },
        ),
        onTap: () => _importFile(file),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'import') {
              _importFile(file);
            } else if (value == 'share') {
              _shareFile(file);
            } else if (value == 'delete') {
              _deleteFile(file);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'import',
              child: Row(
                children: [
                  Icon(Icons.restore, color: Colors.teal, size: 20),
                  SizedBox(width: 12),
                  Text('Restore'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share, color: Colors.blue, size: 20),
                  SizedBox(width: 12),
                  Text('Share'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAllGroups(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Creating backup...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final file = await ExportImportService.exportAllGroupsToFile();

      if (context.mounted) {
        Navigator.pop(context);
        await _loadExportedFiles();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup saved: ${file.path.split('/').last}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () => _shareFile(file),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showGroupSelectionDialog(BuildContext context, List<Group> groups) {
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No groups to backup'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Group'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Text(
                    group.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(group.name),
                subtitle: Text('${group.members.length} members'),
                onTap: () {
                  Navigator.pop(context);
                  _exportSingleGroup(context, group.id, group.name);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportSingleGroup(
    BuildContext context,
    String groupId,
    String groupName,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Creating backup...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final file = await ExportImportService.exportGroupToFile(
        groupId,
        groupName,
      );

      if (context.mounted) {
        Navigator.pop(context);
        await _loadExportedFiles();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup saved: ${file.path.split('/').last}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () => _shareFile(file),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showImportDialog() async {
    if (_exportedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No backup files found'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedFile = await showDialog<File>(
      context: context,
      builder: (context) => _FileSelectionDialog(files: _exportedFiles),
    );

    if (selectedFile != null) {
      await _importFile(selectedFile);
    }
  }

  Future<void> _importFromDevice() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Opening file picker...'),
                ],
              ),
            ),
          ),
        ),
      );

      final file = await ExportImportService.pickFileFromDevice();

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No file selected'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final shouldImport = await _showFilePreviewDialog(file);
      if (shouldImport != true) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Restoring backup...'),
                ],
              ),
            ),
          ),
        ),
      );

      final message = await ExportImportService.importFromFilePath(file.path);

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      final shouldSave = await _showSaveToAppDialog();
      if (shouldSave == true) {
        await ExportImportService.copyFileToAppStorage(file);
        await _loadExportedFiles();
      }

      if (!mounted) return;
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      await provider.refreshGroups();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Close any open dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<bool?> _showFilePreviewDialog(File file) async {
    try {
      final preview = await ExportImportService.readAndValidateJson(file.path);

      if (preview == null) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invalid backup file. Please select a valid ${AppConstants.appName} backup.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return false;
      }

      final isAllGroups = preview.containsKey('groups');
      final fileName = file.path.split('/').last;
      final exportDate = preview['exportDate'] != null
          ? DateFormat(
              'MMM dd, yyyy HH:mm',
            ).format(DateTime.parse(preview['exportDate']))
          : 'Unknown';

      return showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Import'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal[100]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.teal[700],
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Backup Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[900],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildPreviewRow(
                        'File',
                        fileName,
                        Icons.insert_drive_file,
                      ),
                      _buildPreviewRow(
                        'Created',
                        exportDate,
                        Icons.calendar_today,
                      ),
                      if (isAllGroups) ...[
                        _buildPreviewRow(
                          'Type',
                          'Complete Backup',
                          Icons.backup,
                        ),
                        _buildPreviewRow(
                          'Groups',
                          '${(preview['groups'] as List).length}',
                          Icons.folder,
                        ),
                      ] else ...[
                        _buildPreviewRow('Type', 'Single Group', Icons.folder),
                        _buildPreviewRow(
                          'Group',
                          preview['group']['name'],
                          Icons.label,
                        ),
                        _buildPreviewRow(
                          'Expenses',
                          '${(preview['expenses'] as List).length}',
                          Icons.receipt,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Groups with duplicate IDs will be skipped.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reading file: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  Widget _buildPreviewRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.teal[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.teal[900],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showSaveToAppDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Backup?'),
        content: const Text(
          'Would you like to save a copy of this backup file to the app for quick access later?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No Thanks'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFile(File file) async {
    try {
      // Check for duplicates first
      final duplicates = await ExportImportService.checkForDuplicates(
        file.path,
      );

      if (duplicates.isNotEmpty && !mounted) return;

      // Show warning if duplicates exist
      if (duplicates.isNotEmpty) {
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[700]),
                const SizedBox(width: 8),
                const Text('Duplicate Groups Found'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'The following groups already exist and will be skipped:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: duplicates
                          .map(
                            (name) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 6,
                                    color: Colors.orange[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        color: Colors.orange[900],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Continue with import?',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );

        if (shouldContinue != true) return;
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Restoring backup...'),
                ],
              ),
            ),
          ),
        ),
      );

      final message = await ExportImportService.importFromFilePath(file.path);

      if (!mounted) return;
      Navigator.pop(context);

      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      await provider.refreshGroups();

      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // Determine color based on message
      Color bgColor = Colors.green;
      IconData icon = Icons.check_circle;

      if (message.toLowerCase().contains('skipped')) {
        bgColor = Colors.orange;
        icon = Icons.info;
      } else if (message.toLowerCase().contains('failed')) {
        bgColor = Colors.red;
        icon = Icons.error;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: bgColor,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _shareFile(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${AppConstants.appName} Backup',
        text: 'Backup file from ${AppConstants.appName} app',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteFile(File file) async {
    final fileName = file.path.split('/').last;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backup'),
        content: Text('Delete "$fileName"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ExportImportService.deleteExportedFile(file.path);
      await _loadExportedFiles();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _FileSelectionDialog extends StatefulWidget {
  final List<File> files;

  const _FileSelectionDialog({required this.files});

  @override
  State<_FileSelectionDialog> createState() => _FileSelectionDialogState();
}

class _FileSelectionDialogState extends State<_FileSelectionDialog> {
  File? _selectedFile;
  Map<String, dynamic>? _filePreview;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Backup File'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.files.length,
                itemBuilder: (context, index) {
                  final file = widget.files[index];
                  final fileName = file.path.split('/').last;
                  final stats = file.statSync();
                  final modifiedDate = DateFormat(
                    'MMM dd, yyyy HH:mm',
                  ).format(stats.modified);
                  final isSelected = _selectedFile?.path == file.path;

                  return Card(
                    color: isSelected ? Colors.teal[50] : null,
                    child: ListTile(
                      selected: isSelected,
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? Colors.teal
                            : const Color(0xFFE0F2F1),
                        child: Icon(
                          Icons.insert_drive_file,
                          color: isSelected ? Colors.white : Colors.teal,
                        ),
                      ),
                      title: Text(
                        fileName,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: FutureBuilder<String>(
                        future: ExportImportService.getFileSize(file.path),
                        builder: (context, snapshot) {
                          final size = snapshot.data ?? '...';
                          return Text(
                            '$modifiedDate\n$size',
                            style: const TextStyle(fontSize: 11),
                          );
                        },
                      ),
                      isThreeLine: true,
                      onTap: () => _selectFile(file),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.teal)
                          : null,
                    ),
                  );
                },
              ),
            ),
            if (_filePreview != null) ...[
              const Divider(height: 24),
              _buildPreviewInfo(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedFile != null && !_loading
              ? () => Navigator.pop(context, _selectedFile)
              : null,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Restore'),
        ),
      ],
    );
  }

  Future<void> _selectFile(File file) async {
    setState(() {
      _selectedFile = file;
      _loading = true;
      _filePreview = null;
    });

    try {
      final preview = await ExportImportService.readAndValidateJson(file.path);
      if (mounted) {
        setState(() {
          _filePreview = preview;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _filePreview = null;
        });
      }
    }
  }

  Widget _buildPreviewInfo() {
    if (_filePreview == null) return const SizedBox.shrink();

    final isAllGroups = _filePreview!.containsKey('groups');
    final exportDate = _filePreview!['exportDate'] != null
        ? DateFormat(
            'MMM dd, yyyy HH:mm',
          ).format(DateTime.parse(_filePreview!['exportDate']))
        : 'Unknown';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.teal[700], size: 16),
              const SizedBox(width: 6),
              Text(
                'Backup Info',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[900],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isAllGroups) ...[
            _buildInfoRow('Type', 'Complete Backup', Icons.backup),
            _buildInfoRow(
              'Groups',
              '${(_filePreview!['groups'] as List).length}',
              Icons.folder,
            ),
          ] else ...[
            _buildInfoRow('Type', 'Single Group', Icons.folder),
            _buildInfoRow('Name', _filePreview!['group']['name'], Icons.label),
            _buildInfoRow(
              'Expenses',
              '${(_filePreview!['expenses'] as List).length}',
              Icons.receipt,
            ),
          ],
          _buildInfoRow('Created', exportDate, Icons.calendar_today),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.teal[600]),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.teal[900],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
