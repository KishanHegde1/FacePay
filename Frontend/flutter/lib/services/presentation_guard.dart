/// Conservative, explainable labels that can indicate a second device or a
/// display in the camera view. This is only a warning signal; it is not a
/// presentation-attack-detection (PAD) or liveness guarantee.
bool containsPossibleDeviceOrScreen(Iterable<String> labels) {
  const deviceTerms = <String>{
    'phone',
    'mobile phone',
    'cell phone',
    'smartphone',
    'tablet',
    'screen',
    'display',
    'monitor',
    'television',
    'tv',
  };
  return labels.any((label) {
    final normalized = label.trim().toLowerCase();
    return deviceTerms.contains(normalized);
  });
}
