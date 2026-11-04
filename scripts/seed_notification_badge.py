#!/usr/bin/env python3
"""Prepare isolated notification/read-state/follow-back and chat UI acceptance.
Usage: seed_notification_badge.py PUBLIC_CONFIG_JSON QA_JSON
"""
import json,pathlib,sys,urllib.request,uuid
c=json.load(open(sys.argv[1]));path=pathlib.Path(sys.argv[2]);q=json.loads(path.read_text());a,b,_,d=q['accounts']
def req(endpoint,who,method='GET',body=None):
 h={'apikey':c['key'],'Content-Type':'application/json','Prefer':'return=representation'}
 if who:h['Authorization']='Bearer '+who['token']
 r=urllib.request.urlopen(urllib.request.Request(c['url']+endpoint,headers=h,method=method,data=None if body is None else json.dumps(body).encode()));raw=r.read();return json.loads(raw) if raw else None
for who in [a,b,d]:
 s=req('/auth/v1/token?grant_type=password',None,'POST',{'email':who['email'],'password':q['password']});who['token']=s['access_token']
req('/rest/v1/profiles?id=eq.'+d['id'],d,'PATCH',{'visibility':'public'})
for source,target in [(a,d),(d,a)]:req('/rest/v1/follows?follower_id=eq.'+source['id']+'&following_id=eq.'+target['id'],source,'DELETE')
req('/rest/v1/likes?post_id=eq.'+q['comment_fixture']['post']+'&user_id=eq.'+b['id'],b,'DELETE')
req('/rest/v1/rpc/mark_notifications_viewed',a,'POST',{})
assert req('/rest/v1/notifications?read_at=is.null',a)==[]
cid=req('/rest/v1/rpc/start_direct_conversation',a,'POST',{'other_user':b['id']})
suffix=uuid.uuid4().hex[:6];outgoing='Outgoing bubble QA '+suffix;incoming='Incoming bubble QA '+suffix
received=req('/rest/v1/rpc/send_message_with_share',b,'POST',{'conversation_id':cid,'body':incoming})
sent=req('/rest/v1/rpc/send_message_with_share',a,'POST',{'conversation_id':cid,'body':outgoing})
q['badge_fixture']={'post':q['comment_fixture']['post'],'follower':d['id'],'conversation':cid,'sent':sent,'received':received,'sent_text':outgoing,'received_text':incoming}
path.write_text(json.dumps(q));path.chmod(0o600)
print('PASS unread baseline cleared, follow-back is available, and both message directions persisted')
