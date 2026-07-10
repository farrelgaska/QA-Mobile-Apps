import type { QCReport } from '../types/report';

export const dummyReports: QCReport[] = [
  {
    id: 'REP-001',
    type: 'material',
    title: 'Pemeriksaan Tiang Besi 7 Meter 3 Segmen',
    locationName: 'Bekasi Site',
    submittedBy: 'Ahmad Syarif',
    submittedByNik: '120001',
    submittedAt: '2026-07-09T08:30:00Z',
    status: 'Menunggu Review',
    standardResult: 'Perlu Review',
    checklistItems: [
      {
        id: 'REP-001-C01',
        name: 'Ketebalan Seng (Galvanize Thickness)',
        standardLabel: 'min 80 micron',
        actualValue: '82',
        unit: 'micron',
        result: 'pass',
        photoUrls: ['https://images.unsplash.com/photo-1581094288338-2314dddb7ecc?w=600&auto=format&fit=crop&q=60']
      },
      {
        id: 'REP-001-C02',
        name: 'Tebal Segmen Bawah (Segment 1)',
        standardLabel: 'min 4.0 mm',
        actualValue: '4.1',
        unit: 'mm',
        result: 'pass',
        photoUrls: []
      },
      {
        id: 'REP-001-C03',
        name: 'Tebal Segmen Tengah (Segment 2)',
        standardLabel: 'min 3.5 mm',
        actualValue: '3.6',
        unit: 'mm',
        result: 'pass',
        photoUrls: []
      },
      {
        id: 'REP-001-C04',
        name: 'Tebal Segmen Atas (Segment 3)',
        standardLabel: 'min 3.0 mm',
        actualValue: '2.9',
        unit: 'mm',
        result: 'fail',
        photoUrls: [],
        adminNote: 'Tebal kurang dari batas minimum 3.0 mm'
      }
    ],
    photos: [
      'https://images.unsplash.com/photo-1581094288338-2314dddb7ecc?w=600&auto=format&fit=crop&q=60'
    ]
  },
  {
    id: 'REP-002',
    type: 'pekerjaan',
    title: 'Pemasangan Tiang (Erection)',
    locationName: 'Cikarang Plant',
    submittedBy: 'Budi Hartono',
    submittedByNik: '120002',
    submittedAt: '2026-07-09T09:15:00Z',
    status: 'Menunggu Review',
    standardResult: 'Perlu Review',
    checklistItems: [
      {
        id: 'REP-002-C01',
        name: 'Kelurusan tiang diukur dengan waterpass',
        standardLabel: 'Tegak lurus (90 derajat)',
        actualValue: '90',
        unit: 'derajat',
        result: 'pass',
        photoUrls: ['https://images.unsplash.com/photo-1541888946425-d81bb19240f5?w=600&auto=format&fit=crop&q=60']
      },
      {
        id: 'REP-002-C02',
        name: 'Kekencangan baut angkur (torque check)',
        standardLabel: 'Kencang merata',
        actualValue: 'Kencang',
        result: 'pass',
        photoUrls: []
      },
      {
        id: 'REP-002-C03',
        name: 'Pengecatan ulang area sambungan segmen',
        standardLabel: 'Rapi & menutup sempurna',
        actualValue: 'Belum dicat',
        result: 'fail',
        photoUrls: ['https://images.unsplash.com/photo-1590069261209-f8e9b8642343?w=600&auto=format&fit=crop&q=60'],
        adminNote: 'Cat sambungan masih terkelupas'
      }
    ],
    photos: [
      'https://images.unsplash.com/photo-1541888946425-d81bb19240f5?w=600&auto=format&fit=crop&q=60',
      'https://images.unsplash.com/photo-1590069261209-f8e9b8642343?w=600&auto=format&fit=crop&q=60'
    ]
  },
  {
    id: 'REP-003',
    type: 'material',
    title: 'Inspeksi Tiang Beton 7 Meter Bulat',
    locationName: 'Bandung Site',
    submittedBy: 'Cecep Solihin',
    submittedByNik: '120003',
    submittedAt: '2026-07-08T10:00:00Z',
    status: 'Disetujui',
    standardResult: 'Lulus',
    checklistItems: [
      {
        id: 'REP-003-C01',
        name: 'Kuat Tekan Beton',
        standardLabel: 'min 350 kg/cm2',
        actualValue: '365',
        unit: 'kg/cm2',
        result: 'pass',
        photoUrls: ['https://images.unsplash.com/photo-1581094288338-2314dddb7ecc?w=600&auto=format&fit=crop&q=60']
      },
      {
        id: 'REP-003-C02',
        name: 'Diameter Bawah',
        standardLabel: '140 - 150 mm',
        actualValue: '145',
        unit: 'mm',
        result: 'pass',
        photoUrls: []
      },
      {
        id: 'REP-003-C03',
        name: 'Diameter Atas',
        standardLabel: '110 - 120 mm',
        actualValue: '115',
        unit: 'mm',
        result: 'pass',
        photoUrls: []
      }
    ],
    photos: [
      'https://images.unsplash.com/photo-1581094288338-2314dddb7ecc?w=600&auto=format&fit=crop&q=60'
    ],
    adminNote: 'Semua spesifikasi beton terpenuhi dengan baik.'
  },
  {
    id: 'REP-004',
    type: 'pekerjaan',
    title: 'Grounding System Kaki Tiang',
    locationName: 'Site Warehouse Jakarta Barat',
    submittedBy: 'Ahmad Syarif',
    submittedByNik: '120001',
    submittedAt: '2026-07-08T14:20:00Z',
    status: 'Disetujui',
    standardResult: 'Lulus',
    checklistItems: [
      {
        id: 'REP-004-C01',
        name: 'Nilai resistansi pentanahan (Earth Ground Resistance)',
        standardLabel: 'max 5 Ohm',
        actualValue: '3.4',
        unit: 'Ohm',
        result: 'pass',
        photoUrls: ['https://images.unsplash.com/photo-1541888946425-d81bb19240f5?w=600&auto=format&fit=crop&q=60']
      },
      {
        id: 'REP-004-C02',
        name: 'Spesifikasi kabel tembaga grounding (BC)',
        standardLabel: 'Sesuai SNI (min BC-25)',
        actualValue: 'BC-35',
        result: 'pass',
        photoUrls: []
      },
      {
        id: 'REP-004-C03',
        name: 'Koneksi grounding clamp pada kaki tiang',
        standardLabel: 'Kencang dan terlindungi',
        actualValue: 'Sangat Kencang',
        result: 'pass',
        photoUrls: []
      }
    ],
    photos: [
      'https://images.unsplash.com/photo-1541888946425-d81bb19240f5?w=600&auto=format&fit=crop&q=60'
    ],
    adminNote: 'Nilai grounding di bawah 5 Ohm, sangat bagus.'
  },
  {
    id: 'REP-005',
    type: 'material',
    title: 'Pemeriksaan Tiang Galvanis 6M Tanpa Sambungan',
    locationName: 'Bekasi Site',
    submittedBy: 'Ahmad Syarif',
    submittedByNik: '120001',
    submittedAt: '2026-07-07T11:00:00Z',
    status: 'Perlu Perbaikan',
    standardResult: 'Tidak Lulus',
    checklistItems: [
      {
        id: 'REP-005-C01',
        name: 'Ketebalan Seng (Galvanize Thickness)',
        standardLabel: 'min 75 micron',
        actualValue: '68',
        unit: 'micron',
        result: 'fail',
        photoUrls: ['https://images.unsplash.com/photo-1581094288338-2314dddb7ecc?w=600&auto=format&fit=crop&q=60']
      },
      {
        id: 'REP-005-C02',
        name: 'Tebal Dinding Tiang',
        standardLabel: 'min 3.0 mm',
        actualValue: '3.1',
        unit: 'mm',
        result: 'pass',
        photoUrls: []
      }
    ],
    photos: [
      'https://images.unsplash.com/photo-1581094288338-2314dddb7ecc?w=600&auto=format&fit=crop&q=60'
    ],
    adminNote: 'Tebal galvanis tidak memenuhi standar 75 micron. Harap ganti tiang dengan spesifikasi sesuai.'
  },
  {
    id: 'REP-006',
    type: 'pekerjaan',
    title: 'Penarikan Kabel Udara Jembatan',
    locationName: 'Surabaya Site',
    submittedBy: 'Budi Hartono',
    submittedByNik: '120002',
    submittedAt: '2026-07-07T16:00:00Z',
    status: 'Perlu Perbaikan',
    standardResult: 'Tidak Lulus',
    checklistItems: [
      {
        id: 'REP-006-C01',
        name: 'Ketinggian andongan kabel dari permukaan jalan',
        standardLabel: 'min 5.5 meter',
        actualValue: '4.8',
        unit: 'meter',
        result: 'fail',
        photoUrls: ['https://images.unsplash.com/photo-1590069261209-f8e9b8642343?w=600&auto=format&fit=crop&q=60']
      },
      {
        id: 'REP-006-C02',
        name: 'Penggunaan suspension/tension clamp standar',
        standardLabel: 'Menggunakan type standar alumunium',
        actualValue: 'Sesuai Standar',
        result: 'pass',
        photoUrls: []
      },
      {
        id: 'REP-006-C03',
        name: 'Radius kelengkungan kabel saat belok',
        standardLabel: 'min 15x diameter luar kabel',
        actualValue: 'Sesuai',
        result: 'pass',
        photoUrls: []
      },
      {
        id: 'REP-006-C04',
        name: 'Jarak aman dengan kabel tegangan listrik',
        standardLabel: 'min 1.0 meter',
        actualValue: '0.6',
        unit: 'meter',
        result: 'fail',
        photoUrls: ['https://images.unsplash.com/photo-1541888946425-d81bb19240f5?w=600&auto=format&fit=crop&q=60']
      }
    ],
    photos: [
      'https://images.unsplash.com/photo-1590069261209-f8e9b8642343?w=600&auto=format&fit=crop&q=60',
      'https://images.unsplash.com/photo-1541888946425-d81bb19240f5?w=600&auto=format&fit=crop&q=60'
    ],
    adminNote: 'Andongan kabel terlalu rendah (4.8m) dan jarak dengan tegangan tinggi terlalu dekat (0.6m). Sangat membahayakan, segera posisikan ulang!'
  },
  {
    id: 'REP-007',
    type: 'material',
    title: 'Inspeksi Draf Tiang Besi 9 Meter',
    locationName: 'Bandung Site',
    submittedBy: 'Cecep Solihin',
    submittedByNik: '120003',
    submittedAt: '2026-07-06T09:00:00Z',
    status: 'Draft',
    standardResult: 'Perlu Review',
    checklistItems: [
      {
        id: 'REP-007-C01',
        name: 'Ketebalan Seng (Galvanize Thickness)',
        standardLabel: 'min 85 micron',
        actualValue: '86',
        unit: 'micron',
        result: 'pass',
        photoUrls: []
      },
      {
        id: 'REP-007-C02',
        name: 'Tebal Segmen Bawah (Segment 1)',
        standardLabel: 'min 4.5 mm',
        actualValue: '4.6',
        unit: 'mm',
        result: 'pass',
        photoUrls: []
      },
      {
        id: 'REP-007-C03',
        name: 'Tebal Segmen Tengah (Segment 2)',
        standardLabel: 'min 4.0 mm',
        actualValue: '',
        unit: 'mm',
        result: 'review',
        photoUrls: []
      },
      {
        id: 'REP-007-C04',
        name: 'Tebal Segmen Atas (Segment 3)',
        standardLabel: 'min 3.2 mm',
        actualValue: '',
        unit: 'mm',
        result: 'review',
        photoUrls: []
      }
    ],
    photos: []
  },
  {
    id: 'REP-008',
    type: 'pekerjaan',
    title: 'Pondasi Beton Tower Cabang',
    locationName: 'Bekasi Site',
    submittedBy: 'Ahmad Syarif',
    submittedByNik: '120001',
    submittedAt: '2026-07-06T13:45:00Z',
    status: 'Draft',
    standardResult: 'Perlu Review',
    checklistItems: [
      {
        id: 'REP-008-C01',
        name: 'Kedalaman galian tanah sesuai spesifikasi teknis',
        standardLabel: 'min 1.5 meter',
        actualValue: '1.5',
        unit: 'meter',
        result: 'pass',
        photoUrls: []
      },
      {
        id: 'REP-008-C02',
        name: 'Dimensi cor pondasi beton',
        standardLabel: '60 x 60 x 150 cm',
        actualValue: '',
        result: 'review',
        photoUrls: []
      },
      {
        id: 'REP-008-C03',
        name: 'Rasio campuran semen, pasir, dan batu pecah',
        standardLabel: '1 : 2 : 3',
        actualValue: '',
        result: 'review',
        photoUrls: []
      },
      {
        id: 'REP-008-C04',
        name: 'Pemasangan angkur tiang tegak lurus',
        standardLabel: 'Tegak lurus',
        actualValue: '',
        result: 'review',
        photoUrls: []
      }
    ],
    photos: []
  }
];
