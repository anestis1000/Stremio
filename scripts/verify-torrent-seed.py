import socket,struct,threading,json,hashlib,urllib.parse
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
import sys
root=Path(sys.argv[1] if len(sys.argv)>1 else '/tmp/StremioTorrentFixture');data=(root/'native-test.mkv').read_bytes();info=json.loads((root/'info.json').read_text());ih=bytes.fromhex(info['hash'])
def b(v):
 if isinstance(v,int):return b'i'+str(v).encode()+b'e'
 if isinstance(v,str):v=v.encode()
 if isinstance(v,bytes):return str(len(v)).encode()+b':'+v
 if isinstance(v,dict):return b'd'+b''.join(b(k)+b(v[k]) for k in sorted(v))+b'e'
class HTTP(BaseHTTPRequestHandler):
 def do_GET(self):
  if self.path.startswith('/announce'): payload=b({'interval':2,'complete':1,'incomplete':0,'peers':socket.inet_aton('127.0.0.1')+struct.pack('!H',38777)})
  elif self.path.startswith('/native-test.torrent'):payload=(root/'native-test.torrent').read_bytes()
  elif self.path.startswith('/native-test.mkv'):payload=data
  else:self.send_error(404);return
  self.send_response(200);self.send_header('Content-Length',str(len(payload)));self.end_headers();self.wfile.write(payload)
 def log_message(self,*args):pass
def exact(c,n):
 out=b''
 while len(out)<n:
  x=c.recv(n-len(out))
  if not x:raise EOFError()
  out+=x
 return out
def peer(c):
 try:
  c.settimeout(30);hs=exact(c,68)
  if hs[28:48]!=ih:return
  c.sendall(b'\x13BitTorrent protocol'+b'\0'*8+ih+b'-STTEST-123456789012')
  count=(len(data)+16383)//16384;bits=bytearray((count+7)//8)
  for i in range(count):bits[i//8]|=1<<(7-i%8)
  c.sendall(struct.pack('!I',len(bits)+1)+b'\x05'+bits+struct.pack('!IB',1,1))
  while True:
   n=struct.unpack('!I',exact(c,4))[0]
   if n==0:continue
   msg=exact(c,n)
   if msg[0]==6:
    index,begin,length=struct.unpack('!III',msg[1:]);block=data[index*16384+begin:index*16384+begin+length]
    c.sendall(struct.pack('!IBII',len(block)+9,7,index,begin)+block)
 except (EOFError,OSError):pass
 finally:c.close()
def peers():
 s=socket.socket();s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);s.bind(('127.0.0.1',38777));s.listen()
 while True:
  c,a=s.accept();threading.Thread(target=peer,args=(c,),daemon=True).start()
threading.Thread(target=peers,daemon=True).start()
print('Original video fixture tracker/seed ready',flush=True)
ThreadingHTTPServer(('127.0.0.1',38776),HTTP).serve_forever()
