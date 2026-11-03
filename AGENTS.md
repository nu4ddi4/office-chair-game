# 개발 규칙

현재 제품은 《김 대리, 나 좀 밀어봐》다. 물리 인형 직원이 부장님을 의자로 운반하는 PC용 싱글플레이 코미디 게임이며, 상세 구현과 검증은 `docs/OFFICE_CHAIR_CHAOS.md`를 따른다. 기존 게임은 `legacy/pre-reboot`에 보관한다.

## 작업과 이력

- 0.x 개발에서는 최신 main에서 feature/*, fix/*, refactor/* 작업 브랜치를 만든다. main에서 직접 개발하지 않는다. beta를 거치는 통합 단계는 사용하지 않는다.
- 시작 전 브랜치·미커밋 변경·원격 기준을 확인한다. 다른 사람의 작업을 삭제하거나 덮어쓰지 않는다.
- 관련 검증 후 작업 브랜치에서 main 대상으로 PR을 만들고 main에 통합한다. 공개 릴리스는 사용자의 명시적 요청에 따라 main의 검증된 빌드로 게시한다.
- 공유 이력을 rewrite하지 않는다. 레거시 브랜치·기존 태그·릴리스는 유지한다.
- 로컬 Git 작성자·커미터: codex-nu4ddi4 / 95563468+nu4ddi4@users.noreply.github.com. PR·커밋에 Codex 작업임을 명시한다.

## 제품과 자산

- Godot 4.7.2 stable, Jolt 3D, 120Hz 물리를 사용한다. 튜닝 수치는 chaos/scripts/tuning.gd와 각 제어기의 이름 있는 매개변수로 관리한다.
- 직원·부장님의 충돌 반응과 힘을 통한 손 잡기를 유지한다. 실제 플레이에서 강체 위치를 매 프레임 강제로 덮어쓰지 않는다.
- 원본 사무실 GLB·Blender·출처는 보존한다. 새 맵은 Office_Chaos.blend와 Office_Chaos.glb로 제작하며 LFS를 사용한다. source 복원 후 Blender 생성 스크립트로 재현한다.
- 새 저장·설정은 OfficeChairChaos 사용자 폴더에만 쓴다. 기존 게임의 저장·업데이트·Android 패키지를 사용하지 않는다.
- 첫 배포는 Windows 휴대용 EXE와 체크섬이다. Test CI는 아티팩트만 만든다. 사용자가 명시적으로 요청한 공개 릴리스는 main 전용 수동 Release 워크플로에서 검증된 Windows 아티팩트를 재사용해 게시한다. 옛 제품 업데이트는 게시하지 않는다.
- PC 키보드·마우스가 첫 버전의 기준이다. 협동·온라인·모바일·범용 파괴·경제 시스템은 범위 밖이다.

## 검증

- 규칙·저장 변경: python3 scripts/test-game.py --godot PATH --suite rules
- 물리·장면·입력 변경: 같은 명령의 --suite scene(physics·handling 포함). 밀기 조작만 빠르게 검사할 때는 --suite handling. 디스플레이가 있으면 --rendered로 실제 화면도 확인한다.
- 큰 변경은 --suite all 한 번. 테스트는 실제 회귀 위험을 검사하며 같은 입력을 불필요하게 재검사하지 않는다.
- 검사기는 원본 보호 지오메트리·새 맵 배치·미션 경로 검사도 포함한다. 원본 실행 회귀는 scripts/test-map.py로 확인한다.
- 실제 경로의 강체 충돌 검사는 godot/chaos/tests/drive.gd다. 의자에 제한된 힘을 가해 경로·문을 검사하며 플레이어 숙련도나 재미를 입증하는 검사는 아니다.
- CI 변경은 actionlint. 문서는 링크·git diff --check. Windows EXE 실행은 Windows의 scripts/build-game.py --verify 또는 CI로 검증한다.
- 성능 목표·30~60분 분량·재미는 자동 검증으로 통과했다고 주장하지 않는다. 실제 사람의 플레이와 지정 하드웨어 측정이 필요하다.
