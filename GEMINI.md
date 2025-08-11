   █████████  ██████████ ██████   ██████ █████ ██████   █████ █████
  ███░░░░░███░░███░░░░░█░░██████ ██████ ░░███ ░░██████ ░░███ ░░███
 ███     ░░░  ░███  █ ░  ░███░█████░███  ░███  ░███░███ ░███  ░███
░███          ░██████    ░███░░███ ░███  ░███  ░███░░███░███  ░███
░███    █████ ░███░░█    ░███ ░░░  ░███  ░███  ░███ ░░██████  ░███
░░███  ░░███  ░███ ░   █ ░███      ░███  ░███  ░███  ░░█████  ░███
 ░░█████████  ██████████ █████     █████ █████ █████  ░░█████ █████
  ░░░░░░░░░  ░░░░░░░░░░ ░░░░░     ░░░░░ ░░░░░ ░░░░░    ░░░░░ ░░░░░

# Gemini-CLI 개발 가이드: Naive Ableton 12 to 11 Downgrader

## 1. 프로젝트 목표

**Ableton Live 12** 버전으로 제작된 `.als` 프로젝트 파일을 **Ableton Live 11**에서 열 수 있도록 변환해 주는 사용자 친화적인 데스크톱 애플리케이션을 개발합니다. 이 애플리케이션은 프로그래밍 지식이 없는 음악 프로듀서들도 쉽게 사용할 수 있도록 직관적인 GUI를 제공하며, **Windows**와 **macOS**를 지원하는 것을 목표로 합니다.

### 1.1. 프로젝트 배경

