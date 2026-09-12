import fs from 'node:fs';
const read=p=>fs.readFileSync(p,'utf8').replace(/^\uFEFF/,'');
const logo='data:image/png;base64,'+fs.readFileSync('dist/assets/center-logo.png').toString('base64');
const icon='data:image/svg+xml;base64,'+fs.readFileSync('dist/favicon.svg').toString('base64');
let app=read('dist/app.js').replaceAll('./assets/center-logo.png',logo);
const scripts=[read('dist/config.js'),read('dist/plan-data.js'),read('dist/excel.js'),app].join('\n').replace(/<\/script/gi,'<\\/script');
const html='<!doctype html>\n<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="theme-color" content="#146448"><meta name="description" content="청라스마트러닝센터 50일 수학 상하권 학습 관리"><title>청라레고센터에서 하는 50일 수학 · 상하권</title><link rel="icon" href="'+icon+'"><style>'+read('dist/style.css')+'</style></head><body><div id="app"></div><div id="toast" role="status" aria-live="polite"></div><script>'+scripts+'</script></body></html>';
fs.writeFileSync('index.html',html);
// 기존 GitHub Actions가 dist를 게시하는 경우에도 동일한 완성본을 제공합니다.
fs.writeFileSync('dist/index.html',html);
console.log('Single-file index.html generated');
