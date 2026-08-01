# Prompt Log

이미지·영상 생성 결과와 그걸 만든 프롬프트를 한곳에 모아두는 **의존성 없는 단일 HTML 갤러리**.
폴더 하나를 지정하면 그 안의 결과물을 읽어들이고, 메타데이터는 같은 폴더의 `metadata.json`에 남습니다.
서버도 빌드도 계정도 없습니다.

## 실행

File System Access API가 필요하므로 **Chrome / Edge**에서 `http://localhost`로 열어야 합니다
(`file://`에서는 폴더 선택이 동작하지 않습니다).

```bash
python -m http.server 8765 --directory .
```

그 후 `http://localhost:8765/prompt-log.html`.

## 프롬프트 자동 추출

ComfyUI는 PNG의 tEXt 청크에 API 그래프 전체(`prompt`)와 에디터 그래프(`workflow`)를 박아서 저장하고,
A1111 계열은 `parameters`에 평문으로 남깁니다. Prompt Log는 파일을 읽어들일 때 이걸 파싱해서
**프롬프트 · 네거티브 · 모델 · 시드 · steps · cfg · 샘플러 · 스케줄러 · 해상도 · LoRA** 를 자동으로 채웁니다.

ComfyUI 그래프는 단순히 "첫 번째 CLIPTextEncode"를 집지 않고, 샘플러 노드의 `positive` / `negative`
링크를 거꾸로 타고 올라가 실제 텍스트를 찾습니다. 그래서:

- 포지티브와 네거티브가 뒤바뀌지 않습니다
- `ConditioningZeroOut`으로 비워둔 네거티브는 비어 있는 것으로 인식합니다
- `Seed (rgthree)` 처럼 시드를 링크로 넘기는 노드도 값을 따라갑니다
- `ImpactWildcardProcessor`의 `populated_text`(전개된 결과)를 원본 템플릿보다 우선합니다
- `StringConcatenate`로 조립한 프롬프트는 이어붙여 복원합니다
- 샘플러가 없는 그래프(업스케일 등)는 가장 긴 리터럴 문자열로 대체하되,
  `easy showAnything` 같은 표시 전용 노드는 제외합니다

실측: 로컬 ComfyUI 출력 PNG 500장 무작위 표본 기준 — 프롬프트 98%, 모델 100%, 시드 94%.

자동으로 채워진 항목에는 `AUTO` 배지가 붙고, **자동 추출** 버튼으로 기존 항목도 소급 적용됩니다.
이미 입력된 값은 절대 덮어쓰지 않습니다.

영상(mp4 등)에는 표준 메타데이터가 없어 자동 추출 대상이 아닙니다.

## 데이터 안전

- `metadata.json` 파싱에 실패하면 **덮어쓰지 않고 멈춥니다.** 손상본은
  `metadata.corrupt-<날짜>.json` 으로 격리되고, 세션 시작 시 마지막 정상본이
  `metadata.backup.json` 으로 보관됩니다.
- 저장은 임시 파일에 쓴 뒤 교체하며, 동시 저장은 직렬화되어 서로 섞이지 않습니다.

## 단축키

| 키 | 동작 |
|---|---|
| `/` | 검색창 포커스 |
| `Esc` | 모달 닫기 |

드래그앤드롭으로 파일을 추가할 수 있습니다.

## 알려진 제약

- 하위 폴더는 아직 스캔하지 않습니다 (최상위만)
- 썸네일이 `metadata.json` 안에 base64로 들어가 항목이 많아지면 파일이 커집니다
- 항목의 키가 파일명이라, 폴더 밖에서 이름을 바꾸면 새 항목으로 잡힙니다
