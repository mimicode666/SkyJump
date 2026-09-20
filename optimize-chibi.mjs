import fs from 'node:fs';
import {NodeIO} from '@gltf-transform/core';
import {ALL_EXTENSIONS} from '@gltf-transform/extensions';
import {dequantize,weld,simplify,prune} from '@gltf-transform/functions';
import {MeshoptSimplifier} from 'meshoptimizer';
const io=new NodeIO().registerExtensions(ALL_EXTENSIONS);
const stats=[];
for(const id of ['emil','sveta']){
 const doc=await io.read(`game/source-models/${id}.glb`);
 const count=()=>doc.getRoot().listMeshes().reduce((s,m)=>s+m.listPrimitives().reduce((n,p)=>n+p.getIndices().getCount()/3,0),0);
 const before=count();
 await doc.transform(dequantize(),weld(),simplify({simplifier:MeshoptSimplifier,ratio:.035,error:.012}),prune());
 await io.write(`game/assets/models/${id}-lite.glb`,doc);
 fs.copyFileSync(`game/assets/models/${id}-lite.glb`,`dist/models/${id}-chibi.glb`);
 stats.push({id,trianglesBefore:before,trianglesAfter:count(),bytes:fs.statSync(`game/assets/models/${id}-lite.glb`).size});
}
fs.writeFileSync('inspection/chibi/optimization.json',JSON.stringify(stats,null,2));console.log(stats);
