from pathlib import Path
import hashlib,json,shutil,subprocess
here=Path(__file__).resolve().parent
root=here.parent.parent
sources=sorted((root/'msgblast/Resources/Discover/icons').glob('*.png'))+sorted((root/'msgblast/Resources/WebAgentIcons').glob('*'))+[root/'msgblast/Resources/MuseAvatar.jpg']
records=[]
for i,p in enumerate(sources):
    name=f'{i:03d}-{p.stem}'+('.png' if p.suffix in ['.icns','.pdf'] else p.suffix)
    target=here/'public/assets'/name
    if p.suffix in ['.icns','.pdf']:
        subprocess.run(['swift',str(here/'export.swift'),str(p),str(target),'512'],check=True)
    else: shutil.copyfile(p,target)
    records.append({'name':p.stem,'file':name,'source':str(p.relative_to(root)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(here/'src/inventory.json').write_text(json.dumps(records,indent=2)+'\n')
print(f'{len(records)} icons, no omissions')
