import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/auth_provider.dart';
import '../providers/project_provider.dart';

/// Dialogs for project management operations
class ProjectDialogs {
  /// Show dialog to create a new project
  static void showCreateProjectDialog(BuildContext context) {
    final urlController = TextEditingController();
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Target Website URL',
                hintText: 'https://example.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Project Name (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (urlController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a URL')),
                );
                return;
              }
              
              try {
                final projectProvider = context.read<ProjectProvider>();
                final authProvider = context.read<AuthProvider>();
                
                await projectProvider.createProject(
                  authProvider.apiService,
                  urlController.text,
                  nameController.text.isEmpty ? null : nameController.text,
                );
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Project created successfully!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  /// Show dialog to add a keyword to the current project
  static void showAddKeywordDialog(BuildContext context, ProjectProvider projectProvider, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _AddKeywordDialog(
          projectProvider: projectProvider,
          authProvider: authProvider,
        );
      },
    );
  }
}

/// Stateful widget for adding keywords with tabs for manual and CSV upload
class _AddKeywordDialog extends StatefulWidget {
  final ProjectProvider projectProvider;
  final AuthProvider authProvider;

  const _AddKeywordDialog({
    required this.projectProvider,
    required this.authProvider,
  });

  @override
  State<_AddKeywordDialog> createState() => _AddKeywordDialogState();
}

class _AddKeywordDialogState extends State<_AddKeywordDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _keywordController = TextEditingController();
  String? _selectedFileName;
  List<List<dynamic>>? _csvData;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _pickCsvFile() async {
    try {
      // On web, file_picker sometimes needs different configuration
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: kIsWeb, // Only use bytes on web
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // Web always provides bytes, desktop/mobile provides path
        if (file.bytes != null) {
          final csvString = utf8.decode(file.bytes!);
          print('CSV String length: ${csvString.length}');
          
          // Normalize line endings (handle \r\n, \n, or \r)
          final normalizedCsv = csvString.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
          
          // Parse with explicit eol character
          final csvData = const CsvToListConverter(
            eol: '\n',
            shouldParseNumbers: false, // Keep as strings to handle formatting
          ).convert(normalizedCsv);
          
          print('CSV parsed rows: ${csvData.length}');
          if (csvData.isNotEmpty) {
            print('First row (${csvData[0].length} columns): ${csvData[0]}');
            if (csvData.length > 1) {
              print('Second row (${csvData[1].length} columns): ${csvData[1]}');
            }
          }
          
          setState(() {
            _selectedFileName = file.name;
            _csvData = csvData;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not read file data. Please try again.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reading CSV: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _addManualKeyword() async {
    if (_keywordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a keyword')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await widget.projectProvider.addKeyword(
        widget.authProvider.apiService,
        _keywordController.text.trim(),
        null,
        null,
        null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keyword added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding keyword: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _uploadCsvKeywords() async {
    if (_csvData == null || _csvData!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a CSV file first')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      int successCount = 0;
      int errorCount = 0;

      // Detect header row and create column mapping
      Map<String, int> columnMap = {};
      int startIndex = 0;
      
      if (_csvData!.isNotEmpty) {
        final firstRow = _csvData![0];
        final hasHeader = firstRow.any((cell) => 
          cell.toString().toLowerCase().contains('keyword') ||
          cell.toString().toLowerCase().contains('volume')
        );
        
        if (hasHeader) {
          // Map column names to indices
          for (int i = 0; i < firstRow.length; i++) {
            final header = firstRow[i].toString().toLowerCase().trim();
            columnMap[header] = i;
          }
          startIndex = 1;
        } else {
          // No header, assume standard order: keyword, volume, competition, difficulty
          columnMap = {
            'keyword': 0,
            'volume': 1,
            'competition': 2,
            'seo_difficulty': 3,
          };
        }
      }

      // Helper function to get value from row by column name
      String? getValue(List<dynamic> row, List<String> possibleNames) {
        for (final name in possibleNames) {
          final index = columnMap[name];
          if (index != null && index < row.length) {
            final value = row[index]?.toString().trim();
            if (value != null && value.isNotEmpty) {
              return value;
            }
          }
        }
        return null;
      }

      for (int i = startIndex; i < _csvData!.length; i++) {
        final row = _csvData![i];
        if (row.isEmpty) continue;

        // Get keyword (required)
        final keyword = getValue(row, ['keyword', 'keywords']) ?? row[0].toString().trim();
        if (keyword.isEmpty) continue;

        try {
          // Get search volume (try multiple column name variations)
          int? searchVolume;
          final volumeStr = getValue(row, ['volume', 'search_volume', 'search volume']);
          if (volumeStr != null) {
            searchVolume = int.tryParse(volumeStr.replaceAll(',', ''));
          }

          // Get competition
          String? competition = getValue(row, ['competition', 'comp', 'ad_competition']);

          // Get SEO difficulty (try multiple column name variations)
          int? seoDifficulty;
          final difficultyStr = getValue(row, ['kd', 'difficulty', 'seo_difficulty', 'seo difficulty']);
          if (difficultyStr != null && difficultyStr.isNotEmpty) {
            seoDifficulty = int.tryParse(difficultyStr);
          }

          await widget.projectProvider.addKeyword(
            widget.authProvider.apiService,
            keyword,
            searchVolume,
            competition,
            seoDifficulty,
          );
          successCount++;
        } catch (e) {
          errorCount++;
          print('Error adding keyword "$keyword": $e');
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        
        String message = 'Successfully added $successCount keyword(s)';
        if (errorCount > 0) {
          message += ' ($errorCount failed)';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading keywords: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
        return AlertDialog(
      title: const Text('Add Keywords'),
      content: SizedBox(
        width: 500,
        child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Manual'),
                Tab(text: 'CSV Upload'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Manual entry tab
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                        controller: _keywordController,
                decoration: const InputDecoration(
                  labelText: 'Keyword',
                  hintText: 'Enter keyword to track',
                          border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                        enabled: !_isProcessing,
              ),
                      const SizedBox(height: 12),
              const Text(
                'Search volume and competition will be automatically fetched and tracked.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
                  ),
                  // CSV upload tab
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _pickCsvFile,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Choose CSV File'),
                      ),
                      const SizedBox(height: 12),
                      if (_selectedFileName != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedFileName!,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${_csvData!.length} rows',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        'CSV Format:\nColumn 1: Keyword (required)\nColumn 2: Search Volume (optional)\nColumn 3: Competition (optional)\nColumn 4: SEO Difficulty (optional)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
          ),
          actions: [
            TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
          onPressed: _isProcessing
              ? null
              : () {
                  if (_tabController.index == 0) {
                    _addManualKeyword();
                  } else {
                    _uploadCsvKeywords();
                  }
                },
          child: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_tabController.index == 0 ? 'Add' : 'Upload'),
            ),
          ],
    );
  }
}

