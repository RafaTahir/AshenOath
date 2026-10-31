"""Publish nothing: assemble local, unretouched roster review sheets and index."""
import html
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
ledger = json.loads((ROOT / 'stylized_roster.json').read_text())
folder = ROOT / 'evidence/stylized'
levels={}
for location in ('level','level_garment'):
    record=folder/location/'level_roster.json'
    if record.is_file():
        for asset in json.loads(record.read_text())['assets']:
            levels[asset['id']]=(location,asset['source_sha256'])
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 19)
cards = []
thumbs = []
for row in ledger['assets']:
    asset = row['id']
    directory = folder / asset
    directory.mkdir(parents=True, exist_ok=True)
    native = directory/'godot'
    has_native = (native/'review.json').is_file()
    views = native if has_native else directory
    sheet = Image.new('RGB', (1600, 560), '#25272a')
    draw = ImageDraw.Draw(sheet)
    for col, view in enumerate(('front','side','rear','quarter')):
        draw.text((col*400+12, 12), asset+' / '+view+' / NOT ACCEPTED', font=font, fill='white')
        path = views / (view+'.png')
        if path.is_file():
            picture = ImageOps.contain(Image.open(path).convert('RGB'), (390, 505))
            sheet.paste(picture, (col*400+(400-picture.width)//2, 45+(505-picture.height)//2))
        else:
            draw.text((col*400+12, 130), 'Not captured', font=font, fill='white')
    sheet.save(directory/'turnaround.jpg', quality=94)
    quarter = views/'quarter.png'
    if quarter.is_file():
        thumbs.append((asset, quarter))
    metrics = row.get('metrics', {})
    links = [f'<a href="{asset}/comparison.jpg">Design comparison</a>', f'<a href="{asset}/turnaround.jpg">Four views</a>']
    if asset in levels and levels[asset][1]==row['runtime']['sha256']:
        location=levels[asset][0]
        links.extend([f'<a href="{location}/{asset}/level_quarter.png">Greyfen lighting</a>',f'<a href="{location}/{asset}/level_rear.png">Level rear view</a>'])
    if has_native:
        frames = [Image.open(p).convert('RGB') for p in sorted(native.glob('walk_*.png'))]
        if frames:
            review = json.loads((native/'review.json').read_text())
            duration = max(30,round(1000*review.get('walk_cycle_seconds',1)/len(frames)))
            frames = [ImageOps.contain(frame,(600,600)) for frame in frames]
            frames[0].save(directory/'motion.webp',save_all=True,append_images=frames[1:],duration=duration,loop=0,lossless=True)
            paths = sorted(native.glob('walk_*.png')) + sorted(native.glob('action_*.png'))
            motion = Image.new('RGB',(1600,440*((len(paths)+3)//4)),'#25272a')
            labels = ImageDraw.Draw(motion)
            for index,path in enumerate(paths):
                x,y=(index%4)*400,(index//4)*440
                picture=ImageOps.contain(Image.open(path).convert('RGB'),(395,400))
                motion.paste(picture,(x+(400-picture.width)//2,y+35))
                labels.text((x+8,y+5),path.stem.replace('action_','')[:34],font=font,fill='white')
            motion.save(directory/'motion_actions.jpg',quality=94)
            links.extend([f'<a href="{asset}/motion.webp">Native walk cycle</a>',f'<a href="{asset}/motion_actions.jpg">Motion/action samples</a>'])
        links.append(f'<a href="{asset}/godot/review.json">Art capture record</a>')
    for key, title in [('source_path','Editable Blender'), ('runtime_path','Private runtime GLB')]:
        if key in row:
            links.append(f'<a href="{Path(row[key]).as_uri()}">{title}</a>')
    image_path = f'{asset}/godot/quarter.png' if has_native else f'{asset}/quarter.png'
    cards.append(f'''<article><h2>{asset}</h2><a href="{asset}/turnaround.jpg"><img src="{image_path}" alt="{asset} current candidate"></a>
<p>{metrics.get('triangles',0):,} triangles / {metrics.get('joints','?')} skin-joint entries / {row.get('runtime',{}).get('bytes',0):,} runtime bytes</p>
<p>{' | '.join(links)}</p><p>{html.escape(row.get('limitations','Not yet recorded'))}</p>
<p>Authored: {row.get('authored',False)}. Exported: {row.get('exported',False)}. Native art capture: {has_native}. Private integration: {bool(row.get('private_integration'))}. User accepted: false.</p></article>''')

columns, tw, th = 6, 240, 300
contact = Image.new('RGB',(columns*tw, ((len(thumbs)+columns-1)//columns)*th), '#25272a')
draw = ImageDraw.Draw(contact)
for index,(asset,path) in enumerate(thumbs):
    x,y = (index%columns)*tw, (index//columns)*th
    draw.text((x+8,y+5),asset+' / CANDIDATE',font=font,fill='white')
    picture=ImageOps.contain(Image.open(path).convert('RGB'),(tw-10,th-35))
    contact.paste(picture,(x+(tw-picture.width)//2,y+30+(th-35-picture.height)//2))
contact.save(folder/'roster.jpg',quality=94)
for start in range(0,len(ledger['assets']),6):
    group=ledger['assets'][start:start+6]
    board=Image.new('RGB',(1800,len(group)*350),'#25272a')
    labels=ImageDraw.Draw(board)
    for line,row in enumerate(group):
        native=folder/row['id']/'godot'
        actions=sorted(native.glob('action_*.png'))
        paths=[native/'front.png',native/'side.png',native/'rear.png',native/'walk_03.png',actions[0] if actions else native/'quarter.png']
        for col,path in enumerate(paths):
            x,y=col*360,line*350
            labels.text((x+8,y+4),row['id']+' / '+path.stem[:22],font=font,fill='white')
            if path.is_file():
                picture=ImageOps.contain(Image.open(path).convert('RGB'),(350,315))
                board.paste(picture,(x+(360-picture.width)//2,y+30+(315-picture.height)//2))
    board.save(folder/('inspection_board_%02d.jpg'%(start//6+1)),quality=95)
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Ashen Oath private character candidates</title><style>
*{box-sizing:border-box}body{margin:0;background:#191c20;color:#eee;font:16px/1.5 system-ui,sans-serif}header,main{max-width:1440px;margin:auto;padding:24px}header{border-bottom:1px solid #545b63}h1{font-size:28px}h2{font-size:20px;margin:0}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:20px}article{border:1px solid #545b63;border-radius:6px;padding:16px}img{display:block;width:100%;height:330px;object-fit:contain;background:#737373}a{color:#9cdaea}p{font-size:14px}header p{font-size:16px}
</style><header><h1>Ashen Oath: private character candidates</h1><p>33 required; '''+str(ledger.get('exported_count',0))+''' exported; 0 user-accepted. Unpublished work. These are best-effort grounded-stylized derivatives, not final likeness or gameplay acceptance.</p><p>Images are actual source renders, not painted-over mockups. Workbench previews are not PBR lighting validation. Missing motion, approximation and budget exceptions are disclosed per candidate. <a href="roster.jpg">Roster contact sheet</a></p></header><main>'''+''.join(cards)+'</main></html>'
page=page.replace('Images are actual source renders, not painted-over mockups. Workbench previews are not PBR lighting validation.', 'Images are actual renders, not painted-over mockups. Native Godot captures are used where recorded; original Blender comparisons remain linked. Isolated motion samples are not gameplay acceptance.')
if ledger.get('delivery'):
    delivery=ledger['delivery']
    notes='; '.join(delivery.get('budget_failures',[]))
    summary=f'<p><strong>Private review only: {delivery["package_bytes"]/1048576:.2f} MiB. Release validation: {html.escape(delivery.get("release_validation","not accepted"))}.</strong> {html.escape(notes)} Nothing is published. <a href="http://127.0.0.1:8768/">Local game review</a></p>'
    if delivery.get('art_stage_limits'):
        summary += '<p>' + html.escape(' '.join(delivery['art_stage_limits'])) + '</p>'
    page=page.replace('</header>',summary+'</header>')
(folder/'index.html').write_text(page,encoding='utf-8')
print(folder/'index.html')
