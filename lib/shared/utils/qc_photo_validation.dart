const int maxQCPhotoSizeBytes = 700 * 1024;
const int maxQCEvidenceLongEdge = 1920;

const String qcPhotoTooLargeMessage =
    'Foto tidak dapat diproses hingga batas 700 KB dengan kualitas yang aman. Silakan ambil ulang foto.';

const String qcPhotoProcessingMessage =
    'Foto masih diproses. Tunggu hingga selesai sebelum menyimpan atau mengirim laporan.';

bool exceedsQCPhotoSizeLimit(List<int> bytes) =>
    bytes.length > maxQCPhotoSizeBytes;
