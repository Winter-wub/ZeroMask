// shell.js — สร้าง <webview> ฝัง Tinder ลงในเปลือก IG และต่อปุ่ม/ท่าทางแบบฟีด IG
(function () {
  const cfg = window.maskConfig;
  if (!cfg) return;
  const feed = cfg.feed || { enabled: false };

  // ใช้ brand ที่ตั้งใน config มาแสดงบน header (ดีฟอลต์ Instagram)
  const brandEl = document.getElementById('brand');
  if (brandEl && cfg.brand) brandEl.textContent = cfg.brand;

  // ซ่อน header / bottom nav ตาม config.chrome
  if (cfg.chrome && cfg.chrome.header === false) {
    document.getElementById('header').classList.add('hidden');
  }
  if (!cfg.chrome || cfg.chrome.bottomNav === false) {
    document.getElementById('nav').classList.add('hidden');
  }

  // ปิดโหมดฟีด → ซ่อนหัวโพสต์และแถวปุ่ม เหลือ webview เต็ม ๆ เหมือนเดิม
  if (!feed.enabled) {
    document.getElementById('post-head').classList.add('hidden');
    document.getElementById('post-actions').classList.add('hidden');
  }

  // สร้าง webview ที่ฝัง Tinder (อยู่ในช่อง "รูป" ของโพสต์)
  const wv = document.createElement('webview');
  wv.setAttribute('src', cfg.url);
  wv.setAttribute('partition', cfg.partition);
  wv.setAttribute('useragent', cfg.userAgent);
  wv.setAttribute('preload', cfg.geoPreload);
  wv.setAttribute('allowpopups', '');
  // ต้องปิด contextIsolation ของ webview เฉพาะตอน spoof พิกัด GPS
  let webprefs = 'sandbox=no';
  if (cfg.hasLocation) webprefs += ', contextIsolation=no';
  wv.setAttribute('webpreferences', webprefs);

  document.getElementById('media').appendChild(wv);

  const URLS = {
    recs: cfg.url,
    matches: 'https://tinder.com/app/matches',
    explore: 'https://tinder.com/app/explore',
    likesYou: 'https://tinder.com/app/gold-home',
    profile: 'https://tinder.com/app/profile',
  };

  // ── สั่งกดปุ่มจริงของ Tinder (Like/Nope/Super Like) ที่ถูกซ่อนไว้
  // หมายเหตุ: เลย์เอาต์ mobile ของ Tinder (จอแคบ) ไม่รองรับคีย์ลัด
  // เลยใช้วิธี .click() ปุ่ม gamepad แทน → 1 คลิกของผู้ใช้ = 1 แอ็กชัน
  function clickTinder(label) {
    const js = `(() => {
      const btn = Array.from(document.querySelectorAll('button.gamepad-button'))
        .find((b) => (b.textContent || '').trim() === ${JSON.stringify(label)});
      if (!btn) return false;
      btn.click();
      return true;
    })()`;
    try { wv.executeJavaScript(js).catch(() => {}); } catch (_) {}
  }

  // ── แอนิเมชันแบบ IG ──
  const media = document.getElementById('media');
  const burst = document.getElementById('heart-burst');
  const actLike = document.getElementById('act-like');

  function heartBurst() {
    if (!burst) return;
    burst.classList.remove('pop');
    void burst.offsetWidth; // รีสตาร์ตแอนิเมชัน
    burst.classList.add('pop');
    if (actLike) {
      actLike.classList.add('liked');
      setTimeout(() => actLike.classList.remove('liked'), 900);
    }
  }

  function slideAway() {
    if (!media) return;
    media.classList.add('slide-away');
    setTimeout(() => media.classList.remove('slide-away'), 400);
  }

  // ── แอ็กชันหลัก ──
  function like(withBurst) {
    if (withBurst) heartBurst();
    clickTinder('Like');
  }
  function pass() {
    slideAway();
    clickTinder('Nope');
  }
  function superLike() {
    heartBurst();
    clickTinder('Super Like');
  }
  function goTo(url) {
    try { wv.loadURL(url); } catch (_) {}
  }

  // ── รับ gesture ที่ดักไว้ในหน้า Tinder (จาก preload.js) ──
  wv.addEventListener('ipc-message', (e) => {
    if (e.channel === 'mask:double-tap') like(true);
    else if (e.channel === 'mask:scroll-next') pass();
    else if (e.channel === 'mask:profile') {
      const el = document.getElementById('post-user');
      if (el && e.args[0]) el.textContent = e.args[0];
    }
  });

  // ── ลอก UI ของ Tinder ออกให้เหลือแต่รูปการ์ด (selector ตรวจกับ DOM จริงแล้ว)
  wv.addEventListener('dom-ready', () => {
    let css = `
      /* ซ่อนแบนเนอร์ชวนโหลดแอป */
      a[href*="app-store"], a[href*="play.google"] { display: none !important; }
    `;
    if (feed.enabled) {
      css += `
        /* แถบแท็บล่างของ Tinder = nav เดียวที่มีลิงก์ /app/recs → ซ่อนทุกหน้า
           (ปุ่มของเปลือกพาไปครบทุกหน้าแทน) */
        nav:has(a[href="/app/recs"]) { display: none !important; }
        /* แถบบนที่มีโลโก้ Tinder (หน้า recs/matches/explore) ไม่มีลิงก์ข้างในเลย
           ต่างจาก header ของหน้าแชทที่มีลิงก์ Back → ซ่อนเฉพาะแบบไม่มีลิงก์ */
        nav:not(:has(a)) { display: none !important; }
        /* คืนพื้นที่ที่เคยกันไว้ให้แถบล่าง (ซ่อนแล้วทุกหน้า) */
        main.mobile { padding-bottom: 0 !important; }
        /* หน้า recs: คืนพื้นที่แถบบนด้วย ให้รูปการ์ดเต็มจอ */
        main:has(.recsCardboard__cards) { padding-top: 0 !important; }
      `;
    }
    if (feed.hideTinderButtons) {
      css += `
        /* ซ่อนแถวปุ่ม Rewind/Nope/Super Like/Like (ปุ่มยังอยู่ใน DOM — เปลือกสั่ง .click() ได้) */
        .gamepad-button-wrapper { display: none !important; }
      `;
    }
    try { wv.insertCSS(css); } catch (_) {}
  });

  // ── ต่อปุ่มแถวใต้โพสต์ (❤️ Like / 💬 แชท / ✈️ Super Like / 🔖 ข้าม) ──
  const on = (id, fn) => {
    const el = document.getElementById(id);
    if (el) el.addEventListener('click', fn);
  };
  on('act-like', () => like(true));
  on('act-chat', () => goTo(URLS.matches));
  on('act-super', superLike);
  on('act-pass', pass);

  // ปุ่ม header/nav → หน้าต่าง ๆ ของ Tinder (ครบทุกฟังก์ชันเดิม):
  //   🏠 Home = recs, 🔍 Search = Explore, ❤️ (แถบล่าง) = Likes You,
  //   ⭕ Profile = โปรไฟล์เรา, 💬 Messages (header) = แชท, ❤️ (header) = recs
  const byTitle = (root, title) => document.querySelector(`${root} button[title="${title}"]`);
  on('nav-home', () => goTo(URLS.recs));
  on('btn-reload', () => goTo(URLS.recs));
  const wire = (btn, fn) => { if (btn) btn.addEventListener('click', fn); };
  wire(byTitle('#header .actions', 'Messages'), () => goTo(URLS.matches));
  wire(byTitle('#nav', 'Search'), () => goTo(URLS.explore));
  wire(byTitle('#nav', 'Reels'), () => goTo(URLS.recs));
  wire(byTitle('#nav', 'Likes'), () => goTo(URLS.likesYou));
  wire(byTitle('#nav', 'Profile'), () => goTo(URLS.profile));
})();
