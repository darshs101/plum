#!/usr/bin/env python3
"""Live isolated profile/media, notifications, ranked-link, and inbox acceptance.
Usage: verify_profile_social.py PUBLIC_CONFIG_JSON OUTPUT_QA_JSON
Creates isolated signup accounts. Credentials are written only to OUTPUT_QA_JSON.
"""
import base64,json,pathlib,secrets,sys,urllib.request,urllib.error,uuid
c=json.load(open(sys.argv[1])); q={'password':secrets.token_hex(18),'accounts':[]}; result=[]
def req(path,token=None,method='GET',body=None,mime='application/json'):
 h={'apikey':c['key'],'Content-Type':mime,'Prefer':'return=representation'}
 if token:h['Authorization']='Bearer '+token
 data=None if body is None else json.dumps(body).encode() if mime=='application/json' else body
 try:
  r=urllib.request.urlopen(urllib.request.Request(c['url']+path,headers=h,method=method,data=data));b=r.read();return r.status,json.loads(b) if b else None
 except urllib.error.HTTPError as e:
  b=e.read().decode()
  try:b=json.loads(b)
  except ValueError:pass
  return e.code,b

def check(label,response,statuses=(200,201,204)):
 s,b=response
 assert s in statuses,(label,s,b)
 result.append(label);print('PASS',label,flush=True);return b

def rest(table,who,method='GET',body=None,query=''):
 return req('/rest/v1/'+table+query,who['token'],method,body)

def save():
 p=pathlib.Path(sys.argv[2]);p.write_text(json.dumps(q));p.chmod(0o600)

suffix=uuid.uuid4().hex[:8]
for letter in 'abcd':
 name=f'plum_social_{letter}_{suffix}';email=name+'@example.net'
 session=check('Fresh signup '+letter,req('/auth/v1/signup',method='POST',body={'email':email,'password':q['password'],'data':{'username':name,'display_name':name}}))
 assert session.get('access_token'),'Hosted signup must return a session'
 a={'username':name,'email':email,'id':session['user']['id'],'token':session['access_token']};q['accounts'].append(a);save()
 check('Initialize private profile '+letter,rest('profiles',a,'PATCH',{'visibility':'private','onboarding_completed_at':'2026-11-04T00:00:00Z'},'?id=eq.'+a['id']))
a,b,cuser,d=q['accounts']
image=base64.b64decode('/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAf/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABBQJ//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPwF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPwF//9oADAMBAAIAAwAAABD/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAECAQE/EB//xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAE/EB//2Q==')
avatar=a['id']+'/'+str(uuid.uuid4())+'.jpg';q['avatar']=avatar;save()
check('Owner uploads profile photo',req('/storage/v1/object/profile-media/'+avatar,a['token'],'POST',image,'image/jpeg'))
check('Persist profile photo',rest('profiles',a,'PATCH',{'avatar_path':avatar},'?id=eq.'+a['id']))
check('Owner signs photo',req('/storage/v1/object/sign/profile-media/'+avatar,a['token'],'POST',{'expiresIn':60}))
assert req('/storage/v1/object/sign/profile-media/'+avatar,b['token'],'POST',{'expiresIn':60})[0]>=400
print('PASS private photo denied to stranger',flush=True)
assert req('/storage/v1/object/profile-media/'+a['id']+'/spoof.jpg',b['token'],'POST',image,'image/jpeg')[0]>=400
assert rest('profiles',b,'PATCH',{'avatar_path':avatar},'?id=eq.'+b['id'])[0]>=400
print('PASS cross-account uploads and avatar references denied',flush=True)
check('Request follow',rest('follows',b,'POST',{'follower_id':b['id'],'following_id':a['id'],'status':'requested'}))
actors=check('Notification actor identities',req('/rest/v1/rpc/notification_actor_profiles',a['token'],'POST',{}));assert any(x['id']==b['id'] and x['username']==b['username'] and x['city'] is None and x['avatar_path'] is None for x in actors)
check('Approve in place',rest('follows',a,'PATCH',{'status':'approved'},'?follower_id=eq.'+b['id']+'&following_id=eq.'+a['id']))
check('Approved follower signs photo',req('/storage/v1/object/sign/profile-media/'+avatar,b['token'],'POST',{'expiresIn':60}))
def follow(source,target):
 check('Request mutual connection',rest('follows',source,'POST',{'follower_id':source['id'],'following_id':target['id'],'status':'requested'}))
 check('Approve mutual connection',rest('follows',target,'PATCH',{'status':'approved'},'?follower_id=eq.'+source['id']+'&following_id=eq.'+target['id']))
follow(a,b);follow(a,cuser);follow(cuser,a)
def inbox(who):return check('Read friends inbox',req('/rest/v1/rpc/friends_inbox',who['token'],'POST',{}))
rows=inbox(a);assert [x['id'] for x in rows]==[cuser['id'],b['id']]
print('PASS friends with no messages sorted by last mutual follow',flush=True)
for friend in [b,cuser]:
 cid=check('Start conversation',req('/rest/v1/rpc/start_direct_conversation',a['token'],'POST',{'other_user':friend['id']}))
 check('Send real inbox message',req('/rest/v1/rpc/send_message_with_share',friend['token'],'POST',{'conversation_id':cid,'body':'Latest message from '+friend['username']}))
 assert inbox(a)[0]['id']==friend['id']
print('PASS message chronology overrides follow chronology',flush=True)
assert inbox(d)==[]
follow(a,d);follow(d,a);assert inbox(a)[-1]['id']==d['id']
print('PASS friend without conversation appears after messaged friends',flush=True)
rid,did,pid=[str(uuid.uuid4()) for _ in range(3)];q['fixture']={'restaurant':rid,'dish':did,'post':pid,'restaurant_name':'Plum Social QA '+suffix};save()
rpath=a['id']+'/'+rid+'/restaurant.jpg';ppath=a['id']+'/'+pid+'/post.jpg'
check('Restaurant image',req('/storage/v1/object/restaurant-media/'+rpath,a['token'],'POST',image,'image/jpeg'))
check('Create QA location',rest('restaurants',a,'POST',{'id':rid,'name':q['fixture']['restaurant_name'],'address':'Isolated QA, Atlanta','photo_path':rpath,'created_by':a['id']}))
check('Create QA dish',rest('dishes',a,'POST',{'id':did,'restaurant_id':rid,'name':'QA dish','created_by':a['id']}))
check('Post image',req('/storage/v1/object/post-media/'+ppath,a['token'],'POST',image,'image/jpeg'))
check('Save QA tasting',req('/rest/v1/rpc/save_post',a['token'],'POST',{'post_uuid':pid,'restaurant_uuid':rid,'dish_entries':[{'dish_id':did,'rating':4.5}],'photo_paths':[ppath],'caption_text':None,'visited_on':None,'photo_links':[{'photo_path':ppath,'dish_ids':[did]}]}))
collection=check('Create ranked collection',rest('collections',a,'POST',{'owner_id':a['id'],'title':'Social QA rankings','kind':'ranked','is_public':False}))[0];q['fixture']['collection']=collection['id'];save()
check('Save ranked post link',rest('collection_items',a,'POST',{'collection_id':collection['id'],'post_id':pid,'rank':1}))
rows=check('Read restaurant-labelled saved post',rest('collection_items',a,query='?collection_id=eq.'+collection['id']+'&select=*,restaurants(name),posts(restaurants(name),post_dishes(id,dish_id,rating,dishes(name)))'))
assert rows[0]['posts']['restaurants']['name']==q['fixture']['restaurant_name'] and rows[0]['rank']==1
save();print('PASS all social profile acceptance checks',flush=True)
