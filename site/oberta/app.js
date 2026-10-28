const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const phases = {
  notte: {
    image: 'img/notte.png',
    alt: 'La notte: un giocatore legge il proprio compito segreto e sceglie cosa fare',
    title: 'Cala la notte',
    description: 'Ognuno riceve il suo compito segreto: la famiglia sceglie chi colpire, gli altri indagano o proteggono.'
  },
  piazza: {
    image: 'img/piazza.png',
    alt: 'La piazza durante la discussione: il tavolo con i posti numerati sopra la chat',
    title: 'La piazza parla',
    description: 'Alibi, accuse, mezze verità nella chat della piazza. Si parla per numeri di posto, e ogni parola può cambiare il voto.'
  },
  alba: {
    image: 'img/alba.png',
    alt: 'Il giornale dell’alba racconta il delitto senza svelare il ruolo della vittima',
    title: 'Arriva l’alba',
    description: 'Il giornale racconta chi non si è svegliato. Il suo ruolo resta un segreto.'
  },
  voto: {
    image: 'img/voto.png',
    alt: 'Il voto: le mani dei giocatori puntano verso chi accusano, la chat resta visibile',
    title: 'Si vota',
    description: 'Ognuno punta il dito. Chi prende più voti viene linciato e il suo ruolo si scopre.'
  }
};

const phaseImage = document.querySelector('#phase-image');
const phaseTitle = document.querySelector('#phase-title');
const phaseDescription = document.querySelector('#phase-description');

const phaseCaption = document.querySelector('.chronicle__caption');
let swapTimer;

function swapPhase(phase) {
  clearTimeout(swapTimer);
  const same = phaseImage.getAttribute('src') === phase.image;
  if (!same) phaseImage.classList.add('is-changing');
  phaseCaption?.classList.add('is-changing');
  swapTimer = setTimeout(() => {
    const done = () => phaseImage.classList.remove('is-changing');
    if (!same) {
      phaseImage.addEventListener('load', done, { once: true });
      phaseImage.addEventListener('error', done, { once: true });
      phaseImage.src = phase.image;
      if (phaseImage.complete) requestAnimationFrame(done);
    }
    phaseImage.alt = phase.alt;
    phaseTitle.textContent = phase.title;
    phaseDescription.textContent = phase.description;
    phaseCaption?.classList.remove('is-changing');
  }, reduceMotion ? 0 : 230);
}

for (const button of document.querySelectorAll('[data-phase]')) {
  button.addEventListener('click', () => {
    const phase = phases[button.dataset.phase];
    if (!phase || !phaseImage) return;

    for (const tab of document.querySelectorAll('[data-phase]')) {
      const active = tab === button;
      tab.classList.toggle('is-active', active);
      tab.setAttribute('aria-pressed', String(active));
    }

    swapPhase(phase);
  });
}

const year = document.querySelector('#year');
if (year) year.textContent = String(new Date().getFullYear());

