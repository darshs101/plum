#!/usr/bin/env python3
"""Live, isolated two-account integration check. Credentials stay outside the repo.
Usage: python3 scripts/verify_supabase.py /path/to/Plum.app/Info.plist /tmp/plum-qa.json
The fixture accounts must already exist and be confirmed. This is not a signup test.
"""
import json,sys,plistlib,urllib.request,urllib.error,uuid,base64
config=plistlib.load(open(sys.argv[1],'rb')); qa=json.load(open(sys.argv[2])); url=config['SUPABASE_URL']; key=config['SUPABASE_PUBLISHABLE_KEY']
results=[]
def request(path, token=None, method='GET', body=None, content='application/json'):
 headers={'apikey':key,'Content-Type':content,'Prefer':'return=representation'}
 if token: headers['Authorization']='Bearer '+token
 data=None if body is None else json.dumps(body).encode() if content=='application/json' else body
 try:
  r=urllib.request.urlopen(urllib.request.Request(url+path,data=data,headers=headers,method=method)); raw=r.read(); return r.status,json.loads(raw) if raw else None
 except urllib.error.HTTPError as e:
  raw=e.read().decode();
  try: raw=json.loads(raw)
  except: pass
  return e.code,raw
def ok(label, response, expected=(200,201,204)):
 status,body=response
 if status not in expected: raise AssertionError(f'{label}: {status} {body}')
 results.append(label); print('PASS',label,flush=True); return body
def rest(table, token, method='GET',body=None,query=''): return request('/rest/v1/'+table+query,token,method,body)
a,b=qa['accounts']
for account in [a,b]:
 token=ok('Password login '+account['username'],request('/auth/v1/token?grant_type=password',method='POST',body={'email':account['email'],'password':qa['password']}))
 account['token']=token['access_token']; account['refresh']=token['refresh_token']
at,bt=a['token'],b['token']; aid,bid=a['id'],b['id']
ok('Profile readable after login',rest('profiles',at,query='?id=eq.'+aid))
saved=ok('Saved Places created automatically',rest('collections',at,query='?kind=eq.saved_places'))
assert len(saved)==1 and not saved[0]['is_public']
rid,did,pid=[str(uuid.uuid4()) for _ in range(3)]
qa['fixture']={'restaurant':rid,'dish':did,'post':pid}
image=base64.b64decode('/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAf/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABBQJ//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPwF//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPwF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQAGPwJ//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPyF//9oADAMBAAIAAwAAABD/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAEDAQE/EB//xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAECAQE/EB//xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAE/EB//2Q==')
rpath=f'{aid}/{rid}/location.jpg'; ppath=f'{aid}/{pid}/dish.jpg'
ok('Restaurant photo upload',request('/storage/v1/object/restaurant-media/'+rpath,at,'POST',image,'image/jpeg'))
ok('Restaurant creation',rest('restaurants',at,'POST',{'id':rid,'name':'Plum Integration Atlanta','address':'Integration fixture, Atlanta','photo_path':rpath,'created_by':aid}))
ok('Dish creation',rest('dishes',at,'POST',{'id':did,'name':'Integration dish','restaurant_id':rid,'created_by':aid}))
ok('Post photo upload',request('/storage/v1/object/post-media/'+ppath,at,'POST',image,'image/jpeg'))
params={'post_uuid':pid,'restaurant_uuid':rid,'dish_entries':[{'dish_id':did,'rating':4.5}],'photo_paths':[ppath],'caption_text':'Integration check','visited_on':None}
ok('Atomic post creation',request('/rest/v1/rpc/save_post',at,'POST',params))
ok('Public post visible to separate account',rest('posts',bt,query='?id=eq.'+pid)); assert len(rest('posts',bt,query='?id=eq.'+pid)[1])==1
ok('Public photo signed access',request('/storage/v1/object/sign/post-media/'+ppath,bt,'POST',{'expiresIn':60}))
ok('Exact name search',request('/rest/v1/rpc/search_public',bt,'POST',{'search_text':'Plum Integration Atlanta'}))
ok('Save place',rest('collection_items',at,'POST',{'collection_id':saved[0]['id'],'restaurant_id':rid}))
ok('Like another account post',rest('likes',bt,'POST',{'post_id':pid,'user_id':bid}))
comment=ok('Comment on another account post',rest('comments',bt,'POST',{'post_id':pid,'author_id':bid,'body':'Integration comment'}))[0]
ok('Reply to comment',rest('comments',at,'POST',{'post_id':pid,'author_id':aid,'parent_id':comment['id'],'body':'Integration reply'}))
notifications=ok('Social notifications persisted',rest('notifications',at)); assert notifications
ok('Make account private',rest('profiles',at,'PATCH',{'visibility':'private'},'?id=eq.'+aid))
assert rest('posts',bt,query='?id=eq.'+pid)[1]==[];results.append('Private post hidden from nonfollower');print('PASS Private post hidden from nonfollower')
assert request('/storage/v1/object/sign/post-media/'+ppath,bt,'POST',{'expiresIn':60})[0]>=400;results.append('Private photo signing denied');print('PASS Private photo signing denied')
ok('Request private follow',rest('follows',bt,'POST',{'follower_id':bid,'following_id':aid,'status':'requested'}))
assert rest('posts',bt,query='?id=eq.'+pid)[1]==[]
ok('Owner approves follow',rest('follows',at,'PATCH',{'status':'approved'},'?follower_id=eq.'+bid+'&following_id=eq.'+aid))
assert len(rest('posts',bt,query='?id=eq.'+pid)[1])==1;results.append('Approved follower sees private post');print('PASS Approved follower sees private post')
assert rest('public_dish_aggregates',bt,query='?dish_id=eq.'+did)[1]==[];results.append('Private rating excluded from aggregates');print('PASS Private rating excluded from aggregates')
ok('Mutual follow',rest('follows',at,'POST',{'follower_id':aid,'following_id':bid,'status':'approved'}))
cid=ok('Start mutual conversation',request('/rest/v1/rpc/start_direct_conversation',at,'POST',{'other_user':bid}));qa['fixture']['conversation']=cid
ok('Conversation members do not recurse',rest('conversation_members',bt,query='?conversation_id=eq.'+cid))
msg=ok('Send mutual message',rest('messages',at,'POST',{'conversation_id':cid,'sender_id':aid,'body':'Integration message'}))[0]
ok('Read received message',rest('messages',bt,query='?conversation_id=eq.'+cid))
ok('Share post in conversation',rest('post_shares',at,'POST',{'message_id':msg['id'],'post_id':pid}))
bad=dict(params);bad['dish_entries']=[]
assert request('/rest/v1/rpc/save_post',at,'POST',bad)[0]>=400
assert len(rest('post_dishes',at,query='?post_id=eq.'+pid)[1])==1;results.append('Invalid edit rolls back');print('PASS Invalid edit rolls back')
params['dish_entries'][0]['rating']=3.5
ok('Edit post atomically',request('/rest/v1/rpc/save_post',at,'POST',params))
refreshed=ok('Refresh session (relaunch equivalent API check)',request('/auth/v1/token?grant_type=refresh_token',method='POST',body={'refresh_token':a['refresh']}));a['token']=refreshed['access_token'];a['refresh']=refreshed['refresh_token']
ok('Persistence after fresh session',rest('posts',a['token'],query='?id=eq.'+pid))
json.dump(qa,open(sys.argv[2],'w'))
json.dump({'passed':results,'signup':'BLOCKED: email confirmation enabled; email send rate limit exhausted'},open('/tmp/plum-integration-results.json','w'),indent=2)
print('PASSED',len(results),'checks')
