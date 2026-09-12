// 비밀 키는 Supabase 서버 환경에만 보관됩니다. GitHub에 입력하지 마세요.
const url=Deno.env.get('SUPABASE_URL')!;
const key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
Deno.serve(async (req:Request)=>{
 const origin=req.headers.get('origin')||'';
 const allowed=(Deno.env.get('ALLOWED_ORIGINS')||'http://127.0.0.1:4173').split(',').map(s=>s.trim()).filter(Boolean);
 const headers={'Content-Type':'application/json','Access-Control-Allow-Origin':allowed.includes(origin)?origin:'null','Access-Control-Allow-Headers':'authorization,apikey,content-type','Access-Control-Allow-Methods':'POST, OPTIONS','Vary':'Origin'};
 const reply=(status:number,data:unknown)=>new Response(JSON.stringify(data),{status,headers});
 if(!allowed.includes(origin))return reply(403,{error:'허용되지 않은 사이트입니다.'});
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(req.method!=='POST')return reply(405,{error:'POST 요청만 지원합니다.'});
 const auth=req.headers.get('authorization');
 if(!auth)return reply(401,{error:'로그인이 필요합니다.'});
 const internal=async(path:string,method='GET',body?:unknown)=>fetch(url+path,{method,headers:{apikey:key,Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body)});
 try{
  // 전달받은 토큰을 Auth 서버로 검증하고 DB의 관리자 역할을 조회합니다.
  const ar=await fetch(url+'/auth/v1/user',{headers:{apikey:key,Authorization:auth}});
  if(!ar.ok)return reply(401,{error:'로그인이 만료되었습니다.'});
  const user=await ar.json();
  const pr=await internal('/rest/v1/profiles?id=eq.'+encodeURIComponent(user.id)+'&select=role');
  if(!pr.ok)return reply(503,{error:'권한을 확인할 수 없습니다.'});
  const profiles=await pr.json();
  if(profiles[0]?.role!=='admin')return reply(403,{error:'관리자만 계정을 관리할 수 있습니다.'});
  const b=await req.json();
  if(typeof b.password!=='string'||b.password.length<10||b.password.length>128)return reply(400,{error:'비밀번호는 10~128자로 입력하세요.'});
  if(b.action==='reset'){
   if(typeof b.id!=='string'||!/^[0-9a-f-]{36}$/i.test(b.id))return reply(400,{error:'학생을 선택해 주세요.'});
   const sr=await internal('/rest/v1/profiles?id=eq.'+b.id+'&role=eq.student&select=id');
   if(!sr.ok)return reply(503,{error:'학생 정보를 확인할 수 없습니다.'});
   if(!(await sr.json()).length)return reply(404,{error:'학생을 찾을 수 없습니다.'});
   const rr=await internal('/auth/v1/admin/users/'+b.id,'PUT',{password:b.password});
   return rr.ok?reply(200,{ok:true}):reply(400,{error:'비밀번호 변경에 실패했습니다. 비밀번호 정책을 확인하세요.'});
  }
  if(b.action!=='create'||typeof b.username!=='string'||! /^[a-z0-9_-]{3,30}$/.test(b.username)||typeof b.name!=='string'||!b.name.trim()||b.name.length>40||typeof b.grade!=='string'||!b.grade.trim()||b.grade.length>30||typeof b.start_date!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(b.start_date)||isNaN(Date.parse(b.start_date)))return reply(400,{error:'이름, 학년, 아이디, 시작일을 확인해 주세요.'});
  const cr=await internal('/auth/v1/admin/users','POST',{email:b.username+'@students.center.invalid',password:b.password,email_confirm:true});
  if(!cr.ok)return reply(400,{error:'계정을 만들 수 없습니다. 중복 아이디 또는 비밀번호 정책을 확인하세요.'});
  const created=await cr.json();
  const saved=await internal('/rest/v1/profiles','POST',{id:created.id,name:b.name.trim(),grade:b.grade.trim(),role:'student',start_date:b.start_date});
  if(!saved.ok){const cleanup=await internal('/auth/v1/admin/users/'+created.id,'DELETE');if(!cleanup.ok)console.error('Profile rollback failed for user',created.id);return reply(500,{error:'학생 정보 저장에 실패했습니다. 관리자에게 문의하세요.'});}
  return reply(200,{ok:true});
 }catch{return reply(500,{error:'요청 처리에 실패했습니다. 잠시 후 다시 시도하세요.'});}
});

