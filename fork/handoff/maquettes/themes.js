// BirdyGo color themes. Only the brand roles change; semantic colors never do.
window.BIRDY_THEMES = [
  { id: 'loriot', name: 'Loriot', fact: 'Le chanteur jaune et turquoise de BirdyGo.', acc: '#19A7B3', accHi: '#1CAEBA', accDeep: '#0E7C86', accT: '#0B6E77', ton: '#D6EEF0', nav: '#D1ECEF', accL: '#8CD3D9', hi: '#F4C542', hiDeep: '#E3A22B', dot: '#F4C542', dotD: '#F4C542', accTD: '#4FC3CC', glow: 'rgba(25,167,179,.35)' },
  { id: 'martin', name: 'Martin-pêcheur', fact: "Il file comme une flèche au ras de l'eau.", acc: '#3A9BE0', accHi: '#4DA8E8', accDeep: '#1F6FB8', accT: '#1565A8', ton: '#DCEBF8', nav: '#D3E5F7', accL: '#A9D2F3', hi: '#F28C38', hiDeep: '#D46A1E', dot: '#F28C38', dotD: '#F28C38', accTD: '#7DBBF0', glow: 'rgba(58,155,224,.35)' },
  { id: 'flamant', name: 'Flamant rose', fact: 'Il dort debout, sur une seule patte.', acc: '#E86A9A', accHi: '#EE7DA8', accDeep: '#C2447A', accT: '#A8305F', ton: '#FBE1EB', nav: '#F8D6E3', accL: '#F7B6CF', hi: '#3A2F4F', hiDeep: '#231B33', dot: '#E86A9A', dotD: '#F59BC0', accTD: '#F59BC0', glow: 'rgba(232,106,154,.35)' },
  { id: 'etourneau', name: 'Étourneau', fact: 'Il imite les autres oiseaux… et même les téléphones.', acc: '#9D82E0', accHi: '#A98FE6', accDeep: '#6E4FC4', accT: '#5B3FB0', ton: '#E9E3F8', nav: '#E2DAF6', accL: '#CBBDF1', hi: '#E9C46A', hiDeep: '#C9A043', dot: '#E9C46A', dotD: '#E9C46A', accTD: '#BBA6F0', glow: 'rgba(157,130,224,.35)' },
];
window.birdyLogoSvg = function (t) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="30 72 460 372"><defs><linearGradient id="p" gradientUnits="userSpaceOnUse" x1="165" y1="97.7" x2="361.7" y2="434.9"><stop offset="0" stop-color="${t.accHi}"/><stop offset="1" stop-color="${t.accDeep}"/></linearGradient></defs><path d="M364.4 181.4A24.4 24.4 0 0 0 397.4 179.5L424 152A21.5 21.5 0 0 1 458.5 177.1L425 240.5A93.7 93.7 0 0 0 414.2 285.3Z" fill="url(#p)"/><g stroke-linejoin="round" stroke-width="12"><path d="M118.1 206.6L64.5 222.5L140 240.3Z" fill="${t.hiDeep}" stroke="${t.hiDeep}"/><path d="M145.9 149L50.6 160.9L118.1 196.6Z" fill="${t.hi}" stroke="${t.hi}"/></g><path d="M133.1 251.5A95.6 95.6 0 1 1 280.7 131.8A54.3 54.3 0 0 0 312.3 154.7A136.8 136.8 0 1 1 141.2 274.1A28.1 28.1 0 0 0 133.1 251.5Z" fill="url(#p)"/><g fill="none" stroke-width="30" stroke-linecap="round"><path d="M217.4 333.7L217.4 240.1" stroke="#EEF1EC"/><path d="M260.6 365.5L268 223.3" stroke="${t.hi}"/><path d="M306.2 349.4L316 256.2" stroke="#EEF1EC"/><path d="M352.9 331.7L359.3 290.9" stroke="${t.accL}"/></g><circle cx="176.2" cy="172.6" r="18.7" fill="#13233A"/><circle cx="171" cy="166.6" r="5.4" fill="#FFFFFF"/></svg>`;
};
window.birdyLogoUri = (t) => 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(window.birdyLogoSvg(t));
window.birdyApplyTheme = function (t, el) {
  const s = (el || document.documentElement).style;
  s.setProperty('--acc', t.acc); s.setProperty('--accT', t.accT); s.setProperty('--ton', t.ton); s.setProperty('--nav', t.nav);
  s.setProperty('--accL', t.accL); s.setProperty('--accTD', t.accTD); s.setProperty('--glow', t.glow); s.setProperty('--hi', t.hi); s.setProperty('--dot', t.dot); s.setProperty('--accDeep', t.accDeep);
};
