#!/usr/bin/env python3
"""Package a previously verified Windows artifact without rebuilding it."""
import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FILES = ('OfficeChairChaos.exe', 'CREDITS.txt', 'LICENSES.txt', 'FONT-LICENSE.txt')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(source, output, version, tag, run_id, commit, repository, highlights=""):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("Expected the current GitHub repository owner/name")
    if not re.fullmatch(r'\d+\.\d+\.\d+', version) or tag != f'OfficeChairChaos-v{version}':
        raise ValueError('The release tag must match the game version and new product name')
    if not re.fullmatch(r'\d+', str(run_id)) or not re.fullmatch(r'[0-9a-f]{40}', commit):
        raise ValueError('Expected a verified run ID and full main commit SHA')
    for name in (*FILES, 'SHA256SUMS.txt'):
        if not (source / name).is_file():
            raise ValueError(f'Missing verified artifact file: {name}')
    exe = source / FILES[0]
    if exe.read_bytes()[:2] != b'MZ':
        raise ValueError('The artifact does not contain a Windows executable')
    lines = (source / 'SHA256SUMS.txt').read_text(encoding='utf-8').splitlines()
    checksums = dict((parts[1].lstrip('*'), parts[0]) for line in lines if len(parts := line.split()) == 2)
    if checksums.get(FILES[0]) != digest(exe):
        raise ValueError('The verified EXE checksum does not match')
    assets = output / 'assets'
    assets.mkdir(parents=True, exist_ok=True)
    if any(assets.iterdir()):
        raise ValueError('Use an empty release asset directory')
    for name in FILES:
        shutil.copyfile(source / name, assets / name)
    archive = assets / f'OfficeChairChaos-{version}-Windows-x64.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
        for name in (*FILES, 'SHA256SUMS.txt'):
            bundle.write(source / name, f'OfficeChairChaos/{name}')
    (assets / 'SHA256SUMS.txt').write_text(''.join(
        f'{digest(path)}  {path.name}\n' for path in sorted(assets.iterdir())), encoding='utf-8')
    notes = f'''# 김 대리, 나 좀 밀어봐 {version}

풍선인형처럼 휘청거리는 직원이 의자에 앉은 부장님을 운반하는 PC용 물리 코미디 게임입니다.

{highlights}

## 다운로드와 실행

**OfficeChairChaos-{version}-Windows-x64.zip**을 받아 압축을 풀고 `OfficeChairChaos.exe`를 실행하세요. Godot 설치는 필요하지 않습니다. 크레딧과 라이선스 파일은 함께 보관해 주세요.

- WASD: 자유 이동 / 마우스: 시점
- 의자 뒤에서 E: 양손 손잡이 잡기 / 밀기 중 W/S: 전후진, A/D: 조향
- 마우스 좌·우 클릭: 양손 잡기·놓기
- Shift: 달리기·부스트 / Space: 제동·버티기·일어나기
- E: 문·커피·의자·부장님 상호작용
- R 길게: 체크포인트 복구 / Esc: 일시정지

## 포함된 내용

- 직원·부장님의 물리 인형과 양손 의자 운반.
- 확장 사무실, 물리 문, 커피·미끄럼·바람과 연결된 6개 미션.
- 체크포인트, 미션 해금·기록, 독립 저장, 조작·화면·음향 설정.

Linux 검사와 실제 Windows EXE 실행을 통과한 [빌드](https://github.com/{repository}/actions/runs/{run_id})를 재사용했습니다. 릴리스 대상 main 커밋: `{commit}`.

Windows x64용 버전입니다. 플레이 분량·밸런스·기준 GPU 성능은 추가 실플레이 확인 대상입니다. 기존 SecurityLab 릴리스와 저장·자동 업데이트는 사용하지 않습니다.
'''
    (output / 'notes.md').write_text(notes, encoding='utf-8')
    return archive


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--run-id', required=True)
    parser.add_argument('--commit', required=True)
    parser.add_argument('--repository', default=os.environ.get('GITHUB_REPOSITORY', ''))
    args = parser.parse_args()
    version = re.search(r'^config/version="([^"]+)"', (ROOT / 'godot/project.godot').read_text(), re.M).group(1)
    highlights_path = ROOT / "docs/releases" / f"{version}.md"
    highlights = highlights_path.read_text(encoding="utf-8") if highlights_path.exists() else ""
    print(prepare(args.source, args.output, version, args.tag, args.run_id, args.commit, args.repository, highlights))


if __name__ == '__main__':
    main()
