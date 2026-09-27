import Foundation

// JS/CSS ที่ฉีดเข้า tinder.com / instagram.com
// (selector ตรวจกับ DOM จริงแล้ว: nav แบรนด์ Tinder, gamepad, itemprop — ถ้าเว็บอัปเดตต้องปรับที่นี่)
enum MaskScripts {

    /// สคริปต์หลัก ฉีดตอน document end (main frame เท่านั้น)
    static let userScript = #"""
    (function () {
      if (!location.hostname.endsWith('tinder.com')) return;
      if (location.pathname === '/' || location.pathname.indexOf('/login') !== -1) return;

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
          // ไม่เดา UUID จาก key อื่น — อาจได้ device id มาทับ token จริงที่ดักจาก network
          if (token && token !== lastExtractedToken) {
            lastExtractedToken = token;
            send('auth-token', token);
          }
        } catch (e) {}
      };
      checkToken();
      setInterval(checkToken, 3000);

      // ── ตรวจสอบ DOM สำหรับตัวเลขแชทที่ยังไม่ได้อ่านใน Tinder (ไม่นับ Likes / Matches) ──
      var lastDOMBadgeCount = -1;
      var checkTinderDOMBadges = function () {
        try {
          var count = 0;
          // 1. ตรวจ badge ตัวเลขบนแท็บข้อความ (Messages tab เท่านั้น ไม่ตรวจ Matches/Likes)
          var tabButtons = document.querySelectorAll('button[role="tab"], a[href*="/app/messages"]');
          for (var i = 0; i < tabButtons.length; i++) {
            var btn = tabButtons[i];
            var txt = (btn.getAttribute('aria-label') || btn.textContent || '').toLowerCase();
            if ((txt.indexOf('message') !== -1 || txt.indexOf('ข้อความ') !== -1) &&
                txt.indexOf('match') === -1 && txt.indexOf('like') === -1) {
              var badgeEl = btn.querySelector('[class*="badge"], span[aria-label*="unread"], div[aria-label*="unread"]');
              if (badgeEl) {
                var bTxt = (badgeEl.textContent || '').trim();
                var n = parseInt(bTxt, 10);
                if (!isNaN(n) && n > 0) count = Math.max(count, n);
              }
            }
          }
          // 2. ตรวจนับจำนวนห้องแชทที่มี unread dot หรือเครื่องหมายข้อความใหม่
          var unreadChatRows = document.querySelectorAll(
            'a[href*="/app/messages/"] [class*="unread"], ' +
            'a[href*="/app/messages/"] [aria-label*="unread"], ' +
            'a[href*="/app/messages/"] [aria-label*="Unread"]'
          );
          if (unreadChatRows.length > 0) {
            count = Math.max(count, unreadChatRows.length);
          }
          // 3. ตรวจอีกวิธี: badge ตัวเลขบน icon ภายในแท็บ messages
          var allSpans = document.querySelectorAll('a[href*="/app/messages"] span');
          for (var s = 0; s < allSpans.length; s++) {
            var sTxt = (allSpans[s].textContent || '').trim();
            if (/^\d+$/.test(sTxt)) {
              var sNum = parseInt(sTxt, 10);
              if (sNum > 0) count = Math.max(count, sNum);
            }
          }
          if (count !== lastDOMBadgeCount) {
            lastDOMBadgeCount = count;
            send('dom-badge', count);
          }
        } catch (e) {}
      };
      setInterval(checkTinderDOMBadges, 2000);
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

