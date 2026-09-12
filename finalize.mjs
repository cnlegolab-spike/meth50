import fs from 'node:fs';
let app=fs.readFileSync('dist/app.js','utf8');
// Retain five review checkpoints alongside the scheduled lectures.
app=app.replace("${d.review?'review':''}","${d.day%(plan.length/5)===0?'review':''}");
app=app.replace("${d.review?'복습':record(d.day)","${d.day%(plan.length/5)===0?'학습·복습':record(d.day)");
const start=app.indexOf('${p.review?`<p>');
const end=app.indexOf('p.lessons.map',start);
if(start>=0&&end>=0)app=app.slice(0,start)+'${'+app.slice(end);
app=app.replace('<p class="note">강의 사이에', '${selected%(plan.length/5)===0?\'<p class="note">구간 복습: 오늘 강의까지 학습한 뒤, 이번 구간의 오답을 다시 풀어보세요. 마지막 날에는 상하권 전체를 점검하세요.</p>\':\'\'}<p class="note">강의 사이에');
app=app.replace("if(!el)return;const button=$('#refresh-ranking');", "if(!el)return;const button=$('#refresh-ranking');if(!ready){el.innerHTML='<p class=\"muted\">서버 연결 후 학생들의 학습 랭킹이 표시됩니다.</p>';return;}");
fs.writeFileSync('dist/app.js',app);
fs.appendFileSync('사용안내.md','\n각 계획의 5개 구간 마지막 날은 강의 학습과 함께 오답 복습을 진행합니다. 마지막 날은 상하권 전체 점검을 안내합니다.\n');
