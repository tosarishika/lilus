export const species = {cat:{name:'Kitten',icon:'🐱'},dog:{name:'Puppy',icon:'🐶'},bunny:{name:'Bunny',icon:'🐰'},dragon:{name:'Little dragon',icon:'🐲'}};
export const shop = {
 bow:{name:'Cherry bow',icon:'🎀',cost:35,slot:'outfit'},hat:{name:'Starry hat',icon:'🧙',cost:60,slot:'outfit'},crown:{name:'Tiny crown',icon:'👑',cost:100,slot:'outfit'},
 moon:{name:'Moonlight room',icon:'🌙',cost:45,slot:'room'},forest:{name:'Forest room',icon:'🌿',cost:45,slot:'room'},sunset:{name:'Sunset room',icon:'🌅',cost:45,slot:'room'},
 bed:{name:'Cloud bed',icon:'☁️',cost:40,slot:'bed'},plant:{name:'Little plant',icon:'🪴',cost:25,slot:'plant'},toy:{name:'Toy basket',icon:'🧸',cost:30,slot:'toy'},lamp:{name:'Star lamp',icon:'🌟',cost:30,slot:'lamp'},rug:{name:'Soft pink rug',icon:'🌸',cost:35,slot:'rug'}
};
export const care = {feed:{label:'Meal',icon:'🍓',effect:{hunger:25}},treat:{label:'Treat',icon:'🍪',effect:{hunger:10,happiness:10}},water:{label:'Water',icon:'💧',effect:{water:30}},play:{label:'Play',icon:'🧶',effect:{happiness:25,energy:-8}},clean:{label:'Bath & tidy',icon:'🫧',effect:{cleanliness:35}},sleep:{label:'Tuck in',icon:'🌙',effect:{}},wake:{label:'Wake up',icon:'☀️',effect:{}},cuddle:{label:'Cuddle',icon:'💗',effect:{happiness:12}},game:{label:'Toy hunt',icon:'🎯',effect:{happiness:30,energy:-8}}};
export const petDay = t => new Date(t).toISOString().slice(0,10);
Object.assign(care,{walk_begin:{label:'Go for a walk',icon:'🌳',effect:{happiness:10,energy:-2}},walk_finish:{label:'Finish our walk',icon:'🏡',effect:{happiness:20,energy:-8,cleanliness:-8}}});
export const defaultLayout={bed:{x:21,y:68},bath:{x:82,y:66},plant:{x:89,y:37},toy:{x:12,y:42},lamp:{x:71,y:35},rug:{x:50,y:76}};
export const trail=[{x:34,y:58},{x:56,y:48},{x:78,y:58}];
export function petMood(s,now=Date.now()){
 if(s.sleeping)return 'sleepy';
 if(now-(s.lastActions.clean||0)<8000)return 'bath';
 if(now-(s.lastActions.cuddle||0)<10000)return 'loved';
 if(s.hunger<35)return 'hungry';
 if(s.cleanliness<35)return 'dirty';
 if(s.happiness<30)return 'sad';
 if(s.energy<35)return 'sleepy';
 const last=Math.max(s.born,...Object.values(s.lastActions));
 if(now-last>8*3600000)return 'missing';
 return 'happy';
}
const clamp=n=>Math.min(100,Math.max(0,n));
export function advance(s,time){if(!s)return s;const hours=Math.max(0,(time-s.updated)/3600000);return {...s,updated:time,hunger:clamp(s.hunger-hours*3),water:clamp(s.water-hours*4),happiness:clamp(s.happiness-hours*2),cleanliness:clamp(s.cleanliness-hours*1.5),energy:clamp(s.energy+hours*(s.sleeping?12:-2))};}
export function petState(rows,now=Date.now()){
 let s=null;const events=[...rows].filter(r=>r.payload.action).sort((a,b)=>a.created_at.localeCompare(b.created_at)||a.id.localeCompare(b.id));
 for(const r of events){const p=r.payload,t=Date.parse(r.created_at);if(p.action==='adopt'&&!s){s={name:p.name,type:p.type,born:t,updated:t,hunger:80,water:80,happiness:80,cleanliness:80,energy:80,sleeping:false,coins:30,xp:0,owned:[],equipped:{},layout:structuredClone(defaultLayout),position:{x:50,y:62},location:'home',walkProgress:0,careDays:{},rewardCount:{},lastActions:{},jointDays:[],diary:[r]};continue}if(!s)continue;s=advance(s,t);
  if(care[p.action]){for(const [k,v] of Object.entries(care[p.action].effect))s[k]=clamp(s[k]+v);if(p.action==='sleep'){s.sleeping=true;s.location='home';s.position={...s.layout.bed}}if(p.action==='wake')s.sleeping=false;if(p.action==='clean'){s.location='home';s.position={...s.layout.bath}}if(p.action==='walk_begin'){s.location='park';s.walkProgress=0;s.position={x:15,y:65}}if(p.action==='walk_finish'){s.location='home';s.position={x:50,y:62}}if(p.position)s.position={...p.position};s.lastActions[p.action]=t;
   const day=petDay(t);if(p.action!=='wake'){s.careDays[day]=[...new Set([...(s.careDays[day]||[]),r.author])];const count=s.rewardCount[day]||0;const oldStage=Math.floor(s.xp/100);if(count<12){s.coins+=8;s.xp+=10;s.rewardCount[day]=count+1}if(Math.floor(s.xp/100)>oldStage)s.diary.push({...r,payload:{...p,milestone:'grew a little bigger!'}});
    if(s.careDays[day].length>=2&&!s.jointDays.includes(day)){s.coins+=25;s.xp+=20;s.jointDays.push(day);s.diary.push({...r,payload:{...p,milestone:'got love from both of you · +25 coins'}})}
   }s.diary.push(r);
  }else if(p.action==='buy'&&shop[p.item]&&!s.owned.includes(p.item)&&s.coins>=shop[p.item].cost){s.coins-=shop[p.item].cost;s.owned.push(p.item);s.equipped[shop[p.item].slot]=p.item;s.diary.push(r)}
  else if(p.action==='equip'&&s.owned.includes(p.item)){s.equipped[shop[p.item].slot]=p.item;s.diary.push({...r,payload:{...p,milestone:`A new look: ${shop[p.item].name}`}})}
  else if(p.action==='rename'){s.name=p.name;s.diary.push(r)}
  else if(p.action==='move'){s.position={...p.position}}
  else if(p.action==='decorate'){s.layout[p.item]={...p.position};s.diary.push(r);if(s.sleeping&&p.item==='bed')s.position={...p.position}}
  else if(p.action==='walk_step'){s.walkProgress=p.step;s.position={...trail[p.step-1]}}
  else if(p.action==='walk_return'){s.location='home';s.walkProgress=0;s.position={x:50,y:62}}
 }
 if(!s)return null;s=advance(s,now);let cursor=petDay(now),streak=0;if(!s.careDays[cursor])cursor=petDay(now-86400000);while(s.careDays[cursor]){streak++;cursor=petDay(Date.parse(cursor+'T00:00:00Z')-86400000)}s.streak=streak;s.stage=s.xp<100?'Baby':s.xp<300?'Young':'Grown';s.age=Math.max(0,Math.floor((now-s.born)/86400000));return s;
}
export function validatePet(s,p,now=Date.now()){
 if(p.action==='adopt')return s?'You already have a little companion.':!species[p.type]||!p.name?.trim()||p.name.length>30?'Choose a pet and a name (up to 30 letters).':null;
 if(!s)return 'Choose your little companion first.';
 if(['move','decorate'].includes(p.action)){
  if(!p.position||!Number.isFinite(p.position.x)||!Number.isFinite(p.position.y)||p.position.x<8||p.position.x>92||p.position.y<25||p.position.y>85)return 'Keep it inside the room.';
  if(p.action==='decorate')return ['bed','bath','plant','toy','lamp','rug'].includes(p.item)&&(['bed','bath'].includes(p.item)||s.owned.includes(p.item))?null:'Choose something from your collection.';
  if(s.sleeping)return 'Wake your little one before moving them.';
  return s.location==='home'?null:'Follow the trail while outside.';
 }
 if(p.action==='walk_step')return s.location==='park'&&p.step===s.walkProgress+1&&p.step<=3?null:'Follow the next glowing marker.';
 if(p.action==='walk_return')return s.location==='park'?null:'You are already home.';
 if(p.action==='walk_begin'&&(s.location!=='home'||s.sleeping))return 'Come home and wake your pet before another walk.';
 if(p.action==='walk_finish'&&(s.location!=='park'||s.walkProgress!==3))return 'Visit all three trail markers first.';
 if(s.location==='park'&&!['walk_finish','cuddle'].includes(p.action))return 'Head home for meals, baths, and bedtime.';
 if(p.action==='rename')return !p.name?.trim()||p.name.length>30?'Choose a name of up to 30 letters.':null;
 if(p.action==='buy'){if(!shop[p.item])return 'That item is not in the shop.';if(s.owned.includes(p.item))return 'You already own this.';if(s.coins<shop[p.item].cost)return 'A few more care moments will earn those coins.';return null}
 if(p.action==='equip')return s.owned.includes(p.item)?null:'Buy this item first.';
 if(!care[p.action])return 'Unknown pet action.';
 if(s.sleeping&&!['wake','cuddle'].includes(p.action))return 'Your little one is asleep. Let them rest or wake them gently.';
 if(p.action==='wake'&&!s.sleeping)return 'Already wide awake!';
 if(['play','game','walk_begin'].includes(p.action)&&s.energy<10)return 'A nap first, then more adventures.';
 if(now-(s.lastActions[p.action]||0)<30000)return 'Give them a moment ♡ Try again in a few seconds.';
 return null;
}