// Carta ruolo: tieni premuto per scoprirla, come nel gioco.
// roles:start
const roles = [
  ['cittadino', 'Onesto', 'La città', 'citta'], ['mafioso', 'Picciotto', 'La famiglia', 'famiglia'], ['fesso', 'Fesso', 'Per sé', 'neutrale'],
  ['detective', 'Commissario', 'La città', 'citta'], ['padrino', 'Padrino', 'La famiglia', 'famiglia'], ['piromane', 'Piromane', 'Per sé', 'neutrale'],
  ['medico', 'Dottore', 'La città', 'citta'], ['sarto', 'Sarto', 'La famiglia', 'famiglia'], ['cacciatore', 'Cacciatore di taglie', 'Per sé', 'neutrale'],
  ['cecchino', 'Cecchino', 'La città', 'citta'], ['compare', 'Compare', 'La famiglia', 'famiglia'], ['strozzino', 'Strozzino', 'Per sé', 'neutrale'],
  ['giornalista', 'Cronista', 'La città', 'citta'], ['prostituta', 'Prostituta', 'La famiglia', 'famiglia'], ['sicario', 'Sicario', 'Per sé', 'neutrale'],
  ['becchino', 'Becchino', 'La città', 'citta'], ['capoSetta', 'Capo della setta', 'Per sé', 'neutrale'], ['guardaspalle', 'Guardaspalle', 'La città', 'citta'],
  ['reduce', 'Reduce', 'La città', 'citta'], ['pregiudicato', 'Pregiudicato', 'La città', 'citta'], ['messia', 'Messia', 'La città', 'citta'],
  ['sindaco', 'Sindaco', 'La città', 'citta'], ['portinaio', 'Portinaio', 'La città', 'citta'], ['carceriere', 'Carceriere', 'La città', 'citta'],
  ['pacifista', 'Pacifista', 'La città', 'citta'], ['cupido', 'Cupido', 'La città', 'citta'], ['presidente', 'Presidente', 'La città', 'citta']
];
// roles:end
const card = document.querySelector('.role-card');
if (card) {
  let index = 0;
  const nameEl = card.querySelector('.role-card__name');
  const factionEl = card.querySelector('.role-card__faction');
  const seal = document.createElement('img');
  seal.className = 'role-card__icon';
  seal.alt = '';
  card.querySelector('.role-card__seal').replaceWith(seal);
  for (const [id] of roles) new Image().src = `img/roles/${id}.png`;
  const show = () => {
    const [id, name, faction, key] = roles[index % roles.length];
    seal.src = `img/roles/${id}.png`;
    nameEl.textContent = name;
    factionEl.textContent = faction;
    card.dataset.faction = key;
    card.classList.add('is-flipped');
    card.setAttribute('aria-pressed', 'true');
  };
  const hide = () => {
    if (!card.classList.contains('is-flipped')) return;
    card.classList.remove('is-flipped');
    card.setAttribute('aria-pressed', 'false');
    index += 1;
  };
  card.addEventListener('pointerdown', (event) => { event.preventDefault(); show(); });
  for (const type of ['pointerup', 'pointerleave', 'pointercancel']) card.addEventListener(type, hide);
  card.addEventListener('contextmenu', (event) => event.preventDefault());
  card.addEventListener('keydown', (event) => {
    if ((event.key === ' ' || event.key === 'Enter') && !event.repeat) { event.preventDefault(); show(); }
  });
  card.addEventListener('keyup', (event) => { if (event.key === ' ' || event.key === 'Enter') hide(); });
  card.addEventListener('blur', hide);
}

// Entrate delle sezioni, in ordine di lettura. Senza JS tutto resta visibile.
if ('IntersectionObserver' in window && !reduceMotion) {
  const groups = [
    ['.chronicle', ['h2', '.chronicle__intro > p', ['.phase-tab', 'row'], ['.chronicle__view', 'pic']]],
    ['.vote', ['h2', '.vote__heading > p', '.text-link', ['.vote__image', 'pic']]],
    ['.verdict', [['.verdict__image', 'pic'], 'h2', '.verdict__copy > p']],
    ['.cast', ['h2', '.cast__copy p', ['.cast__sheet', 'pic'], ['.role-card', 'pic'], '.cast__image figcaption']],
    ['.look', [['.look__image', 'pic'], 'h2', '.look__copy p', ['.look__image--second', 'pic']]],
    ['.ranked', ['h2', '.ranked__copy p', ['.ranked__image', 'pic']]],
    ['.desk', ['h2', '.desk__copy p', ['.monitor', 'pic']]],
    ['.modes', ['h2', ['.mode', 'row'], '.modes__note', '.button--gold']],
    ['.platforms', ['h2', '.platforms__heading p', ['.platform', 'up'], '.platforms__legal', '.button--paper']]
  ];
  const targets = [];
  for (const [section, parts] of groups) {
    let step = 0;
    const seen = new Set();
    for (const part of parts) {
      const [selector, kind] = Array.isArray(part) ? part : [part, 'up'];
      for (const el of document.querySelectorAll(`${section} ${selector}`)) {
        if (seen.has(el)) continue;
        seen.add(el);
        el.dataset.reveal = kind;
        el.style.setProperty('--d', `${Math.min(step, 8) * 80}ms`);
        targets.push(el);
        step += 1;
      }
    }
  }
  const stamp = document.querySelector('.mode__label--stamp');
  if (stamp) targets.push(stamp);
  document.documentElement.classList.add('js');
  const observer = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      entry.target.classList.add('is-in');
      if (entry.target === stamp) stamp.closest('.mode')?.classList.add('is-shaking');
      observer.unobserve(entry.target);
    }
  }, { rootMargin: '0px 0px -12% 0px' });
  for (const el of targets) observer.observe(el);
}
