import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
const $=s=>document.querySelector(s);
const models={emil:{name:'Эмиль',number:'01',player:'ИГРОК 1',url:'/models/emil-chibi.glb'},sveta:{name:'Света',number:'02',player:'ИГРОК 2',url:'/models/sveta-chibi.glb'}};
const cache=new Map();let selected=null,screen='start',current=null,token=0,auto=false,renderer,controls,camera,scene,frameDistance=4;
const status=$('#load-status'),message=$('#load-message'),viewport=$('#viewport');

function showError(text){status.hidden=false;status.classList.add('error');message.textContent=text;$('#retry').hidden=false;}
function setBusy(busy){$('#reset').disabled=busy;$('#rotate').disabled=busy;$('#canvas').setAttribute('aria-busy',String(busy));}
function load(id){
 if(cache.has(id))return cache.get(id);
 const promise=new Promise((resolve,reject)=>new GLTFLoader().load(models[id].url,gltf=>{
  const object=gltf.scene;object.updateMatrixWorld(true);
  let texturesValid=true;
  object.traverse(node=>{if(node.isMesh){const materials=Array.isArray(node.material)?node.material:[node.material];for(const material of materials){if(!material.map||!material.normalMap||!material.roughnessMap)texturesValid=false;}}});
  if(!texturesValid){reject(new Error('Встроенные текстуры не загрузились'));return;}
  const bounds=new THREE.Box3().setFromObject(object);const size=bounds.getSize(new THREE.Vector3());const center=bounds.getCenter(new THREE.Vector3());
  if(!Number.isFinite(size.length())||size.length()===0){reject(new Error('Empty geometry'));return;}
  const scale=2.65/Math.max(size.x,size.y,size.z);
  const group=new THREE.Group();group.add(object);group.scale.setScalar(scale);object.position.sub(center);
  const normalized=size.clone().multiplyScalar(scale);group.userData.size=normalized;
  resolve(group);
 },progress=>{if(id===selected&&!status.classList.contains('error'))message.textContent=progress.total?`Загрузка: ${Math.round(progress.loaded/progress.total*100)}%`:'Загрузка персонажа…';},reject));
 cache.set(id,promise);promise.catch(()=>cache.delete(id));return promise;
}
function fit(){
 if(!current)return;
 const size=current.userData.size;const vFov=THREE.MathUtils.degToRad(camera.fov);const hFov=2*Math.atan(Math.tan(vFov/2)*camera.aspect);
 frameDistance=Math.max(size.y/2/Math.tan(vFov/2),size.x/2/Math.tan(hFov/2))*1.15+size.z/2;
 controls.target.set(0,0,0);camera.position.set(frameDistance*.075,frameDistance*.035,frameDistance);
 camera.near=.01;camera.far=100;camera.updateProjectionMatrix();controls.minDistance=Math.max(.65,size.z*.62);controls.maxDistance=frameDistance*2.2;controls.update();controls.saveState();
}
async function select(id){
 selected=id;const ticket=++token;$('#portraits').hidden=true;viewport.hidden=false;$('.identity').hidden=false;$('.viewer-footer').hidden=false;try{if(!renderer)initViewer();}catch(error){showError('Браузер не смог включить 3D. Проверьте поддержку WebGL.');return;}resize();setBusy(true);status.hidden=false;status.classList.remove('error');$('#retry').hidden=true;message.textContent=`Загрузка: ${models[id].name}…`;
 document.querySelectorAll('.character').forEach(el=>{const active=el.dataset.character===id;el.classList.toggle('selected',active);el.setAttribute('aria-pressed',String(active));el.querySelector('.card-state').textContent=active?'Выбран':'Выбрать';});
 $('#player-name').textContent=models[id].name;$('#player-number').textContent=models[id].number;$('#player-label').textContent=models[id].player;
 if(current){scene.remove(current);current=null;}
 try{const model=await load(id);if(ticket!==token)return;current=model;scene.add(current);fit();await renderer.compileAsync(scene,camera);if(ticket!==token)return;status.hidden=true;setBusy(false);}
 catch(error){if(ticket!==token)return;console.error('Не удалось открыть GLB:',error);showError(`Не удалось открыть модель «${models[id].name}». Проверьте файлы сайта и повторите загрузку.`);}
}
function resize(){const {width,height}=viewport.getBoundingClientRect();if(!renderer||width<1||height<1)return;renderer.setSize(width,height,false);camera.aspect=width/height;camera.updateProjectionMatrix();fit();}
function setScreen(next){
 screen=next;document.body.dataset.screen=next;$('#start').hidden=next!=='start';$('#selection').hidden=next!=='selection';
 if(next==='start'){
  ++token;selected=null;if(current){scene.remove(current);current=null;}
  viewport.hidden=true;status.hidden=true;$('#portraits').hidden=false;$('.identity').hidden=true;$('.viewer-footer').hidden=true;
  document.querySelectorAll('.character').forEach(el=>{el.classList.remove('selected');el.setAttribute('aria-pressed','false');el.querySelector('.card-state').textContent='Выбрать';});
 }
 if(controls){controls.enabled=next==='selection';controls.autoRotate=next==='selection'&&auto;}
 $('#canvas').tabIndex=next==='selection'?0:-1;resize();if(next==='selection')$('#back').focus();else $('#begin').focus();
}
$('#begin').addEventListener('click',()=>setScreen('selection'));
$('#back').addEventListener('click',()=>setScreen('start'));
$('.wordmark').addEventListener('click',e=>{e.preventDefault();setScreen('start');});
document.querySelectorAll('.character').forEach(el=>el.addEventListener('click',()=>{select(el.dataset.character);}));
$('#reset').addEventListener('click',()=>{controls.reset();fit();});
$('#rotate').addEventListener('click',()=>{auto=!auto;controls.autoRotate=auto;$('#rotate').setAttribute('aria-pressed',String(auto));});
$('#retry').addEventListener('click',()=>{if(renderer)select(selected);else location.reload();});
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&screen==='selection'){setScreen('start');}if(e.key==='Enter'&&screen==='start'&&e.target===document.body)setScreen('selection');});
$('#canvas').addEventListener('keydown',e=>{
 if(!current||screen!=='selection')return;
 const offset=camera.position.clone().sub(controls.target);const spherical=new THREE.Spherical().setFromVector3(offset);
 if(e.key==='ArrowLeft')spherical.theta-=.12;else if(e.key==='ArrowRight')spherical.theta+=.12;else if(e.key==='ArrowUp')spherical.phi-=.12;else if(e.key==='ArrowDown')spherical.phi+=.12;else if(e.key==='+'||e.key==='=')spherical.radius*=.9;else if(e.key==='-')spherical.radius*=1.1;else if(e.key==='0'){fit();e.preventDefault();return;}else return;
 e.preventDefault();spherical.phi=THREE.MathUtils.clamp(spherical.phi,.12,Math.PI-.12);spherical.radius=THREE.MathUtils.clamp(spherical.radius,controls.minDistance,controls.maxDistance);camera.position.copy(controls.target).add(new THREE.Vector3().setFromSpherical(spherical));controls.update();
});
function initViewer(){
 renderer=new THREE.WebGLRenderer({canvas:$('#canvas'),alpha:true,antialias:true,powerPreference:'high-performance'});renderer.setPixelRatio(Math.min(devicePixelRatio,1.75));renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.15;
 scene=new THREE.Scene();camera=new THREE.PerspectiveCamera(34,1,.01,100);
 controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=true;controls.dampingFactor=.07;controls.enablePan=false;controls.rotateSpeed=.65;controls.zoomSpeed=.8;controls.autoRotateSpeed=.65;controls.minPolarAngle=.12;controls.maxPolarAngle=Math.PI-.12;controls.touches.TWO=THREE.TOUCH.DOLLY_ROTATE;controls.enabled=true;controls.autoRotate=auto;
 scene.add(new THREE.HemisphereLight(0xdce7ff,0x41445c,2));
 function light(color,intensity,x,y,z){const l=new THREE.DirectionalLight(color,intensity);l.position.set(x,y,z);scene.add(l);}
 light(0xfff0df,3.0,3,4,5);light(0xc3d9ff,1.8,-3,1,4);light(0x7d9dff,2.6,1,3,-3);
 const clock=new THREE.Clock();renderer.setAnimationLoop(()=>{const delta=Math.min(clock.getDelta(),.05);if(document.hidden||screen!=='selection'||!current)return;controls.update(delta);renderer.render(scene,camera);});
 new ResizeObserver(resize).observe(viewport);resize();
 $('#canvas').addEventListener('webglcontextlost',e=>{e.preventDefault();renderer.setAnimationLoop(null);showError('3D-просмотр прерван. Перезагрузите просмотр.');$('#retry').onclick=()=>location.reload();});
}
