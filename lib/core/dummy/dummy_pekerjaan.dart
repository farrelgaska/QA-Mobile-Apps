import '../../shared/models/pekerjaan_model.dart';
import '../../shared/models/checklist_item_model.dart';
import '../../shared/models/enums.dart';

final List<PekerjaanModel> dummyPekerjaan = [
  // PROVISIONING
  PekerjaanModel(
    id: 'pek-1',
    name: 'Instalasi ONT',
    segment: WorkSegment.provisioning,
    description: 'Pemasangan unit ONT dan aktivasi layanan di lokasi pelanggan.',
    status: 'On Progress',
    checklistItems: [
      ChecklistItemModel(
        id: 'pek-1-c1',
        title: 'Posisi ONT',
        inputType: InputType.choice,
        choices: ['Sesuai', 'Tidak Sesuai'],
        standard: 'Ditempatkan di tempat aman & tinggi rata-rata dada',
        requiredPhoto: true,
      ),
      ChecklistItemModel(
        id: 'pek-1-c2',
        title: 'Instalasi Kabel Dropcore',
        inputType: InputType.choice,
        choices: ['Rapi', 'Bermasalah'],
        standard: 'Kabel dropcore tidak menekuk tajam & dipaku rapi',
        requiredPhoto: true,
      ),
      ChecklistItemModel(
        id: 'pek-1-c3',
        title: 'Pengukuran Nilai Redaman',
        inputType: InputType.number,
        unit: 'dBm',
        standard: 'Nilai redaman ≤ -24 dBm',
        requiredPhoto: true,
      ),
      ChecklistItemModel(
        id: 'pek-1-c4',
        title: 'Dokumentasi Before/After',
        inputType: InputType.text,
        standard: 'Mengambil foto kondisi sebelum dan sesudah instalasi',
        requiredPhoto: true,
      ),
    ],
  ),
  PekerjaanModel(
    id: 'pek-2',
    name: 'Penarikan Kabel Dropcore',
    segment: WorkSegment.provisioning,
    description: 'Pemasangan kabel dropcore dari ODP terdekat menuju rumah pelanggan.',
    status: 'Selesai',
    checklistItems: [
      ChecklistItemModel(
        id: 'pek-2-c1',
        title: 'Pemasangan S-Clamp',
        inputType: InputType.choice,
        choices: ['Kencang', 'Kendor'],
        standard: 'S-Clamp terpasang kencang di tiang & rumah',
        requiredPhoto: true,
      ),
      ChecklistItemModel(
        id: 'pek-2-c2',
        title: 'Rute Kabel',
        inputType: InputType.text,
        standard: 'Aman dari gesekan pohon/kabel listrik bertegangan tinggi',
        requiredPhoto: false,
      ),
      ChecklistItemModel(
        id: 'pek-2-c3',
        title: 'Kerapian Dropwire',
        inputType: InputType.choice,
        choices: ['Rapi', 'Kendor/Berantakan'],
        standard: 'Dropwire masuk rapi, menggunakan flexible pipe jika perlu',
        requiredPhoto: true,
      ),
    ],
  ),

  // ASSURANCE
  PekerjaanModel(
    id: 'pek-3',
    name: 'Validasi Redaman FO',
    segment: WorkSegment.assurance,
    description: 'Pengukuran daya optik pada titik distribusi ODP.',
    status: 'On Progress',
    checklistItems: [
      ChecklistItemModel(
        id: 'pek-3-c1',
        title: 'Nilai Redaman Optik di ODP',
        inputType: InputType.number,
        unit: 'dBm',
        standard: 'Maksimal -24 dBm',
        requiredPhoto: true,
      ),
      ChecklistItemModel(
        id: 'pek-3-c2',
        title: 'Kebersihan Konektor Ferrule',
        inputType: InputType.choice,
        choices: ['Bersih', 'Kotor'],
        standard: 'Konektor ditiup pen/pembersih, tidak berdebu',
        requiredPhoto: true,
      ),
    ],
  ),
  PekerjaanModel(
    id: 'pek-4',
    name: 'Pemeriksaan Kualitas Instalasi',
    segment: WorkSegment.assurance,
    description: 'Verifikasi kelayakan instalasi jaringan optik pasca-pasang.',
    status: 'Selesai',
    checklistItems: [
      ChecklistItemModel(
        id: 'pek-4-c1',
        title: 'Pelabelan Kabel di ODP',
        inputType: InputType.choice,
        choices: ['Ada & Jelas', 'Tidak Ada / Buram'],
        standard: 'Label nomor core & nama pelanggan tertulis jelas',
        requiredPhoto: true,
      ),
      ChecklistItemModel(
        id: 'pek-4-c2',
        title: 'Sisa Kabel (Slack)',
        inputType: InputType.text,
        standard: 'Sisa kabel dropcore digulung rapi dengan diameter min. 30 cm',
        requiredPhoto: false,
      ),
    ],
  ),

  // CONSTRUCTION
  PekerjaanModel(
    id: 'pek-5',
    name: 'Pemasangan Tiang',
    segment: WorkSegment.construction,
    description: 'Pekerjaan penanaman tiang beton/besi baru di lapangan.',
    status: 'On Progress',
    checklistItems: [
      ChecklistItemModel(
        id: 'pek-5-c1',
        title: 'Kedalaman Lubang Pondasi',
        inputType: InputType.number,
        unit: 'm',
        standard: 'Kedalaman lubang pondasi minimal 1.2 meter',
        requiredPhoto: true,
      ),
      ChecklistItemModel(
        id: 'pek-5-c2',
        title: 'Ketegakan Tiang',
        inputType: InputType.choice,
        choices: ['Tegak Lurus', 'Miring'],
        standard: 'Kemiringan tiang maksimal 2 derajat',
        requiredPhoto: true,
      ),
      ChecklistItemModel(
        id: 'pek-5-c3',
        title: 'Pengecoran Base Pondasi',
        inputType: InputType.text,
        standard: 'Cor semen kokoh, permukaan rapi rata tanah',
        requiredPhoto: true,
      ),
    ],
  ),
  PekerjaanModel(
    id: 'pek-6',
    name: 'Pengecoran Pondasi',
    segment: WorkSegment.construction,
    description: 'Pengecoran pondasi untuk tiang atau kabinet outdoor.',
    status: 'Selesai',
    checklistItems: [
      ChecklistItemModel(
        id: 'pek-6-c1',
        title: 'Komposisi Campuran',
        inputType: InputType.choice,
        choices: ['Sesuai Standar', 'Kurang Semen'],
        standard: 'Campuran semen, pasir, kerikil sesuai spek K-175',
        requiredPhoto: true,
      ),
      ChecklistItemModel(
        id: 'pek-6-c2',
        title: 'Dimensi Cor Pondasi',
        inputType: InputType.text,
        standard: 'Ukuran min. 40cm x 40cm x 50cm',
        requiredPhoto: true,
      ),
      ChecklistItemModel(
        id: 'pek-6-c3',
        title: 'Waktu Pengeringan',
        inputType: InputType.number,
        unit: 'jam',
        standard: 'Minimal 24 jam sebelum diberi beban tiang',
        requiredPhoto: false,
      ),
    ],
  ),
  PekerjaanModel(
    id: 'pek-7',
    name: 'Penarikan Kabel Jalur Utama',
    segment: WorkSegment.construction,
    description: 'Penarikan kabel optik utama (aerial feeder/distribution).',
    status: 'On Progress',
    checklistItems: [
      ChecklistItemModel(
        id: 'pek-7-c1',
        title: 'Ketinggian Kabel',
        inputType: InputType.number,
        unit: 'm',
        standard: 'Ketinggian kabel dari jalan raya min. 5 meter',
        requiredPhoto: true,
      ),
      ChecklistItemModel(
        id: 'pek-7-c2',
        title: 'Kerapian Ikatan Kabel',
        inputType: InputType.text,
        standard: 'Diikat rapi ke messenger wire dengan spacing teratur',
        requiredPhoto: false,
      ),
      ChecklistItemModel(
        id: 'pek-7-c3',
        title: 'Pemasangan Accessoris Span Box',
        inputType: InputType.choice,
        choices: ['Lengkap', 'Tidak Lengkap'],
        standard: 'Aksesoris clamp, link, tensioner terpasang lengkap',
        requiredPhoto: true,
      ),
    ],
  ),
];
