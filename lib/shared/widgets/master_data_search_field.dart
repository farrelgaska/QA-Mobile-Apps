import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';

class MasterDataSearchField<T> extends StatelessWidget {
  final Key? fieldKey;
  final String label;
  final String hintText;
  final String value;
  final String? valueSubtitle;
  final String? helperText;
  final String? errorText;
  final IconData prefixIcon;
  final bool enabled;
  final bool loading;
  final bool clearable;
  final Future<List<T>> Function(String query) search;
  final String Function(T option) optionTitle;
  final String? Function(T option)? optionSubtitle;
  final FutureOr<void> Function(T option) onSelected;
  final VoidCallback onClear;

  const MasterDataSearchField({
    super.key,
    this.fieldKey,
    required this.label,
    required this.hintText,
    required this.value,
    this.valueSubtitle,
    this.helperText,
    this.errorText,
    required this.prefixIcon,
    this.enabled = true,
    this.loading = false,
    this.clearable = true,
    required this.search,
    required this.optionTitle,
    this.optionSubtitle,
    required this.onSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: fieldKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          enabled: enabled,
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled && !loading ? () => _showSearch(context) : null,
            child: InputDecorator(
              isEmpty: value.isEmpty,
              decoration: InputDecoration(
                errorText: errorText,
                helperText: helperText,
                prefixIcon: Icon(prefixIcon, size: 20),
                suffixIcon: loading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : value.isNotEmpty && clearable
                        ? IconButton(
                            tooltip: 'Hapus pilihan $label',
                            onPressed: onClear,
                            icon: const Icon(Icons.clear),
                          )
                        : const Icon(Icons.arrow_drop_down),
              ),
              child: value.isEmpty
                  ? Text(
                      hintText,
                      style: const TextStyle(color: Color(0xFF9CA3AF)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (valueSubtitle?.isNotEmpty == true)
                          Text(
                            valueSubtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showSearch(BuildContext context) async {
    final popupTheme = AppTheme.lightTheme.copyWith(
      dividerColor: AppColors.borderSoft,
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textMain,
        subtitleTextStyle: TextStyle(color: AppColors.textMuted),
        selectedColor: AppColors.primary,
        selectedTileColor: AppColors.primarySoft,
      ),
    );
    final selected = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) => Theme(
        data: popupTheme,
        child: _MasterDataSearchSheet<T>(
          label: label,
          search: search,
          optionTitle: optionTitle,
          optionSubtitle: optionSubtitle,
        ),
      ),
    );
    if (selected != null) await onSelected(selected);
  }
}

class _MasterDataSearchSheet<T> extends StatefulWidget {
  final String label;
  final Future<List<T>> Function(String query) search;
  final String Function(T option) optionTitle;
  final String? Function(T option)? optionSubtitle;

  const _MasterDataSearchSheet({
    required this.label,
    required this.search,
    required this.optionTitle,
    this.optionSubtitle,
  });

  @override
  State<_MasterDataSearchSheet<T>> createState() =>
      _MasterDataSearchSheetState<T>();
}

class _MasterDataSearchSheetState<T> extends State<_MasterDataSearchSheet<T>> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<T> _options = const [];
  Object? _error;
  bool _loading = true;
  int _requestRevision = 0;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(value));
  }

  Future<void> _load(String query) async {
    final revision = ++_requestRevision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final options = await widget.search(query);
      if (!mounted || revision != _requestRevision) return;
      setState(() {
        _options = options;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || revision != _requestRevision) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.8,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          top: 16,
          right: 20,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pilih ${widget.label}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('master_data_search_input'),
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Cari ${widget.label.toLowerCase()}',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _load('');
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _load(_searchController.text),
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }
    if (_options.isEmpty) {
      return const Center(child: Text('Tidak ada data yang cocok.'));
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _options.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final option = _options[index];
        final subtitle = widget.optionSubtitle?.call(option);
        return ListTile(
          title: Text(
            widget.optionTitle(option),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: subtitle?.isNotEmpty == true
              ? Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          onTap: () => Navigator.pop(context, option),
        );
      },
    );
  }
}
