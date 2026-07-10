import type { QCMaterial } from '../types/material';

export const dummyMaterials: QCMaterial[] = [
  {
    id: 'MAT-001',
    name: 'Tiang Besi 7 Meter 3 Segmen',
    category: 'Tiang Besi',
    standard: 'SPLN T3.001-1:2020',
    checklistCount: 4,
    status: 'Aktif',
    updatedAt: '2026-07-01T10:00:00Z',
    checklistItems: [
      {
        id: 'MAT-001-C01',
        name: 'Ketebalan Seng (Galvanize Thickness)',
        standardLabel: 'min 80 micron',
        unit: 'micron',
        minVal: 80,
        requiredPhoto: true
      },
      {
        id: 'MAT-001-C02',
        name: 'Tebal Segmen Bawah (Segment 1)',
        standardLabel: 'min 4.0 mm',
        unit: 'mm',
        minVal: 4.0,
        requiredPhoto: false
      },
      {
        id: 'MAT-001-C03',
        name: 'Tebal Segmen Tengah (Segment 2)',
        standardLabel: 'min 3.5 mm',
        unit: 'mm',
        minVal: 3.5,
        requiredPhoto: false
      },
      {
        id: 'MAT-001-C04',
        name: 'Tebal Segmen Atas (Segment 3)',
        standardLabel: 'min 3.0 mm',
        unit: 'mm',
        minVal: 3.0,
        requiredPhoto: false
      }
    ]
  },
  {
    id: 'MAT-002',
    name: 'Tiang Besi 9 Meter 3 Segmen',
    category: 'Tiang Besi',
    standard: 'SPLN T3.001-1:2020',
    checklistCount: 4,
    status: 'Aktif',
    updatedAt: '2026-07-02T10:00:00Z',
    checklistItems: [
      {
        id: 'MAT-002-C01',
        name: 'Ketebalan Seng (Galvanize Thickness)',
        standardLabel: 'min 85 micron',
        unit: 'micron',
        minVal: 85,
        requiredPhoto: true
      },
      {
        id: 'MAT-002-C02',
        name: 'Tebal Segmen Bawah (Segment 1)',
        standardLabel: 'min 4.5 mm',
        unit: 'mm',
        minVal: 4.5,
        requiredPhoto: false
      },
      {
        id: 'MAT-002-C03',
        name: 'Tebal Segmen Tengah (Segment 2)',
        standardLabel: 'min 4.0 mm',
        unit: 'mm',
        minVal: 4.0,
        requiredPhoto: false
      },
      {
        id: 'MAT-002-C04',
        name: 'Tebal Segmen Atas (Segment 3)',
        standardLabel: 'min 3.2 mm',
        unit: 'mm',
        minVal: 3.2,
        requiredPhoto: false
      }
    ]
  },
  {
    id: 'MAT-003',
    name: 'Tiang 7 Meter 2 Segmen',
    category: 'Tiang Besi',
    standard: 'SPLN T3.001-1:2020',
    checklistCount: 3,
    status: 'Aktif',
    updatedAt: '2026-07-03T10:00:00Z',
    checklistItems: [
      {
        id: 'MAT-003-C01',
        name: 'Ketebalan Seng (Galvanize Thickness)',
        standardLabel: 'min 80 micron',
        unit: 'micron',
        minVal: 80,
        requiredPhoto: true
      },
      {
        id: 'MAT-003-C02',
        name: 'Tebal Segmen Bawah',
        standardLabel: 'min 4.0 mm',
        unit: 'mm',
        minVal: 4.0,
        requiredPhoto: false
      },
      {
        id: 'MAT-003-C03',
        name: 'Tebal Segmen Atas',
        standardLabel: 'min 3.2 mm',
        unit: 'mm',
        minVal: 3.2,
        requiredPhoto: false
      }
    ]
  },
  {
    id: 'MAT-004',
    name: 'Tiang Galvanis 6M Tanpa Sambungan',
    category: 'Tiang Besi',
    standard: 'SPLN T3.001-2:2021',
    checklistCount: 2,
    status: 'Aktif',
    updatedAt: '2026-07-04T10:00:00Z',
    checklistItems: [
      {
        id: 'MAT-004-C01',
        name: 'Ketebalan Seng (Galvanize Thickness)',
        standardLabel: 'min 75 micron',
        unit: 'micron',
        minVal: 75,
        requiredPhoto: true
      },
      {
        id: 'MAT-004-C02',
        name: 'Tebal Dinding Tiang',
        standardLabel: 'min 3.0 mm',
        unit: 'mm',
        minVal: 3.0,
        requiredPhoto: false
      }
    ]
  },
  {
    id: 'MAT-005',
    name: 'Tiang Beton 7 Meter Bulat',
    category: 'Tiang Beton',
    standard: 'SNI 1911-2015',
    checklistCount: 3,
    status: 'Aktif',
    updatedAt: '2026-07-05T10:00:00Z',
    checklistItems: [
      {
        id: 'MAT-005-C01',
        name: 'Kuat Tekan Beton',
        standardLabel: 'min 350 kg/cm2',
        unit: 'kg/cm2',
        minVal: 350,
        requiredPhoto: true
      },
      {
        id: 'MAT-005-C02',
        name: 'Diameter Bawah',
        standardLabel: '140 - 150 mm',
        unit: 'mm',
        minVal: 140,
        maxVal: 150,
        requiredPhoto: false
      },
      {
        id: 'MAT-005-C03',
        name: 'Diameter Atas',
        standardLabel: '110 - 120 mm',
        unit: 'mm',
        minVal: 110,
        maxVal: 120,
        requiredPhoto: false
      }
    ]
  },
  {
    id: 'MAT-006',
    name: 'Tiang Besi 11 Meter 3 Segmen',
    category: 'Tiang Besi',
    standard: 'SPLN T3.001-1:2020',
    checklistCount: 4,
    status: 'Nonaktif',
    updatedAt: '2026-07-06T10:00:00Z',
    checklistItems: [
      {
        id: 'MAT-006-C01',
        name: 'Ketebalan Seng (Galvanize Thickness)',
        standardLabel: 'min 90 micron',
        unit: 'micron',
        minVal: 90,
        requiredPhoto: true
      },
      {
        id: 'MAT-006-C02',
        name: 'Tebal Segmen Bawah (Segment 1)',
        standardLabel: 'min 5.0 mm',
        unit: 'mm',
        minVal: 5.0,
        requiredPhoto: false
      },
      {
        id: 'MAT-006-C03',
        name: 'Tebal Segmen Tengah (Segment 2)',
        standardLabel: 'min 4.5 mm',
        unit: 'mm',
        minVal: 4.5,
        requiredPhoto: false
      },
      {
        id: 'MAT-006-C04',
        name: 'Tebal Segmen Atas (Segment 3)',
        standardLabel: 'min 3.6 mm',
        unit: 'mm',
        minVal: 3.6,
        requiredPhoto: false
      }
    ]
  }
];
