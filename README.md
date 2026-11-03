# 김 대리, 나 좀 밀어봐

풍선인형처럼 휘청거리는 직원이 바퀴 의자에 앉은 부장님을 밀고 사무실의 심부름을 수행하는 PC용 3인칭 물리 코미디 게임입니다. 직원·부장님의 15강체 인형, 양손 잡기, 물리 문, 커피, 연결된 6개 미션과 체크포인트를 제공합니다.

## 실행

Godot **4.7.2 stable**과 Git LFS가 필요합니다.

```sh
git lfs pull
godot --path godot
```

편집기에서는 `godot/project.godot`을 열고 F5로 실행합니다. 첫 화면에서 새 게임 또는 미션 선택으로 시작합니다.

| 입력 | 동작 |
|---|---|
| WASD / 마우스 | 이동 / 시점 |
| 마우스 좌·우 클릭 | 왼손·오른손 잡기 또는 놓기 |
| Shift | 빠르게 밀기 |
| Space | 버티기 / 넘어진 상태에서 일어나기 |
| E | 문 밀기, 커피 보충, 의자 세우기, 부장님 다시 태우기 |
| R 1초 | 체크포인트 복구 |
| Esc | 일시정지 |

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

```sh
python3 scripts/test-game.py --godot /path/to/Godot-4.7.2
# 디스플레이가 있으면 실제 렌더링 화면도 검사·저장
python3 scripts/test-game.py --godot /path/to/Godot-4.7.2 --rendered
# 원본 사무실의 보호 지오메트리·이동·문 회귀 검사
python3 scripts/test-map.py --godot /path/to/Godot-4.7.2
# Windows 내보내기 템플릿 설치 후 휴대용 EXE 생성
python3 scripts/build-game.py --godot /path/to/Godot-4.7.2
# Windows에서 내보낸 EXE의 실행까지 확인
python scripts/build-game.py --godot /path/to/Godot-4.7.2 --verify
```

검사 결과와 화면은 `chaos-results/`, EXE·크레딧·체크섬은 `chaos-dist/`에 생성합니다. CI는 Linux 검사 후 실제 Windows에서 내보낸 EXE를 검증하고 다운로드 가능한 아티팩트를 만듭니다. 자동 공개 릴리스·자동 업데이트·Android 배포는 없습니다. 명시적으로 요청한 정식 릴리스는 main의 수동 `Release` 워크플로로 게시합니다. 성공한 `Test` 실행의 Windows 아티팩트와 main의 게임 입력이 같은지 확인하고 기존 EXE를 그대로 재사용합니다.

## 맵 제작과 개발

- `godot/chaos/`: 새 게임의 진입 장면·물리·규칙·UI·검사.
- `godot/chaos/data/`: 미션·경로·60×42m 사무실 배치.
- `assets/authoring/Office_Chaos.blend`: 확장 사무실 제작 원본.
- `godot/assets/models/Office_Chaos.glb`: 새 게임의 실행용 맵.
- `scripts/build-chaos-office.py`: 기존 자산을 재사용해 확장 맵을 재생성하는 Blender 스크립트.

```sh
blender -b --python scripts/build-chaos-office.py
# 개발 전용 직접 시작: 정상 실행에서는 미션을 순서대로 해금
# --chaos-test는 QA 전용 별도 저장과 무음을 사용 (--audible-qa로 음향 활성화)
godot --path godot -- --chaos-test --mission 3
# 그래픽 자산 없이 같은 충돌 배치로 물리 확인
godot --path godot -- --chaos-test --blockout --mission 1
```

상세 구현·수치·검증 범위는 [개발 문서](docs/OFFICE_CHAIR_CHAOS.md)에 기록합니다. 의자와 사무실 자산의 라이선스는 [크레딧](godot/assets/credits.txt), 폰트는 [OFL](godot/assets/fonts/OFL.txt)을 따릅니다.

## 기존 게임 보관

기존 조사·터미널 게임은 [legacy/pre-reboot](https://github.com/nu4ddi4/security-lab-game/tree/legacy/pre-reboot)에 있습니다. 기존 맵 원본 `Security_Lab_Interior_07.blend`와 `Interior_07_Godot.glb`는 자산 원천으로 보존하며, 새 게임은 별도 맵을 사용합니다. 원본 맵 확인 장면 `godot/scenes/office.tscn`은 회귀 검사와 에셋 확인용이며 새 게임 메뉴에 포함하지 않습니다.

## 정식 릴리스

`main` 승격은 PR로 진행합니다. 승격 후 성공한 `Test` 실행 ID를 지정해 게시합니다. 태그는 프로젝트 버전과 일치하는 `OfficeChairChaos-vX.Y.Z`이며 기존 SecurityLab 태그와 릴리스는 보존합니다.

```sh
gh workflow run release.yml --ref main -f tag=OfficeChairChaos-v0.1.0 -f source_run_id=SUCCESSFUL_TEST_RUN_ID
```

게시 전 검증된 EXE의 SHA-256을 확인하고 EXE·ZIP·크레딧·라이선스·체크섬을 첨부합니다. ZIP은 압축을 풀어 바로 실행할 수 있습니다. 공개된 릴리스를 같은 태그로 덮어쓰지 않습니다.
