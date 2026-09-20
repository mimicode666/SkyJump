import fs from 'node:fs';
fs.mkdirSync('inspection', {recursive:true});
for (const [id,path] of [['first','C:/Users/emils/Downloads/meshy_1789859225224.glb'],['glasses','C:/Users/emils/Downloads/meshy_очки.glb']]) {
 const b=fs.readFileSync(path); const n=b.readUInt32LE(12);const j=JSON.parse(b.subarray(20,20+n).toString()); const binStart=28+n;
 const report={id,bytes:b.length,asset:j.asset,extensions:j.extensionsUsed,nodes:j.nodes,meshes:j.meshes.map(m=>({name:m.name,primitives:m.primitives.map(p=>({material:p.material,position:j.accessors[p.attributes.POSITION]}))})),materials:j.materials,textures:j.textures,images:j.images};
 fs.writeFileSync(`inspection/${id}.json`,JSON.stringify(report,null,2));
 console.log(JSON.stringify(report));
 j.images?.forEach((im,i)=>{if(im.bufferView!==undefined){const v=j.bufferViews[im.bufferView];fs.writeFileSync(`inspection/${id}-${i}.${im.mimeType.split('/')[1]}`,b.subarray(binStart+(v.byteOffset||0),binStart+(v.byteOffset||0)+v.byteLength));}});
}
