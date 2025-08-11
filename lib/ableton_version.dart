class AbletonVersion {
  // 에이블톤 11 버젼 릴리스 노트 (https://www.ableton.com/en/release-notes/live-11/)
  // 페이지를 파싱하여 하드코딩된 버전 정보
  final Map<String, List<String>> _validVersions = const {
    '3': ['42', '41', '40', '35', '30', '26', '25', '22', '21', '20', '13', '12', '11', '10', '4', '3', '2'],
    '2': ['11', '10', '7', '6', '5'],
    '1': ['6', '5', '1'],
    '0': ['12', '11', '10', '6', '5', '2', '1'],
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

  /// UI에 표시할 지원 버전 목록을 "11.x.x" 형식으로 반환합니다.
  List<String> getSupportedVersions() {
    final versions = <String>[];
    _validVersions.forEach((minor, patches) {
      for (var patch in patches) {
        versions.add('11.$minor.$patch'); // "11." 접두사 추가
      }
    });
    // 최신 버전이 위로 오도록 정렬
    versions.sort((a, b) {
      final aParts = a.split('.').map(int.parse).toList();
      final bParts = b.split('.').map(int.parse).toList();
      if (aParts[1] != bParts[1]) return bParts[1].compareTo(aParts[1]);
      return bParts[2].compareTo(aParts[2]);
    });
    return versions;
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
