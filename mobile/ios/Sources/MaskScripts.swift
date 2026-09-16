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

      // ── ดึง Auth Token จาก localStorage เพื่อส่งให้ native สำหรับ background polling ──
      var lastExtractedToken = '';
      var checkToken = function () {
        try {
          var token = localStorage.getItem('TinderWeb/APIToken') ||
                      localStorage.getItem('TinderWeb-access-token') ||
                      localStorage.getItem('authToken');
          if (!token) {
            var root = localStorage.getItem('persist:root');
            if (root) {
              try {
                var parsedRoot = JSON.parse(root);
                if (parsedRoot.auth) {
                  var authObj = JSON.parse(parsedRoot.auth);
                  token = authObj.apiToken || authObj.token || authObj.authToken;
                }
              } catch (e) {}
            }
          }
          if (!token) {
            for (var i = 0; i < localStorage.length; i++) {
              var k = localStorage.key(i);
              var val = localStorage.getItem(k);
              if (val && val.length > 20) {
                var m = val.match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i);
                if (m) { token = m[0]; break; }
              }
            }
          }
          if (token && token !== lastExtractedToken) {
            lastExtractedToken = token;
            send('auth-token', token);
          }
        } catch (e) {}
      };
      checkToken();
      setInterval(checkToken, 3000);

      // ── ตรวจสอบ DOM สำหรับ Badge ตัวเลขแจ้งเตือนใน Tinder ──
      var lastDOMBadgeCount = 0;
      var checkTinderDOMBadges = function () {
        try {
          var badges = document.querySelectorAll('nav [aria-label*="unread"], nav [aria-label*="Unread"], nav [class*="badge"], [data-testid*="badge"]');
          var count = 0;
          for (var i = 0; i < badges.length; i++) {
            var txt = (badges[i].textContent || '').trim();
            var n = parseInt(txt, 10);
            if (!isNaN(n) && n > 0) count += n;
            else count += 1;
          }
          if (count !== lastDOMBadgeCount) {
            lastDOMBadgeCount = count;
            send('dom-badge', count);
          }
        } catch (e) {}
      };
      setInterval(checkTinderDOMBadges, 3000);
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

    /// สคริปต์ดักจับ Network (fetch + XHR) ฉีดตั้งแต่ document start เพื่อดึง Auth Token และ Response สด
    static let networkInterceptorScript = #"""
    (function () {
      if (window.__mask_network_hooked) return;
      window.__mask_network_hooked = true;

      var send = function (type, payload) {
        try {
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mask) {
            window.webkit.messageHandlers.mask.postMessage({ type: type, payload: payload || '' });
          }
        } catch (e) {}
      };

      // 1. ดัก window.fetch
      if (window.fetch) {
        var origFetch = window.fetch;
        window.fetch = function (input, init) {
          try {
            var url = (typeof input === 'string') ? input : (input && input.url) ? input.url : '';
            var token = null;

            // ดึง header จาก input (กรณีเป็น Request)
            if (input && typeof input === 'object' && input.headers && typeof input.headers.get === 'function') {
              token = input.headers.get('x-auth-token') || input.headers.get('X-Auth-Token');
            }

            // ดึง header จาก init.headers
            var headers = init && init.headers;
            if (headers) {
              if (typeof headers.get === 'function') {
                token = headers.get('X-Auth-Token') || headers.get('x-auth-token') || token;
              } else if (typeof headers === 'object') {
                if (Array.isArray(headers)) {
                  for (var h of headers) {
                    if (h[0] && h[0].toLowerCase() === 'x-auth-token') { token = h[1]; break; }
                  }
                } else {
                  token = headers['X-Auth-Token'] || headers['x-auth-token'] || headers['X-AUTH-TOKEN'] || token;
                }
              }
            }

            if (token) {
              send('auth-token', token);
            }
            if (url && (url.indexOf('/updates') !== -1 || url.indexOf('/meta') !== -1 || url.indexOf('/inbox') !== -1 || url.indexOf('/fast-match') !== -1)) {
              send('api-endpoint', url);
            }
          } catch (e) {}

          return origFetch.apply(this, arguments).then(function (response) {
            try {
              var u = (typeof input === 'string') ? input : (input && input.url) ? input.url : '';
              if (u && (u.indexOf('/updates') !== -1 || u.indexOf('/meta') !== -1 || u.indexOf('/inbox') !== -1 || u.indexOf('/fast-match') !== -1)) {
                var clone = response.clone();
                clone.json().then(function (json) {
                  send('api-data', { url: u, data: json });
                }).catch(function () {});
              }
            } catch (e) {}
            return response;
          });
        };
      }

      // 2. ดัก XMLHttpRequest
      if (window.XMLHttpRequest) {
        var origOpen = XMLHttpRequest.prototype.open;
        var origSetHeader = XMLHttpRequest.prototype.setRequestHeader;
        var origSend = XMLHttpRequest.prototype.send;

        XMLHttpRequest.prototype.open = function () {
          this._url = arguments[1];
          return origOpen.apply(this, arguments);
        };

        XMLHttpRequest.prototype.setRequestHeader = function (header, value) {
          try {
            if (header && header.toLowerCase() === 'x-auth-token' && value) {
              send('auth-token', value);
            }
          } catch (e) {}
          return origSetHeader.apply(this, arguments);
        };

        XMLHttpRequest.prototype.send = function () {
          var xhr = this;
          var u = xhr._url || '';
          if (u && (u.indexOf('/updates') !== -1 || u.indexOf('/meta') !== -1 || u.indexOf('/inbox') !== -1 || u.indexOf('/fast-match') !== -1)) {
            xhr.addEventListener('load', function () {
              try {
                var json = JSON.parse(xhr.responseText);
                send('api-data', { url: u, data: json });
              } catch (e) {}
            });
          }
          return origSend.apply(this, arguments);
        };
      }
    })();
    """#

    /// สคริปต์ฉีดเข้า instagram.com เพื่อดักจับ Session Cookies, Unread Direct Messages และ Badge
    static let instagramScript = #"""
    (function () {
      if (window.__mask_ig_hooked) return;
      window.__mask_ig_hooked = true;

      var send = function (type, payload) {
        try {
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.maskIG) {
            window.webkit.messageHandlers.maskIG.postMessage({ type: type, payload: payload });
          }
        } catch (e) {}
      };

      // 1. ดึง Session Cookies จาก Instagram (sessionid, ds_user_id, csrftoken)
      var checkCookies = function () {
        try {
          var cookies = document.cookie || '';
          var sessionId = null, userId = null, csrf = null;
          var parts = cookies.split(';');
          for (var i = 0; i < parts.length; i++) {
            var p = parts[i].trim();
            if (p.indexOf('sessionid=') === 0) sessionId = p.substring('sessionid='.length);
            if (p.indexOf('ds_user_id=') === 0) userId = p.substring('ds_user_id='.length);
            if (p.indexOf('csrftoken=') === 0) csrf = p.substring('csrftoken='.length);
          }
          if (sessionId || userId) {
            send('ig-session', {
              sessionId: sessionId || '',
              userId: userId || '',
              csrfToken: csrf || ''
            });
          }
        } catch (e) {}
      };
      checkCookies();
      setInterval(checkCookies, 5000);

      // 2. ดัก DOM Badge ของ Instagram (Direct inbox, Notifications)
      var lastIGCount = -1;
      var checkIGDOM = function () {
        try {
          var count = 0;

          // a. ดักตัวเลขใน Title เช่น "(3) Instagram"
          var tm = document.title ? document.title.match(/^\((\d+)\)/) : null;
          if (tm && tm[1]) {
            var tc = parseInt(tm[1], 10);
            if (!isNaN(tc)) count = Math.max(count, tc);
          }

          // b. ดัก Badge ใน DOM ของ Inbox/Direct icon
          var directBadges = document.querySelectorAll(
            'a[href*="/direct/"] span, a[href*="/direct/"] div[class*="badge"], ' +
            'svg[aria-label*="Direct"] ~ div, svg[aria-label*="Messages"] ~ div, ' +
            '[aria-label*="unread"], [aria-label*="Unread"]'
          );
          for (var i = 0; i < directBadges.length; i++) {
            var txt = (directBadges[i].textContent || '').trim();
            var n = parseInt(txt, 10);
            if (!isNaN(n) && n > 0) {
              count = Math.max(count, n);
            } else if (directBadges[i].getAttribute && directBadges[i].getAttribute('aria-label')) {
              var am = directBadges[i].getAttribute('aria-label').match(/\d+/);
              if (am) count = Math.max(count, parseInt(am[0], 10));
            }
          }

          if (count !== lastIGCount) {
            lastIGCount = count;
            send('ig-badge', count);
          }
        } catch (e) {}
      };
      setInterval(checkIGDOM, 3000);

      // 3. ดัก Network (fetch) ของ Instagram
      if (window.fetch) {
        var origFetch = window.fetch;
        window.fetch = function (input, init) {
          return origFetch.apply(this, arguments).then(function (response) {
            try {
              var u = (typeof input === 'string') ? input : (input && input.url) ? input.url : '';
              if (u && (u.indexOf('/direct_v2/inbox/') !== -1 || u.indexOf('/notifications/badge/') !== -1 || u.indexOf('/news/inbox/') !== -1)) {
                var clone = response.clone();
                clone.json().then(function (data) {
                  send('ig-api-data', { url: u, data: data });
                }).catch(function () {});
              }
            } catch (e) {}
            return response;
          });
        };
      }
    })();
    """#
}
