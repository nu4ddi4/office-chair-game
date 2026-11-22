# 책상 아래

12cm가 된 두 사람이 사무실을 빠져나오는 원격 협동 프로토타입입니다.
호스트는 Linux에서 화면 없는 전용 서버를 열고, 두 참가자는 각자 PC에서 클라이언트를 실행합니다.
두 번째 참가자가 접속하면 함께 시작합니다.

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

Windows는 `TinyOffice-Windows.zip`에서 `TinyOffice.exe`, Linux는 `TinyOffice-Linux.tar.gz`에서 `./tiny-office`를 실행합니다. 두 사람 모두 같은 빌드를 사용합니다. 게임에서 서버의 공개 주소 또는 사설망 주소, UDP 포트와 방 키를 입력합니다.

- WASD로 이동하고 마우스로 봅니다. Space로 점프, E를 길게 눌러 잡기·고정·구출, V로 1·3인칭을 전환합니다. E를 놓으면 잡기를 풉니다.
- 아래에서 한 명이 서랍을 열고 다른 사람이 발판에 올라 클립을 끼웁니다. 두 사람 모두 첫 책상에 올라가면 바인더를 서로 다른 손잡이에서 잡습니다.
- 장치를 건너 두 번째 책상으로 이동한 뒤 노란 케이블을 내려가서 파티션 밑 배선 구멍으로 갑니다. 두 사람이 모두 도착하면 탈출입니다.
- 발소리가 가까워지거나 직원이 바라보면 가구 뒤에 숨습니다. 한 사람이 잡히면 다른 사람이 컵 옆에서 E를 1.5초 유지합니다. 둘 다 잡히면 직전 안전 지점으로 돌아갑니다.
- 한 사람이 방에서 나가면 대기실로 돌아갑니다. 다시 두 사람이 모이면 처음부터 시작합니다. Esc는 자신의 조작만 멈춥니다.

## 소스에서 빌드

이 폴더가 별도 Godot 프로젝트입니다. Godot 4.7.2 stable 및 해당 버전 내보내기 템플릿, Python 3가 필요합니다.

```sh
python3 prototype/tiny-office/build.py --godot /path/to/godot
```

`--target server`로 Linux 서버만 만들 수 있습니다. Linux에 풀어 놓은 공식 템플릿을 쓸 때는 `--templates /path/to/templates`를 지정합니다. 결과의 압축 파일과 체크섬은 `prototype/tiny-office/dist/`에 있습니다.
