const int maxQCPhotoSizeBytes = 5 * 1024 * 1024;

const String qcPhotoTooLargeMessage =
    'Ukuran foto melebihi batas maksimal 5 MB. Ambil ulang foto dengan ukuran yang lebih kecil.';

bool exceedsQCPhotoSizeLimit(List<int> bytes) =>
    bytes.length > maxQCPhotoSizeBytes;
