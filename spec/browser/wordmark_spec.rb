# frozen_string_literal: true

RSpec.describe "The wordmark", type: :feature do
  def animating?
    evaluate_script(<<~JS)
      document.querySelector(".wordmark-slash").getAnimations().some(({ playState }) => playState === "running")
    JS
  end

  def emulate_reduced_motion
    page.driver.browser.page.command(
      "Emulation.setEmulatedMedia",
      features: [{ name: "prefers-reduced-motion", value: "reduce" }],
    )
  end

  shared_examples "a cycling slash" do
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

    it_behaves_like "a cycling slash"
  end

  describe "in the admin top bar" do
    before do
      sign_in_to_admin
      visit "/admin"
    end

    it_behaves_like "a cycling slash"
  end
end
