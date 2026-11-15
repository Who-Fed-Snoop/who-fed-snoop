import 'package:shared_preferences/shared_preferences.dart';

/// Persists this device's bound Scoop Holder identity across cold starts,
/// Home Widget launches, NFC `/tap` intents, and browser reloads.
abstract class ScoopHolderStore {
  String? getMemberName();
  String? getMemberUid();
  Future<void> saveScoopHolder({required String name, String? uid});
  Future<void> clear();
}

/// `shared_preferences`-backed implementation of [ScoopHolderStore].
class SharedPreferencesScoopHolderStore implements ScoopHolderStore {
  SharedPreferencesScoopHolderStore(this._prefs);

  static const String memberNameKey = 'who_fed_snoop.scoop_holder_name';
  static const String memberUidKey = 'who_fed_snoop.scoop_holder_uid';

  final SharedPreferences _prefs;

  @override
  String? getMemberName() {
    final raw = _prefs.getString(memberNameKey)?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  @override
  String? getMemberUid() {
    final raw = _prefs.getString(memberUidKey)?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  @override
  Future<void> saveScoopHolder({required String name, String? uid}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    await _prefs.setString(memberNameKey, cleanName);

    final cleanUid = uid?.trim();
    if (cleanUid != null && cleanUid.isNotEmpty) {
      await _prefs.setString(memberUidKey, cleanUid);
    }
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(memberNameKey);
    await _prefs.remove(memberUidKey);
  }
}

/// Lightweight in-memory [ScoopHolderStore] for tests and fallback environments.
class InMemoryScoopHolderStore implements ScoopHolderStore {
  InMemoryScoopHolderStore({String? initialName, String? initialUid})
      : _name = initialName?.trim().isEmpty == true ? null : initialName?.trim(),
        _uid = initialUid?.trim().isEmpty == true ? null : initialUid?.trim();

  String? _name;
  String? _uid;

  @override
  String? getMemberName() => _name;

  @override
  String? getMemberUid() => _uid;

  @override
  Future<void> saveScoopHolder({required String name, String? uid}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    _name = cleanName;

    final cleanUid = uid?.trim();
    if (cleanUid != null && cleanUid.isNotEmpty) {
      _uid = cleanUid;
    }
  }

  @override
  Future<void> clear() async {
    _name = null;
    _uid = null;
  }
}
