/// 저장소가 유지되도록 이미 허락받았는지. 앱은 늘 유지된다.
Future<bool> isStoragePersisted() async => true;

/// 저장소 유지를 청한다. 허락받았으면 true. 앱은 청할 것이 없다.
Future<bool> requestPersistentStorage() async => true;
