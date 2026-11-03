#!/usr/bin/env python3
"""Isolated QA moderation checks. Requires QA account A to have a temporary server admin claim."""
import sys,json,uuid
helpers=open('scripts/verify_supabase.py').read().split("a,b=qa['accounts']")[0]
exec(helpers)
a,b=qa['accounts']; aid,bid=a['id'],b['id']; bt=b['token'];f=qa['fixture']
token=ok('Admin login',request('/auth/v1/token?grant_type=password',method='POST',body={'email':a['email'],'password':qa['password']}));at=token['access_token']
# An authenticated normal account must never gain moderation authority.
assert request('/rest/v1/rpc/admin_edit_directory',bt,'POST',{'record_type':'restaurant','record_uuid':f['restaurant'],'new_name':'Forbidden'})[0]>=400
print('PASS non-admin directory edit denied')
ok('Admin edit with audit',request('/rest/v1/rpc/admin_edit_directory',at,'POST',{'record_type':'restaurant','record_uuid':f['restaurant'],'new_name':'Plum Integration Atlanta'}))
comment=ok('Mutual comment mention',rest('comments',at,'POST',{'author_id':aid,'post_id':f['post'],'body':'Thanks @'+b['username']}))[0]
mentions=ok('Mention persisted',rest('comment_mentions',bt,query='?comment_id=eq.'+comment['id']));assert mentions
bad=rest('comments',at,'POST',{'author_id':aid,'post_id':f['post'],'body':'No @not_a_mutual_member'});assert bad[0]>=400;print('PASS non-mutual mention rejected')
reply=ok('Reply notifies parent commenter',rest('comments',bt,'POST',{'author_id':bid,'post_id':f['post'],'parent_id':comment['id'],'body':'Reply QA'}))
notifications=ok('Reply notification is persisted',rest('notifications',at,query='?kind=eq.reply'));assert notifications
report=ok('Report persists',rest('reports',bt,'POST',{'reporter_id':bid,'target_type':'post','target_id':f['post'],'reason':'QA report only'}))[0]
ok('Admin triages report',request('/rest/v1/rpc/moderate_report',at,'POST',{'report_uuid':report['id'],'next_status':'triaged','remove_target':False}))
ok('Admin dismisses report',request('/rest/v1/rpc/moderate_report',at,'POST',{'report_uuid':report['id'],'next_status':'dismissed','remove_target':False}))
try:
 ok('Suspend test account',request('/rest/v1/rpc/admin_set_suspension',at,'POST',{'subject':bid,'suspend':True}))
 assert rest('comments',bt,'POST',{'author_id':bid,'post_id':f['post'],'body':'Must fail while suspended'})[0]>=400
 print('PASS suspended account cannot write with existing token')
finally:
 ok('Restore test account',request('/rest/v1/rpc/admin_set_suspension',at,'POST',{'subject':bid,'suspend':False}))
assert rest('posts',at,'POST',{'author_id':aid,'restaurant_id':f['restaurant']})[0]>=400;print('PASS direct incomplete post rejected at commit')
# Preserve both existing references and aliases when merging duplicate dishes.
new=ok('Create merge fixture dish',rest('dishes',at,'POST',{'name':'QA merged alias','restaurant_id':f['restaurant'],'created_by':aid}))[0]
ok('Merge duplicate dish',request('/rest/v1/rpc/merge_dish',at,'POST',{'source_dish':new['id'],'target_dish':f['dish']}))
search=ok('Legacy dish alias searchable',request('/rest/v1/rpc/search_public',at,'POST',{'search_text':'QA merged alias'}));assert any(x['id']==f['dish'] for x in search)
# Reorder a real ranked collection atomically.
coll=ok('Create ranked collection',rest('collections',at,'POST',{'owner_id':aid,'title':'QA ranking '+uuid.uuid4().hex[:6],'kind':'ranked','is_public':False}))[0]
item=ok('Add ranking item',rest('collection_items',at,'POST',{'collection_id':coll['id'],'restaurant_id':f['restaurant'],'rank':1}))[0]
ok('Atomic ranking reorder',request('/rest/v1/rpc/reorder_collection',at,'POST',{'collection_uuid':coll['id'],'ordered_items':[item['id']]}))
print('PASS moderation, mentions, suspended-session enforcement, integrity, alias and ranking checks')
