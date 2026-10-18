# frozen_string_literal: true

module Spec
  module ReadableScreens
    PHONE_BELOW = 700
    SMALLEST_TAP = 44
    SMALLEST_TEXT = 12
  end
end

RSpec.shared_examples "readable screens" do |tap: false|
  def faults(screen, taps:)
    show(screen)

    limits = {
      phoneBelow: Spec::ReadableScreens::PHONE_BELOW,
      smallestTap: taps && Spec::ReadableScreens::SMALLEST_TAP,
      smallestText: Spec::ReadableScreens::SMALLEST_TEXT,
    }

    page.evaluate_script(readable_script, limits) + idle_preloads
  end

  def idle_preloads
    page.evaluate_async_script(<<~'JS')
      const done = arguments[0];
      const bare = (family) => family.replaceAll('"', '');

      const source = (rule) => {
        const url = rule.style.getPropertyValue('src').match(/url\(\s*["']?([^"')]+)/)[1];
        return new URL(url, rule.parentStyleSheet.href).href;
      };

      const drawn = (rule) => [...document.fonts].some((font) => font.status === 'loaded' &&
        bare(font.family) === bare(rule.style.fontFamily) && font.style === rule.style.fontStyle &&
        font.unicodeRange === rule.style.getPropertyValue('unicode-range'));

      document.fonts.ready.then(() => {
        const faces = [...document.styleSheets].flatMap((sheet) => [...sheet.cssRules])
          .filter((rule) => rule instanceof CSSFontFaceRule);

        done([...document.querySelectorAll('link[rel="preload"][as="font"]')]
          .filter((link) => !faces.some((rule) => source(rule) === link.href && drawn(rule)))
          .map((link) => link.getAttribute('href') + ' is preloaded but never drawn'));
      });
    JS
  end

  def readable_script
    <<~JS
      (() => {
        const { phoneBelow, smallestTap, smallestText } = arguments[0];
        const width = window.innerWidth;
        const named = (el) => el.tagName.toLowerCase() + (el.classList.length ? '.' + [...el.classList].join('.') : '');
        const shown = (el) => el.getClientRects().length > 0;
        const seen = (el) => shown(el) && el.checkVisibility({ opacityProperty: true, visibilityProperty: true });
        const hidden = (el) => el.closest('.sr-only, .skip-link, .top-bar-skip');

        const scrolled = (el) => {
          for (let node = el.parentElement; node && node !== document.body; node = node.parentElement) {
            if (getComputedStyle(node).overflowX !== 'visible') return true;
          }
          return false;
        };

        const target = (el) => {
          if (el.tagName === 'LABEL') {
            const field = el.htmlFor && document.getElementById(el.htmlFor);
            return !field || !shown(field);
          }

          return !el.closest('label');
        };

        const phone = width < phoneBelow;

        const page = phone && document.documentElement.scrollWidth > width
          ? ['the page is ' + document.documentElement.scrollWidth + 'px wide on a ' + width + 'px phone']
          : [];

        const overflow = !phone ? [] : [...document.querySelectorAll('body *')]
          .filter((el) => shown(el) && !hidden(el) && !scrolled(el))
          .filter((el) => el.getBoundingClientRect().right > width + 1)
          .map((el) => named(el) + ' reaches ' + Math.round(el.getBoundingClientRect().right) + 'px on a ' + width + 'px phone');

        const controls = !(phone && smallestTap) ? [] : [...document.querySelectorAll('a[href],button,input,select,textarea,summary,label[for]')]
          .filter((el) => shown(el) && el.type !== 'hidden' && !hidden(el) && !el.closest('.site-header') && target(el))
          .map((el) => ({ name: named(el), box: el.getBoundingClientRect() }))
          .filter((el) => el.box.height < smallestTap || el.box.width < smallestTap)
          .map((el) => el.name + ' is ' + Math.round(el.box.width) + 'x' + Math.round(el.box.height) + ', under the ' + smallestTap + 'px tap target');

        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
        const nodes = [];
        for (let node = walker.nextNode(); node; node = walker.nextNode()) nodes.push(node);

        const text = nodes
          .filter((node) => node.textContent.trim().length > 0)
          .map((node) => node.parentElement)
          .filter((el) => seen(el) && !hidden(el))
          .map((el) => ({ name: named(el), size: parseFloat(getComputedStyle(el).fontSize) }))
          .filter((el) => el.size < smallestText)
          .map((el) => el.name + ' reads at ' + el.size + 'px, under ' + smallestText + 'px');

        return [...new Set([...page, ...overflow, ...controls, ...text])];
      })()
    JS
  end

  { "phone" => [390, 844], "desk" => [1280, 800] }.each do |device, (width, height)|
    it "holds every screen to the #{device} it is read on", :aggregate_failures do
      page.current_window.resize_to(width, height)

      screens.each do |name, screen|
        found = faults(screen, taps: tap)

        expect(found).to be_empty, "#{name}: #{found.join('; ')}"
      end
    end
  end
end
