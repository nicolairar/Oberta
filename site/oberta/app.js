const phases = {
  piazza: {
    image: 'img/piazza.png',
    alt: 'La piazza durante la discussione: giocatori numerati sopra la chat',
    title: 'La piazza parla',
    description: 'Alibi, accuse, mezze verità. Ogni parola può cambiare il voto.'
  },
  notte: {
    image: 'img/notte.png',
    alt: 'La notte: un giocatore legge il proprio compito segreto e sceglie cosa fare',
    title: 'Cala la notte',
    description: 'Ognuno riceve il proprio compito. Le mosse si risolvono tutte insieme.'
  },
  alba: {
    image: 'img/alba.png',
    alt: 'Il giornale dell’alba racconta il delitto senza svelare il ruolo della vittima',
    title: 'Arriva l’alba',
    description: 'Il narratore ricostruisce la notte. La piazza si prepara al verdetto.'
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
