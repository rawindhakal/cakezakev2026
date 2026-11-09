import json,copy,hashlib,glob,os,re,sys
from PIL import Image,ImageDraw,ImageFont
import data100 as D
LANG="4"
FB='/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf'
base=copy.deepcopy(json.load(open('l3.json'))['sections'][0]['blocks'][0]['config'])
occ_rows=[l.split('\t') for l in open('occ.tsv').read().strip().split('\n')]
rel_rows=[l.split('\t') for l in open('rel.tsv').read().strip().split('\n')]
OCCDB={r[1].replace('&','and').replace('--','-'):dict(id=int(r[0]),name=r[2],date=r[3],n=int(r[4])) for r in occ_rows}
RELDB={r[1]:dict(id=int(r[0]),name=r[2],n=int(r[3])) for r in rel_rows}
for k in D.OCC: assert k in OCCDB,k
for k in D.REL: assert k in RELDB,k
# ---------- photos ----------
cells={c[0]:c for c in json.load(open('cells.json'))}
def g(p): return glob.glob(p)[0]
PH={'cake_straw':g('img/full_Strawberry*'),'cupcakes':g('img/full_Perfect*'),'roses_pastel':g('img/full_Pastel*'),'choc_slice':g('img/full_Piece*'),
 'cheesecake':g('img/full_New_York*'),'wedding_cake':g('img/full_Wedding*'),'pink_cup':g('img/full_Pink*'),'orange_roses':g('img/full_Orange*'),'red_velvet':g('img/full_Red*'),
 'diya':'img2/c4.jpg','holi':'img2/c7.jpg','xmas':'img2/c10.jpg','baby':'img2/c13.jpg','rings':'img2/c29.jpg','sunflower':'img2/c31.jpg','tulips':'img2/c36.jpg',
 'macarons':'img2/c40.jpg','red_roses':'img2/c45.jpg','bouquet':'img2/c48.jpg','garland':'img2/c50.jpg','pink_rose':'img2/c56.jpg','cosmos':'img2/c57.jpg','cream_roses':'img2/c60.jpg'}
_cache={}
def photo(k):
    if k not in _cache: _cache[k]=Image.open(PH[k]).convert('RGB')
    return _cache[k]
def hexrgb(h): h=h.lstrip('#'); return tuple(int(h[i:i+2],16) for i in (0,2,4))
def font(sz): return ImageFont.truetype(FB,int(sz))
def cover(im,w,h,fx=.5,fy=.5):
    s=max(w/im.width,h/im.height); im=im.resize((int(im.width*s)+1,int(im.height*s)+1),Image.LANCZOS)
    x=int((im.width-w)*fx); y=int((im.height-h)*fy); return im.crop((x,y,x+w,y+h))
def fit(d,text,maxw,sz):
    f=font(sz)
    while d.textlength(text,font=f)>maxw and sz>18: sz-=2; f=font(sz)
    return f
