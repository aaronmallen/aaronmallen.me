# frozen_string_literal: true

RSpec.shared_examples "accessible screens" do
  def breaches(screen)
    show(screen)
    execute_script(Axe::Configuration.instance.jslib)

    using_wait_time(10) { evaluate_async_script(<<~JS, %w[wcag2a wcag2aa wcag21a wcag21aa wcag22aa]) }
      const done = arguments[arguments.length - 1];
      axe.run(document, { runOnly: { type: 'tag', values: arguments[0] } }).then(({ violations }) => done(
        violations.flatMap(({ id, nodes }) => nodes.map((node) => `${id} at ${node.target.join(' ')}: ${node.failureSummary}`))
      ));
    JS
  end

  def mark_stops(screen)
    show(screen)
    evaluate_script(<<~JS)
      (() => {
        const stops = [...document.querySelectorAll('a[href], button, input, select, textarea, summary, [tabindex]')]
          .filter((el) => el.tabIndex >= 0 && !el.disabled && el.type !== 'hidden')
          .filter((el) => el.checkVisibility({ opacityProperty: true, visibilityProperty: true }))
          .filter((el) => {
            if (el.type !== 'radio' || !el.name) return true;
            const group = [...document.getElementsByName(el.name)].filter((r) => r.type === 'radio' && r.form === el.form);
            return el === (group.find((r) => r.checked) ?? group[0]);
          })
          .map((el, index) => (el.dataset.tabStop = `${index}: ${el.outerHTML.slice(0, 60)}`));

        const top = document.createElement('span');
        top.tabIndex = -1;
        document.body.prepend(top);
        top.focus();

        return stops;
      })()
    JS
  end

  def tab
    page.driver.browser.keyboard.type(:tab)

    evaluate_script(<<~JS)
      (() => {
        const style = getComputedStyle(document.activeElement);
        const outline = style.outlineStyle !== 'none' && parseFloat(style.outlineWidth) > 0;
        return { stop: document.activeElement.dataset.tabStop, ring: outline || style.boxShadow !== 'none' };
      })()
    JS
  end

  def tab_past(stop)
    (1..6).reduce(tab) { |step, _| step["stop"] == stop ? tab : step }
  end

  def walk(screen)
    stops = mark_stops(screen)
    walked = stops.each_with_object([]) { |_, steps| steps << tab_past(steps.last&.fetch("stop") || :top) }

    [stops, walked.map { it["stop"] }, walked.reject { it["ring"] }.map { it["stop"] }]
  end

  %w[light dark].each do |scheme|
    it "passes axe on every screen in #{scheme} mode", :aggregate_failures do
      emulate_color_scheme(scheme)

      screens.each do |name, screen|
        found = breaches(screen)
        expect(found).to be_empty, "#{name}: #{found.join("\n")}"
      end
    end
  end

  it "reaches every control on every screen with the Tab key, in order, behind a ring", :aggregate_failures do
    screens.each do |name, screen|
      stops, walked, bare = walk(screen)
      expect(walked).to eq(stops), "#{name}: Tab went out of order"
      expect(bare).to be_empty, "#{name}: no focus ring on #{bare.join(', ')}"
    end
  end
end
