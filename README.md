# 책상 아래

12cm가 된 두 사람이 사무실을 빠져나오는 PC용 2인 온라인 협동 게임입니다. 한 사람이 전용 서버를 열고, 두 참가자가 같은 클라이언트 빌드로 접속합니다.

- **Windows amd64** — `TinyOffice-Windows.zip`을 압축 해제하고 `install-windows.cmd`로 설치하거나 `TinyOffice.exe`를 실행합니다.
- **Debian 12 · Ubuntu 24.04 amd64** — `tiny-office_0.1.0_amd64.deb`를 APT로 설치합니다. `install-linux.sh`를 같은 폴더에 두고 실행해도 됩니다.
- **전용 서버** — Linux amd64의 `TinyOffice-Linux-Server.tar.gz`를 사용합니다. 기본 게임 포트는 UDP 30820입니다.

[설치, 서버 설정 및 플레이 방법](prototype/tiny-office/README.md)

## 개발 및 빌드

Godot 4.7.2 stable에서 `prototype/tiny-office/project.godot`을 엽니다. Windows에서는 `play.bat`로 개발용 클라이언트를 시작할 수 있습니다.

Linux에서 Godot 내보내기 템플릿과 Python 3, `dpkg-deb`를 준비하고 아래 명령을 실행하면 서버와 두 클라이언트를 모두 빌드합니다.

```sh
python3 prototype/tiny-office/build.py --godot godot --deb
```

산출물과 SHA-256 목록은 `prototype/tiny-office/dist/`에 생성됩니다. GitHub Actions의 `Test` 워크플로에서도 같은 산출물을 받을 수 있습니다.

## 이전 게임

《김 대리, 나 좀 밀어봐》의 소스와 이전 빌드 절차는 [싱글플레이 보관 브랜치](https://github.com/nu4ddi4/office-chair-game/tree/archive/office-chair-chaos)에 있습니다. 그보다 앞선 버전은 [레거시 보관 브랜치](https://github.com/nu4ddi4/office-chair-game/tree/legacy/pre-reboot)에 있습니다.
