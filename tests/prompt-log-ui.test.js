const assert = require("assert");
const fs = require("fs");
const path = require("path");

const html = fs.readFileSync(path.join(__dirname, "..", "prompt-log.html"), "utf8");

function extractFunction(name) {
  const marker = name.startsWith("async ") ? `${name}(` : `function ${name}(`;
  const start = html.indexOf(marker);
  assert(start >= 0, `${name} not found`);
  const brace = html.indexOf("{", start);
  let depth = 0;
  for (let i = brace; i < html.length; i++) {
    if (html[i] === "{") depth++;
    else if (html[i] === "}" && --depth === 0) return html.slice(start, i + 1);
  }
  throw new Error(`${name} is not balanced`);
}

assert(html.includes('id="typeChipBar"'), "type filter bar is missing");
assert(html.includes('copyBtn.textContent = "⧉ 복사"'), "card copy button is missing");
assert(html.includes('id="mobileViewBtn"'), "mobile view button is missing");
assert(html.includes('id="mobileFolderInput"'), "mobile folder input is missing");
assert(html.includes("async function openMobileFiles"), "mobile file loader is missing");
assert(html.includes('모바일 보기 · 읽기 전용'), "read-only mobile label is missing");

const filteredSource = extractFunction("filtered");
const entries = [
  {type:"image", prompt:"image prompt", createdAt:"2026-01-01", tags:[]},
  {type:"video", prompt:"video prompt", createdAt:"2026-01-02", tags:[]}
];
const state = {search:"", type:"image", tool:null, tag:null, sort:"new", needOnly:false};
const filtered = new Function("state", "db", `return (${filteredSource});`)(state, {entries});
assert.deepStrictEqual(filtered().map(entry => entry.type), ["image"]);
state.type = "video";
assert.deepStrictEqual(filtered().map(entry => entry.type), ["video"]);
state.type = null;
assert.strictEqual(filtered().length, 2);

const copySource = extractFunction("async function copyPrompt");
let clipboardText = "";
const messages = [];
const copyPrompt = new Function("navigator", "document", "toast", `return (${copySource});`)(
  {clipboard:{writeText: async text => { clipboardText = text; }}},
  {},
  message => messages.push(message)
);

(async () => {
  await copyPrompt("cinematic prompt");
  assert.strictEqual(clipboardText, "cinematic prompt");
  assert.strictEqual(messages.pop(), "프롬프트를 복사했어요.");
  await copyPrompt("");
  assert.strictEqual(messages.pop(), "복사할 프롬프트가 없어요.");
  console.log("PROMPT_LOG_UI_TESTS_OK");
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
