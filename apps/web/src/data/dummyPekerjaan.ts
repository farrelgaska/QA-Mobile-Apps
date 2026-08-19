import type { QCPekerjaan } from '../types/pekerjaan';

export const dummyPekerjaan: QCPekerjaan[] = [
  {
    id: 'WRK-001',
    name: 'Pondasi Tiang Beton/Besi',
    category: 'Sipil Konstruksi',
    segment: 'construction',
    checklistCount: 4,
    isActive: true,
    updatedAt: '2026-07-01T11:00:00Z',
    checklistItems: [
      { id: 'WRK-001-C01', name: 'Kedalaman galian tanah sesuai spesifikasi teknis', isActive: true },
      { id: 'WRK-001-C02', name: 'Dimensi cor pondasi beton (panjang x lebar x tinggi)', isActive: true },
      { id: 'WRK-001-C03', name: 'Rasio campuran semen, pasir, dan batu pecah', isActive: true },
      { id: 'WRK-001-C04', name: 'Pemasangan angkur tiang tegak lurus', isActive: true }
    ]
  },
  {
    id: 'WRK-002',
    name: 'Pemasangan Tiang (Erection)',
    category: 'Struktur Mekanikal',
    segment: 'construction',
    checklistCount: 3,
    isActive: true,
    updatedAt: '2026-07-02T11:00:00Z',
    checklistItems: [
      { id: 'WRK-002-C01', name: 'Kelurusan tiang diukur dengan waterpass', isActive: true },
      { id: 'WRK-002-C02', name: 'Kekencangan baut angkur (torque check)', isActive: true },
      { id: 'WRK-002-C03', name: 'Pengecatan ulang area sambungan segmen', isActive: true }
    ]
  },
  {
    id: 'WRK-003',
    name: 'Penarikan Kabel Udara (Stringing)',
    category: 'Kabel & Aksesoris',
    segment: 'provisioning',
    checklistCount: 4,
    isActive: true,
    updatedAt: '2026-07-03T11:00:00Z',
    checklistItems: [
      { id: 'WRK-003-C01', name: 'Ketinggian andongan kabel dari permukaan jalan', isActive: true },
      { id: 'WRK-003-C02', name: 'Penggunaan suspension/tension clamp standar', isActive: true },
      { id: 'WRK-003-C03', name: 'Radius kelengkungan kabel saat belok', isActive: true },
      { id: 'WRK-003-C04', name: 'Jarak aman dengan kabel tegangan listrik', isActive: true }
    ]
  },
  {
    id: 'WRK-004',
    name: 'Terminasi Kabel Serat Optik',
    category: 'Optical Termination',
    segment: 'provisioning',
    checklistCount: 3,
    isActive: true,
    updatedAt: '2026-07-04T11:00:00Z',
    checklistItems: [
      { id: 'WRK-004-C01', name: 'Nilai redaman (loss) hasil splicing serat optik', isActive: true },
      { id: 'WRK-004-C02', name: 'Pelabelan core dan port di dalam OTB/ODP', isActive: true },
      { id: 'WRK-004-C03', name: 'Kebersihan area connector adapter', isActive: true }
    ]
  },
  {
    id: 'WRK-005',
    name: 'Grounding System (Pentanahan)',
    category: 'Proteksi Kelistrikan',
    segment: 'assurance',
    checklistCount: 3,
    isActive: true,
    updatedAt: '2026-07-05T11:00:00Z',
    checklistItems: [
      { id: 'WRK-005-C01', name: 'Nilai resistansi pentanahan (Earth Ground Resistance)', isActive: true },
      { id: 'WRK-005-C02', name: 'Spesifikasi kabel tembaga grounding (BC)', isActive: true },
      { id: 'WRK-005-C03', name: 'Koneksi grounding clamp pada kaki tiang', isActive: true }
    ]
  },
  {
    id: 'WRK-006',
    name: 'Finishing & Kebersihan Site',
    category: 'Administratif & K3',
    segment: 'assurance',
    checklistCount: 3,
    isActive: false,
    updatedAt: '2026-07-06T11:00:00Z',
    checklistItems: [
      { id: 'WRK-006-C01', name: 'Pembersihan sisa galian tanah dan material semen', isActive: true },
      { id: 'WRK-006-C02', name: 'Restorasi permukaan jalan / paving block', isActive: true },
      { id: 'WRK-006-C03', name: 'Pemasangan pelat identitas nomor tiang', isActive: true }
    ]
  }
];
