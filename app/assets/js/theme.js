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

function render() {
  for (const button of document.querySelectorAll("[data-theme-choice]")) {
    button.setAttribute("aria-pressed", String(button.dataset.themeChoice === currentTheme()));
  }
}

export function setupThemePicker() {
  document.addEventListener("click", (event) => {
    const choice = event.target.closest("[data-theme-choice]");
    if (choice) saveTheme(choice.dataset.themeChoice);
    else if (event.target.closest("[data-theme-toggle]")) saveTheme(currentTheme() === "dark" ? "light" : "dark");
    else return;

    render();
  });

  systemDark.addEventListener("change", render);
  document.addEventListener("admin:morphed", render);
  render();
}
