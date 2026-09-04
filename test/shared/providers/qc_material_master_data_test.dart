import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/services/api_service.dart';
import 'package:mobile/features/qc_material/screens/qc_material_form_screen.dart';
import 'package:mobile/shared/models/qc_material_master_data.dart';
import 'package:mobile/shared/models/qc_material_template_model.dart';
import 'package:mobile/shared/providers/qc_material_form_provider.dart';

const familyA = QCMaterialFamily(
  familyId: 'cable-family-a',
  name: 'KU FO ADSS G652D Marking Myrep',
  category: 'CABLE',
  active: true,
);
const familyB = QCMaterialFamily(
  familyId: 'cable-family-b',
  name: 'KD FO Single Mode G 652D',
  category: 'CABLE',
  active: true,
);
const vendorA = QCMaterialVendor(vendor: 'Vendor A', active: true);
const vendorB = QCMaterialVendor(vendor: 'Vendor B', active: true);
const materialA = QCMaterialOption(
  materialId: 'AC-ADSS-24D-MREP',
  materialName: 'KU FO ADSS 24 C G652D Marking Myrep',
  familyId: 'cable-family-a',
  active: true,
);
const materialA2 = QCMaterialOption(
  materialId: 'AC-ADSS-48D-MREP',
  materialName: 'KU FO ADSS 48 C G652D Marking Myrep',
  familyId: 'cable-family-a',
  active: true,
);
const materialB = QCMaterialOption(
  materialId: 'DC-SM-12D-G652D',
  materialName: 'KD FO Single Mode 12 core G 652D',
  familyId: 'cable-family-b',
  active: true,
);
const brandA = QCMaterialBrand(
  brand: 'Brand A',
  manufacturer: 'Factory A',
  active: true,
);
const brandB = QCMaterialBrand(
  brand: 'Brand B',
  manufacturer: 'Factory B',
  active: true,
);
const warehouse = QCWarehousePlant(
  plant: 'PL01',
  name: 'Warehouse Batam',
  area: 'Batam',
  branch: 'Batam',
  region: 'R1',
  active: true,
);

typedef VendorLoader = Future<List<QCMaterialVendor>> Function(
    String materialId);

class FakeMasterDataApi implements QCMaterialMasterDataApi {
  final Map<String, List<QCMaterialOption>> materialsByFamily = {
    familyA.familyId: [materialA, materialA2],
    familyB.familyId: [materialB],
  };
  final Map<String, List<QCMaterialOption>> materialsByVendor = {};
  final Map<String, List<QCMaterialVendor>> vendorsByMaterial = {};
  final Map<String, QCMaterialBrandResolution> resolutions = {};
  VendorLoader? vendorLoader;
  bool failVendors = false;
  int calls = 0;
  String? lastFamilyId;
  String? lastVendor;
  String? lastMaterialVendorFilter;

  @override
  Future<List<QCMaterialFamily>> fetchMaterialFamilies(
      {String query = ''}) async {
    calls++;
    final normalized = query.toLowerCase();
    return [familyA, familyB]
        .where((family) => family.name.toLowerCase().contains(normalized))
        .toList();
  }

  @override
  Future<List<QCMaterialVendor>> fetchMaterialVendors({
    String query = '',
    String? materialId,
  }) async {
    calls++;
    lastMaterialVendorFilter = materialId;
    if (failVendors) throw const ApiRequestException('Vendor gagal dimuat.');
    final values = vendorLoader != null
        ? await vendorLoader!(materialId!)
        : vendorsByMaterial[materialId] ?? const [];
    final normalized = query.toLowerCase();
    return values
        .where((vendor) => vendor.vendor.toLowerCase().contains(normalized))
        .toList();
  }

  @override
  Future<List<QCMaterialOption>> fetchMaterialOptions({
    String query = '',
    String? vendor,
    String? familyId,
  }) async {
    calls++;
    lastFamilyId = familyId;
    lastVendor = vendor;
    final values = familyId != null
        ? materialsByFamily[familyId] ?? const []
        : materialsByVendor[vendor] ?? const [];
    final normalized = query.toLowerCase();
    return values
        .where((material) =>
            material.materialId.toLowerCase().contains(normalized) ||
            (material.description?.toLowerCase().contains(normalized) ?? false))
        .toList();
  }

  @override
  Future<QCMaterialOption> fetchMaterialDetail(String materialId) async {
    calls++;
    return materialsByFamily.values
        .expand((materials) => materials)
        .firstWhere((material) => material.materialId == materialId);
  }

  @override
  Future<QCMaterialBrandResolution> fetchMaterialBrands({
    required String vendor,
    required String materialId,
  }) async {
    calls++;
    return resolutions['$vendor|$materialId'] ??
        QCMaterialBrandResolution(
          vendor: vendor,
          materialId: materialId,
          choices: const [],
        );
  }

