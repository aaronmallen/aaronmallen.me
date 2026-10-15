# frozen_string_literal: true

RSpec.describe "Search page", type: :feature do
  def box(selector)
    evaluate_script(<<~JS)
      (() => {
        const { width, height } = document.querySelector("#{selector}").getBoundingClientRect();
        return { width, height };
      })()
    JS
  end

  def focused_id = evaluate_script("document.activeElement.id")

  def press(key) = page.driver.browser.keyboard.type(key)

  it "focuses the search box on the / key" do
    visit "/search"
    press("/")

    expect(focused_id).to eq("q")
  end

  it "types a / into the box once it has focus" do
    visit "/search"
    press("/")
    press("/")

    expect(find_field("q").value).to eq("/")
  end

  it "shows the header search link as a 44px icon button below 700px", :aggregate_failures do
    page.current_window.resize_to(390, 844)
    visit "/"

    expect(box(".search-link")).to eq("width" => 44, "height" => 44)
    expect(page).to have_no_css(".search-link span", visible: :visible)
  end
end
