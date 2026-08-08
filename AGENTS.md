# AGENTS.md — 이 저장소에서 작업할 때

Prompt Log는 **의존성 없는 단일 HTML 파일**입니다. `prompt-log.html` 하나가 전부이고,
빌드도 패키지 매니저도 테스트 러너도 없습니다.

## 절대 깨면 안 되는 것

1. **파일은 하나로 유지.** CSS·JS를 별도 파일로 쪼개거나 번들러를 도입하지 마세요.
   사용자가 파일 하나만 복사해서 쓰는 게 이 프로젝트의 핵심 특성입니다.
2. **외부 의존성 0.** npm 패키지, CDN 스크립트, 웹폰트 전부 금지. 네트워크 요청을
   하지 않는 것이 신뢰의 근거입니다.
3. **사용자 데이터를 덮어쓰지 않기.** 자동 추출은 **빈 칸만** 채웁니다. 손으로 입력한
   값은 어떤 경우에도 건드리지 않습니다.
4. **`metadata.json` 파싱 실패 시 절대 새로 쓰지 않기.** 격리 후 정지가 규칙입니다.
   (예전에 이 버그로 라이브러리가 통째로 날아갈 수 있었습니다.)

## 이 프로젝트가 존재하는 이유

수기 입력을 요구하는 프롬프트 기록은 결국 안 쓰게 됩니다. 하루 50장 생성하면 5장만
기록되니까요. **그래서 이 프로젝트의 성패는 "사람이 프롬프트를 안 적게 만드는 것"에
달려 있습니다.** 기능을 추가할 때 이 기준으로 판단하세요.

ComfyUI PNG에는 워크플로가 통째로 박혀 있어서 프롬프트·모델·시드를 자동으로 뽑아낼 수
있습니다. 실측 정확도(500장 표본): 프롬프트 98%, 모델 100%, 시드 94%.

---

## 코드 지도 (`prompt-log.html`, 약 2,200줄)

```
   1– 400   <style> — 전체 CSS (테마 변수는 :root / :root[data-theme="light"])
 400– 500   IndexedDB 핸들 보존, boot()
 495– 610   metadata io — loadMeta / saveMeta (원자적 저장, 손상 격리, 백업)
 609– 878   임베디드 메타데이터 추출
              readPngTextChunks  PNG tEXt/iTXt 리더 (IDAT 전까지, 버퍼 점증)
              extractFromComfyGraph  샘플러 → positive/negative 역추적
              parseA1111
              applyEmbedded  빈 칸만 채움
 878– 943   경로 해석 — getFileAt / removeFileAt (entry.filename은 상대 경로)
 906– 943   썸네일 — .thumbs/<id>.jpg
 943–1155   참조(refs) — .refs/, 종류 판별, 영상 포스터, input 폴더 자동 해석
1155–1343   스캔 — walkMedia(재귀) / scanOrphans(2단계) / processPending(백그라운드)
1398–1505   필터·렌더 — render() / primeThumbs() / refreshCard()
1505–1937   참조 UI — setupRefs(), 라이트박스, 인라인 오디오 재생
1937–2033   항목 모달
2081–2192   내보내기 (자립형 HTML 생성)
```

### 데이터 모델

```js
entry = {
  id, filename,        // filename = 라이브러리 폴더 기준 상대 경로 (POSIX 구분자)
  type: "image"|"video",
  prompt, negative, tool, seed, model, notes, tags: [],
  params: {steps, cfg, sampler, scheduler, denoise, size, loras},
  thumbFile, tw, th,   // .thumbs/<id>.jpg + 크기(레이아웃 예약용)
  size, mtime,         // 옮긴 파일 재매칭용
  refs: [{ id, name, file, poster, kind, dur, from, auto }],
  favorite, needInfo, autoMeta, pending, missing, createdAt
}
```

`refs[].file`이 비어 있으면 **이름만 아는 빈 자리**입니다(그래프에서 읽음).
`from`은 `"graph"` 또는 `"upload"`, `auto`는 input 폴더에서 자동 해석됐다는 뜻입니다.

---

## 검증 방법 — 반드시 읽으세요

이 앱은 File System Access API로 로컬 폴더를 읽습니다. 폴더 선택창은 자동화할 수 없어서
평범한 방법으로는 아무것도 테스트할 수 없습니다.

**해법: OPFS로 진짜 디렉터리 핸들을 만들고 피커만 스텁합니다.** 앱 코드는 한 줄도
수정하지 않은 채로 전체 경로가 실제로 실행됩니다.

```js
// 1) localhost로 페이지를 띄운 뒤, 브라우저 콘솔에서:
const root = await navigator.storage.getDirectory();

// 2) 테스트 파일을 심는다 (하위 폴더도 가능)
const dir = await root.getDirectoryHandle("2603", {create:true});
const fh  = await dir.getFileHandle("a.png", {create:true});
const w   = await fh.createWritable();
await w.write(await (await fetch("/some-test.png")).blob());
await w.close();

// 3) 피커만 갈아끼운다 — 이후는 전부 앱의 실제 코드
window.showDirectoryPicker = async () => root;
document.getElementById("pickFolderBtn").click();

// 4) 결과 검증
const meta = JSON.parse(await (await (await root.getFileHandle("metadata.json")).getFile()).text());
```

입력 폴더까지 필요하면 큐로 순서대로 넘깁니다:
```js
const queue = [libDir, inputDir];
window.showDirectoryPicker = async () => queue.shift();
```

