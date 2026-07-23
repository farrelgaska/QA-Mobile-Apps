const int maxQCPhotoSizeBytes = 2 * 1024 * 1024;

const String qcPhotoTooLargeMessage =
    'Foto tidak dapat diproses hingga batas 2 MB dengan kualitas yang aman. Silakan ambil ulang foto.';

const String qcPhotoProcessingMessage =
    'Foto masih diproses. Tunggu hingga selesai sebelum menyimpan atau mengirim laporan.';

bool exceedsQCPhotoSizeLimit(List<int> bytes) =>
    bytes.length > maxQCPhotoSizeBytes;
