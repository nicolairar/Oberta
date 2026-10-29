// Obertà, la landing. Senza JS si vedono le locandine dei video e tutto il testo.
const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const saveData = navigator.connection?.saveData === true;
const still = reduceMotion || saveData;

const year = document.querySelector('#year');
if (year) year.textContent = String(new Date().getFullYear());

// Video muti in loop: partono solo quando sono in vista, si fermano fuori.
// Con «riduci movimento» o il risparmio dati resta la locandina (nessun download).
if (!still && 'IntersectionObserver' in window) {
  const play = (video) => {
    if (!video.src) {
      video.muted = true;
      video.setAttribute('muted', '');
      video.src = video.dataset.src;
      video.addEventListener('playing', () => video.classList.add('is-playing'), { once: true });
    }
    video.play().catch(() => {});
  };
  const watcher = new IntersectionObserver((entries) => {
    for (const { target, isIntersecting } of entries) {
      if (isIntersecting) play(target);
      else if (target.src) target.pause();
    }
  }, { rootMargin: '200px 0px' });
  for (const video of document.querySelectorAll('video[data-src]')) watcher.observe(video);
}

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
  ['pacifista', 'Pacifista', 'La città', 'citta'], ['cupido', 'Cupido', 'La città', 'citta'], ['presidente', 'Presidente', 'La città', 'citta'],
  ['artigliere', 'Artigliere', 'La città', 'citta'], ['tiratoreScelto', 'Tiratore scelto', 'La città', 'citta']
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

// Entrate delle sezioni, solo con JS e senza «riduci movimento».
if ('IntersectionObserver' in window && !reduceMotion) {
  document.documentElement.classList.add('js');
  const targets = document.querySelectorAll('.beat__copy, .beat__media, .platforms > *');
  const observer = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      entry.target.classList.add('is-in');
      observer.unobserve(entry.target);
    }
  }, { rootMargin: '0px 0px -10% 0px' });
  for (const el of targets) observer.observe(el);
}

// Avvisami quando esce: la lista d'attesa (funzione `waitlist` su Supabase).
// La risposta è la stessa per un indirizzo nuovo e per uno già in lista.
const WAITLIST_URL = 'https://iklohzudrdwjzqgesakq.supabase.co/functions/v1/waitlist';
const waitlist = (body) => fetch(WAITLIST_URL, {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify(body),
}).then((res) => res.json()).catch(() => ({ ok: false, error: 'network' }));

const notify = document.querySelector('#avvisami');
if (notify) {
  const email = notify.querySelector('input[name="email"]');
  const consent = notify.querySelector('input[name="consent"]');
  const consentLabel = notify.querySelector('.notify__consent');
  const button = notify.querySelector('button[type="submit"]');
  const status = notify.querySelector('.notify__status');
  const say = (text, kind) => {
    status.textContent = text;
    status.className = `notify__status${kind ? ` is-${kind}` : ''}`;
  };
  const errors = {
    invalid_email: 'Questa email non sembra giusta.',
    consent_required: 'Spunta la casella per continuare.',
    rate_limited: 'Troppi tentativi. Riprova tra qualche minuto.',
  };
  email.addEventListener('input', () => email.removeAttribute('aria-invalid'));
  consent.addEventListener('change', () => consentLabel.classList.remove('is-missing'));
  notify.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (notify.classList.contains('is-done') || button.disabled) return;
    const address = email.value.trim();
    if (!address || !email.checkValidity()) {
      email.setAttribute('aria-invalid', 'true');
      email.focus();
      say(errors.invalid_email, 'error');
      return;
    }
    if (!consent.checked) {
      consentLabel.classList.add('is-missing');
      consent.focus();
      say(errors.consent_required, 'error');
      return;
    }
    button.disabled = true;
    say('Un attimo…');
    const lang = (navigator.language || 'it').slice(0, 2).toLowerCase() === 'it' ? 'it' : 'en';
    const result = await waitlist({
      action: 'join',
      email: address,
      lang,
      consent: notify.dataset.consent,
      website: notify.elements.website.value,
    });
    if (result.ok) {
      notify.classList.add('is-done');
      email.readOnly = true;
      consent.disabled = true;
      button.textContent = 'Fatto';
      say('Fatto. Ti abbiamo mandato una mail di benvenuto.', 'ok');
      return;
    }
    button.disabled = false;
    if (result.error === 'invalid_email') email.setAttribute('aria-invalid', 'true');
    say(errors[result.error] || 'Qualcosa non va. Riprova tra poco.', 'error');
  });
}

// disiscriviti.html: il token arriva nel link della mail (?t=).
const tokenPage = document.querySelector('[data-waitlist-action]');
if (tokenPage) {
  const token = new URLSearchParams(location.search).get('t') || '';
  const show = (state) => {
    for (const el of tokenPage.querySelectorAll('[data-state]')) el.hidden = el.dataset.state !== state;
  };
  const run = async () => {
    show('working');
    const result = await waitlist({ action: tokenPage.dataset.waitlistAction, token });
    show(result.ok ? 'done' : 'error');
  };
  if (!/^[0-9a-f-]{36}$/i.test(token)) {
    show('invalid');
  } else {
    // Serve un clic: i controlli automatici dei link nelle caselle di posta
    // non cancellano nessuno.
    show('ask');
    tokenPage.querySelector('[data-waitlist-go]')?.addEventListener('click', run, { once: true });
  }
}
