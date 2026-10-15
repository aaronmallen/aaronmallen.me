# frozen_string_literal: true

RSpec.describe "The wordmark", type: :feature do
  def animating?
    evaluate_script(<<~JS)
      document.querySelector(".wordmark-slash").getAnimations().some(({ playState }) => playState === "running")
    JS
  end

  def cycle
    evaluate_script(<<~JS)
      (() => {
        const style = getComputedStyle(document.querySelector("a.wordmark"))
        return [0, 1, 2, 3, 4, 5].map((step) => style.getPropertyValue(`--cy${step}`).trim())
      })()
    JS
  end

  def emulate_reduced_motion
    page.driver.browser.page.command(
      "Emulation.setEmulatedMedia",
      features: [{ name: "prefers-reduced-motion", value: "reduce" }],
    )
  end

  def palette(*names)
    evaluate_script(<<~JS)
      (() => {
        const style = getComputedStyle(document.documentElement)
        return #{names.to_json}.map((name) => style.getPropertyValue(`--color-mk-${name}-text`).trim())
      })()
    JS
  end

  def resolved_color(css)
    evaluate_script(<<~JS)
      (() => {
        const probe = document.createElement("span")
        probe.style.color = #{css.to_json}
        document.body.append(probe)
        const color = getComputedStyle(probe).color
        probe.remove()
        return color
      })()
    JS
  end

  def style_of(selector, property)
    evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json})).#{property}")
  end

  shared_examples "the shared wordmark" do
    it "starts the slash pink" do
      expect(style_of(".wordmark-slash", "color")).to eq(resolved_color("var(--color-mk-pink-text)"))
    end

    it "cycles in the public order" do
      expect(cycle).to eq(palette("pink", "orange", "sand", "green", "blue", "violet"))
    end

    it "sets the wordmark at the brand size" do
      expect(style_of("a.wordmark", "fontSize")).to eq("18px")
    end

    it "rings the wordmark in the accent on focus" do
      execute_script("document.querySelector('a.wordmark').focus({ focusVisible: true })")

      expect(style_of("a.wordmark", "outlineColor")).to eq(resolved_color("var(--color-accent)"))
    end

    it "rests until hovered" do
      expect(animating?).to be(false)
    end

    it "cycles the slash on hover" do
      find("a.wordmark").hover

      expect(animating?).to be(true)
    end

    it "cycles the slash on focus" do
      execute_script("document.querySelector('a.wordmark').focus({ focusVisible: true })")

      expect(animating?).to be(true)
    end

    it "holds the slash still with reduced motion on" do
      emulate_reduced_motion
      find("a.wordmark").hover

      expect(animating?).to be(false)
    end
  end

  describe "in the public header" do
    before { visit "/" }

    it_behaves_like "the shared wordmark"
  end

  describe "in the admin top bar" do
    before do
      sign_in_to_admin
      visit "/admin"
    end

    it_behaves_like "the shared wordmark"
  end
end
