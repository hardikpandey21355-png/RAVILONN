/* Shared helpers for every admin page. */
(function () {
  var csrf = (document.querySelector('meta[name="csrf"]') || {}).content || '';
  var toastEl = document.getElementById('toast'), toastT;

  window.toast = function (msg) {
    if (!toastEl) return;
    toastEl.textContent = msg; toastEl.classList.add('show');
    clearTimeout(toastT); toastT = setTimeout(function () { toastEl.classList.remove('show'); }, 2800);
  };

  // POST JSON to the admin server (adds the CSRF header for you)
  window.api = function (url, body) {
    return fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-CSRF': csrf }, body: JSON.stringify(body || {}) })
      .then(function (r) { return r.json(); })
      .catch(function () { return { ok: false, error: 'Network problem. Try again.' }; });
  };

  // Phone menu (three dots): opens the sidebar as a drawer
  var btn = document.getElementById('menuBtn'), scrim = document.getElementById('scrim'), side = document.getElementById('side');
  function setMenu(open) {
    document.body.classList.toggle('nav-open', open);
    if (btn) btn.setAttribute('aria-expanded', open ? 'true' : 'false');
  }
  if (btn && side) {
    btn.addEventListener('click', function () { setMenu(!document.body.classList.contains('nav-open')); });
    if (scrim) scrim.addEventListener('click', function () { setMenu(false); });
    side.addEventListener('click', function (e) { if (e.target.closest('.nav a')) setMenu(false); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') setMenu(false); });
    window.addEventListener('resize', function () { if (window.innerWidth > 800) setMenu(false); });
    window.addEventListener('pageshow', function () { setMenu(false); });   // back button must not show an open menu
  }
})();