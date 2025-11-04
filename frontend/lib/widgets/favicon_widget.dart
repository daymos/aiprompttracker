import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FaviconWidget extends StatelessWidget {
  final String url;
  final double size;
  final double? iconSize;
  final ApiService? apiService;

  const FaviconWidget({
    super.key,
    required this.url,
    this.size = 48,
    this.iconSize,
    this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    final service = apiService ?? ApiService();
    final faviconUrl = service.getFaviconUrl(url);

    return SizedBox(
      width: size,
      height: size,
      child: Image.network(
        faviconUrl,
        fit: BoxFit.scaleDown,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            print('✅ Favicon loaded for $url: ${child.runtimeType}');
            return Container(
              color: Colors.blue.withOpacity(0.1), // Debug background
              child: child,
            );
          }
          // Show placeholder while loading
          return Center(
            child: Icon(
              Icons.language,
              size: iconSize ?? (size * 0.5),
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('❌ Favicon error for $url: $error');
          // Show placeholder icon on error
          return Center(
            child: Icon(
              Icons.language,
              size: iconSize ?? (size * 0.5),
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        },
      ),
    );
  }
}

