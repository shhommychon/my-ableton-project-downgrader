import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class AbletonConverter {
  // 에이블톤 11 버젼 릴리스 노트 (https://www.ableton.com/en/release-notes/live-11/)
  // 페이지를 파싱하여 하드코딩된 버전 정보
  final Map<String, List<String>> _validVersions = const {
    '3': ['42', '41', '40', '35', '30', '26', '25', '22', '21', '20', '13', '12', '11', '10', '4', '3', '2'],
    '2': ['11', '10', '7', '6', '5'],
    '1': ['6', '5', '1'],
    '0': ['12', '11', '10', '6', '5', '2', '1'],
  };

  /// `.als` 파일 데이터와 목표 버전을 받아 변환된 파일 데이터를 반환합니다.
  ///
  /// [alsFileData]는 GZIP으로 압축된 원본 `.als` 파일의 바이트 데이터입니다.
  /// [targetVersionKey]는 "11.3.42"와 같은 형식의 전체 버전 문자열이어야 합니다.   
  /// 변환에 성공하면 GZIP으로 재압축된 `List<int>`를, 실패하면 예외를 던집니다.
  List<int> convert(List<int> alsFileData, String targetVersionKey) {
    // 1. 버전 유효성 검사 및 정보 생성
    final parts = targetVersionKey.split('.');
    if (parts.length != 3 || parts[0] != '11') {
      throw ArgumentError('잘못된 버전 형식입니다: $targetVersionKey. \'11.x.x\' 형식이어야 합니다.');
    }
    final minorPart = parts[1]; // "3"
    final patchPart = parts[2]; // "42"

    if (!_validVersions.containsKey(minorPart) ||
        !_validVersions[minorPart]!.contains(patchPart)) {
      throw ArgumentError('지원되지 않는 버전입니다: $targetVersionKey');
    }

    final versionInfo = {
      'MinorVersion': '11.0_11${minorPart}00',
      'Creator': 'Ableton Live $targetVersionKey'
    };

    // 2. GZIP 압축 해제
    final gzipDecoder = GzipDecoder();
    final xmlData = gzipDecoder.decodeBytes(alsFileData);
    final xmlString = utf8.decode(xmlData);

    // 3. XML 파싱 및 수정
    final document = XmlDocument.parse(xmlString);
    final abletonNode = document.rootElement;

    // 3A. 버전 정보 수정
    abletonNode.setAttribute('MinorVersion', versionInfo['MinorVersion']!);
    abletonNode.setAttribute('Creator', versionInfo['Creator']!);

    // 3B. <MidiEditorLaneModel> 태그를 <ExpressionLane>으로 치환
    for (var element in document.findAllElements('MidiEditorLaneModel')) {
      element.name = XmlName('ExpressionLane');
    }
    
    final modifiedXmlString = document.toXmlString(pretty: true);

    // 4. GZIP으로 재압축
    final gzipEncoder = GzipEncoder();
    final modifiedAlsData = gzipEncoder.encode(utf8.encode(modifiedXmlString));

    if (modifiedAlsData == null) {
      throw Exception('GZIP 압축에 실패했습니다.');
    }

    return modifiedAlsData;
  }

  /// UI에 표시할 지원 버전 목록을 "11.x.x" 형식으로 반환합니다.
  List<String> getSupportedVersions() {
    final versions = <String>[];
     _validVersions.forEach((minor, patches) {
      for (var patch in patches) {
        versions.add('$minor.$patch');
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
}