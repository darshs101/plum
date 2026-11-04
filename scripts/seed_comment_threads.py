#!/usr/bin/env python3
"""Seed a private real comment/reply tree using isolated social QA accounts.
Usage: seed_comment_threads.py PUBLIC_CONFIG_JSON QA_JSON
Requires the existing QA owner's uploaded JPEG profile photo.
"""
import json,pathlib,sys,urllib.request,uuid
c=json.load(open(sys.argv[1]));path=pathlib.Path(sys.argv[2]);q=json.loads(path.read_text());a,b=q['accounts'][:2]
def request(endpoint,who,method='GET',body=None,mime='application/json'):
 h={'apikey':c['key'],'Content-Type':mime,'Prefer':'return=representation'}
 if who:h['Authorization']='Bearer '+who['token']
 data=None if body is None else json.dumps(body).encode() if mime=='application/json' else body
 r=urllib.request.urlopen(urllib.request.Request(c['url']+endpoint,headers=h,method=method,data=data));raw=r.read()
 return json.loads(raw) if mime=='application/json' and raw else raw
for who in [a,b]:
 t=request('/auth/v1/token?grant_type=password',None,'POST',{'email':who['email'],'password':q['password']});who['token']=t['access_token']
p=request('/rest/v1/profiles?id=eq.'+a['id']+'&select=avatar_path',a)[0]['avatar_path'];image=request('/storage/v1/object/authenticated/profile-media/'+p,a,mime='image/jpeg')
rid,did,pid=[str(uuid.uuid4()) for _ in range(3)];rp=a['id']+'/'+rid+'/photo.jpg';pp=a['id']+'/'+pid+'/photo.jpg'
request('/storage/v1/object/restaurant-media/'+rp,a,'POST',image,'image/jpeg')
request('/rest/v1/restaurants',a,'POST',{'id':rid,'name':'Plum Comment QA '+uuid.uuid4().hex[:8],'address':'Isolated comment acceptance, Atlanta','photo_path':rp,'created_by':a['id']})
request('/rest/v1/dishes',a,'POST',{'id':did,'restaurant_id':rid,'name':'Comment QA dish','created_by':a['id']})
request('/storage/v1/object/post-media/'+pp,a,'POST',image,'image/jpeg')
request('/rest/v1/rpc/save_post',a,'POST',{'post_uuid':pid,'restaurant_uuid':rid,'dish_entries':[{'dish_id':did,'rating':4.5}],'photo_paths':[pp],'photo_links':[{'photo_path':pp,'dish_ids':[did]}],'caption_text':'Comment thread QA','visited_on':None})
def comment(who,body,parent=None):
 row=request('/rest/v1/comments',who,'POST',{'post_id':pid,'author_id':who['id'],'body':body,'parent_id':parent})[0];return row['id']
root=comment(a,'Thread QA parent');other=comment(b,'Thread QA separate comment');child=comment(b,'Thread QA first reply',root);nested=comment(a,'Thread QA nested reply',child);second=comment(b,'Thread QA second reply',root)
q['comment_fixture']={'restaurant':rid,'post':pid,'root':root,'child':child,'nested':nested,'second':second,'other':other};path.write_text(json.dumps(q));path.chmod(0o600)
rows=request('/rest/v1/comments?post_id=eq.'+pid,b);parents={r['id']:r['parent_id'] for r in rows}
assert len(rows)==5 and parents[child]==root and parents[second]==root and parents[nested]==child and parents[other] is None
print('PASS real root, sibling, nested, and unrelated comments persisted and visible to approved follower')
