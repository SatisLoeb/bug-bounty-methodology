import hashlib
import itertools, random

def k(b):
    return hashlib.sha3_256(b).digest()  # stand-in for byte-injectivity check only

# ---------- Model of _decodeMessageV1 (canonicalization test) ----------
BASE=79
class Rev(Exception): pass
def dec(b):
    if len(b)<BASE: raise Rev("min")
    if b[0]!=1: raise Rev("ver")
    o=69
    fields={}
    # onRamp u8
    def u8field(o):
        if o>=len(b): raise Rev("len")
        L=b[o]; o+=1
        if o+L>len(b): raise Rev("content")
        return b[o:o+L], o+L
    def u16field(o):
        if o+2>len(b): raise Rev("len16")
        L=int.from_bytes(b[o:o+2],'big'); o+=2
        if o+L>len(b): raise Rev("content16")
        return b[o:o+L], o+L
    fields['onRamp'],o=u8field(o)
    fields['offRamp'],o=u8field(o)
    fields['sender'],o=u8field(o)
    fields['receiver'],o=u8field(o)
    fields['destBlob'],o=u16field(o)
    # tokenTransfer u16 with expectedEnd
    if o+2>len(b): raise Rev("ttlen")
    ttl=int.from_bytes(b[o:o+2],'big'); o+=2
    if ttl==0:
        fields['tt']=b''
    else:
        exp=o+ttl
        # decode token transfer minimally: just require it consumes exactly ttl
        tt,o=dec_tt(b,o)
        if o!=exp: raise Rev("ttcontent")
        fields['tt']=tt
    fields['data'],o=u16field(o)
    if o!=len(b): raise Rev("FINAL_OFFSET")
    return fields

def dec_tt(b,o):
    start=o
    if o>=len(b): raise Rev("ttver")
    if b[o]!=1: raise Rev("ttverval"); 
    o+=1
    if o+32>len(b): raise Rev("amt")
    o+=32
    for _ in range(4): # sourcePool,sourceToken,destToken,tokenReceiver (u8)
        if o>=len(b): raise Rev("x")
        L=b[o]; o+=1
        if o+L>len(b): raise Rev("xc")
        o+=L
    if o+2>len(b): raise Rev("ed")
    L=int.from_bytes(b[o:o+2],'big'); o+=2
    if o+L>len(b): raise Rev("edc")
    o+=L
    return b[start:o],o

def enc_msg(fixed69, onRamp,offRamp,sender,receiver,destBlob,tt,data):
    out=bytearray(fixed69)
    out+=bytes([len(onRamp)])+onRamp
    out+=bytes([len(offRamp)])+offRamp
    out+=bytes([len(sender)])+sender
    out+=bytes([len(receiver)])+receiver
    out+=len(destBlob).to_bytes(2,'big')+destBlob
    out+=len(tt).to_bytes(2,'big')+tt
    out+=len(data).to_bytes(2,'big')+data
    return bytes(out)

# Test 1: canonicality — random structs encode->decode->encode stable, and appended bytes rejected.
random.seed(1)
fixed=bytes([1])+bytes(68)
collisions=0; trailing_ok=0; roundtrip_fail=0
seen={}
for _ in range(20000):
    def rb(mx): 
        n=random.randint(0,mx); return bytes(random.getrandbits(8) for _ in range(n))
    onR=rb(5);offR=rb(5);sn=rb(5);rc=rb(5);db=rb(6);dt=rb(6)
    m=enc_msg(fixed,onR,offR,sn,rc,db,b'',dt)   # no token transfer for simplicity
    f=dec(m)
    # re-encode from decoded fields
    m2=enc_msg(fixed,f['onRamp'],f['offRamp'],f['sender'],f['receiver'],f['destBlob'],f['tt'],f['data'])
    if m2!=m: roundtrip_fail+=1
    key=(f['onRamp'],f['offRamp'],f['sender'],f['receiver'],f['destBlob'],f['tt'],f['data'])
    if key in seen and seen[key]!=m: collisions+=1
    seen[key]=m
    # trailing byte must be rejected
    try:
        dec(m+b'\x00'); trailing_ok+=1
    except Rev: pass
    # over-long final length prefix by inflating dataLen by 1 without adding content
    mm=bytearray(m); # last 2+len(dt): find data len position
    # inflate dataLen: it's at position len(m)-len(dt)-2
    pos=len(m)-len(dt)-2
    mm[pos:pos+2]=(len(dt)+1).to_bytes(2,'big')
    try:
        dec(bytes(mm)); trailing_ok+=1  # should revert (content16)
    except Rev: pass
