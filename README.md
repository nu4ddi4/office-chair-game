# Office Map

기존 게임을 종료하고 새 게임을 만들기 위한 사무실 맵만 남긴 프로젝트입니다. 현재 게임 규칙이나 스테이지는 없습니다.

## 실행

Godot **4.7.2 stable**에서 `godot/project.godot`을 열고 F5로 실행합니다. 맵을 확인하기 위한 PC용 1인칭 이동과 문 조작만 제공합니다.

- WASD: 이동 / 마우스: 시점 / Space: 점프
- F: 문 열기·닫기
- Esc: 일시 정지 메뉴 / 메뉴에서 계속하기·종료

사무실의 가구·재질·조명·문·충돌과 창밖 도시 배경을 유지합니다. 기존 세이브나 설정 파일을 읽거나 변경하지 않습니다.

## 보관한 이전 게임

이전 조사 게임, 터미널·코미디 스테이지, 기획서·스토리·테스트·배포 코드는 GitHub의 [legacy/pre-reboot](https://github.com/nu4ddi4/security-lab-game/tree/legacy/pre-reboot)에 보관했습니다. 보관 기준 커밋은 `b63f47393a182cc0e056a85b6295f5eed3d7caa5`입니다. 기존 태그와 릴리스도 유지합니다.

현재 브랜치는 게임을 배포하지 않습니다. 기존 설치·자동 업데이트·EXE/APK 릴리스 파이프라인은 레거시 브랜치에 있습니다.

## 맵과 검사

- `assets/authoring/Security_Lab_Interior_07.blend`: 최신 맵 제작 원본
- `godot/assets/models/Interior_07_Godot.glb`: 실행용 맵
- `godot/scripts/world.gd`, `door.gd`, `exterior.gd`: 맵 구성·문·창밖 배경
- `godot/scenes/office.tscn`: 최소 맵 실행 장면

대용량 에셋은 Git LFS로 관리합니다.

```sh
git lfs pull
python3 scripts/test-map.py --godot /path/to/Godot-4.7.2
# 실제 렌더링 및 화면 저장 (디스플레이가 있는 환경)
python3 scripts/test-map.py --godot /path/to/Godot-4.7.2 --rendered
```

검사는 원본 맵의 보호 지오메트리, 문 충돌과 통과, 이동·점프·일시 정지·마우스 입력을 확인합니다. 결과는 `map-results/`에 남습니다. 에셋 출처는 [credits.txt](godot/assets/credits.txt)에 있습니다.
