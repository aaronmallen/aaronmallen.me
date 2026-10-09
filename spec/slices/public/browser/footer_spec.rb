# frozen_string_literal: true

RSpec.describe "Footer glasses", type: :feature do
  before { visit "/" }

  def glasses_style
    evaluate_script(<<~JS)
      (() => {
        const glasses = document.querySelector("footer .site-footer-glasses");
        const { height, width } = glasses.getBoundingClientRect();
        const mask = getComputedStyle(glasses).maskImage || getComputedStyle(glasses).webkitMaskImage;
        return { height, mask, width };
      })()
    JS
  end

  it "draws the glasses as a mask, twice as wide as tall or more", :aggregate_failures do
    style = glasses_style

    expect(style["mask"]).to start_with('url("data:image/svg+xml')
    expect(style["width"]).to be > style["height"] * 2
  end
end
