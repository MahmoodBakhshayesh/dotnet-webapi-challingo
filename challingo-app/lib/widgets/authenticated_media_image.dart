import 'package:fast_cached_network_image/fast_cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/constants/apis.dart';
import '../core/data/app_data.dart';

/// Network image that sends the auth token as a `Bearer` header and caches
/// via [FastCachedImage]. Relative urls are resolved against [Apis.photoBaseUrl].
class AuthenticatedMediaImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final WidgetBuilder? placeholderBuilder;
  final Widget Function(BuildContext context, Object error, StackTrace? stackTrace)? errorBuilder;

  const AuthenticatedMediaImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = resolveMediaUrl(url);
    if (resolvedUrl == null) {
      return placeholderBuilder?.call(context) ?? const SizedBox.shrink();
    }
    final image = FastCachedImage(
      key: ValueKey(resolvedUrl),
      url: resolvedUrl,
      width: width,
      height: height,
      fit: fit,
      headers: mediaAuthHeaders(),
      loadingBuilder: placeholderBuilder == null ? null : (context, _) => placeholderBuilder!(context),
      errorBuilder: errorBuilder,
      showErrorLog: false,
    );
    final radius = borderRadius;
    if (radius == null) return image;
    return ClipRRect(borderRadius: radius, child: image);
  }
}

/// Square logo tile for rectangular brand assets.
class AuthenticatedMediaLogo extends StatelessWidget {
  final String? url;
  final double size;
  final Widget fallback;
  final Color? backgroundColor;
  final BoxBorder? border;
  final BoxFit fit;
  final BorderRadius borderRadius;

  const AuthenticatedMediaLogo({
    super.key,
    required this.url,
    required this.size,
    required this.fallback,
    this.backgroundColor,
    this.border,
    this.fit = BoxFit.contain,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: borderRadius,
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: AuthenticatedMediaImage(
        key: ValueKey(url),
        url: url,
        width: size,
        height: size,
        fit: fit,
        borderRadius: borderRadius,
        placeholderBuilder: (_) => fallback,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

/// Circular avatar with fallback widget while loading / on error.
class AuthenticatedMediaAvatar extends StatelessWidget {
  final String? url;
  final double size;
  final Widget fallback;
  final Color? backgroundColor;
  final Gradient? gradient;
  final BoxBorder? border;
  final BoxFit fit;

  const AuthenticatedMediaAvatar({
    super.key,
    required this.url,
    required this.size,
    required this.fallback,
    this.backgroundColor,
    this.gradient,
    this.border,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: gradient == null ? (backgroundColor ?? Colors.white) : null,
        gradient: gradient,
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: AuthenticatedMediaImage(
        key: ValueKey(url),
        url: url,
        width: size,
        height: size,
        fit: fit,
        borderRadius: BorderRadius.circular(size / 2),
        placeholderBuilder: (_) => fallback,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

Map<String, String>? mediaAuthHeaders() {
  final token = AppData.instance.token?.trim();
  if (token == null || token.isEmpty) return null;
  return {'Authorization': 'Bearer $token'};
}

/// Resolves relative media paths against [Apis.photoBaseUrl]; absolute urls pass through.
String? resolveMediaUrl(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  if (text.startsWith('http://') || text.startsWith('https://')) return text;
  final baseUrl = _withoutTrailingSlash(Apis.photoBaseUrl);
  if (text.startsWith('/')) return '$baseUrl$text';
  return '$baseUrl/$text';
}

/// Drops cached copies of a media url — call after uploading a replacement.
Future<void> evictFastCachedMediaUrl(String? value) async {
  final resolvedUrl = resolveMediaUrl(value);
  if (resolvedUrl == null) return;
  final headers = mediaAuthHeaders();
  await FastCachedImageConfig.deleteCachedImage(imageUrl: resolvedUrl, showLog: false);
  PaintingBinding.instance.imageCache.evict(FastCachedImageProvider(resolvedUrl, headers: headers));
  PaintingBinding.instance.imageCache.evict(NetworkImage(resolvedUrl, headers: headers));
}

String _withoutTrailingSlash(String value) => value.endsWith('/') ? value.substring(0, value.length - 1) : value;
