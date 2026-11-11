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

  // Keep the desktop sidebar preference while moving between admin pages.
  var collapseBtn = document.getElementById('collapseBtn');
  function setCollapsed(collapsed) {
    document.body.classList.toggle('sidebar-collapsed', collapsed);
    if (collapseBtn) {
      collapseBtn.setAttribute('aria-expanded', collapsed ? 'false' : 'true');
      collapseBtn.setAttribute('aria-label', collapsed ? 'Expand sidebar' : 'Collapse sidebar');
      collapseBtn.title = collapsed ? 'Expand sidebar' : 'Collapse sidebar';
    }
  }
  try { setCollapsed(localStorage.getItem('admin-sidebar-collapsed') === 'true'); }
  catch (e) { setCollapsed(false); }
  if (collapseBtn) {
    collapseBtn.addEventListener('click', function () {
      var collapsed = !document.body.classList.contains('sidebar-collapsed');
      setCollapsed(collapsed);
      try { localStorage.setItem('admin-sidebar-collapsed', String(collapsed)); }
      catch (e) { /* The toggle still works for this page when storage is unavailable. */ }
    });
  }

  // Phone menu (three dots): opens the sidebar as a drawer.
  var btn = document.getElementById('menuBtn'), scrim = document.getElementById('scrim'), side = document.getElementById('side');
  function setMenu(open) {
    document.body.classList.toggle('nav-open', open);
    if (btn) {
      btn.setAttribute('aria-expanded', open ? 'true' : 'false');
      btn.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
    }
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