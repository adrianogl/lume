const screen = document.querySelector('[data-screen]');

if (screen) {
  const chips = [...screen.querySelectorAll('[data-page]')];
  const cards = [...screen.querySelectorAll('[data-card]')];
  const dots = [...screen.querySelectorAll('.dots i')];
  const caption = screen.querySelector('[data-caption]');
  const rotateEvery = 5000;
  let index = 0;
  let timer;

  const show = (next) => {
    index = next;
    const page = chips[index].dataset.page;
    chips.forEach((chip, i) => chip.setAttribute('aria-pressed', String(i === index)));
    cards.forEach((card) => card.classList.toggle('on', card.dataset.card === page));
    dots.forEach((dot, i) => dot.classList.toggle('on', i === index));
    caption.textContent = chips[index].dataset.caption;
  };

  const rotate = () => {
    clearInterval(timer);
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    timer = setInterval(() => show((index + 1) % chips.length), rotateEvery);
  };

  chips.forEach((chip, i) => chip.addEventListener('click', () => {
    show(i);
    clearInterval(timer);
  }));

  show(0);
  rotate();
}

const locale = document.documentElement.lang;
const now = new Date();
const time = now.toLocaleTimeString(locale, { hour: '2-digit', minute: '2-digit', hour12: false });

document.querySelectorAll('[data-time]').forEach((node) => { node.textContent = time; });
document.querySelectorAll('[data-date-long]').forEach((node) => {
  node.textContent = now.toLocaleDateString(locale, { weekday: 'long', day: 'numeric', month: 'long' });
});
document.querySelectorAll('[data-date-short]').forEach((node) => {
  node.textContent = now.toLocaleDateString(locale, { weekday: 'short', day: 'numeric', month: 'short' });
});

const week = document.querySelector('[data-week]');

if (week) {
  const monday = new Date(now);
  monday.setDate(now.getDate() - ((now.getDay() + 6) % 7));
  [...week.children].forEach((cell, offset) => {
    const day = new Date(monday);
    day.setDate(monday.getDate() + offset);
    cell.querySelector('b').textContent = day.getDate();
    cell.classList.toggle('today', day.toDateString() === now.toDateString());
  });
}
