import '../local_storage/local_storage.dart';
import '../resources/app_const/app_const.dart';
import '../../modules/user_side/home/model/current_location_model.dart';
import '../../modules/user_side/home/repository/location_repository.dart';

class AuthCoordinates {
  static Future<({double lat, double lng})> read() async {
    final saved = _saved();
    if (saved != null) return saved;

    final location = await LocationRepository().getCurrentLocation();
    if (location.isAvailable) {
      await LocalStorage.saveData(
        key: AppConst.currentLocation,
        data: location.toJson(),
      );
      return (lat: location.latitude!, lng: location.longitude!);
    }
    return (lat: 0.0, lng: 0.0);
  }

  static ({double lat, double lng})? _saved() {
    final raw = LocalStorage.getData(key: AppConst.currentLocation);
    if (raw is! Map) return null;
    final location = CurrentLocationModel.fromJson(
      Map<String, dynamic>.from(raw),
    );
    final lat = location.latitude;
    final lng = location.longitude;
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  }
}
