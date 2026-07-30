class CustomBackgroundPicker {
  const CustomBackgroundPicker();

  bool get isSupported => false;

  Future<String?> pickImage() async => null;

  Future<bool> exists(String path) async => false;

  Future<void> deleteImage(String path) async {}
}
