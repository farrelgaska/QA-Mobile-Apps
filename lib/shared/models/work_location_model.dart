class WorkLocation {
  final String siteName;
  final String? area;
  final String? segment;
  final String? note;
  final bool isCustom;

  WorkLocation({
    required this.siteName,
    this.area,
    this.segment,
    this.note,
    required this.isCustom,
  });
}
