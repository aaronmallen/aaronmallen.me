# frozen_string_literal: true

RSpec.describe "Reduced motion", type: :feature do
  def emulate_reduced_motion(value)
    page.driver.browser.page.command(
      "Emulation.setEmulatedMedia",
      features: [{ name: "prefers-reduced-motion", value: }],
    )
  end

  def moving_parts
    evaluate_script(<<~JS)
      (() => {
        const seconds = (list) => list.split(",").map((time) => parseFloat(time));
        const moves = (style) =>
          seconds(style.transitionDuration).some((time) => time > 0) ||
          style.animationName.split(",").some((name) => name.trim() !== "none");
        const describe = (element, pseudo) =>
          `${element.tagName.toLowerCase()}.${[...element.classList].join(".")}${pseudo ?? ""}`;

        return [...document.querySelectorAll("*")].flatMap((element) =>
          [null, "::before", "::after"]
            .filter((pseudo) => moves(getComputedStyle(element, pseudo)))
            .map((pseudo) => describe(element, pseudo)),
        );
      })()
    JS
  end

  {
    "the home page" => ["/", ".main-nav-link"],
    "the post editor" => ["/admin/posts/new", ".toggle"],
    "the tags page" => ["/admin/tags", ".slash"],
  }.each do |name, (path, mover)|
    describe "on #{name}" do
      before { sign_in_to_admin if path.start_with?("/admin") }

      it "runs no transition or animation with reduced motion on", :aggregate_failures do
        emulate_reduced_motion("reduce")
        visit path

        expect(page).to have_css(mover)
        expect(moving_parts).to be_empty
      end

      it "still moves #{mover} with reduced motion off" do
        emulate_reduced_motion("no-preference")
        visit path

        expect(moving_parts).to include(a_string_including(mover))
      end
    end
  end
end
