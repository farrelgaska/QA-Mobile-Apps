import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';

class PhotoGrid extends StatefulWidget {
  final List<String> photos;
  final List<XFile> localPhotos;
  final Function(int)? onDelete;

  const PhotoGrid({
    super.key,
    required this.photos,
    this.localPhotos = const [],
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

  Widget _buildStoredImage(String reference) {
    if (reference.startsWith('assets/')) {
      return Image.asset(reference, fit: BoxFit.cover);
    }

    final uri = Uri.tryParse(reference);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return Image.network(reference, fit: BoxFit.cover);
    }

    final signedUrl = _signedUrls[reference];
    if (signedUrl != null) {
      return Image.network(signedUrl, fit: BoxFit.cover);
    }
    return Image.asset('assets/images/placeholder.png', fit: BoxFit.cover);
  }

  Widget _buildLocalImage(XFile photo) {
    return FutureBuilder<Uint8List>(
      future: photo.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        if (snapshot.hasError) {
          return Image.asset(
            'assets/images/placeholder.png',
            fit: BoxFit.cover,
          );
        }
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
    );
  }

  Widget _buildImage(int index) {
    if (index < widget.photos.length) {
      return _buildStoredImage(widget.photos[index]);
    }
    return _buildLocalImage(widget.localPhotos[index - widget.photos.length]);
  }

  @override
  Widget build(BuildContext context) {
    final photoCount = widget.photos.length + widget.localPhotos.length;
    if (photoCount == 0) return const SizedBox.shrink();

    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: photoCount,
        itemBuilder: (context, index) {
          return Padding(
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
