import {petMood,shop,defaultLayout} from './pet-engine.js';
export async function petPortrait(s){
 const c=document.createElement('canvas');c.width=900;c.height=650;const g=c.getContext('2d');
 const colors={moon:['#262338','#383047'],forest:['#1c3430','#2c4940'],sunset:['#3e2837','#513a42']};const [wall,floor]=colors[s.equipped.room]||colors.moon;
 g.fillStyle=wall;g.fillRect(0,0,900,650);g.fillStyle=floor;g.fillRect(0,370,900,280);
 g.strokeStyle='#baa2cc';g.lineWidth=5;g.strokeRect(370,70,140,150);g.fillStyle='#d7c8ec';g.font='60px serif';g.fillText('☾',415,135);
 g.strokeStyle='#ffffff15';g.lineWidth=1;for(let x=0;x<900;x+=90){g.beginPath();g.moveTo(x,370);g.lineTo(x,650);g.stroke()}
 const pos=id=>s.layout[id]||defaultLayout[id];
 for(const id of ['rug','bed','bath','plant','toy','lamp']){if(!['bed','bath'].includes(id)&&!s.equipped[id])continue;const p=pos(id);g.font=id==='rug'?'100px serif':'70px serif';g.textAlign='center';g.fillText({bed:'🛏️',bath:'🛁',plant:'🪴',toy:'🧸',lamp:'🌟',rug:'🌸'}[id],p.x*9,p.y*6.5)}
 const im=new Image();im.src=`assets/pet/${petMood(s)}.png`;await im.decode();const p=s.position;const size=340;g.drawImage(im,p.x*9-size/2,p.y*6.5-size*.82,size,size);
 if(s.equipped.outfit){g.font='65px serif';g.fillText(shop[s.equipped.outfit].icon,p.x*9+35,p.y*6.5-size*.67)}
 g.fillStyle='#f4d9e5';g.font='30px Georgia';g.textAlign='left';g.fillText(`${s.name} · ${s.stage}`,30,45);g.font='18px sans-serif';g.fillText(new Date().toLocaleDateString(),30,620);return c.toDataURL('image/png');
}
