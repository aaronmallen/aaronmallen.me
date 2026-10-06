# frozen_string_literal: true

RSpec.describe "Admin today pools", type: :feature do
  before do
    create(:task, title: "Email the accountant")
    create(:task, :someday, title: "Learn Elixir")
    sign_in_to_admin
    visit "/admin"
  end

  def panel = find(".sprint-panel")

  def scroll_down
    execute_script(<<~JS)
      document.querySelector("[data-pools] .seg").scrollIntoView({ block: "center" });
      window.poolsLoaded = true;
      window.poolsScroll = window.scrollY;
    JS
  end

  describe "switching the pool to someday" do
    before do
      page.driver.resize(1024, 400)
      scroll_down
      panel.find(".seg-option", exact_text: "someday · 1").click
    end

    it "switches without loading the page", :aggregate_failures do
      expect(panel).to have_css(".li-title", text: "Learn Elixir")
      expect(evaluate_script("window.poolsLoaded")).to be(true)
      expect(evaluate_script("window.scrollY > 0 && window.scrollY === window.poolsScroll")).to be(true)
    end

    it "marks someday as the current page" do
      expect(panel.all(".seg-option[aria-current]").map { [it.text, it["aria-current"]] })
        .to eq([["someday · 1", "page"]])
    end
  end
end
