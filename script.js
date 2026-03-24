'use strict';

/* ══════════════════════════════════════════════════════
   FIT IS FUN — JS v3
   Canvas BG · Typewriter · Navbar · Reveal · Counters
══════════════════════════════════════════════════════ */

/* ── 0. TYPEWRITER ───────────────────────────────────── */
(function Typewriter() {
  const el = document.getElementById('heroTypewriter');
  if (!el) return;

  const words = [
    'Training · Ernährung · Entspannung',
    'EMS-Training in Scheibbs',
    'Massagepraxis Am Ginselberg',
    'Persönlich · Individuell · Wirksam',
  ];
  const speed        = 55;
  const deleteSpeed  = 28;
  const pauseAfter   = 2200;

  let wordIdx  = 0;
  let charIdx  = 0;
  let deleting = false;
  let timer;

  function tick() {
    const word = words[wordIdx];

    if (!deleting) {
      charIdx++;
      el.textContent = word.substring(0, charIdx);
      if (charIdx === word.length) {
        timer = setTimeout(() => { deleting = true; tick(); }, pauseAfter);
        return;
      }
    } else {
      charIdx--;
      el.textContent = word.substring(0, charIdx);
      if (charIdx === 0) {
        deleting = false;
        wordIdx  = (wordIdx + 1) % words.length;
      }
    }
    timer = setTimeout(tick, deleting ? deleteSpeed : speed);
  }

  tick();
})();

/* ── 1. AURORA SHADER HERO BACKGROUND (Three.js) ──── */
(function AuroraShader() {
  const container = document.getElementById('heroShader');
  if (!container || typeof THREE === 'undefined') return;

  const scene    = new THREE.Scene();
  const camera   = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setSize(window.innerWidth, window.innerHeight);
  container.appendChild(renderer.domElement);

  const vertShader = `void main(){gl_Position=vec4(position,1.0);}`;
  const fragShader = `
    uniform float iTime;
    uniform vec2  iResolution;
    #define NUM_OCTAVES 3

    float rand(vec2 n){return fract(sin(dot(n,vec2(12.9898,4.1414)))*43758.5453);}
    float noise(vec2 p){
      vec2 ip=floor(p),u=fract(p);
      u=u*u*(3.0-2.0*u);
      return mix(mix(rand(ip),rand(ip+vec2(1,0)),u.x),mix(rand(ip+vec2(0,1)),rand(ip+vec2(1,1)),u.x),u.y);
    }
    float fbm(vec2 x){
      float v=0.0,a=0.3;
      vec2 sh=vec2(100);
      mat2 rot=mat2(cos(0.5),sin(0.5),-sin(0.5),cos(0.5));
      for(int i=0;i<NUM_OCTAVES;i++){v+=a*noise(x);x=rot*x*2.0+sh;a*=0.4;}
      return v;
    }
    void main(){
      vec2 shake=vec2(sin(iTime*1.2)*0.005,cos(iTime*2.1)*0.005);
      vec2 p=((gl_FragCoord.xy+shake*iResolution.xy)-iResolution.xy*0.5)/iResolution.y*mat2(6.0,-4.0,4.0,6.0);
      vec2 v;
      vec4 o=vec4(0.0);
      float f=2.0+fbm(p+vec2(iTime*5.0,0.0))*0.5;
      for(float i=0.0;i<35.0;i++){
        v=p+cos(i*i+(iTime+p.x*0.08)*0.025+i*vec2(13.0,11.0))*3.5+vec2(sin(iTime*3.0+i)*0.003,cos(iTime*3.5-i)*0.003);
        float tailNoise=fbm(v+vec2(iTime*0.5,i))*0.3*(1.0-(i/35.0));
        vec4 col=vec4(
          0.1+0.3*sin(i*0.2+iTime*0.4),
          0.3+0.5*cos(i*0.3+iTime*0.5),
          0.7+0.3*sin(i*0.4+iTime*0.3),
          1.0
        );
        float thin=smoothstep(0.0,1.0,i/35.0)*0.6;
        o+=col*exp(sin(i*i+iTime*0.8))/length(max(v,vec2(v.x*f*0.015,v.y*1.5)))*(1.0+tailNoise*0.8)*thin;
      }
      o=tanh(pow(o/60.0,vec4(1.3)));
      gl_FragColor=o*2.2;
    }
  `;

  const material = new THREE.ShaderMaterial({
    uniforms: {
      iTime:       { value: 0 },
      iResolution: { value: new THREE.Vector2(window.innerWidth, window.innerHeight) }
    },
    vertexShader:   vertShader,
    fragmentShader: fragShader,
    transparent:    true
  });

  const mesh = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), material);
  scene.add(mesh);

  let frameId;
  (function animate() {
    material.uniforms.iTime.value += 0.016;
    renderer.render(scene, camera);
    frameId = requestAnimationFrame(animate);
  })();

  window.addEventListener('resize', () => {
    renderer.setSize(window.innerWidth, window.innerHeight);
    material.uniforms.iResolution.value.set(window.innerWidth, window.innerHeight);
  });
})();

