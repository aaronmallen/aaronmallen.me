# frozen_string_literal: true

RSpec.shared_examples "readable screens" do |tap: false|
  def faults(screen, taps:)
    show(screen)

    page.evaluate_script(format(readable_script, phone: 700, readable: 12, tap: taps ? 44 : 0))
  end

  def readable_script
    <<~JS
      (() => {
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

        const phone = width < %<phone>d;

        const page = phone && document.documentElement.scrollWidth > width
          ? ['the page is ' + document.documentElement.scrollWidth + 'px wide']
          : [];

        const overflow = [...document.querySelectorAll(phone ? 'body *' : ':not(*)')]
          .filter((el) => shown(el) && !hidden(el) && !scrolled(el))
          .filter((el) => el.getBoundingClientRect().right > width + 1)
          .map((el) => named(el) + ' reaches ' + Math.round(el.getBoundingClientRect().right) + 'px');

        const tapped = phone && %<tap>d > 0 ? 'a[href],button,input,select,textarea,summary,label[for]' : ':not(*)';

        const controls = [...document.querySelectorAll(tapped)]
          .filter((el) => shown(el) && el.type !== 'hidden' && !hidden(el) && !el.closest('.site-header') && target(el))
          .map((el) => ({ name: named(el), box: el.getBoundingClientRect() }))
          .filter((el) => el.box.height < %<tap>d || el.box.width < %<tap>d)
          .map((el) => el.name + ' is ' + Math.round(el.box.width) + 'x' + Math.round(el.box.height));

        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
        const nodes = [];
        for (let node = walker.nextNode(); node; node = walker.nextNode()) nodes.push(node);

        const text = nodes
          .filter((node) => node.textContent.trim().length > 0)
          .map((node) => node.parentElement)
          .filter((el) => seen(el) && !hidden(el))
          .map((el) => ({ name: named(el), size: parseFloat(getComputedStyle(el).fontSize) }))
          .filter((el) => el.size < %<readable>d)
          .map((el) => el.name + ' reads at ' + el.size + 'px');

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
