import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {stripTypeScriptTypes} from 'node:module';
const source=stripTypeScriptTypes(fs.readFileSync('supabase/functions/manage-student-math80/index.ts','utf8'));
let handler;let role='admin';let calls=[];
vm.runInNewContext(source,{Deno:{env:{get:k=>k==='SUPABASE_URL'?'https://example.invalid':k==='SUPABASE_SERVICE_ROLE_KEY'?'test':undefined},serve:f=>handler=f},Response,console,fetch:async(url,options={})=>{
 calls.push({url,...options});
 const result=url.endsWith('/auth/v1/user')?{id:'admin'}:url.includes('select=role')?[{role}]:url.endsWith('/auth/v1/admin/users')?{id:'new-user'}:{};
 return new Response(JSON.stringify(result),{status:200});
}});
const send=body=>handler(new Request('https://example.invalid',{method:'POST',headers:{Origin:'https://cnlegolab-spike.github.io',Authorization:'Bearer test','Content-Type':'application/json'},body:JSON.stringify(body)}));
const base={action:'create',username:'student1',name:'테스트',grade:'중1',password:'test-password-only',start_date:'2026-09-12'};
for(const days of [50,60,70,80]){calls=[];assert.equal((await send({...base,plan_days:String(days)})).status,200);const save=calls.find(c=>c.url.endsWith('/math80_profiles')&&c.method==='POST');assert.equal(JSON.parse(save.body).plan_days,days);assert.ok(calls.every(c=>!c.url.includes('/rest/v1/profiles')));}
for(const days of [undefined,40,90,'bad']){calls=[];assert.equal((await send({...base,plan_days:days})).status,400);assert.ok(!calls.some(c=>c.url.endsWith('/auth/v1/admin/users')));}
role='student';calls=[];assert.equal((await send({...base,plan_days:60})).status,403);assert.ok(!calls.some(c=>c.method==='POST'));
assert.equal((await handler(new Request('https://example.invalid',{method:'POST',headers:{Origin:'https://untrusted.invalid'}}))).status,403);
console.log('PASS: account plan persistence, invalid-plan rejection before creation, administrator authorization, isolated tables, CORS');