/* ── 2. CANVAS: Particle + Gradient Orb Background ── */
(function CanvasBG() {
  const canvas = document.getElementById('bgCanvas');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');

  const PINK   = [233, 30, 140];
  const VIOLET = [91,  61, 245];
  const COLS   = [PINK, VIOLET, [196, 21, 122], [255, 79, 174]];

  let W, H, particles, orbs;

  function resize() {
    W = canvas.width  = window.innerWidth;
    H = canvas.height = window.innerHeight;
  }

  function makeParticle() {
    const [r, g, b] = COLS[Math.floor(Math.random() * COLS.length)];
    const angle = Math.random() * Math.PI * 2;
    const speed = 0.12 + Math.random() * 0.2;
    return {
      x: Math.random() * W, y: Math.random() * H,
      r: 1.5 + Math.random() * 3.5,
      vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed,
      alpha: 0.15 + Math.random() * 0.35,
      fade: Math.random() > .5 ? 1 : -1,
      fadeSpd: .002 + Math.random() * .003,
      col: [r, g, b]
    };
  }

  function makeOrb() {
    const [r, g, b] = COLS[Math.floor(Math.random() * COLS.length)];
    const angle = Math.random() * Math.PI * 2;
    const spd   = 0.08 + Math.random() * 0.14;
    return {
      x: Math.random() * W, y: Math.random() * H,
      radius: 160 + Math.random() * 260,
      vx: Math.cos(angle) * spd, vy: Math.sin(angle) * spd,
      alpha: 0.03 + Math.random() * 0.05,
      fade: Math.random() > .5 ? 1 : -1,
      fadeSpd: 0.0002 + Math.random() * 0.0003,
      col: [r, g, b],
      wobble: Math.random() * Math.PI * 2,
      wobbleSpd: .002 + Math.random() * .003,
    };
  }

  function init() {
    particles = Array.from({ length: 40 }, makeParticle);
    orbs      = Array.from({ length: 10 }, makeOrb);
  }

  function updateWrap(obj, pad) {
    if (obj.x < -pad)    obj.x = W + pad;
    if (obj.x > W + pad) obj.x = -pad;
    if (obj.y < -pad)    obj.y = H + pad;
    if (obj.y > H + pad) obj.y = -pad;
  }

  function drawParticle(p) {
    ctx.save();
    ctx.globalAlpha = p.alpha;
    ctx.fillStyle = `rgb(${p.col.join(',')})`;
    ctx.beginPath();
    ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  function drawOrb(o) {
    const sx = 1 + Math.sin(o.wobble) * .08;
    const sy = 1 + Math.cos(o.wobble * .7) * .06;
    ctx.save();
    ctx.translate(o.x, o.y);
    ctx.scale(sx, sy);
    ctx.translate(-o.x, -o.y);
    const g = ctx.createRadialGradient(o.x, o.y, 0, o.x, o.y, o.radius);
    g.addColorStop(0,   `rgba(${o.col.join(',')},${o.alpha})`);
    g.addColorStop(.5,  `rgba(${o.col.join(',')},${o.alpha * .4})`);
    g.addColorStop(1,   `rgba(${o.col.join(',')},0)`);
    ctx.beginPath();
    ctx.arc(o.x, o.y, o.radius, 0, Math.PI * 2);
    ctx.fillStyle = g;
    ctx.fill();
    ctx.restore();
  }

  function tick() {
    ctx.clearRect(0, 0, W, H);
    orbs.forEach(o => {
      o.x += o.vx; o.y += o.vy;
      o.wobble += o.wobbleSpd;
      o.alpha += o.fade * o.fadeSpd;
      if (o.alpha > .09 || o.alpha < .02) o.fade *= -1;
      updateWrap(o, o.radius);
      drawOrb(o);
    });
    particles.forEach(p => {
      p.x += p.vx; p.y += p.vy;
      p.alpha += p.fade * p.fadeSpd;
      if (p.alpha > .55 || p.alpha < .08) p.fade *= -1;
      updateWrap(p, p.r + 2);
      drawParticle(p);
    });
    requestAnimationFrame(tick);
  }

  resize(); init(); tick();
  let dbt;
  window.addEventListener('resize', () => {
    clearTimeout(dbt); dbt = setTimeout(() => { resize(); init(); }, 150);
  }, { passive: true });
}());


/* ── 2. NAVBAR scroll ─────────────────────────────── */
const nav = document.getElementById('nav');
window.addEventListener('scroll', () => {
  nav.classList.toggle('scrolled', window.scrollY > 50);
}, { passive: true });


/* ── 3. MOBILE MENU ───────────────────────────────── */
const burger   = document.getElementById('burger');
const mob      = document.getElementById('mob');
const mobClose = document.getElementById('mobClose');
const mobBd    = document.getElementById('mobBd');

function openMob() {
  mob.classList.add('open'); mob.setAttribute('aria-hidden','false');
  burger.setAttribute('aria-expanded','true');
  document.body.style.overflow = 'hidden'; mobBd.style.display = 'block';
}
function closeMob() {
  mob.classList.remove('open'); mob.setAttribute('aria-hidden','true');
  burger.setAttribute('aria-expanded','false');
  document.body.style.overflow = ''; mobBd.style.display = 'none';
}
if (burger)   burger.addEventListener('click', openMob);
if (mobClose) mobClose.addEventListener('click', closeMob);
if (mobBd)    mobBd.addEventListener('click', closeMob);
mob && mob.querySelectorAll('.mob__link').forEach(l => l.addEventListener('click', closeMob));


/* ── 4. SMOOTH SCROLL ─────────────────────────────── */
document.querySelectorAll('a[href^="#"]').forEach(a => {
  a.addEventListener('click', e => {
    const id = a.getAttribute('href');
    if (id === '#') return;
    const target = document.querySelector(id);
    if (!target) return;
    e.preventDefault();
    const offset = (nav ? nav.offsetHeight : 74) + 12;
    window.scrollTo({ top: target.getBoundingClientRect().top + window.scrollY - offset, behavior: 'smooth' });
  });
});


/* ── 5. REVEAL ON SCROLL ──────────────────────────── */
const revealObs = new IntersectionObserver(entries => {
  entries.forEach(entry => {
    if (!entry.isIntersecting) return;
    const el    = entry.target;
    const delay = parseFloat(el.dataset.delay || 0);
    setTimeout(() => el.classList.add('in'), delay * 1000);
    revealObs.unobserve(el);
  });
}, { threshold: 0.05, rootMargin: '0px 0px 0px 0px' });

document.querySelectorAll('[data-reveal],[data-reveal-right]').forEach(el => {
  const rect = el.getBoundingClientRect();
  if (rect.top < window.innerHeight) {
    el.classList.add('in');
  } else {
    revealObs.observe(el);
  }
});


/* ── 6. ANIMATED COUNTERS ─────────────────────────── */
function animCount(el, to, dur = 1400) {
  const start = performance.now();
  (function step(now) {
    const t = Math.min((now - start) / dur, 1);
    el.textContent = Math.round(to * (1 - Math.pow(1 - t, 3)));
    if (t < 1) requestAnimationFrame(step);
  }(start));
}
const countObs = new IntersectionObserver(entries => {
  entries.forEach(entry => {
    if (!entry.isIntersecting) return;
    animCount(entry.target, parseInt(entry.target.dataset.to, 10));
    countObs.unobserve(entry.target);
  });
}, { threshold: 0.8 });
document.querySelectorAll('.count[data-to]').forEach(el => countObs.observe(el));


/* ── 7. ACTIVE NAV ────────────────────────────────── */
const navLinks = document.querySelectorAll('.nav__link');
const secObs   = new IntersectionObserver(entries => {
  entries.forEach(entry => {
    if (!entry.isIntersecting) return;
    navLinks.forEach(a => {
      a.style.color = a.getAttribute('href') === `#${entry.target.id}` ? 'var(--pink)' : '';
    });
  });
}, { threshold: 0.4 });
document.querySelectorAll('section[id]').forEach(s => secObs.observe(s));


/* ── 8. PARALLAX on hero badges ──────────────────── */
const heroVisual = document.querySelector('.hero__visual');
let rafPending   = false;
window.addEventListener('scroll', () => {
  if (rafPending || !heroVisual) return;
  rafPending = true;
  requestAnimationFrame(() => {
    const y = window.scrollY * 0.04;
    const badgeEms = document.querySelector('.hero__badge--ems');
    const badgeCrt = document.querySelector('.hero__badge--cert');
    if (badgeEms) badgeEms.style.transform = `translateY(${-y}px)`;
    if (badgeCrt) badgeCrt.style.transform = `translateX(0) translateY(${y * 0.6}px)`;
    rafPending = false;
  });
}, { passive: true });


/* ── 9. LOGO MOUSEMOVE tilt on hero ──────────────── */
const heroLogo = document.getElementById('heroLogo');
if (heroLogo) {
  document.addEventListener('mousemove', e => {
    const rect = heroLogo.getBoundingClientRect();
    const cx   = rect.left + rect.width / 2;
    const cy   = rect.top  + rect.height / 2;
    const dx   = (e.clientX - cx) / window.innerWidth;
    const dy   = (e.clientY - cy) / window.innerHeight;
    heroLogo.style.transform = `rotate(${dx * 12}deg) scale(1.05) translateY(${dy * -4}px)`;
  });
  document.addEventListener('mouseleave', () => {
    heroLogo.style.transform = '';
  });
}


/* ── 10. CONTACT FORM ─────────────────────────────── */
const contactForm = document.getElementById('contactForm');
if (contactForm) {
  contactForm.addEventListener('submit', e => {
    e.preventDefault();
    const btn = contactForm.querySelector('button[type="submit"]');
    btn.disabled = true; btn.style.opacity = '.7';
    btn.innerHTML = '<span>Wird gesendet …</span>';
    setTimeout(() => {
      const wrap = contactForm.closest('.contact__form-wrap');
      if (!wrap) return;
      wrap.innerHTML = `
        <div class="form-success">
          <div class="form-success__ic">
            <svg viewBox="0 0 24 24" fill="none" width="28" height="28">
              <path d="M5 12l5 5L19 7" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </div>
          <h3>Vielen Dank!</h3>
          <p>Brigitte meldet sich innerhalb von 24 Stunden bei dir — versprochen!</p>
        </div>`;
    }, 900);
  });
}