Ableton Live는 공식적으로 **하위 버전 호환성을 지원하지 않습니다** \([공식 정책](https://help.ableton.com/hc/en-us/articles/360000841004-Backward-Compatibility)\). 이로 인해 최신 버전 사용자와 이전 버전 사용자 간의 협업에 어려움이 발생합니다. 이 문제를 해결하기 위해 몇 가지 시도가 있었습니다.

- 기존 서비스 및 프로젝트:
  - [Jukeblocks Convert](https://jukeblocks.io/convert/): `.als` 파일 다운그레이드를 제공하는 웹 서비스. 신규 버전의 기능은 제거될 수 있다고 고지합니다.
  - [abletonconvert](https://github.com/trobonox/abletonconvert): Live 10.0.x 버전으로 변환을 목표로 하는 오픈소스 프로젝트.
  - [als-version-patcher](https://github.com/tpwl21/als-version-patcher): XML 헤더 패치를 통해 11.x 버전 내의 마이너 업데이트 간 다운그레이드를 지원.
  - [guard-live-set](https://github.com/mgarriss/guard-live-set), [als-tools](https://github.com/luizen/als-tools): `.als` 파일을 XML로 변환하거나 메타데이터를 스캔하는 도구.

본 프로젝트는 이러한 기존 도구들의 아이디어를 바탕으로, 더 안정적이고 사용하기 쉬운 GUI 애플리케이션을 Flutter로 제작하여 더 넓은 사용자층에게 해결책을 제공하고자 합니다.

## 2. 핵심 기술 스택

- 언어: Dart
- 프레임워크: Flutter
- 타겟 플랫폼: Windows, macOS
- 핵심 라이브러리:
  - `archive`: GZIP 압축 및 해제 처리
  - `xml`: XML 데이터 파싱 및 수정
  - `file_picker`: 네이티브 파일 선택기 사용

## 3. 변환 프로세스 상세

`.als` 파일은 실제로는 GZIP으로 압축된 XML 파일입니다. 변환 프로세스는 이 XML 내용을 수정하고 다시 압축하는 방식으로 이루어집니다.

### 3.1. 1단계: `.als` 파일 압축 해제

사용자가 선택한 `.als` 파일을 GZIP 압축 해제하여 원본 XML 데이터를 얻습니다.

- 구현: Dart의 `archive` 라이브러리에 포함된 `GzipDecoder`를 사용하여 파일 스트림을 처리합니다.
- GZIP 사용의 중요성:
    - `.als` 파일은 여러 파일을 묶은 **ZIP 아카이브가 아니라, 단일 XML 파일을 GZIP으로 압축한 것**입니다. ([출처1](https://stackoverflow.com/questions/68616517/anybody-know-how-jukeblocks-io-was-able-to-read-an-ableton-als-file-contents-in), [출처2](https://forum.ableton.com/viewtopic.php?p=1832544))
    - 만약 macOS Finder의 '압축' 기능이나 일반적인 `zip` 명령어로 재압축하면 파일 헤더와 컨테이너 구조가 변경됩니다. 이 경우 Ableton Live는 파일을 정상적으로 인식하지 못하고 "Unknown Compound Stream Type" 오류를 발생시킵니다. ([관련 공식 문서](https://help.ableton.com/hc/en-us/articles/209773445-Corrupt-Sets))
    - GZIP은 단일 데이터 스트림을 압축하는 반면, ZIP은 파일 목록, 중앙 디렉터리 등 메타데이터를 포함하는 컨테이너 포맷입니다. 따라서 반드시 GZIP 스트림을 직접 다루어야 합니다. 올바른 방법은 `gzip -cd`로 압축을 풀고, 편집 후 `gzip -n -c`로 타임스탬프 정보 없이 재압축하는 것입니다. ([참고 자료](https://mslinn.com/av_studio/553-live_set.html))

### 3.2. 2단계: XML 내용 수정

압축 해제된 XML 데이터에서 다음 두 가지 주요 수정 작업을 수행합니다.

### A. 버전 정보 수정 (필수)

XML의 최상단 `<Ableton>` 태그에 있는 `MinorVersion`과 `Creator` 속성값을 Ableton Live 11 버전과 호환되는 값으로 변경합니다.

- 변경 전 예시:
  ```
  <?xml version="1.0" encoding="UTF-8"?>
  <Ableton ... MinorVersion="12.0_12203" ... Creator="Ableton Live 12.2.1" ...>
    <LiveSet>
      ...
  ```
    
- 변경 후 예시:
  ```
  <?xml version="1.0" encoding="UTF-8"?>
  <Ableton ... MinorVersion="11.0_11300" ... Creator="Ableton Live 11.3.26" ...>
    <LiveSet>
      ...
  ```
    
- 앱 기능: 사용자가 유효한 Ableton 11 버전 목록(아래 참조)에서 원하는 버전을 선택할 수 있도록 드롭다운 메뉴를 제공해야 합니다.
  - `MinorVersion="11.0_11300"`, `Creator="Ableton Live 11.3.42"`
  - `MinorVersion="11.0_11200"`, `Creator="Ableton Live 11.2.11"`
  - `MinorVersion="11.0_11100"`, `Creator="Ableton Live 11.1.6"`
  - `MinorVersion="11.0_11000"`, `Creator="Ableton Live 11.0.12"`

### B. 태그 이름 치환 (조건부)

Ableton 12에서 새로 도입된 `<MidiEditorLaneModel>` 태그가 존재할 경우, Ableton 11이 인식할 수 있는 `<ExpressionLane>` 태그로 단순히 텍스트를 치환합니다. 이는 버전 정보만 수정했을 때 파일이 열리지 않는 호환성 문제를 해결합니다.

- 변경 전 예시:
  ```
  <ExpressionLanes>
    <MidiEditorLaneModel Id=...>
      <Type Value=... />
      <Size Value=... />
      <IsMinimized Value=... />
    </MidiEditorLaneModel>
    ...
  </ExpressionLanes>
  <ContentLanes>
    <MidiEditorLaneModel Id=...>
      <Type Value=... />
      <Size Value=... />
      <IsMinimized Value=... />
    </MidiEditorLaneModel>
    ...
  </ContentLanes>
  ```
    
- 변경 후 예시:
  ```
  <ExpressionLanes>
    <ExpressionLane Id=...>
      <Type Value=... />
      <Size Value=... />
      <IsMinimized Value=... />
    </ExpressionLane>
    ...
  </ExpressionLanes>
  <ContentLanes>
    <ExpressionLane Id=...>
      <Type Value=... />
      <Size Value=... />
      <IsMinimized Value=... />
    </ExpressionLane>
    ...
  </ContentLanes>
  ```

### 3.3. 3단계: `.als` 파일로 재압축

수정된 XML 데이터를 다시 GZIP으로 압축하여 새로운 `.als` 파일을 생성합니다.

- 재압축 시 반드시 `n` 옵션(타임스탬프 및 원본 파일 이름 저장 안 함)을 사용한 것과 동일한 효과를 내야 합니다. Dart의 `archive` 라이브러리에 포함된 `GzipEncoder`를 사용하여 이 문제를 해결합니다.

## 4. Gemini의 역할

Gemini는 이 프로젝트의 AI 코딩 어시스턴트로서 다음 역할을 수행합니다.

- 코드 생성: Flutter 위젯, 파일 처리 로직, 상태 관리 등 프로젝트에 필요한 Dart 코드를 작성합니다.
- 아키텍처 제안: 파일 처리, UI 업데이트, 상태 관리를 위한 효율적인 앱 구조를 제안합니다.
- 디버깅 지원: 코드 오류, 플랫폼별 호환성 문제, 변환 로직의 버그를 찾아내고 해결책을 제시합니다.
- 로직 구현: 위에 명시된 3단계 변환 프로세스를 정확하게 구현하는 코드를 작성합니다.
- 사용자 배경 반영: 요청자는 Dart는 생소하지만 Python 경험이 풍부한 아마추어 프로그래머입니다. 프로그래밍 자체에는 익숙하므로 Dart/Flutter 코드 구현과 예제 중심 지원만으로 이해가 가능합니다. 별도의 설명을 요청할 경우 Python 대비 개념·용어 매핑과 간단한 비교, Dart/Flutter 생태계에서의 보편적인 구현 방식에 대한 설명을 덧붙입니다.

이 문서를 바탕으로 프로젝트의 목표와 기술적 요구사항을 숙지하고, 성공적인 앱 개발을 위해 적극적으로 협력해 주시기 바랍니다.