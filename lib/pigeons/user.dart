import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/user_api.dart',
    kotlinOut: 'android/app/src/main/kotlin/com/example/lms/UserApi.kt',
    kotlinOptions: KotlinOptions(package: 'com.example.lms'),
    swiftOut: 'ios/Runner/UserApi.swift',
    objcHeaderOut: 'ios/Runner/UserApi.h',
    objcSourceOut: 'ios/Runner/UserApi.m',
    dartPackageName: 'com.example.lms',
  ),
)
class PigeonUserDetails {
  String? name;
  String? email;
  int? age;
}

@HostApi()
abstract class UserApi {
  List<PigeonUserDetails?> getUser(); // ❌ returns a list
}