  @override
  Future<List<QCWarehousePlant>> fetchWarehousePlants(
      {String query = ''}) async {
    calls++;
    return warehouse.name.toLowerCase().contains(query.toLowerCase())
        ? const [warehouse]
        : const [];
  }

  @override
  Future<QCWarehousePlant> fetchWarehousePlant(String plant) async {
    calls++;
    return warehouse;
  }
}

QCMaterialTemplate template({String category = 'CABLE'}) => QCMaterialTemplate(
      id: 'template-1',
      name: 'Cable inspection',
      code: 'QC-CABLE',
      category: category,
      description: '',
      checklistItems: const [],
    );

QCMaterialFormProvider providerFor(
  FakeMasterDataApi api, {
  String category = 'CABLE',
}) {
  final provider = QCMaterialFormProvider(masterDataApi: api);
  provider.init('template-1', template: template(category: category));
  return provider;
}

QCMaterialBrandResolution resolution(
  QCMaterialVendor vendor,
  QCMaterialOption material,
  List<QCMaterialBrand> choices,
) =>
    QCMaterialBrandResolution(
      vendor: vendor.vendor,
      materialId: material.materialId,
      choices: choices,
    );

void main() {
  testWidgets('cable form orders family, material, vendor, then warehouse',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: QCMaterialFormScreen(
          materialId: 'template-1',
          template: template(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final family = find.text('QC Material');
    final material = find.text('ID Material');
    final vendor = find.text('Nama Mitra Pabrikasi / Vendor');
    final warehouseField = find.text('Lokasi Warehouse Penerima');
    expect(family, findsOneWidget);
    expect(material, findsOneWidget);
    expect(vendor, findsOneWidget);
    expect(warehouseField, findsOneWidget);
    expect(
        tester.getTopLeft(family).dy, lessThan(tester.getTopLeft(material).dy));
    expect(
        tester.getTopLeft(material).dy, lessThan(tester.getTopLeft(vendor).dy));
    expect(
      tester.getTopLeft(vendor).dy,
      lessThan(tester.getTopLeft(warehouseField).dy),
    );
  });

  test('cable family filters material IDs and rejects another family',
      () async {
    final api = FakeMasterDataApi();
    final provider = providerFor(api);
    addTearDown(provider.dispose);

    expect(await provider.searchMaterialFamilies('ADSS'), [familyA]);
    final callsBeforeFamilySelection = api.calls;
    expect(await provider.searchMaterials(''), isEmpty);
    expect(api.calls, callsBeforeFamilySelection);
    provider.selectMaterialFamily(
      const QCMaterialFamily(
        familyId: 'pole-family',
        name: 'Pole',
        category: 'POLE',
        active: true,
      ),
    );
    expect(provider.selectedFamily, isNull);
    provider.selectMaterialFamily(familyA);
    expect(await provider.searchMaterials('48D'), [materialA2]);
    expect(api.lastFamilyId, familyA.familyId);
    expect(api.lastVendor, isNull);

    await provider.selectMaterial(materialB);
    expect(provider.selectedMaterial, isNull);
  });

  test('single vendor and brand auto-fill through manufacturer', () async {
    final api = FakeMasterDataApi()
      ..vendorsByMaterial[materialA.materialId] = const [vendorA]
      ..resolutions['${vendorA.vendor}|${materialA.materialId}'] =
          resolution(vendorA, materialA, const [brandA]);
    final provider = providerFor(api);
    addTearDown(provider.dispose);

    provider.selectMaterialFamily(familyA);
    await provider.selectMaterial(materialA);

    expect(api.lastMaterialVendorFilter, materialA.materialId);
    expect(provider.selectedVendor, vendorA);
    expect(provider.selectedBrand, brandA);
    expect(provider.selectedBrand?.manufacturer, 'Factory A');
  });

  test('multiple vendors and brands remain constrained selections', () async {
    final api = FakeMasterDataApi()
      ..vendorsByMaterial[materialA.materialId] = const [vendorA, vendorB]
      ..resolutions['${vendorB.vendor}|${materialA.materialId}'] =
          resolution(vendorB, materialA, const [brandA, brandB]);
    final provider = providerFor(api);
    addTearDown(provider.dispose);

    provider.selectMaterialFamily(familyA);
    await provider.selectMaterial(materialA);
    expect(provider.selectedVendor, isNull);
    expect(provider.vendorChoices, const [vendorA, vendorB]);
    expect(await provider.searchVendors('B'), const [vendorB]);

    await provider.selectVendor(vendorB);
    expect(provider.selectedBrand, isNull);
    expect(provider.brandChoices, const [brandA, brandB]);
    provider.selectBrand(brandB);
    expect(provider.selectedBrand?.manufacturer, 'Factory B');
  });

  test('changing family clears all dependent selections only', () async {
    final api = FakeMasterDataApi()
      ..vendorsByMaterial[materialA.materialId] = const [vendorA]
      ..resolutions['${vendorA.vendor}|${materialA.materialId}'] =
          resolution(vendorA, materialA, const [brandA]);
    final provider = providerFor(api);
    addTearDown(provider.dispose);

    await provider.selectWarehouse(warehouse);
    provider.selectMaterialFamily(familyA);
    await provider.selectMaterial(materialA);
    provider.selectMaterialFamily(familyB);

    expect(provider.selectedMaterial, isNull);
    expect(provider.selectedVendor, isNull);
    expect(provider.selectedBrand, isNull);
    expect(provider.selectedWarehouse?.plant, warehouse.plant);
  });

  test('stale vendor response cannot overwrite a newer material', () async {
    final first = Completer<List<QCMaterialVendor>>();
    final second = Completer<List<QCMaterialVendor>>();
    final api = FakeMasterDataApi()
      ..vendorLoader = (materialId) =>
          materialId == materialA.materialId ? first.future : second.future;
    final provider = providerFor(api);
    addTearDown(provider.dispose);
    provider.selectMaterialFamily(familyA);

    final firstSelection = provider.selectMaterial(materialA);
    final secondSelection = provider.selectMaterial(materialA2);
    second.complete(const [vendorB]);
    await secondSelection;
    first.complete(const [vendorA]);
    await firstSelection;

    expect(provider.selectedMaterial, materialA2);
    expect(provider.selectedVendor, vendorB);
    expect(provider.vendorChoices, const [vendorB]);
  });

  test('vendor API failure preserves family, material, and warehouse',
      () async {
    final api = FakeMasterDataApi()..failVendors = true;
    final provider = providerFor(api);
    addTearDown(provider.dispose);
    await provider.selectWarehouse(warehouse);
    provider.selectMaterialFamily(familyA);

    await provider.selectMaterial(materialA);

    expect(provider.selectedFamily, familyA);
    expect(provider.selectedMaterial, materialA);
    expect(provider.selectedWarehouse?.plant, warehouse.plant);
    expect(provider.vendorResolutionMessage, 'Vendor gagal dimuat.');
  });

  test('canonical cable chain round-trips in a local draft without API calls',
      () async {
    final api = FakeMasterDataApi()
      ..vendorsByMaterial[materialA.materialId] = const [vendorA]
      ..resolutions['${vendorA.vendor}|${materialA.materialId}'] =
          resolution(vendorA, materialA, const [brandA]);
    final original = providerFor(api);
    addTearDown(original.dispose);
    original.selectMaterialFamily(familyA);
    await original.selectMaterial(materialA);
    await original.selectWarehouse(warehouse);
    final draft = original.createLocalDraftSnapshot();
    final callsBeforeRestore = api.calls;

    final restored = providerFor(api);
    addTearDown(restored.dispose);
    await restored.restoreLocalDraftSnapshot(draft);

    expect(api.calls, callsBeforeRestore);
    expect(restored.selectedFamily?.familyId, familyA.familyId);
    expect(restored.selectedMaterial?.materialId, materialA.materialId);
    expect(restored.selectedVendor?.vendor, vendorA.vendor);
    expect(restored.selectedBrand?.manufacturer, brandA.manufacturer);
    expect(restored.selectedWarehouse?.plant, warehouse.plant);
  });

  test('legacy cable draft remains readable and requires explicit reselection',
      () async {
    final api = FakeMasterDataApi();
    final original = providerFor(api);
    addTearDown(original.dispose);
    final draft = original.createLocalDraftSnapshot();
    final general = Map<String, dynamic>.from(draft['general'] as Map)
      ..['materialId'] = materialA.materialId
      ..['vendorName'] = vendorA.vendor
      ..['brandName'] = brandA.brand
      ..remove('qcMaterialMasterData');
    draft['general'] = general;

    final restored = providerFor(api);
    addTearDown(restored.dispose);
    await restored.restoreLocalDraftSnapshot(draft);

    expect(restored.materialIdController.text, materialA.materialId);
    expect(restored.familyNeedsReselection, isTrue);
    expect(restored.materialNeedsReselection, isTrue);
    restored.validateGeneralInformation();
    expect(
      restored.generalFieldErrors[QCMaterialGeneralField.materialFamily],
      'Pilih ulang QC Material dari master data.',
    );
  });

  test('non-cable templates retain the existing vendor-first flow', () async {
    final api = FakeMasterDataApi()
      ..materialsByVendor[vendorA.vendor] = const [materialA]
      ..resolutions['${vendorA.vendor}|${materialA.materialId}'] =
          resolution(vendorA, materialA, const [brandA]);
    final provider = providerFor(api, category: 'POLE');
    addTearDown(provider.dispose);

    await provider.selectVendor(vendorA);
    expect(await provider.searchMaterials('ADSS'), const [materialA]);
    expect(api.lastVendor, vendorA.vendor);
    expect(api.lastFamilyId, isNull);
    await provider.selectMaterial(materialA);

    expect(provider.selectedFamily, isNull);
    expect(provider.selectedBrand, brandA);
  });
}
