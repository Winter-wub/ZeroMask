import Foundation

// JS/CSS ที่ฉีดเข้า tinder.com — พอร์ตมาจาก src/preload.js + src/shell.js ของเวอร์ชัน desktop
// (selector ชุดเดียวกับที่ตรวจกับ DOM จริงแล้ว: nav แบรนด์ Tinder, gamepad, itemprop)
enum MaskScripts {

    /// สคริปต์หลัก ฉีดตอน document end (main frame เท่านั้น)
    static let userScript = #"""
    (function () {
      if (!location.hostname.endsWith('tinder.com')) return;

      // ── CSS ลอก UI ของ Tinder ออก ──
      var css = [
        // แบนเนอร์ชวนโหลดแอป
        'a[href*="app-store"], a[href*="play.google"] { display: none !important; }',
        // แถบแท็บล่างของ Tinder = nav เดียวที่มีลิงก์ /app/recs
        'nav:has(a[href="/app/recs"]) { display: none !important; }',
        // แถบบนที่มีโลโก้ Tinder ไม่มีลิงก์ข้างใน (header หน้าแชทมีลิงก์ Back → รอด)
        'nav:not(:has(a)) { display: none !important; }',
        'main.mobile { padding-bottom: 0 !important; }',
        'main:has(.recsCardboard__cards) { padding-top: 0 !important; }',
        // แถวปุ่ม Rewind/Nope/Like (ยังอยู่ใน DOM ให้ native สั่ง .click() ได้)
        '.gamepad-button-wrapper { display: none !important; }',
      ].join('\n');
      var tag = document.createElement('style');
      tag.id = 'mask-detinder';
      tag.textContent = css;
      (document.head || document.documentElement).appendChild(tag);

      var send = function (type, payload) {
        try { window.webkit.messageHandlers.mask.postMessage({ type: type, payload: payload || '' }); } catch (e) {}
      };
      var onRecs = function () { return location.pathname.indexOf('/app/recs') === 0; };

      // ── ดับเบิลแท็ปรูป → Like ──
      var lastTap = 0, lastX = 0, lastY = 0;
      document.addEventListener('touchend', function (e) {
        if (!onRecs()) return;
        var t = e.changedTouches[0];
        if (!t) return;
        if (e.target.closest && e.target.closest('button, a, input, textarea, [contenteditable]')) return;
        var now = Date.now();
        if (now - lastTap < 300 && Math.abs(t.clientX - lastX) < 40 && Math.abs(t.clientY - lastY) < 40) {
          lastTap = 0;
          send('double-tap');
        } else {
          lastTap = now; lastX = t.clientX; lastY = t.clientY;
        }
      }, true);

      // ── ปัดลงแรง ๆ (เหมือนเลื่อนผ่านโพสต์ในฟีด) → ข้ามคนนี้ ──
      // ใช้ "ปัดลง" ไม่ใช่ "ปัดขึ้น" เพราะปัดขึ้นบน Tinder = Super Like จะชนกัน
      var sy = null, sx = 0, st = 0, coolUntil = 0;
      document.addEventListener('touchstart', function (e) {
        var t = e.touches[0];
        if (t) { sy = t.clientY; sx = t.clientX; st = Date.now(); }
      }, { passive: true, capture: true });
      document.addEventListener('touchend', function (e) {
        if (!onRecs() || sy === null) return;
        var t = e.changedTouches[0];
        if (!t) { sy = null; return; }
        var down = t.clientY - sy, dx = Math.abs(t.clientX - sx), dt = Date.now() - st;
        sy = null;
        var now = Date.now();
        if (now < coolUntil) return;
        if (down > 120 && dx < 80 && dt < 600) {
          coolUntil = now + 1400;
          send('scroll-next');
        }
      }, { passive: true, capture: true });

      // ── อ่านชื่อ+อายุจากการ์ดที่โชว์อยู่ (microdata itemprop) ──
      var lastName = '';
      setInterval(function () {
        if (!onRecs()) return;
        var el = document.elementFromPoint(Math.floor(innerWidth / 2), innerHeight - 90);
        while (el && el !== document.body && !(el.querySelector && el.querySelector('[itemprop="name"]'))) {
          el = el.parentElement;
        }
        if (!el || el === document.body) return;
        var n = el.querySelector('[itemprop="name"]');
        var a = el.querySelector('[itemprop="age"]');
        var name = n ? n.textContent.trim() : '';
        var age = a ? a.textContent.trim() : '';
        var label = name + (age ? ' · ' + age : '');
        if (name && label !== lastName) { lastName = label; send('profile', label); }
      }, 1000);
    })();
    """#

    /// สั่งกดปุ่มจริงของ Tinder ที่ซ่อนไว้ (Like / Nope / Super Like)
    static func clickGamepad(_ label: String) -> String {
        let quoted = "'" + label.replacingOccurrences(of: "'", with: "\\'") + "'"
        return """
        (function () {
          var btn = Array.prototype.slice.call(document.querySelectorAll('button.gamepad-button'))
            .filter(function (b) { return (b.textContent || '').trim() === \(quoted); })[0];
          if (btn) { btn.click(); return true; }
          return false;
        })();
        """
    }
}
