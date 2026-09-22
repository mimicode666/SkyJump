import {NodeIO} from '@gltf-transform/core';
import {ALL_EXTENSIONS} from '@gltf-transform/extensions';
import {dequantize} from '@gltf-transform/functions';
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
for (const id of (process.argv.slice(2).length ? process.argv.slice(2) : ['kirby-blink','klubnich','manye','pikachu','yablochko','zaichik'])) {
  const doc = await io.read(`game/source-models/${id}.glb`);
  const count = () => doc.getRoot().listMeshes().reduce((sum, mesh) => sum + mesh.listPrimitives().reduce((n, p) => n + p.getIndices().getCount() / 3, 0), 0);
  const before = count();
  const animationCount = doc.getRoot().listAnimations().length;
  const textures = doc.getRoot().listTextures().map(t => Buffer.from(t.getImage()));
  await doc.transform(dequantize());
  if (before !== count() || animationCount !== doc.getRoot().listAnimations().length || textures.some((bytes, i) => !bytes.equals(Buffer.from(doc.getRoot().listTextures()[i].getImage())))) throw Error(`Asset changed unexpectedly: ${id}`);
  await io.write(`game/assets/models/${id}.glb`, doc);
  console.log(`${id}: ${count()} triangles, ${animationCount} animations, textures unchanged`);
}
