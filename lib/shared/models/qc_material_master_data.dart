class QCMaterialFamily {
  final String familyId;
  final String name;
  final String category;
  final bool active;

  const QCMaterialFamily({
    required this.familyId,
    required this.name,
    required this.category,
    required this.active,
  });

  factory QCMaterialFamily.fromJson(Map<String, dynamic> json) =>
      QCMaterialFamily(
        familyId: _requiredString(json, 'family_id'),
        name: _requiredString(json, 'name'),
        category: _requiredString(json, 'category'),
        active: json['active'] == true,
      );

  Map<String, dynamic> toJson() => {
        'family_id': familyId,
        'name': name,
        'category': category,
        'active': active,
      };
}

class QCMaterialVendor {
  final String vendor;
  final bool active;

  const QCMaterialVendor({required this.vendor, required this.active});

  factory QCMaterialVendor.fromJson(Map<String, dynamic> json) =>
      QCMaterialVendor(
        vendor: _requiredString(json, 'vendor'),
        active: json['active'] == true,
      );

  Map<String, dynamic> toJson() => {'vendor': vendor, 'active': active};
}

class QCMaterialOption {
  final String materialId;
  final String? materialDescription;
  final String? materialName;
  final String? familyId;
  final bool active;

  const QCMaterialOption({
    required this.materialId,
    this.materialDescription,
    this.materialName,
    this.familyId,
    required this.active,
  });

  String? get description => materialDescription ?? materialName;

  factory QCMaterialOption.fromJson(Map<String, dynamic> json) =>
      QCMaterialOption(
        materialId: _requiredString(json, 'material_id'),
        materialDescription: _optionalString(json['material_description']),
        materialName: _optionalString(json['material_name']),
        familyId: _optionalString(json['family_id']),
        active: json['active'] == true,
      );

  Map<String, dynamic> toJson() => {
        'material_id': materialId,
        'material_description': materialDescription,
        'material_name': materialName,
        'family_id': familyId,
        'active': active,
      };
}

class QCMaterialBrand {
  final String brand;
  final String? manufacturer;
  final String? materialName;
  final String? materialDescription;
  final String? sapMaterialId;
  final String? category;
  final bool active;

  const QCMaterialBrand({
    required this.brand,
    this.manufacturer,
    this.materialName,
    this.materialDescription,
    this.sapMaterialId,
    this.category,
    required this.active,
  });

  factory QCMaterialBrand.fromJson(Map<String, dynamic> json) =>
      QCMaterialBrand(
        brand: _requiredString(json, 'brand'),
        manufacturer: _optionalString(json['manufacturer']),
        materialName: _optionalString(json['material_name']),
        materialDescription: _optionalString(json['material_description']),
        sapMaterialId: _optionalString(json['sap_material_id']),
        category: _optionalString(json['category']),
        active: json['active'] == true,
      );

  Map<String, dynamic> toJson() => {
        'brand': brand,
        'manufacturer': manufacturer,
        'material_name': materialName,
        'material_description': materialDescription,
        'sap_material_id': sapMaterialId,
        'category': category,
        'active': active,
      };
}

class QCMaterialBrandResolution {
  final String vendor;
  final String materialId;
  final List<QCMaterialBrand> choices;
  final QCMaterialBrand? resolved;

  const QCMaterialBrandResolution({
    required this.vendor,
    required this.materialId,
    required this.choices,
    this.resolved,
  });

  factory QCMaterialBrandResolution.fromJson(Map<String, dynamic> json) {
    final rawChoices = json['choices'];
    if (rawChoices is! List) {
      throw const FormatException('choices must be a list');
    }
    final rawResolved = json['resolved'];
    return QCMaterialBrandResolution(
      vendor: _requiredString(json, 'vendor'),
      materialId: _requiredString(json, 'material_id'),
      choices: rawChoices
          .map((item) => QCMaterialBrand.fromJson(_map(item)))
          .toList(growable: false),
      resolved: rawResolved == null
          ? null
          : QCMaterialBrand.fromJson(_map(rawResolved)),
    );
  }
}

class QCWarehousePlant {
  final String plant;
  final String name;
  final String area;
  final String branch;
  final String region;
  final bool active;

  const QCWarehousePlant({
    required this.plant,
    required this.name,
    required this.area,
    required this.branch,
    required this.region,
    required this.active,
  });

  factory QCWarehousePlant.fromJson(Map<String, dynamic> json) =>
      QCWarehousePlant(
        plant: _requiredString(json, 'plant'),
        name: _requiredString(json, 'name'),
        area: _optionalString(json['area']) ?? '',
        branch: _optionalString(json['branch']) ?? '',
        region: _optionalString(json['region']) ?? '',
        active: json['active'] == true,
      );

  Map<String, dynamic> toJson() => {
        'plant': plant,
        'name': name,
        'area': area,
        'branch': branch,
        'region': region,
        'active': active,
      };
}

Map<String, dynamic> _map(dynamic value) {
  if (value is! Map) throw const FormatException('item must be an object');
  return Map<String, dynamic>.from(value);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _optionalString(json[key]);
  if (value == null) throw FormatException('$key must be a non-empty string');
  return value;
}

String? _optionalString(dynamic value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('value must be a string');
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
