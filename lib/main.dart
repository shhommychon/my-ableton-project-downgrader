import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:my_ableton_project_downgrader/ableton_converter.dart';
import 'package:my_ableton_project_downgrader/ableton_version.dart';

void main() {
  runApp(const MyApp());
}

/// 앱 루트 위젯
/// - 테마와 홈 화면만 설정
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '에이블톤 프로젝트 12 → 11',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

/// 메인 화면: 파일 선택 → 버전 선택 → 변환 실행 UI
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // --- 상태 보관 객체 ---
  // - 버전 조회 및 변환 로직은 별도 클래스로 분리
  final AbletonVersion _abletonVersion = AbletonVersion();
  final AbletonConverter _converter = AbletonConverter();

  // --- 드롭다운 데이터 및 선택값 ---
  List<String> _minorVersions = [];
  List<String> _patchVersions = [];
  String? _selectedMinorVersion;
  String? _selectedPatchVersion;

  // --- 파일 선택 및 진행 상태 ---
  final List<File> _filesToConvert = [];
  String _status = '1. .als 파일 또는 폴더를 선택하세요.';
  bool _isProcessing = false;

  // macOS 권한 보조 상태
  bool _pickedFolder = false;   // 폴더 선택 흐름인지 여부
  String? _grantedDir;          // 사용자가 쓰기 허용한 폴더 경로

  @override
  void initState() {
    super.initState();
    // 초기 데이터 적재: 마이너 버전 목록을 내림차순으로 정렬해 드롭다운에 바인딩
    _minorVersions = _abletonVersion.getMinorVersions();
    _minorVersions.sort((a, b) => b.compareTo(a));
  }

  // --- 유틸: 전체 상태 초기화 ---
  void _resetAll() {
    setState(() {
      _filesToConvert.clear();
      _selectedMinorVersion = null;
      _selectedPatchVersion = null;
      _patchVersions = [];
      _status = '1. .als 파일 또는 폴더를 선택하세요.';
      _isProcessing = false;
      _pickedFolder = false;
      _grantedDir = null;
    });
  }

  // --- 유틸: 마이너 선택 시 패치 목록 갱신 ---
  // - 마이너가 선택되면 해당 패치 리스트를 불러와 첫 항목으로 기본 선택
  void _updatePatchVersions(String? minor) {
    setState(() {
      _selectedMinorVersion = minor;
      _selectedPatchVersion = null;
      if (minor != null) {
        _patchVersions = _abletonVersion.getPatchVersions(minor);
        if (_patchVersions.isNotEmpty) {
          _selectedPatchVersion = _patchVersions.first;
        }
      } else {
        _patchVersions = [];
      }
      _updateStatus();
    });
  }

  // --- 유틸: 상단 진행 상태 문구 갱신 ---
  // - 파일 유무, 버전 선택 유무에 따라 1/2/3단계 문구 표시
  void _updateStatus() {
    if (_filesToConvert.isEmpty) {
      _status = '1. .als 파일 또는 폴더를 선택하세요.';
    } else {
      if (_selectedMinorVersion == null || _selectedPatchVersion == null) {
        _status = '2. 목표 Ableton 11 버전을 선택하세요.';
      } else {
        _status = '3. 변환 준비 완료. 버튼을 누르세요.';
      }
    }
  }

  // --- 파일 선택(단일) ---
  // - 기존 목록을 비우고 단일 파일로 대체
  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['als'],
    );

    if (result != null && result.files.single.path != null) {
      final selectedPath = result.files.single.path!;
      setState(() {
        _pickedFolder = false;
        _filesToConvert
          ..clear()
          ..add(File(selectedPath));
      });

      // macOS: 같은 폴더 쓰기 권한 요청
      if (Platform.isMacOS) {
        final parent = p.dirname(selectedPath);
        final dir = await FilePicker.platform.getDirectoryPath(
          dialogTitle: '원본 폴더 쓰기 권한을 부여하세요',
          initialDirectory: parent,
        );
        if (dir != null && p.equals(p.normalize(dir), p.normalize(parent))) {
          _grantedDir = dir; // 같은 폴더로 승인됨
        } else {
          _grantedDir = null; // 승인 실패 시 변환 단계에서 재요청
        }
      }

      _updateStatus();
    }
  }

  // --- 폴더 선택 후 .als 재귀 검색 ---
  // - 진행 표시를 켜고, .als 확장자만 수집
  Future<void> _selectFolder() async {
    final String? directoryPath = await FilePicker.platform.getDirectoryPath();

    if (directoryPath != null) {
      setState(() {
        _pickedFolder = true;
        _grantedDir = directoryPath; // 이 흐름은 이미 폴더 쓰기 권한 포함
        _isProcessing = true;
        _status = '.als 파일을 검색하는 중...';
        _filesToConvert.clear();
      });

      try {
        final dir = Directory(directoryPath);
        await for (var entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File && p.extension(entity.path) == '.als') {
            _filesToConvert.add(entity);
          }
        }
      } catch (e) {
        _status = '폴더 읽기 오류: $e';
      } finally {
        setState(() {
          _isProcessing = false;
          _status = '${_filesToConvert.length}개 파일을 찾았습니다.';
          _updateStatus();
        });
      }
    }
  }


  // --- 변환 실행 ---
  // - 선택된 모든 파일에 대해 압축 해제 → XML 수정 → 재압축
  Future<void> _convertFiles() async {
    if (_filesToConvert.isEmpty || _selectedMinorVersion == null || _selectedPatchVersion == null) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    final targetVersion = '11.$_selectedMinorVersion.$_selectedPatchVersion';
    int successCount = 0;
    int failCount = 0;

    for (int i = 0; i < _filesToConvert.length; i++) {
      final file = _filesToConvert[i];
      final fileName = p.basename(file.path);
      setState(() {
        _status = '변환 중 (${i + 1}/${_filesToConvert.length}): $fileName';
      });

      try {
        final originalBytes = await file.readAsBytes();
        final convertedBytes = _converter.convert(originalBytes, targetVersion);

        final parentDir = p.dirname(file.path);
        final newFileName = '${p.basenameWithoutExtension(file.path)}_downgraded.als';
        final newPath = p.join(parentDir, newFileName);

        // macOS 단일 파일 흐름: 동일 폴더 쓰기 권한 확인 및 필요 시 재요청
        if (Platform.isMacOS && !_pickedFolder) {
          final hasGrant = _grantedDir != null &&
              p.equals(p.normalize(_grantedDir!), p.normalize(parentDir));
          if (!hasGrant) {
            final dir = await FilePicker.platform.getDirectoryPath(
              dialogTitle: '저장할 원본 폴더를 선택하세요',
              initialDirectory: parentDir,
            );
            if (dir == null || !p.equals(p.normalize(dir), p.normalize(parentDir))) {
              // 같은 폴더로 승인되지 않으면 실패 처리
              failCount++;
              continue;
            }
            _grantedDir = dir;
          }
        }

        await File(newPath).writeAsBytes(convertedBytes);
        successCount++;
      } catch (e) {
        failCount++;
        debugPrint('변환 실패 $fileName: $e');
      }
    }

    setState(() {
      _isProcessing = false;
      _status = failCount > 0
          ? '변환 완료. $successCount개 성공, $failCount개 실패.'
          : '성공. 총 $successCount개 파일 변환 완료.';
    });
  }


  // --- UI 빌드 ---
  // - 상단 AppBar: 제목 + 항상 보이는 초기화 버튼
  // - 본문: 파일 선택 영역 → 버전 선택 영역 → 변환 버튼 → 상태 표시
  @override
  Widget build(BuildContext context) {
    final bool canConvert = _filesToConvert.isNotEmpty &&
        _selectedMinorVersion != null &&
        _selectedPatchVersion != null &&
        !_isProcessing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ableton 12 to 11 Downgrader'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            tooltip: '초기화',
            icon: const Icon(Icons.refresh),
            onPressed: _isProcessing ? null : _resetAll,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // --- 파일/폴더 선택 영역 ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('단일 파일 선택'),
                    onPressed: _isProcessing ? null : _selectFile,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(180, 50),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(' - 또는 - '),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: const Text('폴더 선택'),
                    onPressed: _isProcessing ? null : _selectFolder,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(180, 50),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- 선택된 파일 개수 표시 ---
              Text(
                _filesToConvert.isNotEmpty
                    ? '${_filesToConvert.length}개 파일 선택됨'
                    : '선택된 파일 없음',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              // --- 버전 선택 영역 ---
              if (_filesToConvert.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('버전: 11 . '),
                    const SizedBox(width: 20),
                    // 마이너 버전 드롭다운
                    DropdownButton<String>(
                      value: _selectedMinorVersion,
                      hint: const Text('Minor'),
                      items: _minorVersions
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: _isProcessing ? null : _updatePatchVersions,
                    ),
                    const SizedBox(width: 10),
                    const Text(' . '),
                    const SizedBox(width: 10),
                    // 패치 버전 드롭다운
                    DropdownButton<String>(
                      value: _selectedPatchVersion,
                      hint: const Text('Patch'),
                      items: _patchVersions
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: _isProcessing || _selectedMinorVersion == null
                          ? null
                          : (String? newValue) {
                              setState(() {
                                _selectedPatchVersion = newValue;
                                _updateStatus();
                              });
                            },
                    ),
                  ],
                ),
              const SizedBox(height: 40),

              // --- 변환 실행 버튼 ---
              ElevatedButton.icon(
                icon: const Icon(Icons.transform),
                label: const Text('변환 실행'),
                onPressed: canConvert ? _convertFiles : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // --- 보조 초기화 버튼(원하는 경우 화면 내에서도 접근) ---
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('초기화'),
                onPressed: _isProcessing ? null : _resetAll,
              ),
              const SizedBox(height: 24),

              // --- 진행 상태 표시 ---
              if (_isProcessing)
                const CircularProgressIndicator()
              else
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
