/// Utility function for alphanumeric/natural sorting.
/// Ensures "G2" comes before "G10", and "Batch 2" before "Batch 10".
int naturalCompare(String a, String b) {
  final regExp = RegExp(r'(\d+)|(\D+)');
  final matchesA = regExp.allMatches(a.toLowerCase()).toList();
  final matchesB = regExp.allMatches(b.toLowerCase()).toList();

  for (int i = 0; i < matchesA.length && i < matchesB.length; i++) {
    final matchA = matchesA[i].group(0)!;
    final matchB = matchesB[i].group(0)!;

    // If both are digits, compare numerically
    if (RegExp(r'\d').hasMatch(matchA) && RegExp(r'\d').hasMatch(matchB)) {
      final intA = int.tryParse(matchA) ?? 0;
      final intB = int.tryParse(matchB) ?? 0;
      if (intA != intB) return intA.compareTo(intB);
    } else {
      // Otherwise compare lexicographically
      if (matchA != matchB) return matchA.compareTo(matchB);
    }
  }
  
  // If all matched parts are equal, the shorter string comes first
  return matchesA.length.compareTo(matchesB.length);
}

/// Strips common titles (Dr., Mr., Prof., etc.) from a name for cleaner sorting.
String getSortableName(String name) {
  final prefixes = [
    'dr.', 'mr.', 'mrs.', 'ms.', 'prof.', 'dr', 'mr', 'mrs', 'ms', 'prof',
    'assistant professor', 'associate professor'
  ];
  String lower = name.toLowerCase().trim();
  for (final prefix in prefixes) {
    if (lower.startsWith('$prefix ')) {
      // Return the part after the prefix, but keep original case
      return name.substring(prefix.length).trim();
    }
  }
  return name.trim();
}
