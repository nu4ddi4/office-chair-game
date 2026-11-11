# 김 대리, 나 좀 밀어봐

풍선인형처럼 휘청거리는 직원이 바퀴 의자에 앉은 부장님을 밀고 사무실의 심부름을 수행하는 PC용 3인칭 물리 코미디 게임입니다. 직원·부장님의 15강체 인형, 양손 잡기, 물리 문, 커피, 연결된 6개 미션과 체크포인트를 제공합니다.

## 다운로드·설치·업데이트

[최신 릴리즈](https://github.com/nu4ddi4/office-zirral/releases/latest)의 **OfficeChairChaos-Setup.exe**를 실행하세요. 관리자 권한 없이 사용자 계정에 설치하며 시작 메뉴와 제거 기능을 제공합니다. 설치가 필요 없으면 Windows-x64.zip을 압축 해제해 실행하세요.

설치형은 게임 시작 시 새 안정 버전을 알리고 설정 → 업데이트에서 설치할 수 있습니다. 동의 후 진행 저장·다운로드·SHA-256 검증·설치·재실행을 수행하며 실행 확인에 실패하면 이전 파일로 복구합니다. 자동 확인은 설정에서 끌 수 있고, 오프라인에서도 게임을 계속할 수 있습니다. 휴대용 버전은 동의 후 설치 프로그램을 엽니다.

### Fedora·RHEL 계열 Linux (x86_64)

CI의 `OfficeChairChaos-Linux-x64` 아티팩트에 RPM과 휴대용 tar.gz가 들어 있습니다(정식 릴리스 첨부는 아직 Windows만). Fedora에서는 `sudo dnf install ./office-chair-chaos-<버전>-1.x86_64.rpm` 후 앱 메뉴의 Office Chair Chaos를 실행하거나 `office-chair-chaos`를 입력하세요. 제거는 `sudo dnf remove office-chair-chaos`입니다. 다른 배포판은 tar.gz를 풀어 `OfficeChairChaos.x86_64`를 실행하거나 `install.sh`로 사용자 계정에 설치합니다. Vulkan 또는 OpenGL 3.3 드라이버(Mesa)가 필요합니다. Linux에서는 자동 설치 업데이트 대신 게임의 업데이트 화면이 릴리스 페이지를 엽니다. 진행은 `~/.local/share/OfficeChairChaos`에 저장되며 제거해도 남습니다.

릴리즈 첨부는 설치 EXE·휴대용 ZIP·SHA256SUMS.txt 세 개입니다. 자산·엔진·폰트의 크레딧과 라이선스 전문은 패키지의 LICENSES.txt 및 게임의 라이선스 화면에 있습니다. 제거해도 진행·설정은 보존합니다.

## 소스에서 실행

Godot **4.7.2 stable**과 Git LFS가 필요합니다.

```sh
git lfs pull
godot --path godot
```

편집기에서는 `godot/project.godot`을 열고 F5로 실행합니다. 첫 화면에서 새 게임 또는 미션 선택으로 시작합니다.

| 입력 | 동작 |
|---|---|
| WASD / 마우스 | 자유 이동 / 시점 |
| 의자 뒤에서 E | 양손으로 손잡이 잡기 |
| 양손 밀기 중 W/S, A/D | 전후진, 조향 (시점 방향과 독립) |
| 마우스 좌·우 클릭 | 왼손·오른손 잡기 또는 놓기 |
| Shift | 달리기 / 밀기 중 부스트 |
| Space | 밀기 중 제동 / 버티기 / 일어나기 |
| E | 문 밀기, 커피 보충, 의자 세우기, 부장님 다시 태우기 |
| R 1초 | 체크포인트 복구 |
| Esc | 일시정지 |

의자 뒤에서 E를 누르면 양손 밀기로 진입합니다. 마우스로 양쪽 손잡이를 잡아도 같은 조작이 활성화됩니다. 한 손을 놓으면 자유 이동으로 돌아갑니다. 부스트 직진은 버틸 수 있지만 급회전·급제동·충돌에서는 부장님이 떨어지고 커피도 많이 쏟아집니다.

잡기는 클릭 유지가 기본이며 설정에서 누르는 동안 잡기로 바꿀 수 있습니다. 키·시야각·감도·음량·자막·화면 흔들림·품질도 설정할 수 있습니다.

## 여섯 가지 업무

1. **김 대리, 나 좀 밀어봐** — 걷기·잡기·제동과 첫 운반.
2. **커피 식겠다** — 커피를 보충하고 최소 20%를 남겨 회의실에 도착.
3. **문 좀 잡아줘** — 닫히는 문을 통과해 자료실에 갔다가 돌아오기.
4. **회의 시작했대** — 구간당 60초 안에 회의실로 운반.
5. **바람 좀 쐬자** — 미끄럼과 송풍, 후반 지정 구간의 낙하 금지.
6. **마지막으로 딱 하나만** — 구간당 90초와 커피 10% 조건을 지키고 퇴근.

진행·설정은 새 제품 전용 `OfficeChairChaos` 사용자 폴더에 저장합니다. 이전 게임의 사용자 데이터는 읽거나 변경하지 않습니다. 체크포인트에서 안전한 자세로 계속하며, 재도전해도 누적 운행 시간·파손·낙하 기록은 유지됩니다.

## 검사와 빌드

### 개발 중 빠르게 실행 (Windows)

- `play.bat`: 소스에서 바로 게임을 실행합니다. 빌드 과정이 없습니다.
- `build-dev.bat`: 약 6초 만에 `chaos-dev\OfficeChairChaos.exe`를 만들고 실행합니다. 내보내기 템플릿(1.2GB)이 필요 없습니다. Godot 실행 파일 옆에 같은 이름의 게임 팩(`.pck`)을 두는 방식이며, 정식 배포 빌드는 아래 `build-game.py`로 만듭니다.
- 둘 다 Godot 4.7.2를 `CHAOS_GODOT` 환경 변수, PATH, 저장소의 `.tools\godot` 순서로 찾습니다. 없으면 공식 GitHub 릴리스에서 받을지(약 82MB) 묻고, SHA-512를 확인한 뒤 `.tools\godot`에 둡니다. 맵 텍스처가 없다는 경고가 나오면 `git lfs pull`을 실행하세요.

```sh
python3 scripts/test-game.py --godot /path/to/Godot-4.7.2
# 디스플레이가 있으면 실제 렌더링 화면도 검사·저장
python3 scripts/test-game.py --godot /path/to/Godot-4.7.2 --rendered
# 원본 사무실의 보호 지오메트리·이동·문 회귀 검사
python3 scripts/test-map.py --godot /path/to/Godot-4.7.2
# Linux(내보내기 템플릿·rpmbuild 필요): RPM·tar.gz 생성과 실행 검사
python3 scripts/build-linux.py --godot godot --verify --rpm
# Windows 내보내기 템플릿 설치 후 휴대용 EXE 생성
python3 scripts/build-game.py --godot /path/to/Godot-4.7.2
# Windows에서 고정된 Inno Setup 6.7.3으로 설치형 생성·실행 검사
python scripts/build-game.py --godot /path/to/Godot-4.7.2 --verify --installer --iscc /path/to/ISCC.exe
# Windows PowerShell에서 설치·업데이트·복구·제거 검사
powershell -NoProfile -File tests/windows/installer-update.ps1
```

검사 결과와 화면은 `chaos-results/`, EXE·설치 프로그램·통합 라이선스·체크섬은 `chaos-dist/`에 생성합니다. CI는 Linux 검사와 동시에 실제 Windows PowerShell에서 설치·업데이트·실패 복구·제거까지 검증하고 다운로드 가능한 아티팩트를 만듭니다. 자동 공개 릴리스·Android 배포는 없습니다. 명시적으로 요청한 정식 릴리스는 main의 수동 `Release` 워크플로로 게시합니다. 성공한 `Test` 실행의 Windows 아티팩트와 main의 게임 입력이 같은지 확인하고 기존 EXE를 그대로 재사용합니다.

## 맵 제작과 개발

- `godot/chaos/`: 새 게임의 진입 장면·물리·규칙·UI·검사.
- `godot/chaos/data/`: 미션·경로·60×42m 사무실 배치.
- `assets/authoring/Office_Chaos.blend`: 확장 사무실 제작 원본.
- `godot/assets/models/Office_Chaos.glb`: 새 게임의 실행용 맵.
- `scripts/build-chaos-office.py`: 확장 맵의 초기 생성 기록. 이후 `Office_Chaos.blend`를 Blender에서 직접 편집하므로 다시 실행하지 않는다(편집 내용이 사라짐).

```sh
# 개발 전용 직접 시작: 정상 실행에서는 미션을 순서대로 해금
# --chaos-test는 QA 전용 별도 저장과 무음을 사용 (--audible-qa로 음향 활성화)
godot --path godot -- --chaos-test --mission 3
# 그래픽 자산 없이 같은 충돌 배치로 물리 확인
godot --path godot -- --chaos-test --blockout --mission 1
```

상세 구현·수치·검증 범위는 [개발 문서](docs/OFFICE_CHAIR_CHAOS.md)에 기록합니다. 의자와 사무실 자산의 라이선스는 [크레딧](godot/assets/credits.txt), 폰트는 [OFL](godot/assets/fonts/OFL.txt)을 따릅니다.

## 기존 게임 보관

기존 조사·터미널 게임은 [legacy/pre-reboot](https://github.com/nu4ddi4/office-zirral/tree/legacy/pre-reboot)에 있습니다. 기존 맵 원본 `Security_Lab_Interior_07.blend`와 `Interior_07_Godot.glb`는 자산 원천으로 보존하며, 새 게임은 별도 맵을 사용합니다. 원본 맵 확인 장면 `godot/scenes/office.tscn`은 회귀 검사와 에셋 확인용이며 새 게임 메뉴에 포함하지 않습니다.

## 정식 릴리스

0.x 개발은 최신 `main`에서 작업 브랜치를 만들고 PR로 `main`에 합칩니다. 통합 후 성공한 `Test` 실행 ID를 지정해 게시합니다. 태그는 프로젝트 버전과 일치하는 `OfficeChairChaos-vX.Y.Z`이며 기존 SecurityLab 태그와 릴리스는 보존합니다.

```sh
gh workflow run release.yml --ref main -f tag=OfficeChairChaos-v0.1.1 -f source_run_id=SUCCESSFUL_TEST_RUN_ID
```

게시 전 검증된 게임·설치 EXE·라이선스의 SHA-256을 확인하고 설치 EXE·휴대용 ZIP·체크섬만 첨부합니다. ZIP에는 게임과 통합 라이선스가 들어갑니다. 공개된 같은 태그의 게임 파일은 덮어쓰지 않습니다. `cleanup_old_assets=true`는 0.1.0의 원본 ZIP·내부 실행 파일·라이선스 검증 후 중복 첨부만 정리하고 체크섬 목록을 갱신합니다.
