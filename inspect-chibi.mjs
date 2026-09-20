import fs from 'node:fs';
const source='C:/Users/emils/OneDrive/Рабочий стол/modelka/Модельки под проект/';
fs.mkdirSync('game/assets/models',{recursive:true});
fs.mkdirSync('game/source-models',{recursive:true});
fs.writeFileSync('game/source-models/.gdignore','');
fs.mkdirSync('inspection/chibi',{recursive:true});
for(const id of ['emil','sveta']){
 const b=fs.readFileSync(source+id+'_chibi.glb');fs.writeFileSync('game/source-models/'+id+'.glb',b);
 const n=b.readUInt32LE(12),j=JSON.parse(b.subarray(20,20+n).toString()),bin=28+n;
 const report={id,bytes:b.length,extensions:j.extensionsUsed,nodes:j.nodes,animations:j.animations?.length||0,skins:j.skins?.length||0,meshes:j.meshes.map(m=>({name:m.name,primitives:m.primitives.map(p=>({material:p.material,position:j.accessors[p.attributes.POSITION],indices:j.accessors[p.indices]}))})),materials:j.materials,images:j.images};
 console.log(JSON.stringify(report));fs.writeFileSync('inspection/chibi/'+id+'.json',JSON.stringify(report,null,2));
 j.images?.slice(0,1).forEach((im,i)=>{if(im.bufferView!==undefined){const v=j.bufferViews[im.bufferView];fs.writeFileSync(`inspection/chibi/${id}-${i}.${im.mimeType.split('/')[1]}`,b.subarray(bin+(v.byteOffset||0),bin+(v.byteOffset||0)+v.byteLength));}});
}