      // 2. ดัก DOM Badge ของ Instagram Direct Inbox เท่านั้น (ไม่ดัก Notifications/Heart หรือ Title)
      var lastIGCount = -1;
      var checkIGDOM = function () {
        try {
          var count = 0;

          // วิธีที่ 1: ตรวจ badge ตัวเลขบนลิงก์ /direct/
          var allLinks = document.querySelectorAll('a[href*="/direct/"]');
          for (var i = 0; i < allLinks.length; i++) {
            var link = allLinks[i];
            // หา span หรือ div ที่มีตัวเลข (badge) ภายในลิงก์
            var spans = link.querySelectorAll('span, div[role="button"]');
            for (var j = 0; j < spans.length; j++) {
              var txt = (spans[j].textContent || '').trim();
              if (/^\d+$/.test(txt)) {
                var n = parseInt(txt, 10);
                if (n > 0) count = Math.max(count, n);
              }
            }
          }

          // วิธีที่ 2: ตรวจ aria-label ที่มี "Direct" หรือ "Messenger"
          var ariaEls = document.querySelectorAll('[aria-label*="Direct"], [aria-label*="direct"], [aria-label*="Messenger"], [aria-label*="message"]');
          for (var k = 0; k < ariaEls.length; k++) {
            var el = ariaEls[k];
            var parentLink = el.closest('a');
            if (parentLink && parentLink.getAttribute('href') && parentLink.getAttribute('href').indexOf('/direct') !== -1) {
              var badgeSpans = el.querySelectorAll('span');
              for (var m = 0; m < badgeSpans.length; m++) {
                var bTxt = (badgeSpans[m].textContent || '').trim();
                if (/^\d+$/.test(bTxt)) {
                  var bNum = parseInt(bTxt, 10);
                  if (bNum > 0) count = Math.max(count, bNum);
                }
              }
            }
          }

          if (count !== lastIGCount) {
            lastIGCount = count;
            send('ig-badge', count);
          }
        } catch (e) {}
      };
      setInterval(checkIGDOM, 2000);

