/* ==========================================================================
   Sunup — a morning-routine game for ADHD brains.
   Vanilla JS, no build step, all data stays on this device (localStorage).
   ========================================================================== */
(() => {
  'use strict';

  /* ---------- The rules (straight from the notebook page) ---------- */
  const RULES = {
    fastMin: 5, fastXp: 10,   // up within 5 min of the alarm  → +10
    okMin: 10, okXp: 5,       // up within 10 min              → +5
    lateXp: 1,                // up later                      → +1
    idleMin: 10, penalty: 5,  // stationary > 10 min before everything is done → −5 (once a morning)
    warnMin: 2,               // heads-up this long before the −5
    earliestMin: 180,         // "I'm up" unlocks 3 h before the alarm
  };

  const KEY = 'sunup.v1';
  const MIN = 60 * 1000;

  const WAKE_STEP = { id: 'up', emoji: '🛏️', label: 'Get out of bed' };
  const DEFAULT_TASKS = [
    { id: 'hair', emoji: '💇', label: 'Hair' },
    { id: 'face', emoji: '🧼', label: 'Wash face' },
    { id: 'eat', emoji: '🍳', label: 'Eat something' },
  ];
  const DEFAULT_REWARDS = [
    { id: 'food', emoji: '🍜', label: 'Food treat', cost: 25 },
    { id: 'toys', emoji: '🧩', label: 'Toys & board games', cost: 50 },
    { id: 'sensory', emoji: '🫧', label: 'Anything sensory', cost: 75 },
    { id: 'cash', emoji: '💵', label: '$100 to spend on anything', cost: 100 },
  ];
  // [bg, surface, accent] — used for the picker swatches and the status-bar colour.
  const THEMES = [
    { id: 'midnight', name: 'Midnight', c: ['#0D0F14', '#1F2331', '#8B7CFF'] },
    { id: 'daylight', name: 'Daylight', c: ['#F4F5F9', '#FFFFFF', '#5B5BF0'] },
    { id: 'notebook', name: 'Notebook', c: ['#F3EDE0', '#FFFCF5', '#1F5A43'] },
    { id: 'ocean', name: 'Ocean', c: ['#06141D', '#122B3B', '#2EC5D3'] },
    { id: 'forest', name: 'Forest', c: ['#0B140F', '#1A2B21', '#5FD08A'] },
    { id: 'sunset', name: 'Sunset', c: ['#170C11', '#2D1B24', '#FF7A59'] },
    { id: 'blossom', name: 'Blossom', c: ['#FFF3F6', '#FFFFFF', '#D9467A'] },
    { id: 'arcade', name: 'Arcade', c: ['#07060D', '#1A1730', '#3DFFB0'] },
  ];
  const LEVEL_NAMES = [
    'Sleepyhead', 'Early Riser', 'Sunup Scout', 'Morning Mover', 'Dawn Patrol',
    'Routine Ranger', 'Daybreak Hero', 'Sunrise Captain', 'Morning Legend', 'Sun Sovereign',
  ];
  const MOODS = ['😫', '😕', '🙂', '😄', '🤩'];

  const ICONS = {
    check: '<path d="M20 6 9 17l-5-5"/>',
    bolt: '<path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/>',
    lock: '<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
    flame: '<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.07-2.14-.22-4.05 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.15.43-2.29 1-3a2.5 2.5 0 0 0 2.5 2.5z"/>',
    timer: '<circle cx="12" cy="13" r="8"/><path d="M12 9v4l2 2M10 2h4"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    bell: '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    trash: '<path d="M3 6h18M8 6V4h8v2M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/>',
    up: '<path d="m18 15-6-6-6 6"/>',
    down: '<path d="m6 9 6 6 6-6"/>',
    chevron: '<path d="m9 18 6-6-6-6"/>',
    x: '<path d="M18 6 6 18M6 6l12 12"/>',
    download: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>',
    upload: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M17 8l-5-5-5 5M12 3v12"/>',
    share: '<path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8M16 6l-4-4-4 4M12 2v13"/>',
    calendar: '<rect x="3" y="4" width="18" height="18" rx="3"/><path d="M16 2v4M8 2v4M3 10h18"/>',
    calPlus: '<rect x="3" y="4" width="18" height="18" rx="3"/><path d="M16 2v4M8 2v4M3 10h18M12 13v6M9 16h6"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 16v-4M12 8h.01"/>',
    leaf: '<path d="M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.48 19 2c1 2 2 4.18 2 8 0 5.5-4.78 10-10 10z"/><path d="M2 21c0-3 1.85-5.36 5.08-6C9.5 14.52 12 13 13 12"/>',
  };
  const I = (name, cls = '') =>
    `<svg class="ic ${name === 'bolt' ? 'fill ' : ''}${cls}" viewBox="0 0 24 24" aria-hidden="true">${ICONS[name] || ''}</svg>`;

  /* ---------- State ---------- */
  const clone = (o) => JSON.parse(JSON.stringify(o));
  function fresh() {
    return {
      v: 1, onboarded: false, bank: 0, days: {}, checkins: [], redemptions: [], createdAt: Date.now(),
      settings: {
        name: '', wakeTime: '07:00', checkinTime: '17:00', theme: 'midnight',
        sound: true, alerts: false, unit: 'xp',
        tasks: clone(DEFAULT_TASKS), rewards: clone(DEFAULT_REWARDS),
      },
    };
  }
  function normalize(s) {
    const base = fresh();
    if (!s || typeof s !== 'object') return base;
    s.settings = Object.assign(base.settings, s.settings || {});
    if (!Array.isArray(s.settings.tasks)) s.settings.tasks = base.settings.tasks;
    if (!Array.isArray(s.settings.rewards)) s.settings.rewards = base.settings.rewards;
    s.days = s.days && typeof s.days === 'object' ? s.days : {};
    s.checkins = Array.isArray(s.checkins) ? s.checkins : [];
    s.redemptions = Array.isArray(s.redemptions) ? s.redemptions : [];
    s.bank = Math.max(0, Number(s.bank) || 0);
    s.v = 1;
    return s;
  }
  function load() {
    try {
      const raw = localStorage.getItem(KEY);
      if (raw) return normalize(JSON.parse(raw));
    } catch (e) { /* fall through to a fresh start */ }
    return fresh();
  }
  let S = load();
  function save() {
    try { localStorage.setItem(KEY, JSON.stringify(S)); }
    catch (e) { toast('Couldn’t save — storage is blocked or full.'); }
  }

  /* ---------- Small helpers ---------- */
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const uid = () => Math.random().toString(36).slice(2, 9);
  const U = () => (S.settings.unit === 'points' ? 'pts' : 'XP');
  const signed = (n) => (n > 0 ? '+' : n < 0 ? '−' : '') + Math.abs(n);
  const reduceMotion = () => matchMedia('(prefers-reduced-motion: reduce)').matches;
  const isStandalone = () => matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
  const isIOS = () => /iP(hone|ad|od)/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  // Inside the Android app, android-app/native-src.js provides real scheduled notifications.
  const NATIVE = window.SunupNative && window.SunupNative.isNative ? window.SunupNative : null;
  const APK_URL = 'https://github.com/WarmFridge/WarmFridge.github.io/releases/latest/download/sunup.apk';
  const LIGHT_THEMES = ['daylight', 'notebook', 'blossom'];
  let nativePerm = 'prompt';
  function firstGrapheme(v) {
    v = String(v || '').trim();
    if (!v) return '';
    if (window.Intl && Intl.Segmenter) {
      const it = new Intl.Segmenter(undefined, { granularity: 'grapheme' }).segment(v)[Symbol.iterator]().next();
      return it.done ? '' : it.value.segment;
    }
    return Array.from(v).slice(0, 2).join('');
  }

  /* ---------- Time ---------- */
  const now = () => Date.now();
  const pad = (n) => String(n).padStart(2, '0');
  const keyOf = (t) => { const d = new Date(t); return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`; };
  const dateOfKey = (k) => { const [y, m, d] = k.split('-').map(Number); return new Date(y, m - 1, d); };
  const validHHMM = (v) => /^\d{2}:\d{2}$/.test(v || '');
  function at(k, hhmm) {
    const d = dateOfKey(k);
    const [h, m] = (validHHMM(hhmm) ? hhmm : '07:00').split(':').map(Number);
    d.setHours(h, m, 0, 0);
    return d.getTime();
  }
  const dow = (t) => new Date(t).getDay();
  const isWeekday = (t) => { const x = dow(t); return x >= 1 && x <= 5; };
  const isFriday = (t) => dow(t) === 5;
  const addDays = (k, n) => { const d = dateOfKey(k); d.setDate(d.getDate() + n); return keyOf(d); };
  const mondayKey = (t) => { const d = new Date(t); d.setDate(d.getDate() - ((d.getDay() + 6) % 7)); return keyOf(d); };
  const daysUntilFriday = (t) => (5 - dow(t) + 7) % 7;
  const fmtTime = (t) => new Date(t).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
  const fmtHHMM = (hhmm) => fmtTime(at(keyOf(now()), hhmm));
  const fmtDate = (t, o) => new Date(t).toLocaleDateString([], o);
  const fmtClock = (ms) => { const s = Math.max(0, Math.ceil(ms / 1000)); return `${Math.floor(s / 60)}:${pad(s % 60)}`; };
  const fmtLeft = (ms) => (ms >= 3600000 ? `${Math.floor(ms / 3600000)} h ${Math.floor((ms % 3600000) / MIN)} min` : fmtClock(ms));
  const whenFriday = (n) => (n === 0 ? 'today' : n === 1 ? 'tomorrow' : `in ${n} days`);

  /* ---------- Scoring ---------- */
  function wakeXpFor(upAt, target) {
    const m = (upAt - target) / MIN;
    if (m <= RULES.fastMin) return RULES.fastXp;
    if (m <= RULES.okMin) return RULES.okXp;
    return RULES.lateXp;
  }
  function wakeWindow(t, target) {
    const e = t - target;
    if (e < 0) return { phase: 'early', xp: RULES.fastXp, remaining: -e, total: 0 };
    if (e <= RULES.fastMin * MIN) return { phase: 'fast', xp: RULES.fastXp, remaining: RULES.fastMin * MIN - e, total: RULES.fastMin * MIN };
    if (e <= RULES.okMin * MIN) return { phase: 'ok', xp: RULES.okXp, remaining: RULES.okMin * MIN - e, total: (RULES.okMin - RULES.fastMin) * MIN };
    return { phase: 'late', xp: RULES.lateXp, remaining: 0, total: 0 };
  }
  const net = (d) => (d.wakeXp || 0) - (d.penalty || 0);
  const currentSteps = () => [WAKE_STEP, ...S.settings.tasks].map((s) => ({ id: s.id, emoji: s.emoji, label: s.label }));
  const newDay = (target) => ({ target, steps: currentSteps(), done: {}, upAt: null, wakeXp: 0, last: null, penalty: 0, penaltyAt: null, completeAt: null, collected: 0 });
  const nextStep = (d) => d.steps.find((s) => !d.done[s.id]);
  const allDone = (d) => d.steps.every((s) => d.done[s.id]);
  const idleLeft = (d, t = now()) => RULES.idleMin * MIN - (t - d.last);
  const targetFor = (k) => at(k, (S.days[k] && S.days[k].target) || S.settings.wakeTime);

  const pendingXp = () => Object.values(S.days).reduce((a, d) => a + net(d) - (d.collected || 0), 0);
  const lifetimeXp = () => Object.values(S.days).reduce((a, d) => a + Math.max(0, net(d)), 0);
  const morningsDone = () => Object.values(S.days).filter((d) => d.completeAt).length;
  const checkedInToday = () => S.checkins.some((c) => c.date === keyOf(now()));
  const threshold = (L) => (25 * (L - 1) * L) / 2; // 0, 25, 75, 150, 250, 375…
  function levelOf(xp) { let L = 1; while (xp >= threshold(L + 1)) L++; return L; }
  const levelName = (L) => LEVEL_NAMES[Math.min(L, LEVEL_NAMES.length) - 1];
  function streakNow() {
    const tk = keyOf(now());
    let n = 0;
    for (let k = tk, i = 0; i < 1000; i++, k = addDays(k, -1)) {
      if (!isWeekday(dateOfKey(k).getTime())) continue;
      const d = S.days[k];
      if (d && d.completeAt) n++;
      else if (k !== tk) break; // today still in progress doesn't break it; weekends never do
    }
    return n;
  }

  // Apply the "stationary for 10+ minutes" rule from timestamps, so it works even if the app was closed.
  function settle() {
    const t = now();
    let changed = false, freshHit = false;
    for (const d of Object.values(S.days)) {
      if (d.upAt && !d.completeAt && !d.penalty && d.last && t - d.last > RULES.idleMin * MIN) {
        d.penalty = RULES.penalty;
        d.penaltyAt = d.last + RULES.idleMin * MIN;
        changed = true;
        if (t - d.penaltyAt < 5000) freshHit = true;
      }
    }
    if (changed) save();
    return { changed, freshHit };
  }

  /* ---------- Rendering ---------- */
  const VIEWS = { today: viewToday, week: viewWeek, store: viewStore, settings: viewSettings };
  let tab = VIEWS[location.hash.slice(1)] ? location.hash.slice(1) : 'today';
  let justDone = null;
  let liveSig = '';

  function render() {
    settle();
    applyTheme();
    $('#view').innerHTML = VIEWS[tab]();
    renderChrome();
    liveSig = tab === 'today' ? todaySig(now()) : '';
    justDone = null;
    queueNativeSync();
  }
  function renderChrome() {
    $('#tb-bank').textContent = S.bank;
    $('#tb-unit').textContent = U();
    $('#tb-level').textContent = levelOf(lifetimeXp());
    const fri = isFriday(now());
    $$('.tab').forEach((b) => {
      const on = b.dataset.tab === tab;
      b.classList.toggle('is-active', on);
      if (on) b.setAttribute('aria-current', 'page'); else b.removeAttribute('aria-current');
    });
    $('.tab[data-tab="week"] .dot').hidden = !(fri && (pendingXp() !== 0 || !checkedInToday()));
    $('.tab[data-tab="store"] .dot').hidden = !fri;
  }
  let barTheme = '';
  function applyTheme() {
    const th = THEMES.find((x) => x.id === S.settings.theme) || THEMES[0];
    document.documentElement.dataset.theme = th.id;
    const m = $('meta[name="theme-color"]');
    if (m) m.setAttribute('content', th.c[0]);
    if (NATIVE && barTheme !== th.id) { barTheme = th.id; NATIVE.setBarStyle(!LIGHT_THEMES.includes(th.id)); }
  }
  let enterTimer = 0;
  function animateIn() {
    const v = $('#view');
    v.classList.remove('enter');
    void v.offsetWidth; // restart the animation
    v.classList.add('enter');
    clearTimeout(enterTimer);
    enterTimer = setTimeout(() => v.classList.remove('enter'), 450);
  }
  function go(t) {
    if (!VIEWS[t]) return;
    const changed = t !== tab;
    tab = t;
    history.replaceState(null, '', '#' + t);
    render();
    if (changed) { animateIn(); window.scrollTo(0, 0); }
  }
  const head = (eyebrow, title, sub = '') =>
    `<header class="view-head"><p class="eyebrow">${eyebrow}</p><h1>${title}</h1>${sub ? `<div class="sub">${sub}</div>` : ''}</header>`;
  const todayEyebrow = () => fmtDate(now(), { weekday: 'long', month: 'short', day: 'numeric' });
  function greeting() {
    const h = new Date(now()).getHours();
    const g = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
    return S.settings.name ? `${g}, ${esc(S.settings.name)}` : g;
  }

  /* ----- Today ----- */
  function viewToday() {
    const t = now(), k = keyOf(t), d = S.days[k];
    if (!isWeekday(t)) return head(todayEyebrow(), 'Weekend mode') + weekendBody();
    if (!d || !d.upAt) return head(todayEyebrow(), greeting()) + wakeHero(k) + routinePreview();
    const sub = `<span class="chip xp">${I('bolt')} ${signed(net(d))} ${U()} today</span><span>Up at ${fmtTime(d.upAt)}</span>`;
    if (!d.completeAt) {
      const title = d.penalty ? 'Finish strong' : Object.keys(d.done).length <= 1 ? 'You’re up!' : 'Keep it rolling';
      return head(todayEyebrow(), title, sub) + idleCard(d) + stepsList(d);
    }
    return head(todayEyebrow(), 'Morning done') + doneHero(d) + fridayCta() +
      `<h3 class="section-title">This morning</h3>` + stepsList(d);
  }

  const RING_C = 2 * Math.PI * 52;
  function ringOffset(w) {
    const p = w.phase === 'early' ? 1 : w.total ? w.remaining / w.total : 0;
    return (RING_C * (1 - Math.max(0, Math.min(1, p)))).toFixed(2);
  }
  function wakeLine(w, tooEarly, target) {
    if (tooEarly) return `Too early to count — unlocks at <b>${fmtTime(target - RULES.earliestMin * MIN)}</b>`;
    if (w.phase === 'early') return `Alarm in <b data-live="wake-clock">${fmtLeft(w.remaining)}</b> · up early still counts`;
    if (w.phase === 'fast') return `Get up within <b data-live="wake-clock">${fmtClock(w.remaining)}</b> for +${RULES.fastXp} ${U()}`;
    if (w.phase === 'ok') return `Get up within <b data-live="wake-clock">${fmtClock(w.remaining)}</b> for +${RULES.okXp} ${U()}`;
    return `Still worth <b>+${RULES.lateXp} ${U()}</b> — every start counts`;
  }
  function wakeHero(k) {
    const t = now(), target = targetFor(k);
    const w = wakeWindow(t, target);
    const tooEarly = t < target - RULES.earliestMin * MIN;
    const tierIdx = w.phase === 'ok' ? 1 : w.phase === 'late' ? 2 : 0;
    const tiers = [
      [`+${RULES.fastXp}`, `within ${RULES.fastMin} min`],
      [`+${RULES.okXp}`, `within ${RULES.okMin} min`],
      [`+${RULES.lateXp}`, 'later'],
    ];
    return `
      <section class="card hero">
        <div class="ring-wrap">
          <svg class="ring is-${w.phase}" viewBox="0 0 120 120" aria-hidden="true">
            <circle class="ring-track" cx="60" cy="60" r="52"/>
            <circle class="ring-fill" data-live="ring" cx="60" cy="60" r="52" stroke-dasharray="${RING_C.toFixed(2)}" stroke-dashoffset="${ringOffset(w)}"/>
          </svg>
          <div class="ring-center"><div class="ring-xp">+${w.xp}</div><div class="ring-unit">${U()}</div></div>
        </div>
        <p class="hero-line">${wakeLine(w, tooEarly, target)}</p>
        <button class="btn btn-primary btn-xl" data-action="get-up" ${tooEarly ? 'disabled' : ''}>${I('check')} I’m up</button>
        <button class="link-btn" data-action="change-target">${I('clock')} Alarm ${fmtTime(target)} · change for today</button>
      </section>
      <div class="tiers">${tiers.map(([xp, label], i) =>
        `<div class="tier ${i === tierIdx ? 'is-active' : ''} ${i < tierIdx ? 'is-past' : ''}"><b>${xp}</b><span>${label}</span></div>`).join('')}
      </div>`;
  }
  function routinePreview() {
    const steps = currentSteps();
    return `<h3 class="section-title">This morning</h3>
      <div class="steps is-preview">${steps.map((s, i) => `
        <div class="step ${i === 0 ? 'is-next' : ''}">
          <span class="check"></span><span class="emoji">${esc(s.emoji)}</span>
          <span class="label">${esc(s.label)}</span>${i === 0 ? '<span class="meta">Tap “I’m up”</span>' : ''}
        </div>`).join('')}
      </div>`;
  }
  function idleCard(d) {
    if (d.penalty) {
      return `<section class="card notice notice-bad">${I('timer')}
        <div><b>−${d.penalty} ${U()} for a 10-minute stall</b>
        <p>That’s the only one today — no more penalties. Just finish.</p>
        <button class="link-btn" data-action="waive-penalty">I did move, I forgot to tap — remove it</button></div>
      </section>`;
    }
    const left = idleLeft(d);
    const pct = Math.max(0, Math.min(100, (left / (RULES.idleMin * MIN)) * 100));
    const next = nextStep(d);
    return `<section class="card idle ${left <= RULES.warnMin * MIN ? 'is-warn' : ''}">
      <div class="idle-top">
        <span class="idle-label">${I('timer')} Keep moving</span>
        <span class="idle-clock" data-live="idle-clock">${fmtClock(left)}</span>
      </div>
      <div class="bar"><i data-live="idle-bar" style="width:${pct}%"></i></div>
      <p class="idle-hint">Tick off <b>${esc(next ? next.label : 'the next step')}</b> before this runs out to dodge −${RULES.penalty} ${U()}.</p>
    </section>`;
  }
  function stepsList(d) {
    const next = d.completeAt ? null : nextStep(d);
    return `<div class="steps">${d.steps.map((s) => {
      const done = d.done[s.id];
      let meta = '';
      if (s.id === 'up' && done) meta = `${fmtTime(d.upAt)} · +${d.wakeXp}`;
      else if (done) meta = fmtTime(done);
      else if (next && next.id === s.id) meta = 'Up next';
      const cls = ['step', done ? 'is-done' : '', next && next.id === s.id ? 'is-next' : '', justDone === s.id ? 'just-done' : ''].join(' ');
      return `<button class="${cls}" data-action="step" data-id="${esc(s.id)}" aria-pressed="${done ? 'true' : 'false'}">
        <span class="check">${done ? I('check') : ''}</span><span class="emoji">${esc(s.emoji)}</span>
        <span class="label">${esc(s.label)}</span><span class="meta">${meta}</span>
      </button>`;
    }).join('')}</div>`;
  }
  function doneHero(d) {
    return `<section class="card done-hero">
      <div class="done-badge">${I('check')}</div>
      <div class="done-xp">${signed(net(d))} ${U()}</div>
      <p>Up at ${fmtTime(d.upAt)} · done at ${fmtTime(d.completeAt)}${d.penalty ? ` · −${d.penalty} stall` : ''}</p>
      ${weekStrip(mondayKey(now()))}
    </section>`;
  }
  function fridayCta() {
    const t = now();
    const p = pendingXp();
    if (!isFriday(t)) {
      return `<p class="hint-center">${I('lock')} ${p > 0 ? `${signed(p)} ${U()} waiting` : 'Your XP is safe'} · check-in &amp; store open Friday</p>`;
    }
    if (p !== 0 || !checkedInToday()) {
      return `<button class="card cta" data-action="open-checkin"><span class="cta-emoji">🎁</span>
        <span><b>Friday check-in is open</b><small>Collect ${signed(p)} ${U()} and unlock the store</small></span>${I('chevron')}</button>`;
    }
    return `<button class="card cta" data-action="tab" data-tab="store"><span class="cta-emoji">🛍️</span>
      <span><b>The store is open</b><small>${S.bank} ${U()} to spend</small></span>${I('chevron')}</button>`;
  }
  function weekendBody() {
    const t = now(), p = pendingXp(), n = daysUntilFriday(t);
    return `<section class="card weekend">
        <div class="weekend-ic">🌿</div>
        <h2>No tracking on weekends</h2>
        <p>Rest up. Sunup is back Monday — alarm at ${fmtHHMM(S.settings.wakeTime)}.</p>
      </section>
      ${p > 0 ? `<section class="card notice notice-info">${I('info')}<div><b>Your ${signed(p)} ${U()} is safe</b>
        <p>Missed Friday’s check-in? No stress — it rolls into next Friday.</p></div></section>` : ''}
      <div class="stat-grid">
        <section class="card stat"><span>In the bank</span><b>${I('bolt')} ${S.bank}</b></section>
        <section class="card stat"><span>Store opens</span><b>${n === 0 ? 'Today' : `${n} days`}</b></section>
      </div>
      ${levelCard()}`;
  }

  /* ----- Week ----- */
  function dayStatus(k) {
    const d = S.days[k], tk = keyOf(now());
    if (k > tk) return 'future';
    if (d && d.completeAt) return 'done';
    if (d && d.upAt) return k === tk ? 'active' : 'partial';
    return k === tk ? 'today' : 'missed';
  }
  function weekStrip(mk) {
    return `<div class="week">${[0, 1, 2, 3, 4].map((i) => {
      const k = addDays(mk, i), d = S.days[k], st = dayStatus(k);
      const name = fmtDate(dateOfKey(k), { weekday: 'short' });
      let dot = '', xp = '';
      if (st === 'done') { dot = I('check'); xp = `${signed(net(d))}`; }
      else if (st === 'partial' || st === 'active') { dot = signed(net(d)); xp = st === 'active' ? 'now' : ''; }
      else if (st === 'missed') { dot = '–'; }
      else if (st === 'today') { dot = '•'; xp = 'today'; }
      return `<div class="wd is-${st}"><span class="wd-name">${name}</span><span class="wd-dot">${dot}</span><span class="wd-xp">${xp}</span></div>`;
    }).join('')}</div>`;
  }
  function viewWeek() {
    const t = now(), mk = mondayKey(t);
    const keys = [0, 1, 2, 3, 4].map((i) => addDays(mk, i));
    const days = keys.map((k) => S.days[k]).filter(Boolean);
    const earned = days.reduce((a, d) => a + net(d), 0);
    const done = days.filter((d) => d.completeAt).length;
    const stalls = days.filter((d) => d.penalty).length;
    const range = `${fmtDate(dateOfKey(mk), { month: 'short', day: 'numeric' })} – ${fmtDate(dateOfKey(keys[4]), { month: 'short', day: 'numeric' })}`;
    return head(range, 'This week') + `
      <section class="card">
        ${weekStrip(mk)}
        <div class="sum3">
          <div><b class="num">${signed(earned) || '0'}</b><span>${U()} earned</span></div>
          <div><b class="num">${done}/5</b><span>mornings done</span></div>
          <div><b class="num">${stalls}</b><span>${stalls === 1 ? 'stall' : 'stalls'}</span></div>
        </div>
      </section>
      ${checkinCard()}
      ${levelCard()}
      ${pastWeeks(mk)}`;
  }
  function checkinCard() {
    const t = now(), p = pendingXp();
    if (isFriday(t) && (p !== 0 || !checkedInToday())) {
      return `<section class="card checkin is-open">
        <div class="ci-top"><span class="ci-icon">🎁</span><div><b>Friday check-in is open</b><span>Look back at your week, bank your ${U()}, unlock the store.</span></div></div>
        <button class="btn btn-primary btn-xl" data-action="open-checkin">${p > 0 ? `Collect ${signed(p)} ${U()}` : 'Check in'}</button>
      </section>`;
    }
    if (isFriday(t)) {
      return `<section class="card checkin">
        <div class="ci-top"><span class="ci-icon">✅</span><div><b>Checked in</b><span>${S.bank} ${U()} in the bank. The store is open today.</span></div></div>
        <button class="btn btn-primary btn-xl" data-action="tab" data-tab="store">Open the store</button>
      </section>`;
    }
    const n = daysUntilFriday(t);
    return `<section class="card checkin">
      <div class="ci-top"><span class="ci-icon">${I('lock')}</span><div><b>Friday check-in</b>
      <span>Opens ${whenFriday(n)} · ${p > 0 ? `${signed(p)} ${U()} waiting for you` : 'earn XP this week to collect'}</span></div></div>
    </section>`;
  }
  function levelCard() {
    const xp = lifetimeXp(), L = levelOf(xp), lo = threshold(L), hi = threshold(L + 1);
    const pct = ((xp - lo) / (hi - lo)) * 100;
    const streak = streakNow(), total = morningsDone();
    return `<section class="card level">
      <div class="lv-row"><div class="lv-badge">${L}</div>
        <div class="lv-main"><b>${levelName(L)}</b><span>Level ${L} · ${xp} lifetime ${U()}</span></div></div>
      <div class="bar xp"><i style="width:${pct}%"></i></div>
      <div class="lv-next">${hi - xp} ${U()} to Level ${L + 1} · ${levelName(L + 1)}</div>
      <div class="chips">
        ${streak >= 2 ? `<span class="chip flame">${I('flame')} ${streak}-day streak</span>` : ''}
        <span class="chip">${I('check')} ${total} ${total === 1 ? 'morning' : 'mornings'} done</span>
        <span class="chip">${I('leaf')} Weekends never break streaks</span>
      </div>
    </section>`;
  }
  function pastWeeks(mk) {
    const weeks = {};
    for (const [k, d] of Object.entries(S.days)) {
      const w = mondayKey(dateOfKey(k).getTime());
      if (w >= mk) continue;
      weeks[w] = weeks[w] || { xp: 0, done: 0 };
      weeks[w].xp += net(d);
      if (d.completeAt) weeks[w].done++;
    }
    const list = Object.keys(weeks).sort().reverse().slice(0, 12);
    if (!list.length) return '';
    return `<h3 class="section-title">Past weeks</h3>
      <section class="card list">${list.map((w) => `
        <div class="row"><div class="row-main"><b>Week of ${fmtDate(dateOfKey(w), { month: 'short', day: 'numeric' })}</b>
          <span>${weeks[w].done}/5 mornings done</span></div>
          <span class="xp-val ${weeks[w].xp < 0 ? 'neg' : 'pos'}">${signed(weeks[w].xp)} ${U()}</span></div>`).join('')}
      </section>`;
  }

  /* ----- Store ----- */
  function viewStore() {
    const t = now(), open = isFriday(t), p = pendingXp(), n = daysUntilFriday(t);
    const rewards = [...S.settings.rewards].sort((a, b) => a.cost - b.cost);
    const pill = open
      ? `<span class="status-pill open"><i class="live-dot"></i> Open today</span>`
      : `<span class="status-pill locked">${I('lock')} Opens Friday · ${whenFriday(n)}</span>`;
    return head(open ? 'Friday · cash out' : 'Rewards', 'Store') + `
      <section class="card bank-card">
        ${pill}
        <div class="bank-amt">${I('bolt')}<span>${S.bank}</span><small>${U()}</small></div>
        <p class="muted small">${p !== 0 ? `${signed(p)} ${U()} waiting for ${open ? 'your check-in' : 'Friday’s check-in'}` : 'Ready to spend · XP never expires'}</p>
      </section>
      ${open && (p !== 0 || !checkedInToday()) ? `<button class="card cta" data-action="open-checkin"><span class="cta-emoji">🎁</span>
        <span><b>Check in first</b><small>${p !== 0 ? `Collect ${signed(p)} ${U()} into your bank` : 'Close out your week'}</small></span>${I('chevron')}</button>` : ''}
      <section class="card list">${rewards.map(rewardRow).join('')}</section>
      <h3 class="section-title">Cashed out</h3>
      ${S.redemptions.length ? `<section class="card list">${S.redemptions.slice(0, 40).map((r) => `
        <div class="row"><span class="reward-emoji" style="width:40px;height:40px;font-size:22px;border-radius:12px">${esc(r.emoji)}</span>
          <div class="row-main"><b>${esc(r.label)}</b><span>${fmtDate(r.at, { weekday: 'short', month: 'short', day: 'numeric' })}</span></div>
          <span class="xp-val">−${r.cost} ${U()}</span></div>`).join('')}</section>`
        : `<p class="empty">Nothing cashed out yet — your first reward is waiting.</p>`}`;
  }
  function rewardRow(r) {
    const open = isFriday(now());
    const projected = S.bank + Math.max(0, pendingXp());
    const can = open && S.bank >= r.cost;
    const pct = Math.min(100, (projected / r.cost) * 100);
    let status;
    if (can) status = 'Ready to cash out';
    else if (projected >= r.cost) status = open ? 'Check in to unlock' : 'Ready on Friday 🎉';
    else status = `${r.cost - projected} ${U()} to go`;
    return `<div class="row reward ${can ? 'can' : ''}">
      <span class="reward-emoji">${esc(r.emoji)}</span>
      <div class="row-main"><b>${esc(r.label)}</b>
        <span class="reward-cost">${I('bolt')} ${r.cost} ${U()}</span>
        <div class="bar thin"><i style="width:${pct}%"></i></div>
        <span class="reward-status">${status}</span></div>
      ${can ? `<button class="btn btn-sm btn-primary" data-action="redeem" data-id="${esc(r.id)}">Cash out</button>`
        : open ? '' : `<span class="reward-lock" title="Opens Friday">${I('lock')}</span>`}
    </div>`;
  }

  /* ----- Settings ----- */
  const switchEl = (key, on, label) =>
    `<button class="switch" role="switch" aria-checked="${on ? 'true' : 'false'}" aria-label="${label}" data-action="toggle" data-key="${key}"></button>`;
  function calButtons() {
    return ['wake', 'friday'].map((kind) => {
      const hhmm = kind === 'wake' ? S.settings.wakeTime : S.settings.checkinTime;
      const inner = `${I('calPlus')}<span><b>${kind === 'wake' ? 'Wake-up' : 'Check-in'}</b>
        <small>${kind === 'wake' ? 'Mon–Fri' : 'Fridays'} · ${fmtHHMM(hhmm)}</small></span>`;
      const path = window.SunupICS && SunupICS.staticPath(kind, hhmm);
      return path
        ? `<a class="cal-btn" href="${path}" target="_blank" rel="noopener">${inner}</a>`
        : `<button class="cal-btn" data-action="cal" data-kind="${kind}">${inner}</button>`;
    }).join('');
  }
  const remindersSummary = () =>
    `Mon–Fri at ${fmtHHMM(S.settings.wakeTime)}: wake-up + “1 min left” nudges. Keep-moving nudges during your routine. ` +
    `Fridays at ${fmtHHMM(S.settings.checkinTime)}: check-in. Rings even when Sunup is closed.`;
  function viewSettings() {
    const s = S.settings;
    const d = S.days[keyOf(now())];
    const inProgress = d && d.upAt && !d.completeAt;
    const isAndroidWeb = !NATIVE && /Android/i.test(navigator.userAgent);
    return head('Make it yours', 'Settings') + `
      ${isAndroidWeb ? `<a class="card install" href="${APK_URL}"><span class="ci-icon">${I('download')}</span><div>
        <b>Get the Android app</b>
        <span>Reminders that ring even when Sunup is closed. Tip: Back up here first, then Restore inside the app to bring your XP.</span></div></a>` : ''}
      ${NATIVE || isStandalone() || isAndroidWeb ? '' : `<section class="card install"><span class="ci-icon">${I('share')}</span><div>
        <b>Put Sunup on your Home Screen</b>
        <span>iPhone: tap Share → “Add to Home Screen”. Android: ⋮ menu → “Install app”. It opens full-screen, works offline, unlocks notifications on iPhone, and keeps your XP safe.</span></div></section>`}

      <h3 class="section-title">Morning</h3>
      <section class="card list">
        <label class="row"><div class="row-main"><b>Weekday alarm</b><span>Your wake-up score counts from this time</span></div>
          <input type="time" data-field="wakeTime" value="${s.wakeTime}"></label>
        <label class="row"><div class="row-main"><b>Your name</b><span>For the greeting</span></div>
          <input type="text" class="in-name" data-field="name" value="${esc(s.name)}" placeholder="Optional" maxlength="24" autocomplete="given-name"></label>
      </section>

      <h3 class="section-title">Reminders</h3>
      ${NATIVE ? `<section class="card list">
        <div class="row"><div class="row-main"><b>${I('bell')} Reminders</b><span id="remind-summary">${remindersSummary()}</span></div>
          ${switchEl('alerts', nativeAlertsOn(), 'Reminders')}</div>
        ${S.settings.alerts && nativePerm === 'denied' ? `<div class="row"><div class="row-main"><span>Notifications are blocked for Sunup. Turn them on in Android Settings → Apps → Sunup → Notifications.</span></div></div>` : ''}
        <label class="row"><div class="row-main"><b>Friday check-in time</b><span>When the Friday reminder rings</span></div>
          <input type="time" data-field="checkinTime" value="${s.checkinTime}"></label>
        <div class="row"><div class="row-main"><b>Sounds &amp; haptics</b><span>Little chimes when you tick things off</span></div>
          ${switchEl('sound', s.sound, 'Sounds and haptics')}</div>
      </section>` : `<section class="card list">
        <div class="row col"><div class="row-main"><b>${I('calendar')} Calendar alarms</b>
          <span>Reliable reminders even when Sunup is closed. Tap each once and choose “Add All”.</span></div>
          <div class="cal-grid" id="cal-btns">${calButtons()}</div></div>
        <label class="row"><div class="row-main"><b>Friday check-in time</b><span>When the Friday reminder fires</span></div>
          <input type="time" data-field="checkinTime" value="${s.checkinTime}"></label>
        <div class="row"><div class="row-main"><b>Phone notifications</b><span>Nudges while your routine is running: “1 min left for +10”, “2 min to dodge −5”.</span></div>
          ${switchEl('alerts', s.alerts, 'Phone notifications')}</div>
        <div class="row"><div class="row-main"><b>Sounds &amp; haptics</b><span>Little chimes when you tick things off</span></div>
          ${switchEl('sound', s.sound, 'Sounds and haptics')}</div>
      </section>`}

      <h3 class="section-title">Theme</h3>
      <section class="theme-grid">${THEMES.map((th) => `
        <button class="theme-sw ${th.id === s.theme ? 'is-on' : ''}" data-action="theme" data-id="${th.id}" aria-pressed="${th.id === s.theme}">
          <span class="sw" style="background:${th.c[0]}"><b style="background:${th.c[2]}"></b><em style="background:${th.c[2]}"></em><i style="background:${th.c[1]}"></i></span>
          ${th.name}</button>`).join('')}
      </section>

      <h3 class="section-title">Morning routine</h3>
      <section class="card list">
        <div class="edit-row"><span class="emoji-static">🛏️</span><span class="grow fixed-label"><b>Get out of bed</b><small>Always step 1 · scored against your alarm</small></span></div>
        ${s.tasks.map((t, i) => `
          <div class="edit-row">
            <input class="emoji-in" type="text" data-task="${esc(t.id)}" data-prop="emoji" value="${esc(t.emoji)}" aria-label="Emoji">
            <input class="grow" type="text" data-task="${esc(t.id)}" data-prop="label" value="${esc(t.label)}" maxlength="40" aria-label="Step name">
            <button class="icon-btn" data-action="move-task" data-id="${esc(t.id)}" data-dir="-1" aria-label="Move up" ${i === 0 ? 'disabled' : ''}>${I('up')}</button>
            <button class="icon-btn" data-action="move-task" data-id="${esc(t.id)}" data-dir="1" aria-label="Move down" ${i === s.tasks.length - 1 ? 'disabled' : ''}>${I('down')}</button>
            <button class="icon-btn" data-action="del-task" data-id="${esc(t.id)}" aria-label="Remove step">${I('trash')}</button>
          </div>`).join('')}
        <button class="row add-row" data-action="add-task">${I('plus')} Add a step</button>
      </section>
      ${inProgress ? '<p class="foot-note">Routine changes apply from your next morning.</p>' : ''}

      <h3 class="section-title">Rewards</h3>
      <section class="card list">
        ${s.rewards.map((r) => `
          <div class="edit-row">
            <input class="emoji-in" type="text" data-reward="${esc(r.id)}" data-prop="emoji" value="${esc(r.emoji)}" aria-label="Emoji">
            <input class="grow" type="text" data-reward="${esc(r.id)}" data-prop="label" value="${esc(r.label)}" maxlength="48" aria-label="Reward name">
            <span class="cost-wrap">${I('bolt')}<input class="cost-in" type="number" inputmode="numeric" min="1" max="9999" data-reward="${esc(r.id)}" data-prop="cost" value="${r.cost}" aria-label="Cost"></span>
            <button class="icon-btn" data-action="del-reward" data-id="${esc(r.id)}" aria-label="Remove reward">${I('trash')}</button>
          </div>`).join('')}
        <button class="row add-row" data-action="add-reward">${I('plus')} Add a reward</button>
      </section>

      <h3 class="section-title">Game</h3>
      <section class="card list">
        <div class="row"><div class="row-main"><b>Call them</b><span>Same rules, your favourite word</span></div>
          <div class="seg" role="group" aria-label="Points name">
            <button class="${s.unit !== 'points' ? 'is-on' : ''}" data-action="unit" data-unit="xp">XP</button>
            <button class="${s.unit === 'points' ? 'is-on' : ''}" data-action="unit" data-unit="points">Points</button>
          </div></div>
      </section>

      <h3 class="section-title">How scoring works</h3>
      <section class="card rules">
        <div class="rule"><span class="rule-xp good">+${RULES.fastXp}</span><span>Up within ${RULES.fastMin} min of your alarm</span></div>
        <div class="rule"><span class="rule-xp good">+${RULES.okXp}</span><span>Up within ${RULES.okMin} min</span></div>
        <div class="rule"><span class="rule-xp good">+${RULES.lateXp}</span><span>Up later — it still counts</span></div>
        <div class="rule"><span class="rule-xp bad">−${RULES.penalty}</span><span>Stationary ${RULES.idleMin}+ min before everything’s done (once a morning, max)</span></div>
        <div class="rule"><span class="rule-xp">🗓️</span><span>Tracked Monday–Friday. Weekends are off.</span></div>
        <div class="rule"><span class="rule-xp">🎁</span><span>Check in on Friday to bank your ${U()}. The store only opens on Fridays. ${U()} carries over forever.</span></div>
      </section>

      <h3 class="section-title">Your data</h3>
      <section class="card list">
        <button class="row" data-action="export">${I('download')}<div class="row-main"><b>Back up</b><span>Save a file with all your ${U()} and history</span></div></button>
        <button class="row" data-action="import">${I('upload')}<div class="row-main"><b>Restore from a backup</b><span>Moving phones? Load your file here</span></div></button>
        <button class="row danger" data-action="reset">${I('trash')}<div class="row-main"><b>Erase everything</b></div></button>
      </section>
      <p class="foot">Sunup · saved only on this device · no account, no ads, no subscription</p>`;
  }

  /* ---------- Live updates (every second) ---------- */
  function todaySig(t) {
    const k = keyOf(t), d = S.days[k];
    if (!isWeekday(t)) return `${k}:weekend`;
    if (!d || !d.upAt) {
      const target = targetFor(k);
      return `${k}:wake:${wakeWindow(t, target).phase}:${t < target - RULES.earliestMin * MIN}`;
    }
    if (!d.completeAt && !d.penalty) return `${k}:idle:${idleLeft(d, t) <= RULES.warnMin * MIN}`;
    return `${k}:static`;
  }
  function updateLive(t) {
    const k = keyOf(t), d = S.days[k];
    if (!d || !d.upAt) {
      const w = wakeWindow(t, targetFor(k));
      const clk = $('[data-live="wake-clock"]');
      if (clk) clk.textContent = w.phase === 'early' ? fmtLeft(w.remaining) : fmtClock(w.remaining);
      const ring = $('[data-live="ring"]');
      if (ring) ring.setAttribute('stroke-dashoffset', ringOffset(w));
    } else if (!d.completeAt && !d.penalty) {
      const left = idleLeft(d, t);
      const c = $('[data-live="idle-clock"]');
      if (c) c.textContent = fmtClock(left);
      const b = $('[data-live="idle-bar"]');
      if (b) b.style.width = Math.max(0, Math.min(100, (left / (RULES.idleMin * MIN)) * 100)) + '%';
    }
  }
  let lastKey = keyOf(now());
  function tick() {
    const t = now(), k = keyOf(t);
    const st = settle();
    if (st.changed) {
      const d = S.days[k];
      if (st.freshHit && d && d.penalty) {
        const nx = nextStep(d);
        alertUser(`${k}:penalty`, `−${RULES.penalty} ${U()} — 10 minutes without a step`, `It happens. Shake it off — next up: ${nx ? nx.label : 'finish up'}.`);
      }
      softRender();
      return;
    }
    if (k !== lastKey) { lastKey = k; softRender(); return; }
    checkAlerts(t);
    if (tab === 'today') {
      if (todaySig(t) !== liveSig) render();
      else updateLive(t);
    }
  }
  // Don't yank the keyboard away while someone is typing in Settings.
  function softRender() { if (tab === 'settings') renderChrome(); else render(); }

  /* ---------- Android app: real scheduled notifications ---------- */
  // Everything Sunup might want to tell you in the next 3 weeks, worked out from the current state.
  // Re-planned after every change, so tapping "I'm up" or ticking a step cancels stale nudges.
  function plannedNotifications() {
    const t = now(), tk = keyOf(t), out = [];
    const add = (when, title, body) => { if (when > t + 2000) out.push({ at: when, title, body }); };
    const p = pendingXp();
    for (let i = 0; i < 21; i++) {
      const k = addDays(tk, i), dayT = dateOfKey(k).getTime();
      if (!isWeekday(dayT)) continue;
      const d = S.days[k];
      if (!(d && d.upAt)) {
        const target = targetFor(k);
        add(target, '☀️ Time to get up!', `Up within ${RULES.fastMin} min = +${RULES.fastXp} ${U()}. Tap “I’m up” once your feet hit the floor.`);
        add(target + (RULES.fastMin - 1) * MIN, `⏰ 1 minute left for +${RULES.fastXp} ${U()}`, 'Feet on the floor, then tap “I’m up”.');
        add(target + (RULES.okMin - 1) * MIN, `⏰ 1 minute left for +${RULES.okXp} ${U()}`, 'Up you get — it still counts.');
      }
      if (isFriday(dayT) && !S.checkins.some((c) => c.date === k)) {
        add(at(k, S.settings.checkinTime), '🎁 Friday check-in — the store is open',
          p > 0 ? `Collect your ${signed(p)} ${U()} and treat yourself.` : 'Close out your week and visit the store.');
      }
    }
    const d = S.days[tk];
    if (isWeekday(t) && d && d.upAt && !d.completeAt && !d.penalty) {
      const nx = nextStep(d), label = nx ? nx.label : 'your next step';
      add(d.last + (RULES.idleMin - RULES.warnMin) * MIN, `⏱ ${RULES.warnMin} minutes to dodge −${RULES.penalty}`, `Next up: ${label}. Go go go!`);
      add(d.last + RULES.idleMin * MIN + 1500, `−${RULES.penalty} ${U()} — 10 minutes without a step`, `It happens. Shake it off — next up: ${label}.`);
    }
    return out.sort((a, b) => a.at - b.at).slice(0, 60).map((n, i) => ({ id: i + 1, ...n }));
  }
  let syncTimer = 0, lastSyncSig = '';
  function queueNativeSync(immediate) {
    if (!NATIVE) return;
    clearTimeout(syncTimer);
    syncTimer = setTimeout(syncNative, immediate ? 0 : 400);
  }
  async function syncNative() {
    const list = S.settings.alerts && nativePerm === 'granted' ? plannedNotifications() : [];
    const sig = JSON.stringify(list);
    if (sig === lastSyncSig) return;
    lastSyncSig = sig;
    try { await NATIVE.schedule(list); } catch (e) { lastSyncSig = ''; }
  }
  const nativeAlertsOn = () => !!(NATIVE && S.settings.alerts && nativePerm === 'granted');

  /* ---------- Notifications, sound, haptics ---------- */
  const fired = new Set(JSON.parse(sessionStorage.getItem('sunup.fired') || '[]'));
  function alertUser(key, title, body) {
    if (fired.has(key)) return;
    fired.add(key);
    try { sessionStorage.setItem('sunup.fired', JSON.stringify([...fired].slice(-50))); } catch (e) { /* ignore */ }
    if (nativeAlertsOn()) return; // the Android notification already covers it — no double ping
    toast(`<span><b>${esc(title)}</b><br>${esc(body)}</span>`, { ms: 7000, cls: 'alert', html: true });
    chime('warn');
    buzz([120, 60, 120]);
    if (document.hidden) sysNotify(title, body);
  }
  function checkAlerts(t) {
    if (!isWeekday(t)) return;
    const k = keyOf(t), d = S.days[k];
    if (!d || !d.upAt) {
      const target = targetFor(k);
      const w = wakeWindow(t, target);
      if (w.phase === 'fast' && w.remaining <= MIN) alertUser(`${k}:wake-fast`, `1 minute left for +${RULES.fastXp} ${U()}`, 'Feet on the floor, then tap “I’m up”.');
      if (w.phase === 'ok' && w.remaining <= MIN) alertUser(`${k}:wake-ok`, `1 minute left for +${RULES.okXp} ${U()}`, 'Up you get — it still counts.');
      return;
    }
    if (!d.completeAt && !d.penalty) {
      const left = idleLeft(d, t);
      const nx = nextStep(d);
      if (left > 0 && left <= RULES.warnMin * MIN) {
        alertUser(`${k}:idle:${d.last}`, `${RULES.warnMin} minutes to dodge −${RULES.penalty}`, `Next up: ${nx ? nx.label : 'your next step'}. Go go go!`);
      }
    }
  }
  async function sysNotify(title, body, force) {
    if (!force && !S.settings.alerts) return;
    if (!('Notification' in window) || Notification.permission !== 'granted') return;
    const opts = { body, icon: 'icons/icon-192.png', badge: 'icons/icon-192.png', tag: 'sunup', renotify: true };
    try {
      const reg = navigator.serviceWorker && (await navigator.serviceWorker.getRegistration());
      if (reg) await reg.showNotification(title, opts);
      else new Notification(title, opts);
    } catch (e) { /* notifications are a bonus — never break the app */ }
  }
  let audio = null;
  function unlockAudio() {
    try {
      audio = audio || new (window.AudioContext || window.webkitAudioContext)();
      if (audio.state === 'suspended') audio.resume();
    } catch (e) { audio = null; }
  }
  function chime(kind = 'good') {
    if (!S.settings.sound) return;
    unlockAudio();
    if (!audio) return;
    const notes = { tick: [880], good: [660, 990], win: [523, 659, 784, 1047], warn: [587, 440] }[kind] || [660];
    const t0 = audio.currentTime + 0.01;
    notes.forEach((f, i) => {
      const o = audio.createOscillator(), g = audio.createGain();
      const t = t0 + i * 0.11;
      o.type = 'sine'; o.frequency.value = f;
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(0.22, t + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 0.38);
      o.connect(g); g.connect(audio.destination);
      o.start(t); o.stop(t + 0.42);
    });
  }
  const buzz = (p) => { if (S.settings.sound && navigator.vibrate) try { navigator.vibrate(p); } catch (e) { /* ignore */ } };

  /* ---------- Celebration ---------- */
  function confetti(count = 150) {
    if (reduceMotion()) return;
    const c = $('#confetti'), ctx = c.getContext('2d');
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    c.width = innerWidth * dpr; c.height = innerHeight * dpr; c.style.display = 'block';
    const cs = getComputedStyle(document.documentElement);
    const colors = ['--accent', '--xp', '--good', '--bad', '--warn'].map((v) => cs.getPropertyValue(v).trim() || '#fff');
    const P = Array.from({ length: count }, () => ({
      x: c.width / 2 + (Math.random() - 0.5) * 60 * dpr, y: c.height * 0.38,
      vx: (Math.random() - 0.5) * 17 * dpr, vy: (-Math.random() * 15 - 5) * dpr,
      w: (6 + Math.random() * 6) * dpr, h: (9 + Math.random() * 9) * dpr,
      r: Math.random() * Math.PI, vr: (Math.random() - 0.5) * 0.35,
      col: colors[(Math.random() * colors.length) | 0],
    }));
    const start = performance.now(), dur = 2600;
    function frame(ts) {
      const el = ts - start;
      ctx.clearRect(0, 0, c.width, c.height);
      for (const p of P) {
        p.vy += 0.38 * dpr; p.vx *= 0.99; p.x += p.vx; p.y += p.vy; p.r += p.vr;
        ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.r);
        ctx.globalAlpha = Math.max(0, 1 - el / dur);
        ctx.fillStyle = p.col;
        ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h * Math.abs(Math.cos(p.r * 2)));
        ctx.restore();
      }
      if (el < dur) requestAnimationFrame(frame);
      else { ctx.clearRect(0, 0, c.width, c.height); c.style.display = 'none'; }
    }
    requestAnimationFrame(frame);
  }
  function floatXp(txt) {
    if (reduceMotion()) return;
    const el = document.createElement('div');
    el.className = 'float-xp';
    el.textContent = txt;
    document.body.appendChild(el);
    setTimeout(() => el.remove(), 1600);
  }

  /* ---------- Toasts & sheets ---------- */
  function toast(msg, opts = {}) {
    const root = $('#toast-root');
    while (root.children.length > 2) root.firstChild.remove();
    const el = document.createElement('div');
    el.className = 'toast' + (opts.cls ? ' ' + opts.cls : '');
    el.innerHTML = (opts.html ? msg : `<span>${msg}</span>`) + (opts.undo ? '<button class="toast-btn">Undo</button>' : '');
    root.appendChild(el);
    requestAnimationFrame(() => requestAnimationFrame(() => el.classList.add('show')));
    const kill = () => { el.classList.remove('show'); setTimeout(() => el.remove(), 300); };
    if (opts.undo) el.querySelector('.toast-btn').addEventListener('click', () => { opts.undo(); kill(); });
    else el.addEventListener('click', kill);
    setTimeout(kill, opts.ms || 3200);
  }
  const closeX = `<button class="icon-btn" data-action="close-sheet" aria-label="Close">${I('x')}</button>`;
  function sheet(html, { dismissable = true } = {}) {
    const root = $('#sheet-root');
    root.innerHTML = `<div class="sheet-backdrop" ${dismissable ? 'data-action="close-sheet"' : ''}></div>
      <div class="sheet" role="dialog" aria-modal="true">${html}</div>`;
    root.dataset.dismissable = dismissable ? '1' : '';
    requestAnimationFrame(() => requestAnimationFrame(() => root.classList.add('open')));
  }
  function closeSheet() {
    const root = $('#sheet-root');
    root.classList.remove('open');
    setTimeout(() => { if (!root.classList.contains('open')) root.innerHTML = ''; }, 320);
  }

  /* ---------- Actions: morning ---------- */
  function getUp() {
    const t = now(), k = keyOf(t);
    if (!isWeekday(t)) return;
    const d = S.days[k] || (S.days[k] = newDay(S.settings.wakeTime));
    if (d.upAt) return;
    const target = at(k, d.target || S.settings.wakeTime);
    if (t < target - RULES.earliestMin * MIN) { toast('A bit early — this unlocks 3 hours before your alarm.'); return; }
    d.steps = currentSteps();
    d.upAt = t; d.done = { up: t }; d.last = t;
    d.wakeXp = wakeXpFor(t, target);
    if (allDone(d)) d.completeAt = t;
    save();
    if (NATIVE) NATIVE.clearDelivered();
    justDone = 'up';
    render();
    floatXp(`+${d.wakeXp} ${U()}`);
    if (d.wakeXp >= RULES.fastXp) { confetti(90); chime('win'); } else chime('good');
    buzz(40);
    const msg = d.wakeXp >= RULES.fastXp ? `Up fast! +${d.wakeXp} ${U()} 🔥` : d.wakeXp >= RULES.okXp ? `You’re up! +${d.wakeXp} ${U()}` : `You’re up — +${d.wakeXp} ${U()}. Every start counts.`;
    toast(msg, { undo: undoUp, ms: 6000 });
  }
  function undoUp() {
    const d = S.days[keyOf(now())];
    if (!d) return;
    Object.assign(d, { upAt: null, wakeXp: 0, done: {}, last: null, penalty: 0, penaltyAt: null, completeAt: null });
    save();
    render();
  }
  function toggleStep(id) {
    const t = now(), d = S.days[keyOf(t)];
    if (!d || !d.upAt) return;
    if (id === 'up') {
      sheet(`<div class="sheet-head"><h2>Undo “I’m up”?</h2>${closeX}</div>
        <p class="muted">This clears this morning’s progress and ${U()}, so you can tap “I’m up” again.</p>
        <div class="btn-stack"><button class="btn btn-danger btn-xl" data-action="undo-up">Undo</button>
        <button class="btn btn-xl" data-action="close-sheet">Keep it</button></div>`);
      return;
    }
    settle(); // if they were stuck for 10+ min, that counts before this tap
    if (d.done[id]) { delete d.done[id]; d.completeAt = null; }
    else { d.done[id] = t; justDone = id; }
    d.last = t;
    const finished = !d.completeAt && allDone(d);
    if (finished) d.completeAt = t;
    save();
    if (NATIVE) NATIVE.clearDelivered();
    render();
    if (finished) {
      confetti();
      chime('win');
      buzz([40, 50, 90]);
      toast(`Morning done! ${signed(net(d))} ${U()} today 🎉`);
    } else if (justDone || d.done[id]) {
      chime('tick');
      buzz(20);
    }
  }
  function waivePenalty() {
    const d = S.days[keyOf(now())];
    if (!d) return;
    d.penalty = 0; d.penaltyAt = null; d.last = now();
    save();
    render();
    toast('Removed — timer restarted. Honour system 🤝');
  }
  function openChangeTarget() {
    const k = keyOf(now());
    const cur = (S.days[k] && S.days[k].target) || S.settings.wakeTime;
    sheet(`<div class="sheet-head"><h2>Today’s alarm</h2>${closeX}</div>
      <p class="muted">Different alarm today? Your wake-up score uses this time — just for today.</p>
      <input type="time" id="target-in" class="in-lg" value="${cur}">
      <button class="btn btn-primary btn-xl" data-action="save-target">Save for today</button>`);
  }
  function saveTarget() {
    const v = $('#target-in').value;
    if (!validHHMM(v)) return;
    const k = keyOf(now());
    const d = S.days[k] || (S.days[k] = newDay(v));
    d.target = v;
    save();
    closeSheet();
    render();
    toast(`Today’s alarm: ${fmtHHMM(v)}`);
  }

  /* ---------- Actions: Friday ---------- */
  let moodPick = null;
  function openCheckin() {
    if (!isFriday(now())) { toast('Check-in opens on Friday.'); return; }
    moodPick = null;
    const p = pendingXp(), mk = mondayKey(now());
    sheet(`<div class="sheet-head"><div><p class="eyebrow">Week of ${fmtDate(dateOfKey(mk), { month: 'short', day: 'numeric' })}</p><h2>Friday check-in</h2></div>${closeX}</div>
      <div style="margin-top:14px">${weekStrip(mk)}</div>
      <div class="collect-amt">${signed(p) || '0'} <small>${U()}</small></div>
      <p class="center muted">${p > 0 ? 'ready to collect into your bank' : p < 0 ? 'a rough week — it happens. Fresh start Monday.' : 'Nothing to collect this time — fresh start Monday.'}</p>
      <div class="mood"><p>How did this week feel? <span class="muted">(optional)</span></p>
        <div class="mood-row">${MOODS.map((m, i) => `<button class="mood-btn" data-action="mood" data-i="${i}" aria-label="Mood ${i + 1} of 5">${m}</button>`).join('')}</div></div>
      <button class="btn btn-primary btn-xl" data-action="collect">${p > 0 ? `Collect ${signed(p)} ${U()}` : 'Check in'}</button>`);
  }
  function collect() {
    const p = pendingXp();
    for (const d of Object.values(S.days)) d.collected = net(d);
    S.bank = Math.max(0, S.bank + p);
    S.checkins.push({ at: now(), date: keyOf(now()), xp: p, mood: moodPick });
    save();
    closeSheet();
    render();
    if (p > 0) { confetti(); chime('win'); floatXp(`+${p} ${U()}`); buzz([40, 50, 90]); }
    toast(p > 0 ? `Banked ${p} ${U()} — the store is open 🎁` : 'Checked in ✓ The store is open.');
  }
  function openRedeem(id) {
    const r = S.settings.rewards.find((x) => x.id === id);
    if (!r) return;
    if (!isFriday(now())) { toast('The store opens on Friday.'); return; }
    if (S.bank < r.cost) { toast(`${r.cost - S.bank} ${U()} to go.`); return; }
    sheet(`<div class="sheet-head"><span></span>${closeX}</div>
      <div class="redeem-emoji">${esc(r.emoji)}</div>
      <h2 class="center">Cash out “${esc(r.label)}”?</h2>
      <p class="center muted" style="margin-top:8px">${r.cost} ${U()} → you’ll have ${S.bank - r.cost} ${U()} left.</p>
      <div class="btn-stack"><button class="btn btn-primary btn-xl" data-action="confirm-redeem" data-id="${esc(r.id)}">Cash out ${r.cost} ${U()}</button>
      <button class="btn btn-xl" data-action="close-sheet">Not now</button></div>`);
  }
  function confirmRedeem(id) {
    const r = S.settings.rewards.find((x) => x.id === id);
    if (!r || !isFriday(now()) || S.bank < r.cost) { closeSheet(); return; }
    S.bank -= r.cost;
    S.redemptions.unshift({ at: now(), id: r.id, emoji: r.emoji, label: r.label, cost: r.cost });
    save();
    render();
    sheet(`<div class="redeem-emoji" style="margin-top:12px">🎉</div>
      <h2 class="center">Enjoy it — you earned it</h2>
      <p class="center muted" style="margin-top:8px">${esc(r.emoji)} ${esc(r.label)} is all yours. ${S.bank} ${U()} left in the bank.</p>
      <div class="btn-stack"><button class="btn btn-primary btn-xl" data-action="close-sheet">Done</button></div>`);
    confetti();
    chime('win');
    buzz([40, 50, 90]);
  }

  /* ---------- Actions: settings ---------- */
  async function toggleSetting(key, el) {
    if (key === 'sound') {
      S.settings.sound = !S.settings.sound;
      save();
      el.setAttribute('aria-checked', String(S.settings.sound));
      if (S.settings.sound) chime('good');
      return;
    }
    if (key === 'alerts' && NATIVE) {
      if (nativeAlertsOn()) {
        S.settings.alerts = false;
        save();
        el.setAttribute('aria-checked', 'false');
        queueNativeSync(true);
        toast('Reminders off');
        return;
      }
      nativePerm = await NATIVE.requestPermission();
      if (nativePerm !== 'granted') {
        toast('Notifications are blocked — allow them in Android Settings → Apps → Sunup.', { ms: 5000 });
        render();
        return;
      }
      S.settings.alerts = true;
      save();
      render();
      queueNativeSync(true);
      toast('Reminders are on ✓');
      return;
    }
    if (key === 'alerts') {
      if (S.settings.alerts) { S.settings.alerts = false; save(); el.setAttribute('aria-checked', 'false'); return; }
      if (!('Notification' in window)) {
        toast(isIOS() && !isStandalone() ? 'On iPhone, add Sunup to your Home Screen first, then switch this on there.' : 'This browser doesn’t support notifications.', { ms: 5000 });
        return;
      }
      let perm = Notification.permission;
      if (perm === 'default') { try { perm = await Notification.requestPermission(); } catch (e) { perm = 'denied'; } }
      if (perm !== 'granted') { toast('Notifications are blocked — allow them for Sunup in your phone’s settings.', { ms: 5000 }); return; }
      S.settings.alerts = true;
      save();
      el.setAttribute('aria-checked', 'true');
      sysNotify('Notifications are on ✓', 'Sunup will nudge you while your morning routine is running.', true);
    }
  }
  function addTask() {
    if (S.settings.tasks.length >= 12) { toast('That’s plenty of steps!'); return; }
    const t = { id: uid(), emoji: '✨', label: 'New step' };
    S.settings.tasks.push(t);
    save();
    render();
    const inp = $(`input[data-task="${t.id}"][data-prop="label"]`);
    if (inp) { inp.focus(); inp.select(); }
  }
  function delTask(id) {
    const a = S.settings.tasks, i = a.findIndex((t) => t.id === id);
    if (i < 0) return;
    const [t] = a.splice(i, 1);
    save();
    render();
    toast(`Removed “${esc(t.label)}”`, { undo: () => { a.splice(i, 0, t); save(); render(); } });
  }
  function moveTask(id, dir) {
    const a = S.settings.tasks, i = a.findIndex((t) => t.id === id), j = i + dir;
    if (i < 0 || j < 0 || j >= a.length) return;
    [a[i], a[j]] = [a[j], a[i]];
    save();
    render();
  }
  function addReward() {
    if (S.settings.rewards.length >= 12) { toast('That’s a well-stocked store!'); return; }
    const r = { id: uid(), emoji: '🎁', label: 'New reward', cost: 30 };
    S.settings.rewards.push(r);
    save();
    render();
    const inp = $(`input[data-reward="${r.id}"][data-prop="label"]`);
    if (inp) { inp.focus(); inp.select(); }
  }
  function delReward(id) {
    const a = S.settings.rewards, i = a.findIndex((r) => r.id === id);
    if (i < 0) return;
    const [r] = a.splice(i, 1);
    save();
    render();
    toast(`Removed “${esc(r.label)}”`, { undo: () => { a.splice(i, 0, r); save(); render(); } });
  }
  function onFieldChange(el) {
    const f = el.dataset.field;
    if (f === 'wakeTime' || f === 'checkinTime') {
      if (!validHHMM(el.value)) return;
      S.settings[f] = el.value;
      save();
      const box = $('#cal-btns');
      if (box) box.innerHTML = calButtons();
      const sum = $('#remind-summary');
      if (sum) sum.textContent = remindersSummary();
      queueNativeSync();
      toast(f === 'wakeTime' ? `Weekday alarm set to ${fmtHHMM(el.value)}` : `Friday reminder at ${fmtHHMM(el.value)}`);
    } else if (f === 'name') {
      S.settings.name = el.value.trim().slice(0, 24);
      save();
    }
  }
  function onItemChange(el, list, id) {
    const item = list.find((x) => x.id === id);
    if (!item) return;
    const prop = el.dataset.prop;
    if (prop === 'label') {
      const v = el.value.trim();
      if (!v) { el.value = item.label; return; }
      item.label = v.slice(0, 48);
    } else if (prop === 'emoji') {
      item.emoji = firstGrapheme(el.value) || '✨';
      el.value = item.emoji;
    } else if (prop === 'cost') {
      const n = Math.round(Number(el.value));
      if (!(n >= 1)) { el.value = item.cost; return; }
      item.cost = Math.min(9999, n);
      el.value = item.cost;
    }
    save();
  }
  function downloadBlob(blob, name) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = name;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 5000);
  }
  function downloadCal(kind) {
    const hhmm = kind === 'wake' ? S.settings.wakeTime : S.settings.checkinTime;
    const ics = SunupICS.build(kind, hhmm, location.origin + location.pathname);
    downloadBlob(new Blob([ics], { type: 'text/calendar;charset=utf-8' }), `sunup-${kind}.ics`);
  }
  function exportData() {
    const name = `sunup-backup-${keyOf(now())}.json`, json = JSON.stringify(S, null, 2);
    if (NATIVE) {
      NATIVE.shareFile(name, json).catch(() => toast('Couldn’t open the share sheet.'));
      return;
    }
    downloadBlob(new Blob([json], { type: 'application/json' }), name);
    toast('Backup saved ✓');
  }
  function importData() {
    const inp = document.createElement('input');
    inp.type = 'file';
    inp.accept = 'application/json,.json';
    inp.addEventListener('change', async () => {
      const f = inp.files && inp.files[0];
      if (!f) return;
      try {
        const data = JSON.parse(await f.text());
        if (!data || typeof data !== 'object' || !data.settings || !data.days) throw new Error('not a backup');
        S = normalize(data);
        S.onboarded = true;
        save();
        render();
        toast('Backup restored ✓');
      } catch (e) {
        toast('That file isn’t a Sunup backup.');
      }
    });
    inp.click();
  }
  function confirmReset() {
    sheet(`<div class="sheet-head"><h2>Erase everything?</h2>${closeX}</div>
      <p class="muted">This deletes your ${U()}, history and settings on this device. Back up first if you might want them later.</p>
      <div class="btn-stack"><button class="btn btn-danger btn-xl" data-action="do-reset">Erase everything</button>
      <button class="btn btn-xl" data-action="close-sheet">Cancel</button></div>`);
  }
  function doReset() {
    S = fresh();
    save();
    closeSheet();
    go('today');
    setTimeout(showOnboarding, 380);
  }

  /* ---------- First run ---------- */
  function showOnboarding() {
    sheet(`<div class="onb">
      <img class="onb-logo" src="icons/icon.svg" alt="">
      <h2>Welcome to Sunup</h2>
      <p class="muted" style="margin-top:4px">Your weekday mornings, turned into a game.</p>
      <ol class="onb-steps">
        <li><span>⏰</span><div><b>Get up fast</b><small>Up within 5 min of your alarm = +10 XP · within 10 = +5 · later = +1.</small></div></li>
        <li><span>✅</span><div><b>Keep moving</b><small>Hair, face, food. Stationary 10+ min before you’re done = −5.</small></div></li>
        <li><span>🎁</span><div><b>Cash out on Fridays</b><small>Check in, bank your XP, spend it in the store. XP carries over.</small></div></li>
      </ol>
      <label class="onb-time"><span>Your weekday alarm</span><input type="time" id="onb-wake" value="${S.settings.wakeTime}"></label>
      <button class="btn btn-primary btn-xl" data-action="finish-onboarding">Let’s go</button>
    </div>`, { dismissable: false });
  }
  function finishOnboarding() {
    const v = $('#onb-wake') && $('#onb-wake').value;
    if (validHHMM(v)) S.settings.wakeTime = v;
    S.onboarded = true;
    save();
    closeSheet();
    render();
    unlockAudio();
    if (NATIVE) {
      // Ask once, right after setting the alarm time — that's when it makes sense.
      NATIVE.requestPermission().then((p) => {
        nativePerm = p;
        if (p === 'granted') { S.settings.alerts = true; save(); toast('Reminders are on ✓ — you’ll get a nudge at your alarm time.', { ms: 4500 }); }
        softRender();
        queueNativeSync(true);
      });
    }
  }

  /* ---------- Wiring ---------- */
  const ACTIONS = {
    tab: (el) => go(el.dataset.tab),
    'get-up': getUp,
    step: (el) => toggleStep(el.dataset.id),
    'undo-up': () => { closeSheet(); undoUp(); },
    'waive-penalty': waivePenalty,
    'change-target': openChangeTarget,
    'save-target': saveTarget,
    'open-checkin': openCheckin,
    mood: (el) => { moodPick = Number(el.dataset.i); $$('.mood-btn').forEach((b) => b.classList.toggle('is-on', b === el)); },
    collect,
    redeem: (el) => openRedeem(el.dataset.id),
    'confirm-redeem': (el) => confirmRedeem(el.dataset.id),
    'close-sheet': closeSheet,
    theme: (el) => { S.settings.theme = el.dataset.id; save(); render(); },
    toggle: (el) => toggleSetting(el.dataset.key, el),
    unit: (el) => { S.settings.unit = el.dataset.unit; save(); render(); },
    'add-task': addTask,
    'del-task': (el) => delTask(el.dataset.id),
    'move-task': (el) => moveTask(el.dataset.id, Number(el.dataset.dir)),
    'add-reward': addReward,
    'del-reward': (el) => delReward(el.dataset.id),
    cal: (el) => downloadCal(el.dataset.kind),
    export: exportData,
    import: importData,
    reset: confirmReset,
    'do-reset': doReset,
    'finish-onboarding': finishOnboarding,
  };
  document.addEventListener('click', (e) => {
    const el = e.target.closest('[data-action]');
    if (!el || el.disabled) return;
    const fn = ACTIONS[el.dataset.action];
    if (fn) { e.preventDefault(); fn(el, e); }
  });
  document.addEventListener('change', (e) => {
    const el = e.target;
    if (el.dataset.field) onFieldChange(el);
    else if (el.dataset.task) onItemChange(el, S.settings.tasks, el.dataset.task);
    else if (el.dataset.reward) onItemChange(el, S.settings.rewards, el.dataset.reward);
  });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && $('#sheet-root').classList.contains('open') && $('#sheet-root').dataset.dismissable) closeSheet();
    if (e.key === 'Enter' && e.target.matches('input[type="text"], input[type="number"]')) e.target.blur();
  });
  document.addEventListener('pointerdown', unlockAudio, { once: true });
  document.addEventListener('visibilitychange', () => { if (!document.hidden) { lastKey = keyOf(now()); softRender(); } });
  window.addEventListener('storage', (e) => { if (e.key === KEY) { S = load(); softRender(); } });

  if (NATIVE) {
    NATIVE.permission().then((p) => { nativePerm = p; softRender(); queueNativeSync(true); });
    NATIVE.onResume(() => {
      lastKey = keyOf(now());
      NATIVE.permission().then((p) => { nativePerm = p; softRender(); queueNativeSync(true); });
    });
    // Android back: close a sheet → go to Today → leave the app.
    NATIVE.onBack(() => {
      const root = $('#sheet-root');
      if (root.classList.contains('open')) { if (root.dataset.dismissable) closeSheet(); return; }
      if (tab !== 'today') { go('today'); return; }
      NATIVE.exit();
    });
  } else if ('serviceWorker' in navigator && location.protocol !== 'file:') {
    navigator.serviceWorker.register('sw.js').catch(() => { /* offline support is optional */ });
  }
  if (navigator.storage && navigator.storage.persist) navigator.storage.persist().catch(() => {});

  render();
  animateIn();
  setInterval(tick, 1000);
  if (!S.onboarded) setTimeout(showOnboarding, 250);
})();