print("Test1 canonicality: roundtrip_fail=%d struct-collisions=%d nonrejected-malformed=%d"%(roundtrip_fail,collisions,trailing_ok))

# ---------- Test 2: FinalityCodec semantics ----------
MASK=0xFFFF
def validate_requested(f):
    if f==0: return True
    hasDepth = (f & MASK)!=0
    modes = 1 if hasDepth else 0
    flags = (f>>16)&0xFFFF
    if flags:
        for i in range(16):
            if flags&(1<<i): modes+=1
    return modes==1
def ensure_allowed(req,allowed):
    # returns True if accepted (no revert)
    if req==0: return True
    if not validate_requested(req): return False
    if ((req>>16)&(allowed>>16))!=0: return True
    rbd=req&MASK; abd=allowed&MASK
    if abd==0 or rbd<abd: return False
    return True

# Security intent: a message must NEVER execute with finality WEAKER than what 'allowed' demands.
# Model "strength": full finality(req==0) is strongest. For block-depth, larger depth = stronger (waits more).
# We check the property: if accepted and it is a block-depth request, requested depth >= allowed min depth (when allowed is depth-based).
viol=0
tested=0
# enumerate a representative space: depths 0..4, safe flag, one reserved flag (bit17)
vals=[0, 1,2,3, 0x00010000, 0x00010001, 0x00020000, 0x00020001, 0xFFFF, 0x0002FFFF]
for req in vals:
    for allowed in vals:
        tested+=1
        acc=ensure_allowed(req,allowed)
        if not acc: continue
        # If accepted, verify no downgrade below a pure-depth allowed policy:
        if req!=0 and (allowed>>16)==0 and (allowed&MASK)!=0:
            # allowed is pure block-depth -> requested must be depth-based and >= allowed depth
            if (req>>16)!=0:   # requested used a flag while allowed demanded depth
                viol+=1; print("  DOWNGRADE? req=%08x allowed=%08x accepted via flag over depth-policy"%(req,allowed))
            elif (req&MASK) < (allowed&MASK):
                viol+=1; print("  DOWNGRADE req depth<allowed depth req=%08x allowed=%08x"%(req,allowed))
print("Test2 finality: pairs=%d downgrade_violations=%d"%(tested,viol))
# Also: is full-finality(0) ever rejected? (should always be allowed)
print("  full-finality always accepted:", all(ensure_allowed(0,a) for a in vals))
# Can a flag-only request bypass a depth-only allowed? (should be rejected)
print("  SAFE req vs depth-3 allowed accepted?", ensure_allowed(0x00010000,3), "(expect False)")

# ---------- Test 3: _computeCCVAndExecutorHash byte injectivity ----------
def ccv_encode(ccvs, executor):
    out=bytes([20])
    for c in ccvs: out+=c.to_bytes(20,'big')
    out+=executor.to_bytes(20,'big')
    return out
seen={}; coll=0; n=0
random.seed(2)
def raddr(): return random.getrandbits(160)
for _ in range(30000):
    m=random.randint(0,3)
    ccvs=[raddr() for _ in range(m)]
    ex=raddr()
    e=ccv_encode(ccvs,ex)
    key=(tuple(ccvs),ex); n+=1
    if e in seen and seen[e]!=key:
        coll+=1; print("  CCV byte-collision:",seen[e],key)
    seen[e]=key
print("Test3 CCV-hash preimage: tuples=%d byte_collisions=%d"%(n,coll))
# Explicit [A,B]+C vs [A]+? style: show executor always trailing 20 bytes => unique split
print("  enc([A,B],C)=",ccv_encode([0xAA,0xBB],0xCC).hex())
print("  enc([A],B) len differs:", len(ccv_encode([0xAA],0xBB)), "vs", len(ccv_encode([0xAA,0xBB],0xCC)))