**테스트 사이 정리 순서가 중요합니다.** 백그라운드 처리가 계속 돌고 있으면 지운 파일을
다시 써버립니다. 반드시 이 순서로:

```js
location.reload();              // 먼저 리로드 — 백그라운드 작업을 죽인다
// 그 다음에 지운다. 순회하면서 지우면 NotFoundError가 나니 이름을 먼저 모을 것
const names = []; for await (const [n] of root.entries()) names.push(n);
for (const n of names) await root.removeEntry(n, {recursive:true});
indexedDB.deleteDatabase("promptlog-store");   // 저장된 폴더 핸들 제거
```

### 환경 함정 (실제로 다 겪었습니다)

| 증상 | 원인 |
|---|---|
| 썸네일이 영원히 안 뜸 | 탭이 렌더링을 안 돌리면 **IntersectionObserver 콜백이 아예 안 옴.** 그래서 `primeThumbs()`가 별도로 있습니다 — 지우지 마세요 |
| `requestAnimationFrame`이 안 옴 | 같은 이유. rAF에 의존하는 코드를 넣지 마세요 |
| 썸네일 생성이 초당 1장 | 백그라운드 탭에서 JPEG 인코딩이 스로틀됨. `OffscreenCanvas.convertToBlob`도 **똑같이 느립니다**(측정함). 해결책 없음, 문서화만 함 |
| 클릭해도 아무 일 없음 | `window.open`이 팝업 차단으로 `null` 반환. **새 탭을 쓰지 마세요** — 라이트박스나 인라인 재생으로 처리 |
| 옮긴 파일 재매칭이 테스트에서 실패 | OPFS 쓰기는 **mtime을 보존하지 않습니다**(복사처럼 보임). 실제 탐색기 이동은 보존합니다. 그래서 매칭이 크기+수정시각 **또는** 크기+파일명 두 갈래입니다 |

---

## 컨벤션

- **주석은 "왜"만.** 무엇을 하는지는 코드가 말합니다. 비직관적인 선택에만 붙이세요
  (예: 왜 IntersectionObserver를 못 믿는지)
- **커밋 메시지는 한국어**, 제목 한 줄 + 본문에 배경·판단 근거·검증 결과
- 사용자 대면 문구는 한국어. 코드 식별자는 영어
- 새 기능은 **실제 파일로 검증하고 수치를 남기세요.** 이 저장소의 주장은 전부 실측입니다
  (98%, 313바이트/항목 등). 추측을 문서에 쓰지 마세요

### 실측용 데이터 (이 사용자 컴퓨터 기준)

| 용도 | 경로 |
|---|---|
| ComfyUI 출력 PNG 약 7,500장 (추출 정확도 측정용) | `C:\Users\welcr\Documents\ComfyUI\output` |
| ComfyUI input (참조 해석 테스트용, 한글 파일명 포함) | `C:\Users\welcr\Documents\ComfyUI\input` |
| 실사용 라이브러리 (항목 15개) | `C:\Users\welcr\Downloads\Prompt 정리` |

정확도를 다시 재려면 `prompt-log.html`에서 추출 함수 구간을 잘라내 Node로 임포트해
코퍼스에 돌리는 방식이 편합니다(`const s = html.indexOf("const PNG_SIG")` 식으로 슬라이스 →
`data:text/javascript;base64,` 로 동적 import).

---

## 현재 상태

브랜치 `feat/auto-metadata` (master 머지 전). 완료된 것:

1. 메타데이터 유실 방지 (손상 격리·백업·원자적 저장)
2. PNG tEXt 자동 추출 (ComfyUI/A1111)
3. 하위 폴더 재귀 스캔 + 썸네일 `.thumbs/` 분리 + 2단계 스캔
4. 옮긴 파일 재매칭
5. 참조 첨부(이미지·영상·오디오) + `.refs/`
6. ComfyUI `input/` 연결로 참조 자동 채우기
7. 인앱 라이트박스·인라인 오디오 재생 (`window.open` 제거)

### 커밋 안 된 작업

- `README.md` — 사용자용 가이드로 전면 재작성 (구현 설명 → 사용법 중심)
- `run.bat` — 원클릭 실행 런처. **⚠ 검증 못 했습니다.** 실행해보고 브라우저가 열리는지,
  Python 없을 때 안내가 제대로 나오는지 확인이 필요합니다

### 다음 후보 (v0.4)

- **가상 스크롤** — 수천 장에서 검색·필터 시 렌더가 무거움. 실사용에서 가장 먼저 아플 부분
- 파라미터 구조화 필터 (`cfg만 바꾼 것들 모아보기`)
- 계보(parentId) + 나란히 비교
- 검색 문법 (`tool:kling`, `-제외`)
- 읽기 전용 웹 모드 — 폴더를 정적 호스팅에 올리고 `fetch`로 읽게 하면 링크 하나로 외부
  열람 가능. 읽는 지점이 4곳(`loadMeta`, `getFileAt`, `readThumbFile`, `readRefFile`)뿐이라
  생각보다 작은 작업입니다

### 알려진 제약

- 영상은 프롬프트 자동 추출 불가 (규격 없음)
- 파일명과 수정시각이 동시에 바뀌면 재매칭 실패
- Chrome/Edge 전용 (File System Access API)
- 같은 폴더를 두 곳에서 동시에 열면 `metadata.json` 충돌
