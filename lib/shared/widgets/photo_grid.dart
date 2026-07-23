import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../models/qc_photo_processing_entry.dart';

class PhotoGrid extends StatefulWidget {
  final List<String> photos;
  final List<XFile> localPhotos;
  final List<Uint8List> localPhotoBytes;
  final List<QCPhotoProcessingEntry> processingPhotos;
  final Map<String, Uint8List> uploadedPhotoPreviewBytes;
  final Function(int)? onDelete;

  const PhotoGrid({
    super.key,
    required this.photos,
    this.localPhotos = const [],
    this.localPhotoBytes = const [],
    this.processingPhotos = const [],
    this.uploadedPhotoPreviewBytes = const {},
    this.onDelete,
  });

  @override
  State<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<PhotoGrid> {
  final Map<String, String> _signedUrls = {};

  @override
  void initState() {
    super.initState();
    _resolveObjectPaths();
  }

  @override
  void didUpdateWidget(covariant PhotoGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.photos, widget.photos)) {
      _resolveObjectPaths();
    }
  }

  Future<void> _resolveObjectPaths() async {
    final paths = widget.photos
        .where(_isCanonicalObjectPath)
        .where((path) => !_signedUrls.containsKey(path))
        .toSet()
        .toList();
    try {
      for (int start = 0; start < paths.length; start += 50) {
        final end = start + 50 < paths.length ? start + 50 : paths.length;
        final resolved = await ApiService().resolveQCEvidenceSignedUrls(
          paths.sublist(start, end),
        );
        if (!mounted) return;
        setState(() => _signedUrls.addAll(resolved));
      }
    } catch (_) {
      // Keep the canonical path and show a placeholder if URL resolution fails.
    }
  }

  bool _isCanonicalObjectPath(String value) => RegExp(
    r'^reports/[A-Za-z0-9_-]{1,128}/(?:general/[0-9a-f-]{36}|checklist/[A-Za-z0-9_-]{1,128}/[0-9a-f-]{36})\.(?:jpg|png|webp|heic)$',
  ).hasMatch(value);

  Widget _buildRemoteImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const ColoredBox(
        color: AppColors.backgroundSoft,
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: AppColors.textSoft),
        ),
      ),
    );
  }

  Widget _buildStoredImage(String reference) {
    final previewBytes = widget.uploadedPhotoPreviewBytes[reference];
    if (previewBytes != null) {
      return Image.memory(previewBytes, fit: BoxFit.cover);
    }
    if (reference.startsWith('assets/')) {
      return Image.asset(reference, fit: BoxFit.cover);
    }

    final uri = Uri.tryParse(reference);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return _buildRemoteImage(reference);
    }

    final signedUrl = _signedUrls[reference];
    if (signedUrl != null) {
      return _buildRemoteImage(signedUrl);
    }
    return Image.asset('assets/images/placeholder.png', fit: BoxFit.cover);
  }

  Widget _buildLocalImage(int localIndex) {
    if (localIndex < widget.localPhotoBytes.length) {
      return Image.memory(
        widget.localPhotoBytes[localIndex],
        fit: BoxFit.cover,
      );
    }
    return Image.asset('assets/images/placeholder.png', fit: BoxFit.cover);
  }

  Widget _buildProcessingImage(QCPhotoProcessingEntry entry) {
    final placeholder = ColoredBox(
      key: Key('processing_photo_placeholder_${entry.id}'),
      color: AppColors.backgroundSoft,
      child: const Center(
        child: Icon(Icons.image_outlined, color: AppColors.textSoft),
      ),
    );
    final preview = entry.previewBytes;
    final image = preview == null
        ? placeholder
        : FutureBuilder<Uint8List>(
            future: preview,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes == null) return placeholder;
              return Image.memory(
                bytes,
                key: Key('processing_photo_preview_${entry.id}'),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => placeholder,
              );
            },
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            color: Colors.black54,
            child: Text(
              entry.processingLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImage(int index) {
    if (index < widget.photos.length) {
      return _buildStoredImage(widget.photos[index]);
    }
    final localIndex = index - widget.photos.length;
    if (localIndex < widget.localPhotos.length) {
      return _buildLocalImage(localIndex);
    }
    return _buildProcessingImage(
      widget.processingPhotos[localIndex - widget.localPhotos.length],
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoCount =
        widget.photos.length +
        widget.localPhotos.length +
        widget.processingPhotos.length;
    if (photoCount == 0) return const SizedBox.shrink();

    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: photoCount,
        itemBuilder: (context, index) {
          final Key photoKey;
          if (index < widget.photos.length) {
            photoKey = ValueKey<String>('stored:${widget.photos[index]}');
          } else if (index <
              widget.photos.length + widget.localPhotos.length) {
            photoKey = ObjectKey(
              widget.localPhotos[index - widget.photos.length],
            );
          } else {
            final processingIndex =
                index - widget.photos.length - widget.localPhotos.length;
            photoKey = ValueKey<String>(
              'processing:${widget.processingPhotos[processingIndex].id}',
            );
          }
          return Padding(
            key: photoKey,
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 300,
                              width: double.infinity,
                              child: _buildImage(index),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Tutup',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: _buildImage(index),
                    ),
                  ),
                ),
                if (widget.onDelete != null)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => widget.onDelete!(index),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.rejectedText,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
