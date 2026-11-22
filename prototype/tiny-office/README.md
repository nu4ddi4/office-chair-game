# SMALL BUSINESS

작아진 직원들이 책상 위에서 일하는 1~2인 온라인 협동 프로토타입입니다. Linux 전용 서버에 접속한 뒤 혼자 근무하거나 동료와 함께 시작할 수 있습니다.

## 서버 열기

Debian 12 또는 Ubuntu 24.04급 Linux amd64에서 `TinyOffice-Linux-Server.tar.gz`의 압축을 풀고 서버 폴더로 들어갑니다. Godot 편집기는 설치할 필요가 없습니다.

```sh
tar -xzf TinyOffice-Linux-Server.tar.gz
cd TinyOffice-Linux-Server
umask 077
cp server.example.cfg server.cfg
openssl rand -hex 18
```

`server.cfg`의 `room_key`를 방금 생성한 값으로 바꿉니다. 방 키는 영문·숫자·하이픈·밑줄 16~64자이며 참가자 두 사람에게만 공유합니다. 기본 바인딩은 모든 인터페이스, 기본 포트는 UDP 30820입니다.

```sh
./tiny-office-server --headless -- --config "$PWD/server.cfg"
```

- VPS 보안 그룹과 OS 방화벽에서 UDP 30820을 엽니다. 참가자 IP를 알면 해당 IP에만 허용합니다. 가정용 공유기 뒤에서 서버를 열 경우 해당 포트를 서버 PC로 전달합니다.
- 터미널의 `TINY_OFFICE_READY`에서 포트를 확인합니다. `TINY_OFFICE_JOIN`은 참가 인원, `TINY_OFFICE_TICK`은 최근 600틱 중 가장 오래 걸린 게임 로직에서 상태 전송까지의 시간을 출력합니다. 목표는 틱당 16.67ms 이내입니다.
- `Ctrl+C`로 서버를 종료합니다. 상태는 메모리에만 있고 플레이어 연결과 함께 해제됩니다.
- 방 키에 대한 응답을 매 접속마다 확인합니다. 게임 데이터는 일반 ENet UDP라 공개망에서 보호가 필요하면 참가자끼리 쓸 수 있는 사설망 주소로 연결합니다.

## 친구 PC에서 접속

### Windows 64비트

`TinyOffice-Windows.zip`을 모두 압축 해제하고 `install-windows.cmd`를 실행합니다. 관리자 권한 없이 현재 사용자에게 설치하며, 시작 메뉴에서 **Tiny Office**를 실행할 수 있습니다. 설치 없이 플레이하려면 `TinyOffice.exe`를 바로 실행합니다.

### Debian 12 · Ubuntu 24.04 amd64

`tiny-office_0.2.0_amd64.deb`와 `install-linux.sh`를 같은 폴더에 두고 실행합니다. 설치 스크립트가 APT로 필요한 패키지를 함께 설치합니다.

```sh
sh ./install-linux.sh
```

설치 후 앱 메뉴에서 **책상 아래**를 열거나 터미널에서 `tiny-office`를 실행합니다. 설치 없이 플레이하려면 `TinyOffice-Linux.tar.gz`를 풀고 `./tiny-office`를 실행합니다.

로컬 DEB에는 GNOME 소프트웨어에서 사용하는 한국어 이름과 요약, 아이콘과 AppStream 메타데이터가 포함됩니다. 설치 후 GNOME 소프트웨어의 **설치됨**에서 **책상 아래**의 앱 정보를 열 수 있습니다.

서버와 모든 참가자는 같은 빌드를 사용합니다. 근무조 버전은 이전 서버·클라이언트와 호환되지 않습니다. 게임에서 호스트가 공유한 서버 주소, UDP 포트(기본값 `30820`)와 방 키를 입력합니다.

## 근무조 플레이

1. 대기실에서 **근무 시작**을 누릅니다. 혼자 시작하거나 두 사람이 모인 뒤 시작할 수 있습니다.
2. 파란 USB를 컴퓨터 옆 파란 표식에, 서류 묶음을 노란 트레이에 놓습니다. 두 업무는 동시에 진행할 수 있습니다.
3. 모든 업무가 끝나면 결과를 잠깐 보여 준 뒤 같은 방에서 다음 판을 시작합니다. 세 번째 판을 마치면 퇴근 화면에서 팀 업무 수와 근무 시간을 확인하고, **새 근무조 시작**으로 다시 플레이할 수 있습니다.

- WASD로 이동하고 마우스로 시점을 조작합니다. Space는 점프, V는 1·3인칭 전환, Esc는 메뉴입니다.
- 물건 가까이에서 E로 잡고 다시 E를 눌러 놓습니다. 왼쪽 클릭으로 보고 있는 방향에 던질 수 있습니다. 떨어진 물건은 출발 위치, 플레이어는 책상 위 안전 위치로 돌아옵니다.
- 도중에 들어온 참가자는 다음 판부터 합류합니다. 동료가 방을 나가도 남은 사람이 판을 마칠 수 있습니다.

## 소스에서 빌드

이 폴더가 별도 Godot 프로젝트입니다. Godot 4.7.2 stable 및 해당 버전 내보내기 템플릿, Python 3가 필요합니다.

```sh
python3 prototype/tiny-office/build.py --godot /path/to/godot
```

`--target server`로 Linux 서버만 만들 수 있습니다. Linux에 풀어 놓은 공식 템플릿을 쓸 때는 `--templates /path/to/templates`를 지정합니다. 결과의 압축 파일과 체크섬은 `prototype/tiny-office/dist/`에 있습니다.

Windows 클라이언트만 만들려면 `--target windows`, Debian 패키지를 포함한 Linux 클라이언트를 만들려면 `--target linux --deb`를 추가합니다. `--deb`에는 `dpkg-deb`가 필요합니다. 대상 옵션 없이 `--deb`만 추가하면 모든 플랫폼 결과와 Debian 패키지를 함께 만듭니다.

## 근무조 회귀 검사

```sh
python3 prototype/tiny-office/tests/test_shift.py --godot /path/to/godot
```

루프백의 임시 ENet 서버와 실제 헤드리스 클라이언트로 1인·2인 접속, 세 판 진행, 중간 합류와 이탈, 새 근무조 초기화를 확인합니다.
