export function setupMenuSuggest(menu, fit) {
  const list = menu.querySelector("[data-menu-suggest]");
  if (!list) return;

  const form = list.closest("form");
  const input = form.querySelector("input[name]:not([type=hidden])");
  const tags = JSON.parse(list.dataset.menuSuggest);

  const close = () => {
    list.hidden = true;
    list.replaceChildren();
  };

  const item = ({ name, color }) => {
    const tag = document.createElement("span");
    tag.className = ["tag", color].filter(Boolean).join(" ");
    tag.textContent = `#${name}`;

    const button = document.createElement("button");
    button.type = "button";
    button.className = "ctx-item";
    button.tabIndex = -1;
    button.setAttribute("role", "menuitem");
    button.dataset.contextItem = "";
    button.dataset.name = name;
    button.append(tag);
    return button;
  };

  input.addEventListener("input", () => {
    const query = input.value.trim().toLowerCase();
    const found = query ? tags.filter(({ name }) => name.includes(query)) : [];
    if (!found.length) return close();

    list.replaceChildren(...found.map(item));
    list.hidden = false;
    fit(form.closest("[role=menu]"));
  });

  list.addEventListener("click", (event) => {
    const picked = event.target.closest("[data-name]");
    if (!picked) return;

    input.value = picked.dataset.name;
    close();
    form.requestSubmit();
  });

  form.addEventListener("keydown", (event) => {
    if (event.key !== "Escape" || list.hidden) return;

    event.preventDefault();
    event.stopPropagation();
    close();
    input.focus();
  });
}
