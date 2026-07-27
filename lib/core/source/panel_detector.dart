// ignore_for_file: prefer_single_quotes
// SSH command strings MUST stay double-quoted per CI constitution (so any
// future `$var` interpolates correctly). Lint hints about single quotes are
// intentionally suppressed here.

/// Result of probing a host for a known control panel.
enum PanelStatus { none, onePanel, baota }

/// Detects whether a remote host runs 1Panel or 宝塔 (Baota) by running
/// shell probes over an injected executor.
///
/// The executor is injected (rather than importing [dartssh2]) so the detector
/// is fully unit-testable. [SshServerSource] wires it to its real SSH exec.
class PanelDetector {
  final Future<String> Function(String cmd) exec;

  const PanelDetector(this.exec);

  Future<PanelStatus> detect() async {
    // 1Panel: CLI `1pctl` on PATH, or its install dir.
    final onePanel = await exec(
      "if command -v 1pctl >/dev/null 2>&1 || [ -d /opt/1panel ]; "
      "then echo 1p; fi",
    );
    if (onePanel.contains('1p')) return PanelStatus.onePanel;

    // 宝塔 (Baota): CLI `bt`, or its install dir.
    final baota = await exec(
      "if command -v bt >/dev/null 2>&1 || [ -d /www/server/panel ]; "
      "then echo bt; fi",
    );
    if (baota.contains('bt')) return PanelStatus.baota;

    return PanelStatus.none;
  }
}