      // 3. ดัก Network (fetch) ของ Instagram เฉพาะ Direct Messages
      if (window.fetch) {
        var origFetch = window.fetch;
        window.fetch = function (input, init) {
          return origFetch.apply(this, arguments).then(function (response) {
            try {
              var u = (typeof input === 'string') ? input : (input && input.url) ? input.url : '';
              if (u && u.indexOf('/direct_v2/inbox/') !== -1) {
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

    /// CSS/JS ที่ฉีดเข้า Instagram Direct เพื่ออำพรางหน้าตาเป็น ChatGPT 4o Dark Mode อย่างสมบูรณ์
    static let chatGPTDirectScript = #"""
    (function () {
      var STYLE_ID = 'mask-chatgpt-override';

      var css = [
        /* 1. บังคับพื้นหลังดำเทา #212121 สไตล์ ChatGPT 4o */
        'html, body, #mount_0_0, div[role="main"], section, main {',
        '  background-color: #212121 !important;',
        '  color: #ececec !important;',
        '  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif !important;',
        '}',

        /* 2. บังคับข้อความทั้งหมดในหน้ารวมแชทและห้องแชทให้อ่านได้ชัดเจน ไม่มืดดำ */
        'div[role="main"] span, div[role="main"] p, div[role="main"] div, div[role="main"] h1, div[role="main"] h2, div[role="main"] h3 {',
        '  color: #ececec !important;',
        '}',

        /* 3. รายการแชทใน Inbox -> สีเทาเข้ม มีเส้นคั่นบางๆ */
        'a[href^="/direct/t/"] {',
        '  background-color: #212121 !important;',
        '  border-bottom: 1px solid rgba(255, 255, 255, 0.08) !important;',
        '}',
        'a[href^="/direct/t/"]:active {',
        '  background-color: #2f2f2f !important;',
        '}',

        /* 4. ซ่อนแบนเนอร์ชวนเปิดแอพ และโลโก้คำว่า Instagram (เฉพาะใน /direct/) */
        'svg[aria-label="Instagram"],',
        'div:has(> a[href*="app-store"]), div:has(> a[href*="play.google"]),',
        'a[href*="app-store"], a[href*="play.google"] {',
        '  display: none !important;',
        '}',

        /* 5. ซ่อนแท็บล่างทั่วไปของ Instagram (Home, Reels, Explore) เพื่อให้ดูเหมือนหน้าต่างแชทเดี่ยว */
        'nav:has(a[href^="/explore"]) {',
        '  display: none !important;',
        '}',

        /* 6. แถบหัวด้านบนของ Direct -> แต่งเป็นสีเทาดำ #171717 */
        'header, div[role="navigation"] {',
        '  background-color: #171717 !important;',
        '  border-bottom: 1px solid rgba(255, 255, 255, 0.08) !important;',
        '}',
        'header *, div[role="navigation"] * {',
        '  color: #ececec !important;',
        '}',

        /* 7. กล่องข้อความที่เราส่ง (Sent) -> แคปซูล Prompt สีเทาเข้ม #2f2f2f */
        'div[style*="border-top-right-radius"],',
        'div[style*="background: rgb(55, 151, 240)"],',
        'div[style*="linear-gradient"] {',
        '  background: #2f2f2f !important;',
        '  color: #ffffff !important;',
        '  border-radius: 18px !important;',
        '  box-shadow: none !important;',
        '}',
        'div[style*="border-top-right-radius"] *,',
        'div[style*="background: rgb(55, 151, 240)"] *,',
        'div[style*="linear-gradient"] * {',
        '  color: #ffffff !important;',
        '}',

        /* 8. กล่องข้อความที่คู่สนทนาตอบ (Received) -> ไร้กรอบ แบบ Plain Text ของ ChatGPT */
        'div[style*="background-color: rgb(38, 38, 38)"],',
        'div[style*="background-color: rgb(240, 240, 240)"] {',
        '  background: transparent !important;',
        '  color: #d1d5db !important;',
        '  border: none !important;',
        '  box-shadow: none !important;',
        '}',

        /* 9. ช่องพิมพ์ข้อความด้านล่าง -> แคปซูล ChatGPT มนๆ */
        'div:has(> textarea[placeholder*="Message"]),',
        'div:has(> textarea),',
        'div[contenteditable="true"] {',
        '  background-color: #2f2f2f !important;',
        '  border: 1px solid rgba(255, 255, 255, 0.18) !important;',
        '  border-radius: 24px !important;',
        '  color: #ffffff !important;',
        '}',
        'textarea, input, [contenteditable="true"] {',
        '  background: transparent !important;',
        '  color: #ffffff !important;',
        '}',
        'textarea::placeholder, input::placeholder {',
        '  color: rgba(255, 255, 255, 0.45) !important;',
        '}',

        /* 10. ปรับไอคอนต่างๆ ให้เป็นสีขาวนวล */
        'svg {',
        '  fill: #ececec !important;',
        '}'
      ].join('\n');

      var removeStyle = function () {
        var existing = document.getElementById(STYLE_ID);
        if (existing && existing.parentNode) {
          existing.parentNode.removeChild(existing);
        }
      };

      var applyStyle = function () {
        if (!document.getElementById(STYLE_ID)) {
          var tag = document.createElement('style');
          tag.id = STYLE_ID;
          tag.textContent = css;
          (document.head || document.documentElement).appendChild(tag);
        }
      };

      // ฟังก์ชันสำหรับเปิด/ปิดโหมด ChatGPT จาก Native หรือตาม URL
      window.__mask_chatgpt_enabled = true;
      window.__mask_toggle_chatgpt = function (enabled) {
        window.__mask_chatgpt_enabled = (enabled !== false);
        window.__mask_check_route();
      };

      window.__mask_check_route = function () {
        // ห้ามฉีดสไตล์ในหน้า Login / Accounts เด็ดขาด เพื่อให้ล็อกอินได้ปกติ
        if (location.pathname.indexOf('/accounts') !== -1) {
          removeStyle();
          return;
        }

        // ฉีดเฉพาะเมื่อเปิดโหมด ChatGPT และอยู่ใน /direct/ เท่านั้น
        if (window.__mask_chatgpt_enabled && location.pathname.indexOf('/direct') !== -1) {
          applyStyle();
        } else {
          removeStyle();
        }
      };

      // รันการตรวจสอบทันทีและตามระยะเมื่อ URL มีการเปลี่ยนแปลง (SPA Routing)
      window.__mask_check_route();
      setInterval(window.__mask_check_route, 1000);
    })();
    """#
}
