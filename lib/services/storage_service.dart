import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService instance = StorageService._();
  SharedPreferences? _prefs;

  StorageService._();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String? getString(String key) => _prefs?.getString(key);
  Future<bool> setString(String key, String value) =>
      _prefs?.setString(key, value) ?? Future.value(false);
  Future<bool> remove(String key) => _prefs?.remove(key) ?? Future.value(false);
}
