const DEFAULT_OPTIONS = {
  enabled: true
};

const enabledInput = document.getElementById("enabled");
const state = document.getElementById("state");

function render(enabled) {
  enabledInput.checked = enabled;
  state.textContent = enabled ? "已隐藏" : "已显示";
}

chrome.storage.sync.get(DEFAULT_OPTIONS, (options) => {
  render(options.enabled !== false);
});

enabledInput.addEventListener("change", () => {
  chrome.storage.sync.set({
    enabled: enabledInput.checked
  });
  render(enabledInput.checked);
});
