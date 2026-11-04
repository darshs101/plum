import { readFileSync } from 'node:fs';
const config = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const qa = JSON.parse(readFileSync(process.argv[3], 'utf8'));
const [a,b] = qa.accounts;
const conversation = qa.fixture.conversation;
const body = `Realtime integration ${Date.now()}`;
const socket = new WebSocket(`${config.url.replace('https:', 'wss:')}/realtime/v1/websocket?apikey=${config.key}&vsn=1.0.0`);
await new Promise((resolve, reject) => {
  const timeout = setTimeout(() => { socket.close(); reject(new Error('No authorized realtime message arrived')); }, 20000);
  let sent = false;
  socket.onopen = () => socket.send(JSON.stringify({topic:'realtime:plum-qa',event:'phx_join',ref:'1',payload:{access_token:b.token,config:{postgres_changes:[{event:'INSERT',schema:'public',table:'messages',filter:`conversation_id=eq.${conversation}`}]}}}));
  socket.onerror = reject;
  socket.onmessage = async event => {
    const message = JSON.parse(event.data);
    if (message.event === 'system' && message.payload.status === 'ok' && !sent) {
      sent = true;
      const response = await fetch(`${config.url}/rest/v1/messages`,{method:'POST',headers:{apikey:config.key,Authorization:`Bearer ${a.token}`,'Content-Type':'application/json'},body:JSON.stringify({conversation_id:conversation,sender_id:a.id,body})});
      if (!response.ok) { clearTimeout(timeout); socket.close(); reject(new Error(`Message insert failed ${response.status}`)); }
    }
    if (message.event === 'postgres_changes' && message.payload.data.record.body === body) { clearTimeout(timeout); socket.close(); console.log('PASS authorized mutual follower receives live message via Realtime'); resolve(); }
  };
});
