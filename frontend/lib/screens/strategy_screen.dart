import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/strategy_provider.dart';

class StrategyScreen extends StatefulWidget {
  const StrategyScreen({super.key});

  @override
  State<StrategyScreen> createState() => _StrategyScreenState();
}

class _StrategyScreenState extends State<StrategyScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isCreatingStrategy = false;
  bool _showCreateForm = false;

  @override
  void initState() {
    super.initState();
    // Load strategies after build completes to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStrategies();
    });
  }

  Future<void> _loadStrategies() async {
    final strategyProvider = Provider.of<StrategyProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    await strategyProvider.loadAllStrategies(authProvider.apiService);
    await strategyProvider.loadActiveStrategy(authProvider.apiService);
  }

  Future<void> _createStrategy() async {
    if (_urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a target URL')),
      );
      return;
    }

    setState(() => _isCreatingStrategy = true);

    final strategyProvider = Provider.of<StrategyProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await strategyProvider.createStrategy(
        authProvider.apiService,
        _urlController.text,
        _nameController.text.isEmpty ? null : _nameController.text,
      );

      if (mounted) {
        _urlController.clear();
        _nameController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Strategy created!')),
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
        setState(() => _isCreatingStrategy = false);
      }
    }
  }

  Future<void> _refreshRankings() async {
    final strategyProvider = Provider.of<StrategyProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await strategyProvider.refreshRankings(authProvider.apiService);
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
    final strategyProvider = context.watch<StrategyProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Strategy'),
        actions: [
          if (strategyProvider.activeStrategy != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshRankings,
              tooltip: 'Refresh rankings',
            ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(authProvider.name ?? authProvider.email ?? 'User'),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sign out'),
                  dense: true,
                ),
                onTap: () async {
                  await authProvider.signOut();
                },
              ),
            ],
          ),
        ],
      ),
      body: strategyProvider.activeStrategy == null
          ? _buildNoStrategy()
          : _buildStrategyView(strategyProvider),
    );
  }

  Widget _buildNoStrategy() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.track_changes,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                'Create Your SEO Strategy',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Track your keyword rankings over time and see how your SEO efforts pay off.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Target URL',
                  hintText: 'https://mywebsite.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Strategy Name (optional)',
                  hintText: 'My Main Website',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isCreatingStrategy ? null : _createStrategy,
                  child: _isCreatingStrategy
                      ? const CircularProgressIndicator()
                      : const Text('Create Strategy'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStrategyView(StrategyProvider provider) {
    final strategy = provider.activeStrategy!;
    final keywords = provider.trackedKeywords;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Strategy header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.track_changes, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strategy.name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  strategy.targetUrl,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Keywords header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tracked Keywords',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${keywords.length} keywords',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Keywords list
              Expanded(
                child: keywords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No keywords tracked yet',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add keywords from chat to start tracking',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
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
                                      backgroundColor: _getPositionColor(keyword.currentPosition)
                                          .withOpacity(0.2),
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
                      ),
              ),
            ],
          ),
        ),
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
    super.dispose();
  }
}

