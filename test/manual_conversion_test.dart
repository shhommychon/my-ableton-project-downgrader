
import 'dart:io';
import 'package:my_ableton_project_downgrader/ableton_converter.dart';
import 'package:my_ableton_project_downgrader/ableton_version.dart';

/// 이 테스트는 커맨드 라인에서 직접 실행하여 `.als` 파일 변환을 테스트합니다.
///
/// 사용법:
/// dart run test/manual_conversion_test.dart <입력 파일 경로> <목표 버전>
///
/// 예시:
/// dart run test/manual_conversion_test.dart "/path/to/your/project.als" "11.3.42"
void main(List<String> args) {
  if (args.length != 2) {
    print('사용법: dart run test/manual_conversion_test.dart <입력 파일 경로> <목표 버전>');
    print('예시: dart run test/manual_conversion_test.dart "/path/to/your/project.als" "11.3.42"');
    exit(1);
  }

  final inputPath = args[0];
  final targetVersion = args[1];

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    print('오류: 입력 파일이 존재하지 않습니다: $inputPath');
    exit(1);
  }

  final versionManager = AbletonVersion();
  if (!versionManager.isValidVersion(targetVersion)) {
    print('오류: 지원되지 않는 버전입니다: $targetVersion');
    print('지원되는 버전 목록:');
    versionManager.getSupportedVersions().forEach((v) => print('- $v'));
    exit(1);
  }

  print('파일 변환을 시작합니다...');
  print('  - 입력: $inputPath');
  print('  - 목표 버전: $targetVersion');

  try {
    final alsFileData = inputFile.readAsBytesSync();
    
    final converter = AbletonConverter();
    final convertedData = converter.convert(alsFileData, targetVersion);

    final outputPath = inputPath.replaceAll('.als', '_downgraded.als');
    final outputFile = File(outputPath);
    outputFile.writeAsBytesSync(convertedData);

    print('\n변환 성공!');
    print('  - 출력 파일: $outputPath');
  } catch (e) {
    print('\n오류: 변환 중 문제가 발생했습니다.');
    print(e);
    exit(1);
  }
}
