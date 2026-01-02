class CloudStorage {
  Future<String> upload({required String bucket, required String path, required List<int> bytes, required String contentType}) async {
    throw UnimplementedError('Cloud storage no configurado');
  }
}
