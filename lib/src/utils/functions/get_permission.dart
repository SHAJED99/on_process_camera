part of './../../../on_process_camera.dart';
//! --------------------------------------- All permission handling will be here

Future<bool> _askPermission(
  BuildContext context,
  Permission permission, [
  Future<bool> Function(BuildContext, PermissionStatus?)? onPermission,
]) async {
  PermissionStatus permissionStatus = await permission.request();

  if (!context.mounted) return false;

  return onPermission == null
      ? await _permissionHandler(context, permissionStatus, permission)
      : await onPermission(context, permissionStatus);
}

Future<bool> _permissionHandler(
  BuildContext context,
  PermissionStatus status,
  Permission permission,
) async {
  if (status.isGranted) return true;

  String message;
  String buttonText;
  Future<bool> Function() onPressed;

  if (status == PermissionStatus.denied) {
    message = 'Permission denied. Please allow to continue.';
    buttonText = 'Retry';
    onPressed = () => _askPermission(context, permission);
  } else if (status == PermissionStatus.permanentlyDenied) {
    message = 'Permission permanently denied. Please enable it from Settings.';
    buttonText = 'Open Settings';
    onPressed = () => _openSettingsAndWait(permission);
  } else {
    message = 'Permission status: $status';
    buttonText = 'OK';
    onPressed = () async => false;
  }

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: const Text('Permission Required'),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            final bool granted = await onPressed();
            if (ctx.mounted) Navigator.of(ctx).pop(granted);
          },
          child: Text(buttonText),
        ),
      ],
    ),
  );

  return result ?? false;
}

/// Opens app settings, waits for resume, then re-checks [permission].
Future<bool> _openSettingsAndWait(Permission permission) async {
  final Completer<bool> completer = Completer<bool>();
  AppLifecycleListener? listener;

  listener = AppLifecycleListener(
    onResume: () async {
      final PermissionStatus newStatus = await permission.request();
      listener?.dispose();
      if (!completer.isCompleted) {
        completer.complete(newStatus.isGranted);
      }
    },
  );

  await openAppSettings();
  return completer.future;
}
