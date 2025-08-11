class AbletonVersion {
  final Map<String, List<String>> _validVersions = const {
    '3': ['10', '9'],
    '2': ['78', '8', '7'],
    '1': ['6', '5', '4'],
    '0': ['3', '2', '1', '0'],
  };

  /// 마이너 버전 목록을 반환합니다. (예: ['3', '2', '1', '0'])
  List<String> getMinorVersions() {
    return _validVersions.keys.toList();
  }

  /// 주어진 마이너 버전에 해당하는 패치 버전 목록을 반환합니다.
  /// 최신순으로 정렬됩니다.
  List<String> getPatchVersions(String minorVersion) {
    final source = _validVersions[minorVersion];  // 맵에서 해당 마이너 버전의 원본 리스트 조회(불변일 수 있음)
    if (source == null) return const [];          // 항목이 없으면 빈 리스트 반환
    final patches = List<String>.from(source);    // 정렬을 위해 가변 리스트로 복사
    patches.sort((a, b) =>                        // 문자열 숫자를 정수로 변환
        int.parse(b).compareTo(int.parse(a)));    // 내림차순으로 정렬
    return patches;                               // 정렬된 리스트 반환
  }

  /// 제공된 버전 문자열이 지원되는 목표 버전인지 확인합니다.
  /// version 형식은 "11.x.x"여야 합니다.
  bool isValidVersion(String version) {
    final parts = version.split('.');
    if (parts.length != 3 || parts[0] != '11') {
      return false;
    }
    final minor = parts[1];
    final patch = parts[2];

    if (_validVersions.containsKey(minor)) {
      return _validVersions[minor]!.contains(patch);
    }
    return false;
  }
}