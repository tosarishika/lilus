export function profileAvatar(role='girl',name='Profile',className='profile-picture'){
 const selected=role==='boy'?'boy':'girl';
 const alt=String(name).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 return `<img class="${className}" src="assets/profiles/${selected}.png" alt="${alt}’s profile picture">`;
}
