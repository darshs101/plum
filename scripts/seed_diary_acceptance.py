#!/usr/bin/env python3
"""Create private, live diary fixtures for two-account simulator acceptance.
Usage: seed_diary_acceptance.py PUBLIC_CONFIG_JSON QA_JSON
Uses the isolated accounts produced by verify_profile_social.py after the
profile-photo UI acceptance has uploaded a full-size JPEG avatar.
"""
import json,pathlib,sys,urllib.request,uuid
config=json.load(open(sys.argv[1])); path=pathlib.Path(sys.argv[2]);qa=json.loads(path.read_text());owner,viewer=qa['accounts'][:2]
def call(endpoint,account,method='GET',body=None,mime='application/json'):
 headers={'apikey':config['key'],'Content-Type':mime,'Prefer':'return=representation'}
 if account:headers['Authorization']='Bearer '+account['token']
 data=None if body is None else json.dumps(body).encode() if mime=='application/json' else body
 r=urllib.request.urlopen(urllib.request.Request(config['url']+endpoint,headers=headers,method=method,data=data));raw=r.read()
 return json.loads(raw) if mime=='application/json' and raw else raw
for a in [owner,viewer]:
 token=call('/auth/v1/token?grant_type=password',None,'POST',{'email':a['email'],'password':qa['password']});a['token']=token['access_token']
for a,b in [(owner,viewer),(viewer,owner)]:
 rows=call('/rest/v1/follows?follower_id=eq.'+a['id']+'&following_id=eq.'+b['id'],a);assert rows and rows[0]['status']=='approved','Fixture accounts must be mutual approved followers'
avatar=call('/rest/v1/profiles?id=eq.'+owner['id']+'&select=avatar_path',owner)[0]['avatar_path']
photo=call('/storage/v1/object/authenticated/profile-media/'+avatar,owner,mime='image/jpeg');assert len(photo)>1000
rid,did=str(uuid.uuid4()),str(uuid.uuid4());name='Plum Diary QA '+uuid.uuid4().hex[:8];rpath=owner['id']+'/'+rid+'/location.jpg'
call('/storage/v1/object/restaurant-media/'+rpath,owner,'POST',photo,'image/jpeg')
call('/rest/v1/restaurants',owner,'POST',{'id':rid,'name':name,'address':'Isolated diary acceptance, Atlanta','created_by':owner['id'],'photo_path':rpath})
call('/rest/v1/dishes',owner,'POST',{'id':did,'restaurant_id':rid,'name':'Diary QA dish','created_by':owner['id']})
qa['diary_fixture']={'restaurant':rid,'dish':did,'restaurant_name':name,'posts':[]}
for index in range(1,33):
 pid=str(uuid.uuid4());ppath=owner['id']+'/'+pid+'/diary.jpg'
 call('/storage/v1/object/post-media/'+ppath,owner,'POST',photo,'image/jpeg')
 call('/rest/v1/rpc/save_post',owner,'POST',{'post_uuid':pid,'restaurant_uuid':rid,'dish_entries':[{'dish_id':did,'rating':4.5}],'photo_paths':[ppath],'caption_text':f'Diary QA entry {index:02d}','visited_on':'2020-01-02' if index==31 else None,'photo_links':[{'photo_path':ppath,'dish_ids':[did]}]})
 qa['diary_fixture']['posts'].append(pid)
 path.write_text(json.dumps(qa));path.chmod(0o600)
 print('Created private diary entry',index,flush=True)
rows=call('/rest/v1/posts?author_id=eq.'+owner['id']+'&is_removed=eq.false&select=id,visit_date&order=created_at.desc,id.desc&limit=30',viewer)
assert rows[0]['id']==qa['diary_fixture']['posts'][31] and rows[1]['id']==qa['diary_fixture']['posts'][30]
assert rows[1]['visit_date']=='2020-01-02'
print('PASS approved viewer sees the selected dated post and a full first page')
