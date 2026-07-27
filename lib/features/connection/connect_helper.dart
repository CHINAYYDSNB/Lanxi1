import 'package:lanxi/core/source/server_source_factory.dart';
import 'package:lanxi/core/store/server_store.dart';
import 'package:lanxi/services/server_service.dart';

/// Orchestrates connecting to a [ServerProfile]:
///   1. loads persisted secrets from [store],
///   2. builds the correct [ServerSource] via [ServerSourceFactory],
///   3. verifies connectivity with a probe call,
///   4. returns a ready [ServerService].
///
/// The transport decision lives entirely in [ServerSourceFactory] — this is
/// pure orchestration, no `if (isPanel)` branching here.
Future<ServerService> connectProfile(
  ServerProfile profile,
  ServerStore store,
) async {
  final full = await store.loadSecrets(profile);
  final source = ServerSourceFactory.build(full);
  final service = ServerService(source);
  await service.getSystemInfo();
  return service;
}
