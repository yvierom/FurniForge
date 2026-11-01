import math, os, random, struct, zlib

out = os.path.join('sketchup','furniforge','materials')
os.makedirs(out, exist_ok=True)
N = 128
rng = random.Random(43217)
warp = [rng.uniform(-1,1) for _ in range(N//4)]
weft = [rng.uniform(-1,1) for _ in range(N//4)]
grain = [rng.uniform(-1,1) for _ in range(N//4)]
def height(kind,x,y):
    x %= N; y %= N
    if kind == 'fabric':
        a=math.cos(2*math.pi*x/4); b=math.cos(2*math.pi*y/4)
        return .22*a+.22*b+.10*a*b+.12*warp[x//4]+.12*weft[y//4]
    return .36*math.sin(2*math.pi*x/32+.35*math.sin(2*math.pi*y/N))+.12*math.sin(2*math.pi*x/8)+.09*grain[x//4]
def png(path, rows):
    def chunk(kind,data):
        return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    raw=b''.join(b'\0'+row for row in rows)
    with open(path,'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',N,N,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))
for kind in ('fabric','wood'):
    base=[]; normal=[]
    for y in range(N):
        b=bytearray(); n=bytearray()
        for x in range(N):
            h=height(kind,x,y); val=round(218+10*h)
            b.extend((val,val,val))
            dx=height(kind,x+1,y)-height(kind,x-1,y); dy=height(kind,x,y+1)-height(kind,x,y-1)
            nx,ny,nz=-dx*.25,-dy*.25,1.; norm=math.sqrt(nx*nx+ny*ny+nz*nz)
            n.extend(round(127.5*(c/norm+1)) for c in (nx,ny,nz))
        base.append(bytes(b)); normal.append(bytes(n))
    png(os.path.join(out,kind+'-base.png'),base); png(os.path.join(out,kind+'-normal.png'),normal)

