# frozen_string_literal: true

RSpec.describe "The wordmark", type: :feature do
  def cycle
    evaluate_script(<<~JS)
      ((slash) => {
        const [animation] = slash.getAnimations();
        animation.pause();
        return animation.effect.getKeyframes().slice(0, -1).map(({ computedOffset }) => {
          animation.currentTime = computedOffset * animation.effect.getTiming().duration;
          return getComputedStyle(slash).color;
        });
      })(document.querySelector(".wordmark-slash"))
    JS
  end

  def emulate_reduced_motion
    page.driver.browser.page.command(
      "Emulation.setEmulatedMedia",
      features: [{ name: "prefers-reduced-motion", value: "reduce" }],
    )
  end

  def rgb(hex) = "rgb(#{hex.scan(/\h\h/).map(&:hex).join(', ')})"

  def still? = evaluate_script("document.querySelector('.wordmark-slash').getAnimations().length === 0")

  shared_examples "a cycling slash" do |hexes|
    it "rests until hovered" do
      expect(still?).to be(true)
    end

    it "cycles the slash on hover" do
      emulate_color_scheme("dark")
      find("a.wordmark").hover

      expect(cycle).to eq(hexes.map { rgb(it) })
    end

    it "cycles the slash on focus" do
      emulate_color_scheme("dark")
      execute_script("document.querySelector('a.wordmark').focus({ focusVisible: true })")

      expect(cycle).to eq(hexes.map { rgb(it) })
    end

    it "holds the slash still with reduced motion on" do
      emulate_reduced_motion
      find("a.wordmark").hover

      expect(still?).to be(true)
    end
  end

  describe "in the public header" do
    before { visit "/" }

    it_behaves_like "a cycling slash", %w[#f92672 #fd971f #e6db74 #a6e22e #66d9ef #ae81ff]
  end

  describe "in the admin top bar" do
    before do
      sign_in_to_admin
      visit "/admin"
    end

    it_behaves_like "a cycling slash", %w[#a6e22e #66d9ef #ae81ff #fb5a94 #fd971f #e6db74]
  end
end
