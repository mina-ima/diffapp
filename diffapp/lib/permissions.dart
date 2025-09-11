class PermissionResult {
  final bool granted;
  final bool permanentlyDenied;
  const PermissionResult(
      {required this.granted, this.permanentlyDenied = false});
}

abstract class PermissionService {
  Future<PermissionResult> requestCamera();
  Future<PermissionResult> requestGallery();
  Future<void> openAppSettings();
}

/// 現状はダミー実装。将来的に permission_handler などに差し替え。
class BasicPermissionService implements PermissionService {
  const BasicPermissionService();

  @override
  Future<PermissionResult> requestCamera() async =>
      const PermissionResult(granted: true);

  @override
  Future<PermissionResult> requestGallery() async =>
      const PermissionResult(granted: true);

  @override
  Future<void> openAppSettings() async {/* no-op */}
}
