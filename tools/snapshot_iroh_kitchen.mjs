// Isolated, reproducible environment snapshot; never checks out or merges branches.
import {execFileSync} from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
const revision='origin/dev/iroh';
const dest='assets/iroh_kitchen';
const source='scenes/prototyping/proto_kitchen_studio.tscn';
const git=(...args)=>execFileSync('git',args,{maxBuffer:100*1024*1024});
const tracked=new Set(git('ls-tree','-r','--name-only',revision).toString().trim().split('\n'));
const localCase=new Map(execFileSync('rg',['--files']).toString().trim().split('\n').map(p=>[p.toLowerCase(),p]));
const classes=new Map();
for(const line of git('grep','-n','^class_name ',revision,'--','*.gd').toString().split('\n')) {
 const m=line.match(/^origin\/dev\/iroh:(.*?):\d+:class_name\s+(\w+)/);
 if(m) classes.set(m[2],m[1]);
}
function environmentOnly(text) {
 const blocks=text.split(/\n(?=\[)/);
 const ext=new Map(),sub=new Map(); const nodes=[];
 for(const b of blocks) {
  if(b.startsWith('[ext_resource')) ext.set(b.match(/ id="([^"]+)"/)[1],b);
  if(b.startsWith('[sub_resource')) sub.set(b.match(/ id="([^"]+)"/)[1],b);
  if(b.startsWith('[node')) {
   const p=b.match(/ parent="([^"]+)"/)?.[1]; const n=b.match(/ name="([^"]+)"/)?.[1];
   if((p==='.' && ['_Set','_Lighting','HighStool'].includes(n)) || p?.startsWith('_Set') || p?.startsWith('_Lighting') || p?.startsWith('HighStool')) nodes.push(b);
  }
 }
 const neededExt=new Set(),neededSub=new Set();
 function visit(b) {
  for(const m of b.matchAll(/(Ext|Sub)Resource\("([^"]+)"\)/g)) {
   const set=m[1]==='Ext'?neededExt:neededSub, table=m[1]==='Ext'?ext:sub;
   if(!set.has(m[2])) {set.add(m[2]); visit(table.get(m[2])??'');}
  }
 }
 nodes.forEach(visit);
 return ['[gd_scene format=3]',...[...ext].filter(([id])=>neededExt.has(id)).map(([,b])=>b),...[...sub].filter(([id])=>neededSub.has(id)).map(([,b])=>b),'[node name="IrohKitchen" type="Node3D"]',...nodes].join('\n\n');
}
const mapped=new Map(); const manifest=[];
function copy(file) {
 if(mapped.has(file))return mapped.get(file);
 if(!path.extname(file) || (fs.existsSync(file) && fs.statSync(file).isDirectory()))return file;
 if(!tracked.has(file) && fs.existsSync(file))return path.relative(process.cwd(),fs.realpathSync(file));
 if(!tracked.has(file) && localCase.has(file.toLowerCase()))return localCase.get(file.toLowerCase());
 if(!tracked.has(file)) {
  const canonical=[...tracked].find(p=>p.toLowerCase()===file.toLowerCase());
  if(canonical)return copy(canonical);
 }
 const data=git('show',`${revision}:${file}`);
 const textual=/\.(tscn|tres|gd|gdshader)$/.test(file);
 // Reuse byte-identical binary assets already present on Zhe's branch.
 const importScale=tracked.has(file+'.import') ? git('show',`${revision}:${file}.import`).toString().match(/^nodes\/root_scale=(.*)$/m)?.[1] : undefined;
 const localScale=fs.existsSync(file+'.import') ? fs.readFileSync(file+'.import','utf8').match(/^nodes\/root_scale=(.*)$/m)?.[1] : undefined;
 if(!textual && file!=='assets/textures/T_Metal_Scratched_1K_MR.png' && fs.existsSync(file) && fs.readFileSync(file).equals(data) && importScale===localScale) {mapped.set(file,file);return file;}
 const output=dest+'/'+file; mapped.set(file,output);
 let result=data;
 if(textual) {
  let text=data.toString();
  if(file===source)text=environmentOnly(text).replace(/type="Node"/g,'type="Node3D"');
  if(file.endsWith('.gd')) {
   for(const [name,location]of classes) if(new RegExp(`\\b${name}\\b`).test(text)) {
    if(location!==file)copy(location);
    text=text.replace(new RegExp(`\\b${name}\\b`,'g'),'IrohKitchen'+name);
   }
  }
  text=text.replace(/res:\/\/([^"'\s)]+)/g,(_,dependency)=>'res://'+copy(dependency));
  text=text.replace(/ uid="uid:\/\/[^\"]+"/g,'').replace(/^metadata\/_custom_type_script =.*\n/gm,'');
  result=Buffer.from(text);
 }
 fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,result);
 if(importScale && /\.(glb|gltf)$/.test(file)) {
  const sidecar=output+'.import';
  const settings=fs.existsSync(sidecar) ? fs.readFileSync(sidecar,'utf8') : `[remap]\nimporter="scene"\ntype="PackedScene"\n[deps]\nsource_file="res://${output}"\n[params]\nnodes/root_scale=1.0\n`;
  fs.writeFileSync(sidecar,settings.replace(/^nodes\/root_scale=.*$/m,'nodes/root_scale='+importScale));
 }
 manifest.push({source:file,output,bytes:result.length});return output;
}
copy(source);
fs.writeFileSync(dest+'/SOURCE.json',JSON.stringify({branch:revision,commit:git('rev-parse',revision).toString().trim(),note:'Environment-only snapshot. Original project files unchanged.',files:manifest},null,2));
console.log(`Copied ${manifest.length} environment dependencies; reused ${mapped.size-manifest.length} binary assets.`);
