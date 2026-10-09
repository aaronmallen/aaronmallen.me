# frozen_string_literal: true

RSpec.describe "About layout", type: :feature do
  def box(selector)
    evaluate_script(<<~JS)
      (() => {
        const { bottom, left, right, top } = document.querySelector("#{selector}").getBoundingClientRect();
        return { bottom, left, right, top };
      })()
    JS
  end

  def position(selector) = evaluate_script("getComputedStyle(document.querySelector('#{selector}')).position")

  before do
    create(:work_entry, role: "Engineer")
    visit "/about"
  end

  it "sticks the sidebar beside the prose from 900px", :aggregate_failures do
    page.current_window.resize_to(1280, 800)

    expect(position("aside")).to eq("sticky")
    expect(box("aside")["left"]).to be > box(".prose")["right"]
  end

  it "sets the sidebar after the prose below 900px", :aggregate_failures do
    page.current_window.resize_to(800, 800)

    expect(position("aside")).to eq("static")
    expect(box("aside")["top"]).to be > box(".prose")["bottom"]
  end
end
