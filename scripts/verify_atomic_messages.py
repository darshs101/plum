#!/usr/bin/env python3
"""Live two-account atomic DM check. Usage: script QA_JSON PUBLIC_CONFIG_JSON"""
import json,urllib.request,urllib.error,pathlib,uuid,sys
q=json.load(open(sys.argv[1]));c=json.load(open(sys.argv[2]))
def req(path,token=None,method='GET',body=None):
 h={'apikey':c['key'],'Content-Type':'application/json','Prefer':'return=representation'}
 if token:h['Authorization']='Bearer '+token
 try:
  r=urllib.request.urlopen(urllib.request.Request(c['url']+path,headers=h,method=method,data=None if body is None else json.dumps(body).encode()));s=r.read();return r.status,json.loads(s) if s else None
 except urllib.error.HTTPError as e:return e.code,e.read().decode()
for a in q['accounts']:
 s,t=req('/auth/v1/token?grant_type=password',method='POST',body={'email':a['email'],'password':q['password']});assert s==200;a['token']=t['access_token']
a,b=q['accounts'];cid=q['fixture']['conversation'];pid=q['fixture']['post'];at=a['token'];bt=b['token']
for label,body in [('text',{'conversation_id':cid,'body':'Audit atomic text'}),('share',{'conversation_id':cid,'post_id':pid})]:
 s,r=req('/rest/v1/rpc/send_message_with_share',at,'POST',body);assert s==200,(label,s,r);print('PASS atomic',label)
s,before=req('/rest/v1/messages?conversation_id=eq.'+cid+'&select=id',at)
s,r=req('/rest/v1/rpc/send_message_with_share',at,'POST',{'conversation_id':cid,'post_id':str(uuid.uuid4())});assert s>=400
s,after=req('/rest/v1/messages?conversation_id=eq.'+cid+'&select=id',at);assert len(before)==len(after);print('PASS invalid share rolls back message')
path='/rest/v1/follows?follower_id=eq.'+a['id']+'&following_id=eq.'+b['id']
s,r=req(path,at,'DELETE');assert s in (200,204),(s,r)
try:
 s,r=req('/rest/v1/rpc/send_message_with_share',at,'POST',{'conversation_id':cid,'body':'Must be denied'});assert s>=400,(s,r);print('PASS send denied after unfollow')
finally:
 s,r=req('/rest/v1/follows',at,'POST',{'follower_id':a['id'],'following_id':b['id'],'status':'approved'});assert s in (200,201),(s,r)
pathlib.Path(sys.argv[1]).write_text(json.dumps(q))
