import { expect, type Page } from "@playwright/test";
import { Then } from "../support/world.ts";

const faults = (page: Page, taps: boolean) =>
  page.evaluate(
    ({ phoneBelow, smallestTap, smallestText }) => {
      const width = window.innerWidth;
      const named = (el: Element) =>
        el.tagName.toLowerCase() + (el.classList.length ? `.${[...el.classList].join(".")}` : "");
      const shown = (el: Element) => el.getClientRects().length > 0;
      const seen = (el: Element) =>
        shown(el) && el.checkVisibility({ opacityProperty: true, visibilityProperty: true });
      const hidden = (el: Element) => el.closest(".sr-only, .skip-link, .top-bar-skip");
      const scrolled = (el: Element) => {
        for (let node = el.parentElement; node && node !== document.body; node = node.parentElement) {
          if (getComputedStyle(node).overflowX !== "visible") return true;
        }
        return false;
      };
      const target = (el: Element) => {
        if (el instanceof HTMLLabelElement) {
          const field = el.htmlFor && document.getElementById(el.htmlFor);
          return !field || !shown(field);
        }
        return !el.closest("label");
      };
      const phone = width < phoneBelow;
      const wide =
        phone && document.documentElement.scrollWidth > width
          ? [`the page is ${document.documentElement.scrollWidth}px wide on a ${width}px phone`]
          : [];
      const overflow = !phone
        ? []
        : [...document.querySelectorAll("body *")]
            .filter((el) => shown(el) && !hidden(el) && !scrolled(el))
            .filter((el) => el.getBoundingClientRect().right > width + 1)
            .map(
              (el) => `${named(el)} reaches ${Math.round(el.getBoundingClientRect().right)}px on a ${width}px phone`,
            );
      const controls = !(phone && smallestTap)
        ? []
        : [...document.querySelectorAll("a[href],button,input,select,textarea,summary,label[for]")]
            .filter(
              (el) =>
                shown(el) &&
                (el as HTMLInputElement).type !== "hidden" &&
                !hidden(el) &&
                !el.closest(".site-header") &&
                target(el),
            )
            .map((el) => ({ box: el.getBoundingClientRect(), name: named(el) }))
            .filter(({ box }) => box.height < smallestTap || box.width < smallestTap)
            .map(({ box, name }) => `${name} is ${Math.round(box.width)}x${Math.round(box.height)}`);
      const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
      const nodes: Node[] = [];
      for (let node = walker.nextNode(); node; node = walker.nextNode()) nodes.push(node);
      const text = nodes
        .filter((node) => (node.textContent ?? "").trim().length > 0)
        .map((node) => node.parentElement as Element)
        .filter((el) => el && seen(el) && !hidden(el))
        .map((el) => ({ name: named(el), size: Number.parseFloat(getComputedStyle(el).fontSize) }))
        .filter(({ size }) => size < smallestText)
        .map(({ name, size }) => `${name} reads at ${size}px, under ${smallestText}px`);
      return [...new Set([...wide, ...overflow, ...controls, ...text])];
    },
    { phoneBelow: 700, smallestTap: taps ? 44 : 0, smallestText: 12 },
  );

const unusedPreloads = (page: Page) =>
  page.evaluate(async () => {
    await document.fonts.ready;
    const bare = (family: string) => family.replaceAll('"', "");
    const faces = [...document.styleSheets]
      .flatMap((sheet) => [...sheet.cssRules])
      .filter((rule): rule is CSSFontFaceRule => rule instanceof CSSFontFaceRule);
    const source = (rule: CSSFontFaceRule) =>
      new URL(
        rule.style.getPropertyValue("src").match(/url\(\s*["']?([^"')]+)/)?.[1] ?? "",
        rule.parentStyleSheet?.href ?? "",
      ).href;
    const drawn = (rule: CSSFontFaceRule) =>
      [...document.fonts].some(
        (font) =>
          font.status === "loaded" &&
          bare(font.family) === bare(rule.style.getPropertyValue("font-family")) &&
          font.style === rule.style.getPropertyValue("font-style") &&
          font.unicodeRange === rule.style.getPropertyValue("unicode-range"),
      );
    return [...document.querySelectorAll<HTMLLinkElement>('link[rel="preload"][as="font"]')]
      .filter((link) => !faces.some((rule) => source(rule) === link.href && drawn(rule)))
      .map((link) => `${link.getAttribute("href")} is preloaded but never drawn`);
  });

Then("the page reads well on the window, preloading only fonts it draws", async ({ page }) => {
  expect([...(await faults(page, false)), ...(await unusedPreloads(page))]).toEqual([]);
});

Then("the page reads well on the window, with 44px tap targets", async ({ page }) => {
  expect(await faults(page, true)).toEqual([]);
});

Then("the Tab key reaches every control on the page in order, each behind a ring", async ({ page }) => {
  const stops = await page.evaluate(() => {
    const modal = document.querySelector("dialog:modal");
    const scope = modal ?? document;
    const marked = [
      ...scope.querySelectorAll<HTMLElement>("a[href], button, input, select, textarea, summary, [tabindex]"),
    ]
      .filter(
        (el) => el.tabIndex >= 0 && !(el as HTMLButtonElement).disabled && (el as HTMLInputElement).type !== "hidden",
      )
      .filter((el) => el.checkVisibility({ opacityProperty: !el.closest(".hov"), visibilityProperty: true }))
      .filter((el) => {
        const input = el as HTMLInputElement;
        if (input.type !== "radio" || !input.name) return true;
        const group = [...document.getElementsByName(input.name)].filter(
          (radio) => (radio as HTMLInputElement).type === "radio" && (radio as HTMLInputElement).form === input.form,
        ) as HTMLInputElement[];
        return input === (group.find((radio) => radio.checked) ?? group[0]);
      })
      .map((el, index) => {
        el.dataset.tabStop = `${index}: ${el.outerHTML.slice(0, 60)}`;
        return el.dataset.tabStop;
      });
    const top = document.createElement("span");
    top.tabIndex = -1;
    (modal ?? document.body).prepend(top);
    top.focus();
    return marked;
  });
  const tab = async () => {
    await page.keyboard.press("Tab");
    return page.evaluate(() => {
      const active = document.activeElement as HTMLElement;
      const style = getComputedStyle(active);
      const outline = style.outlineStyle !== "none" && Number.parseFloat(style.outlineWidth) > 0;
      return { ring: outline || style.boxShadow !== "none", stop: active.dataset.tabStop };
    });
  };
  const walked: { ring: boolean; stop?: string }[] = [];
  for (const _ of stops) {
    const last = walked.at(-1)?.stop ?? "top";
    let step = await tab();
    for (let extra = 0; extra < 6 && step.stop === last; extra++) step = await tab();
    walked.push(step);
  }
  expect(walked.map(({ stop }) => stop)).toEqual(stops);
  expect(walked.filter(({ ring }) => !ring).map(({ stop }) => stop)).toEqual([]);
});
