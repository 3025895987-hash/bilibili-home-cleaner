(() => {
  const COVER_ID = "bili-focus-cover";
  const ROOT_CLASS = "bili-focus-home-active";
  const DEFAULT_OPTIONS = {
    enabled: true
  };

  let enabled = DEFAULT_OPTIONS.enabled;
  let scheduled = false;

  function isBilibiliHome() {
    if (location.hostname !== "www.bilibili.com") {
      return false;
    }

    const path = location.pathname.replace(/\/+$/, "") || "/";
    return path === "/" || path === "/index.html";
  }

  function ensureCover() {
    let cover = document.getElementById(COVER_ID);
    if (cover) {
      return cover;
    }

    if (!document.body) {
      return null;
    }

    cover = document.createElement("div");
    cover.id = COVER_ID;
    cover.setAttribute("aria-hidden", "true");

    document.body.appendChild(cover);
    return cover;
  }

  function removeCover() {
    const cover = document.getElementById(COVER_ID);
    if (cover) {
      cover.remove();
    }
  }

  function updateCoverPosition() {
    const header = document.querySelector(".bili-header, .international-header, .mini-header");
    const sidebar = document.querySelector(".left-entry, .v-popover-wrap.left-loc-entry, .bili-sidebar, .side-bar");

    if (header) {
      const rect = header.getBoundingClientRect();
      if (rect.height > 40 && rect.height < 160) {
        document.documentElement.style.setProperty("--bili-focus-cover-top", `${Math.ceil(rect.bottom)}px`);
      }
    }

    if (sidebar) {
      const rect = sidebar.getBoundingClientRect();
      if (rect.width > 40 && rect.width < 180 && rect.left < 100) {
        document.documentElement.style.setProperty("--bili-focus-cover-left", `${Math.ceil(rect.right)}px`);
      }
    }
  }

  function applyState() {
    const active = enabled && isBilibiliHome();
    document.documentElement.classList.toggle(ROOT_CLASS, active);

    if (!active) {
      removeCover();
      return;
    }

    ensureCover();
    updateCoverPosition();
  }

  function scheduleApplyState() {
    if (scheduled) {
      return;
    }

    scheduled = true;
    requestAnimationFrame(() => {
      scheduled = false;
      applyState();
    });
  }

  function loadOptions() {
    chrome.storage.sync.get(DEFAULT_OPTIONS, (options) => {
      enabled = options.enabled !== false;
      scheduleApplyState();
    });
  }

  function patchHistory() {
    const notify = () => window.dispatchEvent(new Event("bili-focus-location-change"));

    for (const method of ["pushState", "replaceState"]) {
      const original = history[method];
      history[method] = function patchedHistoryMethod(...args) {
        const result = original.apply(this, args);
        notify();
        return result;
      };
    }

    window.addEventListener("popstate", notify);
    window.addEventListener("bili-focus-location-change", scheduleApplyState);
  }

  chrome.storage.onChanged.addListener((changes, areaName) => {
    if (areaName !== "sync" || !changes.enabled) {
      return;
    }

    enabled = changes.enabled.newValue !== false;
    scheduleApplyState();
  });

  patchHistory();
  loadOptions();

  document.addEventListener("DOMContentLoaded", scheduleApplyState);
  window.addEventListener("load", scheduleApplyState);
  window.addEventListener("resize", scheduleApplyState);

  const observer = new MutationObserver(scheduleApplyState);
  observer.observe(document.documentElement, {
    childList: true,
    subtree: true
  });
})();
