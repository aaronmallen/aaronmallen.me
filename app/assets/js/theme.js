const ONE_YEAR = 1000 * 60 * 60 * 24 * 365;

const root = document.documentElement;
const systemDark = matchMedia("(prefers-color-scheme: dark)");
const currentTheme = () => root.dataset.siteTheme ?? (systemDark.matches ? "dark" : "light");

function saveTheme(theme) {
  root.dataset.siteTheme = theme;
  globalThis.cookieStore?.set({
    expires: Date.now() + ONE_YEAR,
    name: root.dataset.themeCookie,
    path: "/",
    sameSite: "lax",
    value: theme,
  });
}

export function setupThemePicker() {
  for (const toggle of document.querySelectorAll("[data-theme-toggle]")) {
    toggle.addEventListener("click", () => saveTheme(currentTheme() === "dark" ? "light" : "dark"));
  }

  const buttons = document.querySelectorAll("[data-theme-choice]");
  if (buttons.length === 0) return;

  const render = () => {
    for (const button of buttons) {
      button.setAttribute("aria-pressed", String(button.dataset.themeChoice === currentTheme()));
    }
  };

  for (const button of buttons) {
    button.addEventListener("click", () => {
      saveTheme(button.dataset.themeChoice);
      render();
    });
  }

  systemDark.addEventListener("change", render);
  render();
}
