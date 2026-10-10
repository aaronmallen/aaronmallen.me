const ONE_YEAR = 1000 * 60 * 60 * 24 * 365;

export function setupThemePicker() {
  const buttons = document.querySelectorAll("[data-theme-choice]");
  if (buttons.length === 0) return;

  const root = document.documentElement;
  const systemDark = matchMedia("(prefers-color-scheme: dark)");
  const currentTheme = () => root.dataset.siteTheme ?? (systemDark.matches ? "dark" : "light");

  const render = () => {
    for (const button of buttons) {
      button.setAttribute("aria-pressed", String(button.dataset.themeChoice === currentTheme()));
    }
  };

  for (const button of buttons) {
    button.addEventListener("click", () => {
      root.dataset.siteTheme = button.dataset.themeChoice;
      render();
      globalThis.cookieStore?.set({
        expires: Date.now() + ONE_YEAR,
        name: root.dataset.themeCookie,
        path: "/",
        sameSite: "lax",
        value: button.dataset.themeChoice,
      });
    });
  }

  systemDark.addEventListener("change", render);
  render();
}
