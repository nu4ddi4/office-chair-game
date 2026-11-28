# 개발 규칙

현재 제품의 가제는 SMALL BUSINESS입니다. Godot 4.7.2 stable의 PC용 1~2인 온라인 협동 프로토타입이며, 소스와 실행 절차는 `prototype/tiny-office/`에 있습니다.

## 작업과 이력

- 변경 전 현재 브랜치, 미커밋 파일, 원격 기준을 확인합니다. 최신 `main`에서 작업 브랜치를 만들고 검증 후 PR을 엽니다.
- 기존 이력, 태그 및 릴리스를 보존합니다. 이전 싱글플레이 게임은 `archive/office-chair-chaos`, 그 이전 게임은 `legacy/pre-reboot`에서 보관합니다.
- 커밋 작성자, 커미터 및 GitHub 게시 절차는 전역 Codex 지침을 따릅니다.
- 공개 릴리스는 사용자가 별도로 요청할 때만 게시합니다.

## 제품과 검증

- 전용 서버는 권위 서버로 동작하며, 같은 빌드의 PC 클라이언트 1~2개를 지원합니다. 기존 방 키 인증과 기본 UDP 포트 30820을 유지합니다.
- 실제 서버 설정과 방 키는 저장소에 넣지 않습니다. 배포에 포함하는 설정은 `server.example.cfg`입니다.
- 배포 대상은 Windows x64 클라이언트, Debian·Ubuntu amd64 클라이언트, Linux amd64 헤드리스 서버입니다. `prototype/tiny-office/build.py`에서 패키지와 SHA-256 목록을 생성합니다.
- 패키징을 변경하면 해당 대상을 다시 빌드하고, Debian 패키지는 설치·실행·제거를 확인합니다. 네트워크나 게임 동작을 변경하면 서버와 두 클라이언트로 관련 동작을 확인합니다.
- GitHub Actions 변경은 `actionlint`, 문서 변경은 링크와 `git diff --check`를 확인합니다.
