import 'package:shared_preferences/shared_preferences.dart';

class LocalProfile {
  final String phone;
  final String address;

  const LocalProfile({this.phone = '', this.address = ''});
}

class ProfileService {
  static const _phoneKey = 'profile_phone';
  static const _addressKey = 'profile_address';

  Future<LocalProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalProfile(
      phone: prefs.getString(_phoneKey) ?? '',
      address: prefs.getString(_addressKey) ?? '',
    );
  }

  Future<void> save({required String phone, required String address}) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_phoneKey, phone.trim()),
      prefs.setString(_addressKey, address.trim()),
    ]);
  }
}
