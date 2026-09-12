import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const window={addEventListener(){}};
const ctx=vm.createContext({window,console,URL,Intl,Date,setTimeout,sessionStorage:{getItem(){return null}},navigator:{},document:{querySelector(){return {style:{},innerHTML:'',textContent:''}}}});
vm.runInContext(fs.readFileSync('dist/plan-data.js','utf8'),ctx);
assert.equal(window.CENTER_LESSONS.length,80);
assert.equal(window.CENTER_LESSONS.filter(l=>l.book==='상권').length,46);
assert.equal(window.CENTER_LESSONS[32].label,'32-1');
assert.equal(window.CENTER_LESSONS[46].label,'01');
for(const days of [50,60,70,80]){
 const plan=window.CENTER_PLANS[days];assert.equal(plan.length,days);
 assert.equal(JSON.stringify(plan.flatMap(p=>p.lessons)),JSON.stringify(window.CENTER_LESSONS));
 assert.ok(plan.every(p=>p.lessons.length>=1&&p.lessons.length<=2));
}
let src=fs.readFileSync('dist/app.js','utf8');
src=src.slice(0,src.indexOf("if(session&&ready)"))+`window.test={record,metric,studyView,adminView,linksView,set:(users,rows,id)=>{students=users;me=users.find(s=>s.id===id);records=rows;plan=planFor(id);selected=1;}};})();`;
await vm.runInContext(src,ctx);
const users=[50,60,70,80].map(n=>({id:'s'+n,name:'학생'+n,role:'student',plan_days:n,start_date:'2026-09-12'}));
const rows=users.flatMap(u=>window.CENTER_PLANS[u.plan_days].map(p=>({student_id:u.id,plan_days:u.plan_days,day:p.day,checks:[true,true,true,true],minutes:10,note:''})));
for(const u of users){
 window.test.set(users,rows,u.id);
 assert.equal(window.test.metric(u.id).done,u.plan_days);
 assert.equal(window.test.metric(u.id).lectures,80);
 const html=window.test.studyView();assert.ok(html.includes('100%'));assert.ok(html.includes(u.plan_days+'일 완주'));
 assert.ok(!html.includes('undefined'));assert.ok(!html.includes('NaN'));
 assert.ok(window.test.adminView().includes('100%'));
 assert.ok(window.test.linksView().includes('상권 32-1강'));
}
// A switch never maps another plan's day records onto different lectures.
window.test.set([{...users[0],plan_days:60}],rows,'s50');
assert.equal(window.test.metric('s50').checks,0);
window.test.set(users,rows,'s50');assert.equal(window.test.metric('s50').checks,200);
console.log('PASS: 80 lessons, 4 schedules, complete coverage, statistics, plan record isolation, student/admin/link views');