def hero(k,pal,h1,h2,sub,cta,w,h,fname):
    c1,c2=map(hexrgb,D.PALETTES[pal]); web=w>h*2
    pw=int(w*(0.47 if web else 0.6)); im=Image.new('RGB',(w,h)); g=Image.new('RGB',(pw,h)); gp=g.load()
    for x in range(pw):
        t=x/pw; col=tuple(int(c1[i]+(c2[i]-c1[i])*t) for i in range(3))
        for y in range(h): gp[x,y]=col
    im.paste(g,(0,0)); im.paste(cover(photo(k),w-pw,h),(pw,0))
    d=ImageDraw.Draw(im,'RGBA'); sc=h/(640 if web else 720); pad=int(w*0.05); mw=pw-pad-int(w*0.03)
    d.ellipse((-h*.25,h*.55,h*.45,h*1.25),fill=(255,255,255,26)); d.ellipse((pw-h*.35,-h*.3,pw+h*.15,h*.2),fill=(255,209,102,60))
    base1=70*sc if web else 60*sc
    f1=fit(d,h1,mw,base1); f2=fit(d,h2,mw,base1); fs=fit(d,sub,mw,(32 if web else 30)*sc); fc=font((28)*sc)
    y=int(h*.20)
    d.text((pad,y),h1,font=f1,fill='white'); y+=int(f1.size*1.12)
    d.text((pad,y),h2,font=f2,fill=(255,224,130)); y+=int(f2.size*1.25)
    d.text((pad,y),sub,font=fs,fill=(255,255,255,235)); y+=int(fs.size*1.9)
    tw=d.textlength(cta,font=fc); bw=int(tw+fc.size*1.8); bh=int(fc.size*2.1)
    d.rounded_rectangle((pad,y,pad+bw,y+bh),radius=bh//2,fill='white')
    d.text((pad+(bw-tw)/2,y+(bh-fc.size)/2-fc.size*.08),cta,font=fc,fill=c1)
    im.save(fname,quality=80,optimize=True,progressive=True)
# ---------- sections ----------
def tm(t): return {LANG:t}
N=[0]
def uid(p,n): return f"{p}-{hashlib.md5((p+str(n)).encode()).hexdigest()[:8]}"
def dev(a,t,w): return {"app":a,"tablet":t,"web":w}
def sec(type_,over,layout='horizontal',items=None,mt=4,mb=8,radius=0):
    N[0]+=1; n=N[0]; cfg=copy.deepcopy(base); cfg.update(over)
    return {"id":uid('sec',n),"type":type_,"active":True,"margin_top":mt,"margin_bottom":mb,
      "border_radius":{k:radius for k in ("top_left","top_right","bottom_left","bottom_right")},"border_radius_custom":radius>0,
      "platforms":{"app":True,"tablet":True,"web":True},
      "blocks":[{"id":uid('blk',n),"type":type_,"layout":layout,"image":{"app":None,"web":None,"tablet":None},"config":cfg,"items":items or []}]}
def redirect(t,i): return {"redirect_type":t,"redirect_id":i,"redirect_url":None,"redirect_filters":copy.deepcopy(base['redirect_filters'])}
def banner(slug,rid): 
    it=[{"image":{"app":f"home_builder/cz-seo-{slug}-app.jpg","tablet":f"home_builder/cz-seo-{slug}-app.jpg","web":f"home_builder/cz-seo-{slug}-web.jpg"},**redirect('category',rid)}]
    return sec('banner_slider',{"carousel_style":"full_width","indicator":"dots","auto_scroll":False,"infinite_loop":False,"image_aspect":{"app":"16:9","tablet":"16:9","web":"3:1"}},items=it,mt=0,mb=8)
RAIL=[2,3,4,5,6,9,10,11]
def rail(): return sec('category_section',{"variant":"with_title","section_title":tm("Shop by Category"),"category_ids":RAIL,"category_gap":dev(12,16,18),"category_radius":dev(16,16,16),"grid_columns":dev(4,6,8)},layout='circular')
def slider(title,src,ids=None,key=None,limit=10,layout='horizontal'):
    cfg={"variant":"with_title","section_title":tm(title),"data_source":src,"limit":limit,"slider_category_ids":ids or [],"grid_columns":dev(2,3,5),"product_grid_gap":dev(10,12,14),"product_card_radius":12,"block_padding":6}
    if key: cfg[key[0]]=key[1]
    return sec('product_slider',cfg,layout=layout)
def gift(type_,title,key,ids): return sec(type_,{"variant":"with_title","section_title":tm(title),key:ids,"category_gap":dev(12,16,16),"category_radius":dev(16,16,16),"grid_columns":dev(4,6,8)},layout='circular',mt=8,radius=12)
def promise(extra=""): return sec('text_section',{"variant":"with_color","section_title":tm("Why CakeZake?"),"section_subtitle":tm("Baked fresh to order  •  Same-day, express & midnight delivery  •  A personal message on every gift"+extra),"text_align":"center","text_color":"#B3203F","background_color":"#FFF1F3"},mt=8,mb=12,radius=12)
ALLOCC=[v['id'] for v in OCCDB.values()]; ALLREL=[v['id'] for v in RELDB.values()]
def rot(lst,i,n=10): 
    i=i%len(lst); r=(lst[i:]+lst[:i])[:n]; return r
TOPOCC=[OCCDB[k]['id'] for k in ['birthday','anniversary','valentines-day','mothers-day','fathers-day','wedding-and-engagement','rakhi','tihar','dashain','christmas']]
TOPREL=[RELDB[k]['id'] for k in ['mother','father','for-her','for-him','for-wife','for-husband','sister','brother','for-friend','for-kids']]
ZT="Damak, Birtamode and Kathmandu"
def pick(lst,s): return lst[int(hashlib.md5(s.encode()).hexdigest(),16)%len(lst)]
WHO={'for-her':'her','for-him':'him','for-wife':'your wife','for-husband':'your husband','for-girlfriend':'your girlfriend','for-boyfriend':'your boyfriend','for-friend':'a friend','for-kids':'kids','women':'women','teens':'teens','couples':'couples','parents':'your parents','newborn':'a newborn','in-laws':'your in-laws','boss':'your boss','colleague':'a colleague','teacher':'a teacher','fiance':'your fiancé','fiancee':'your fiancée'}
def whotext(key,who): return WHO.get(key) or 'your '+who.lower()
# ---------- SEO copy ----------
def faqs(kind,name,date,cats,extra_q):
    f=[]
    f.append((f"How do I send a {name} gift to someone else?",f"Add your gift to the cart, enter the recipient's name, phone number and address at checkout, and write an optional message that is delivered with it. You can also choose the delivery date and slot."))
    f.append((f"Can I choose the delivery date and time?",f"Yes. Pick the date and a delivery slot at checkout{' (for '+date+' we recommend ordering early so your preferred slot is available)' if date else ''}. You can place an order in advance for a date you choose."))
    f.append(("Do you offer same-day, express and midnight delivery?","Yes, in serviced areas. Same Day Delivery needs about four hours' notice, Express Delivery arrives in roughly 60 minutes for Rs 150, and Midnight Delivery is delivered between 11 PM and midnight for Rs 200. Availability depends on your location and the item."))
    f.append(("Which areas do you deliver to?",f"We currently deliver in {ZT}. Enter your delivery location on the site to see exactly what is available for you."))
    f.append(extra_q)
    return [{"q":q,"a":a} for q,a in f]
def trim(s,n):
    if len(s)<=n: return s
    s=s[:n-1].rsplit(' ',1)[0].rstrip(',;:-–')
    return s+'…'
VAR_P2=[
 "At CakeZake you can shop {x} in one place: freshly baked cakes, fresh flower bouquets, gift hampers, chocolates, combos and personalised gifts. Browse the picks above or choose a category to find the right fit.",
 "Our {x} collection brings together cakes, flowers, hampers and chocolates picked for the moment. Every order can include a personal message card, and many items can be customised with a name or a photo.",
 "Looking for {x}? Start with a cake for sharing, add a bouquet for the extra touch, or choose a hamper when you want something that lasts. Everything is packed fresh and delivered by our delivery team.",
 "Whether you want something sweet, something floral or something personal, the {x} range has it. Add a handwritten-style message at checkout and we will deliver it together with your gift.",
]
VAR_P3=[
 "Order online and choose the date and delivery slot that suits you. We deliver across "+ZT+", with Standard, Same Day, Express and Midnight delivery options in serviced areas.",
 "Send your gift to {ZT} with delivery you schedule yourself: pick the day, pick a slot, and add a message for the recipient. Same Day, Express and Midnight options are available where we serve.",
 "Ordering is simple: choose your gift, set the delivery date and time, and we take care of the rest. We serve {ZT}, and you can add a gift message and personalisation at checkout.",
]
def p3(slug): return pick(VAR_P3,slug).replace('{ZT}',ZT)
def intro(about,x,slug,extra=""):
    return "\n\n".join([about+extra, pick(VAR_P2,slug+'a').replace('{x}',x), p3(slug)])
pages=[]
def add(kind,slug,name,pal,photo_key,h1,h2,sub,cta,primary,secs,seo):
    pages.append(dict(kind=kind,slug=slug,name=name,pal=pal,photo=photo_key,h=(h1,h2,sub,cta),primary=primary,secs=secs,seo=seo))
# --- occasions ---
i=0
for key,(pal,pk,prim,about,date) in D.OCC.items():
    i+=1; o=OCCDB[key]; name=o['name']; slug=f"{key}-gifts"
    if o['n']>0: main=slider(f"Best {name} Gifts",'occasion',key=('occasion_ids',[o['id']]),limit=12)
    else: main=slider(f"{name} Gift Ideas",'category',[prim] if prim in (2,3) else [4,5],limit=12)
    secs=[banner(slug,prim),rail(),main,slider(f"Cakes to Celebrate {name}",'category',[2],limit=10),slider("Flowers & Bouquets",'category',[3],limit=10),
          gift('relationship_section',"Gifts for Your Loved Ones",'relationship_ids',rot(TOPREL,i)),slider("Hampers & Chocolates",'category',[4,5],limit=10),
          gift('occasion_section',"More Occasions",'occasion_ids',rot(ALLOCC,i*3)),promise()]
    dn=f" ({date})" if date else ""
    seo=dict(meta_title=trim(f"{name} Gifts, Cakes & Flowers Online | CakeZake",70),
      meta_description=trim(f"Send {name} gifts online in Nepal{dn}: fresh cakes, flowers, hampers and chocolates, with same-day and midnight delivery in selected areas.",175),
      keywords=f"{name.lower()} gifts, {name.lower()} cake, {name.lower()} flowers, send gifts nepal, cake delivery nepal, {name.lower()} gift ideas",
      h1=f"{name} Gifts, Cakes & Flowers",intro=intro(about,f"{name} gift ideas",slug, f" It is celebrated in {date}." if date and key not in ('new-year','christmas','valentines-day','womens-day','teachers-day','childrens-day','girlfriends-day','boss-day') else (f" It falls on {date}." if date else "")),
      kind='occasion' if not date else 'seasonal',
      faqs=faqs('occ',name,date,"",(f"What are the best gifts for {name}?",f"Popular {name} gifts include fresh cakes, flower bouquets, gift hampers, chocolates and personalised gifts. Browse the sections on this page and add a personal message at checkout."))) 
    add(seo['kind'],slug,f"{name} Gifts",pal,pk,name,"Gifts & Cakes",(date or "Delivered across Nepal"),"Shop now",prim,secs,seo)
# --- relationships ---
i=0
for key,(pal,pk,prim,about) in D.REL.items():
    i+=1; r=RELDB[key]; nm=r['name']; slug=f"gifts-for-{key.replace('for-','')}"
    disp=nm if nm.lower().startswith('for ') else nm
    title_name = nm if nm.lower().startswith('for ') else f"{nm}"
    if r['n']>0: main=slider(f"Gifts for {disp}".replace('Gifts for For ','Gifts for '),'relationship',key=('relationship_ids',[r['id']]),limit=12)
    else: main=slider(f"Gift Ideas for {disp}".replace('Gift Ideas for For ','Gift Ideas for '),'category',[prim],limit=12)
    who=disp if not disp.lower().startswith('for ') else disp[4:]
    secs=[banner(slug,prim),rail(),main,slider("Freshly Baked Cakes",'category',[2],limit=10),slider("Flowers & Bouquets",'category',[3],limit=10),
          gift('occasion_section',"Shop by Occasion",'occasion_ids',rot(TOPOCC,i)),slider("Hampers & Chocolates",'category',[4,5],limit=10),
          gift('relationship_section',"More Gifts for Loved Ones",'relationship_ids',rot(ALLREL,i*2)),promise()]
    seo=dict(meta_title=trim(f"Gifts for {who} – Cakes, Flowers & Hampers | CakeZake",70),
      meta_description=trim(f"Find the perfect gift for {whotext(key,who)}: cakes, flowers, hampers and personalised gifts delivered in {ZT}. Choose your date and add a message.",175),
      keywords=f"gifts for {who.lower()}, gift for {who.lower()} nepal, cake for {who.lower()}, flowers for {who.lower()}, send gift online",
      h1=f"Gifts for {who}",intro=intro(about,f"gifts for {whotext(key,who)}",slug),kind='relationship',
      faqs=faqs('rel',who,"","",(f"What is a good gift for {whotext(key,who)}?",f"Cakes, flower bouquets, gift hampers, chocolates and personalised gifts are all popular. Pick a favourite flavour or colour, add a message and we will deliver it on the date you choose."))) 
    add('relationship',slug,f"Gifts for {who}",pal,pk,"Gifts for",who,"Cakes, flowers & hampers","Shop gifts",prim,secs,seo)
# --- zones ---
for key,(zn,pal,pk,place) in D.ZONES.items():
    slug=f"cake-and-gift-delivery-in-{key}"
    secs=[banner(slug,2),rail(),slider(f"Bestsellers in {zn}",'top_selling',limit=12),slider("Freshly Baked Cakes",'category',[2],limit=10),slider("Flowers & Bouquets",'category',[3],limit=10),
          gift('occasion_section',"Shop by Occasion",'occasion_ids',TOPOCC),slider("Gift Hampers",'category',[4],limit=10),gift('relationship_section',"Gifts for Your Loved Ones",'relationship_ids',TOPREL),promise(f"  •  Serving {zn}")]
    about=f"Looking for cakes and gifts in {zn}? CakeZake delivers freshly baked cakes, flower bouquets, hampers and personalised gifts to addresses across {zn}, with delivery slots you choose."
    seo=dict(meta_title=trim(f"Cake & Gift Delivery in {zn} – Same Day | CakeZake",70),
      meta_description=trim(f"Order cakes, flowers and gifts online in {zn}. Same-day, express and midnight delivery. Choose your date and slot, add a message, and we deliver.",175),
      keywords=f"cake delivery in {zn.lower()}, gift delivery {zn.lower()}, flowers {zn.lower()}, birthday cake {zn.lower()}, same day delivery {zn.lower()}",
      h1=f"Cake & Gift Delivery in {zn}",intro=intro(about,f"gifts in {zn}",slug),kind='zone',
      faqs=faqs('zone',zn,"","",(f"How fast can you deliver a cake in {zn}?",f"Same Day Delivery needs about four hours' notice, and Express Delivery arrives in roughly 60 minutes for Rs 150 where we serve. You can also schedule a date and slot in advance, or choose Midnight Delivery for Rs 200."))) 
    add('zone',slug,f"Cake & Gift Delivery in {zn}",pal,pk,"Cake & Gift Delivery",f"in {zn}","Same day • Midnight • Express","Order now",2,secs,seo)
# --- collections ---
i=0
for slug,name,pal,pk,sl,blurb in D.COLL:
    i+=1
    sliders=[slider(t,'category',ids,limit=20 if len(sl)==1 else 12,layout='grid' if len(sl)==1 else 'horizontal') for t,ids in sl]
    secs=[banner(slug,sl[0][1][0]),rail()]+sliders+[gift('occasion_section',"Shop by Occasion",'occasion_ids',rot(TOPOCC,i)),gift('relationship_section',"Gifts for Your Loved Ones",'relationship_ids',rot(TOPREL,i)),promise()]
    w=name.split(); half=(len(w)+1)//2
    h1=' '.join(w[:half]); h2=' '.join(w[half:]) or 'Online'
    seo=dict(meta_title=trim(f"{name} | Fresh & Delivered | CakeZake",70),
      meta_description=trim(f"{blurb} Delivered in {ZT} with delivery you schedule.",175),
      keywords=f"{name.lower()}, buy {name.lower()}, {name.lower()} delivery, cake and gift delivery nepal",
      h1=name,intro=intro(blurb,name.lower(),slug),kind='collection',
      faqs=faqs('coll',name,"","",(f"Can I personalise my order?","Many items can be personalised with a name, a message or a photo, and every order can include a gift message. Look for the personalisation options on the product page."))) 
    add('collection',slug,name,pal,pk,h1,h2,"Fresh • On time • With love","Shop now",sl[0][1][0],secs,seo)
assert len(pages)==100,len(pages)
slugs=[p['slug'] for p in pages]; assert len(set(slugs))==100
os.makedirs('out2',exist_ok=True)
if '--img' in sys.argv:
    for n,p in enumerate(pages):
        h1,h2,sub,cta=p['h']
        for sz,(w,h) in (('web',(1600,533)),('app',(1000,563))):
            hero(p['photo'],p['pal'],h1,h2,sub,cta,w,h,f"out2/cz-seo-{p['slug']}-{sz}.jpg")
        if n%20==0: print('img',n)
out=[]
for p in pages:
    s=p['seo']; s['og_image']=f"home_builder/cz-seo-{p['slug']}-app.jpg"
    out.append(dict(name=p['name'],slug=p['slug'],title=tm(p['name']),header_color=D.PALETTES[p['pal']][0],title_color='#FFFFFF',seo=s,draft_json={"sections":p['secs']}))
json.dump(out,open('pages_seed.json','w'))
print(len(out),sum(len(json.dumps(o)) for o in out)//1024,'KB')
for p in pages[:2]+pages[50:52]+pages[80:82]: print(p['slug'],'|',p['seo']['meta_title'],'|',len(p['seo']['meta_description']))
