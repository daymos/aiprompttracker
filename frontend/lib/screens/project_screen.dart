import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/project_provider.dart';
import '../services/api_service.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isCreatingProject = false;
  bool _showCreateForm = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);  // Changed from 3 to 4
    // Load projects after build completes to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProjects();
    });
  }

  Future<void> _loadProjects() async {
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    await projectProvider.loadAllProjects(authProvider.apiService);
    await projectProvider.loadActiveProject(authProvider.apiService);
  }

  Future<void> _createProject() async {
    if (_urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a target URL')),
      );
      return;
    }

    setState(() => _isCreatingProject = true);

    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await projectProvider.createProject(
        authProvider.apiService,
        _urlController.text,
        _nameController.text.isEmpty ? null : _nameController.text,
      );

      // Clear form and hide it
      _urlController.clear();
      _nameController.clear();
      setState(() {
        _showCreateForm = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingProject = false);
      }
    }
  }

  Future<void> _refreshRankings() async {
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await projectProvider.refreshRankings(authProvider.apiService);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rankings updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final projectProvider = context.watch<ProjectProvider>();
    final selectedProject = projectProvider.selectedProject;
    final allProjects = projectProvider.allProjects;
    final keywords = projectProvider.trackedKeywords;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.purple,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Q',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text('My SEO Projects'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'v1.0.2+3',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          if (selectedProject != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: projectProvider.isLoading ? null : _refreshRankings,
              tooltip: 'Refresh Rankings',
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              setState(() {
                _showCreateForm = !_showCreateForm;
              });
            },
            tooltip: 'Add Project',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Create Strategy Form
                if (_showCreateForm)
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Create New Project',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _showCreateForm = false;
                                    _urlController.clear();
                                    _nameController.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _urlController,
                            decoration: const InputDecoration(
                              labelText: 'Target Website URL',
                              hintText: 'https://example.com',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Project Name (Optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _isCreatingProject
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton.icon(
                                  onPressed: _createProject,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create Project'),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(50),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                
                // Empty state
                if (allProjects.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.track_changes,
                            size: 64,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No SEO Projects Yet',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create your first SEO project to start tracking keywords',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showCreateForm = true;
                              });
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Create Project'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (selectedProject != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Project Header Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedProject.name,
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        selectedProject.targetUrl,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // GSC Status
                                      Row(
                                        children: [
                                          Icon(
                                            selectedProject.isGSCLinked ? Icons.check_circle : Icons.link_off,
                                            size: 16,
                                            color: selectedProject.isGSCLinked ? Colors.green : Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            selectedProject.isGSCLinked 
                                                ? 'GSC Connected' 
                                                : 'GSC Not Connected',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: selectedProject.isGSCLinked ? Colors.green : Colors.grey,
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
                        ),
                        const SizedBox(height: 16),
                        
                        // Tab Bar
                        TabBar(
                          controller: _tabController,
                          tabs: const [
                            Tab(
                              icon: Icon(Icons.push_pin),
                              text: 'Pinboard',
                            ),
                            Tab(
                              icon: Icon(Icons.key),
                              text: 'Keywords',
                            ),
                            Tab(
                              icon: Icon(Icons.link),
                              text: 'Backlinks',
                            ),
                            Tab(
                              icon: Icon(Icons.search),
                              text: 'GSC',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Tab Bar View
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Pinboard Tab
                              _buildPinboardTab(),
                              
                              // Keywords Tab
                              _buildKeywordsTab(projectProvider, keywords),
                              
                              // Backlinks Tab
                              _buildBacklinksTab(),
                              
                              // GSC Tab
                              _buildGSCTab(selectedProject, authProvider.apiService),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinboardTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.push_pin_outlined,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Pinboard',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save and organize important insights, data, and findings',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement add pin functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon!')),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Pin'),
          ),
        ],
      ),
    );
  }

  Widget _buildKeywordsTab(ProjectProvider projectProvider, List<dynamic> keywords) {
    if (projectProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (keywords.isEmpty) {
      return const Center(
        child: Text('No keywords tracked yet. Add some from the chat!'),
      );
    }
    
    return ListView.builder(
      itemCount: keywords.length,
      itemBuilder: (context, index) {
        final keyword = keywords[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () {
              Navigator.pushNamed(
                context,
                '/keyword-detail',
                arguments: {
                  'keywordId': keyword.id,
                  'keyword': keyword.keyword,
                  'currentPosition': keyword.currentPosition,
                },
              );
            },
            leading: CircleAvatar(
              backgroundColor: _getPositionColor(keyword.currentPosition),
              child: Text(
                keyword.currentPosition?.toString() ?? '--',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              keyword.keyword,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${keyword.searchVolume ?? '--'} searches/mo • ${keyword.competition ?? 'UNKNOWN'} competition',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (keyword.currentPosition != null)
                  Chip(
                    label: Text('Position ${keyword.currentPosition}'),
                    backgroundColor: _getPositionColor(keyword.currentPosition).withOpacity(0.2),
                  )
                else
                  const Chip(
                    label: Text('Not ranked'),
                    backgroundColor: Colors.grey,
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBacklinksTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.link,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Backlinks',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track and manage backlinks to your site',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement backlinks functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon!')),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Backlink'),
          ),
        ],
      ),
    );
  }

  Widget _buildGSCTab(Project project, ApiService apiService) {
    return FutureBuilder(
      future: _loadGSCData(project, apiService),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final gscData = snapshot.data as Map<String, dynamic>?;
        
        if (!project.isGSCLinked) {
          return _buildGSCLinkingUI(project, apiService);
        }

        return _buildGSCDataUI(project, gscData, apiService);
      },
    );
  }

  Future<Map<String, dynamic>?> _loadGSCData(Project project, ApiService apiService) async {
    if (!project.isGSCLinked) {
      return null;
    }

    try {
      final analytics = await apiService.getGSCAnalytics(project.id);
      final sitemaps = await apiService.getGSCSitemaps(project.id);
      
      return {
        'analytics': analytics,
        'sitemaps': sitemaps,
      };
    } catch (e) {
      // Return null if GSC data fails (user may not have permission or token expired)
      return null;
    }
  }

  Widget _buildGSCLinkingUI(Project project, ApiService apiService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Google Search Console',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect this project to GSC to view real Google data',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showGSCLinkDialog(project, apiService),
            icon: const Icon(Icons.link),
            label: const Text('Link to GSC Property'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(200, 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGSCDataUI(Project project, Map<String, dynamic>? gscData, ApiService apiService) {
    if (gscData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Unable to load GSC data'),
            const SizedBox(height: 8),
            const Text(
              'Your GSC token may have expired or you may not have permission',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final analytics = gscData['analytics'] as Map<String, dynamic>;
    final sitemaps = gscData['sitemaps'] as List;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with unlink button
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text('Linked to: ${project.gscPropertyUrl}'),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showGSCLinkDialog(project, apiService),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Analytics Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Performance',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        '${analytics['start_date']} to ${analytics['end_date']}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Clicks',
                          analytics['total_clicks'].toString(),
                          Icons.mouse,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Impressions',
                          analytics['total_impressions'].toString(),
                          Icons.visibility,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'CTR',
                          '${analytics['average_ctr']}%',
                          Icons.trending_up,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Avg Position',
                          analytics['average_position'].toString(),
                          Icons.military_tech,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sitemaps Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.map, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Sitemaps',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  if (sitemaps.isEmpty)
                    const Text('⚠️  No sitemaps found', style: TextStyle(color: Colors.red))
                  else
                    ...sitemaps.map((sitemap) => ListTile(
                      leading: Icon(
                        sitemap['errors'] > 0 ? Icons.error : Icons.check_circle,
                        color: sitemap['errors'] > 0 ? Colors.red : Colors.green,
                      ),
                      title: Text(sitemap['path']),
                      subtitle: Text(
                        'Last submitted: ${sitemap['last_submitted']}\n'
                        'Errors: ${sitemap['errors']}, Warnings: ${sitemap['warnings']}',
                      ),
                    )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Future<void> _showGSCLinkDialog(Project project, ApiService apiService) async {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: apiService.getGSCProperties(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              content: SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          if (snapshot.hasError) {
            return AlertDialog(
              title: const Text('Error'),
              content: Text('Failed to load GSC properties: ${snapshot.error}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          }

          final properties = snapshot.data!;

          if (properties.isEmpty) {
            return AlertDialog(
              title: const Text('No Properties Found'),
              content: const Text(
                'No verified properties found in your Google Search Console. '
                'Please verify a website in GSC first.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Link GSC Property'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: properties.length,
                itemBuilder: (context, index) {
                  final property = properties[index];
                  return ListTile(
                    leading: const Icon(Icons.public),
                    title: Text(property['site_url']),
                    subtitle: Text(property['permission_level']),
                    trailing: project.gscPropertyUrl == property['site_url']
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        await apiService.linkProjectToGSCProperty(
                          project.id,
                          property['site_url'],
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('GSC property linked!')),
                          );
                          setState(() {}); // Refresh the UI
                          await _loadProjects(); // Reload projects
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
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
          );
        },
      ),
    );
  }

  Color _getPositionColor(int? position) {
    if (position == null) return Colors.grey;
    if (position <= 3) return Colors.green;
    if (position <= 10) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}
