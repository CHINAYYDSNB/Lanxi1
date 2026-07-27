// ---
// Directory: lib/core/
// Responsibility: Core infrastructure — logging, SSH connections,
//                 panel API clients, and the ServerSource abstraction.
// ---
//
// Files:
//   logger.dart          — appLogger (d/i/w/e levels, no stdout)
//   exceptions.dart      — PanelFallbackException
//   server_source.dart   — Abstract ServerSource interface (Pillar 1)
//   ssh_server_source.dart    — dartssh2-based implementation
//   server_source_factory.dart — The ONLY router (Pillar 2)
//
// Subdirectories:
//   ssh/   — SshConnection, SshSessionPool
//   source/panel/ — DioPanelApiClient, OnePanelAdapter, OnePanelServerSource,
//                   FallbackServerSource
