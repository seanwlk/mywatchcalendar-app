import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UniversalImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final int? memCacheWidth;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final Duration? fadeInDuration;

  const UniversalImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.memCacheWidth,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: memCacheWidth,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          
          if (placeholder != null) {
            return placeholder!(context, imageUrl);
          }
          return const SizedBox.shrink();
        },
        errorBuilder: (context, error, stackTrace) {
          if (errorWidget != null) {
            return errorWidget!(context, imageUrl, error);
          }
          return const Icon(Icons.broken_image);
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      fadeInDuration: fadeInDuration ?? const Duration(milliseconds: 500),
      placeholder: placeholder,
      errorWidget: errorWidget ?? (_, _, _) => const Icon(Icons.broken_image),
    );
  }
}