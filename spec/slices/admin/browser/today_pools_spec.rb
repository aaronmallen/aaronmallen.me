# frozen_string_literal: true

RSpec.describe "Admin today pools", type: :feature do
  let(:someday) { create(:task, :someday, title: "Learn Elixir") }

  before do
    create(:task, title: "Email the accountant")
    someday
    sign_in_to_admin
    visit "/admin"
  end

  def await_swap
    expect(page).to have_current_path(/pool=someday/)
    Timeout.timeout(5) { sleep 0.05 until request_gate.answered("/admin") >= request_gate.count("/admin") }
  end

  def copied = Admin::Slice["i18n"].t("ui.components.record_key.copied.task", key: someday.label)

  def panel = find("[data-sprint-panel]")

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
      await_swap
    end

    it "switches without loading the page", :aggregate_failures do
      expect(panel).to have_css(".li-title", text: "Learn Elixir")
      expect(evaluate_script("window.poolsLoaded")).to be(true)
      expect(evaluate_script("window.scrollY > 0 && window.scrollY === window.poolsScroll")).to be(true)
    end

    it "copies a task's key from the new pool", :aggregate_failures do
      watch_clipboard
      find("[data-pool-panel='someday'] .record-key").click

      expect(page).to have_css(".toast", text: copied)
      expect(evaluate_script("window.copiedKeys")).to eq([someday.label])
    end

    it "marks someday as the current page", :aggregate_failures do
      expect(panel).to have_css(".seg-option[aria-current='page']", exact_text: "someday · 1")
      expect(panel).to have_css(".seg-option[aria-current]", count: 1)
    end
  end
end
