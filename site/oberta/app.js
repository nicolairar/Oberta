const phases = {
  notte: {
    image: 'img/notte.png',
    alt: 'La notte: un giocatore legge il proprio compito segreto e sceglie cosa fare',
    title: 'Cala la notte',
    description: 'Ognuno riceve il suo compito segreto: la famiglia sceglie chi colpire, gli altri indagano o proteggono.'
  },
  piazza: {
    image: 'img/piazza.png',
    alt: 'La piazza durante la discussione: giocatori numerati sopra la chat',
    title: 'La piazza parla',
    description: 'Alibi, accuse, mezze verità. Ogni parola può cambiare il voto.'
  },
  alba: {
    image: 'img/alba.png',
    alt: 'Il giornale dell’alba racconta il delitto senza svelare il ruolo della vittima',
    title: 'Arriva l’alba',
    description: 'Il giornale racconta chi non si è svegliato. Il suo ruolo resta un segreto.'
  },
  voto: {
    image: 'img/voto.png',
    alt: 'Il voto: ogni giocatore indica chi accusa, la chat resta visibile',
    title: 'Si vota',
    description: 'Ognuno punta il dito. Chi prende più voti viene linciato e il suo ruolo si scopre.'
  }
};

const phaseImage = document.querySelector('#phase-image');
const phaseTitle = document.querySelector('#phase-title');
const phaseDescription = document.querySelector('#phase-description');

for (const button of document.querySelectorAll('[data-phase]')) {
  button.addEventListener('click', () => {
    const phase = phases[button.dataset.phase];
    if (!phase || !phaseImage) return;

    for (const tab of document.querySelectorAll('[data-phase]')) {
      const active = tab === button;
      tab.classList.toggle('is-active', active);
      tab.setAttribute('aria-pressed', String(active));
    }

    if (phaseImage.getAttribute('src') !== phase.image) {
      phaseImage.classList.add('is-changing');
      phaseImage.addEventListener('load', () => phaseImage.classList.remove('is-changing'), { once: true });
      phaseImage.src = phase.image;
    }
    phaseImage.alt = phase.alt;
    phaseTitle.textContent = phase.title;
    phaseDescription.textContent = phase.description;
  });
}

const year = document.querySelector('#year');
if (year) year.textContent = String(new Date().getFullYear());
