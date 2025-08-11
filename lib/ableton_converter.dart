import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// 버전별 변환 룰을 정의하는 클래스
class ConversionRule {
  final String description;
  final String xpathSelector;
  final String attributeName;
  final dynamic Function(String) converter;
  final bool Function(XmlElement)? condition;

  ConversionRule({
    required this.description,
    required this.xpathSelector,
    required this.attributeName,
    required this.converter,
    this.condition,
  });
}

/// Ableton Live 11 호환성을 위한 변환 룰북
class Live11CompatibilityRules {
  static final List<ConversionRule> rules = [
    // Oversampling: bool -> int (true -> 1, false -> 0)
    ConversionRule(
      description: 'Oversampling: bool -> int',
      xpathSelector: '//Oversampling',
      attributeName: 'Value',
      converter: (value) {
        if (value.toLowerCase() == 'true') return '1';
        if (value.toLowerCase() == 'false') return '0';
        return value; // 이미 숫자인 경우 그대로 유지
      },
    ),
    
    // 다른 자료형 변환이 필요한 태그들도 여기에 추가 가능
    // 예: <SomeOtherTag Value="aBc"/> -> <SomeOtherTag Value="DeF"/>
  ];

  /// 모든 룰을 적용합니다
  static void applyAllRules(XmlDocument document) {
    for (final rule in rules) {
      _applyRule(document, rule);
    }
  }

  /// 개별 룰을 적용합니다
  static void _applyRule(XmlDocument document, ConversionRule rule) {
    try {
      final elements = document.findAllElements(rule.xpathSelector.split('/').last);
      
      for (final element in elements) {
        // 조건이 있으면 확인
        if (rule.condition != null && !rule.condition!(element)) {
          continue;
        }

        final attribute = element.getAttribute(rule.attributeName);
        if (attribute != null) {
          final convertedValue = rule.converter(attribute);
          element.setAttribute(rule.attributeName, convertedValue.toString());
        }
      }
    } catch (e) {
      // 개별 룰 적용 실패 시 로그만 남기고 계속 진행
      print('경고: Live 11 호환성 룰북 내 "${rule.description}" 규칙을 적용하는데 실패했습니다: $e');
    }
  }
}

class AbletonConverter {
  /// `.als` 파일 데이터와 목표 버전을 받아 변환된 파일 데이터를 반환합니다.
  ///
  /// [alsFileData]는 GZIP으로 압축된 원본 `.als` 파일의 바이트 데이터입니다.
  /// [targetVersion]은 "11.3.42"와 같은 형식의 전체 버전 문자열이어야 합니다.
  /// 변환에 성공하면 GZIP으로 재압축된 `List<int>`를, 실패하면 예외를 던집니다.
  List<int> convert(List<int> alsFileData, String targetVersion) {
    // 1. 버전 정보 생성
    final parts = targetVersion.split('.');
    final minorPart = parts[1];
    final versionInfo = {
      'MinorVersion': '11.0_11${minorPart}00',
      'Creator': 'Ableton Live $targetVersion'
    };

    // 2. GZIP 압축 해제
    final gzipDecoder = GZipDecoder();
    final xmlData = gzipDecoder.decodeBytes(alsFileData);
    final xmlString = utf8.decode(xmlData);

    // 3. XML 파싱 및 수정
    final document = XmlDocument.parse(xmlString);
    final abletonNode = document.rootElement;

    // 3A. 버전 정보 수정
    abletonNode.setAttribute('MinorVersion', versionInfo['MinorVersion']!);
    abletonNode.setAttribute('Creator', versionInfo['Creator']!);

    // 3B. <MidiEditorLaneModel> 태그를 <ExpressionLane>으로 치환
    final elementsToReplace = document.findAllElements('MidiEditorLaneModel').toList();
    for (final oldElement in elementsToReplace) {
      final newElement = XmlElement(
        XmlName('ExpressionLane'),
        oldElement.attributes.map((a) => a.copy()),
        oldElement.children.map((n) => n.copy()),
      );
      final parent = oldElement.parent;
      if (parent != null) {
        final index = parent.children.indexOf(oldElement);
        parent.children[index] = newElement;
      }
    }

    // 3C. Live 11 호환성을 위한 룰북 적용
    Live11CompatibilityRules.applyAllRules(document);
    
    final modifiedXmlString = document.toXmlString(pretty: true);

    // 4. GZIP으로 재압축
    final gzipEncoder = GZipEncoder();
    final modifiedAlsData = gzipEncoder.encode(utf8.encode(modifiedXmlString));

    if (modifiedAlsData == null) {
      throw Exception('GZIP 압축에 실패했습니다.');
    }

    return modifiedAlsData;
  }
}