# frozen_string_literal: true

RSpec.describe "Post layout", type: :feature do
  def style(selector, property)
    evaluate_script("getComputedStyle(document.querySelector('#{selector}')).#{property}")
  end

  before do
    create(:post, :published, slug: "hello", body: "one two")
    visit "/writing/hello"
  end

  it "sets the body in the serif face" do
    expect(style(".e-content", "fontFamily")).to start_with("Newsreader")
  end

  it "grows the title with the viewport" do
    page.current_window.resize_to(800, 800)
    narrow = style("h1.p-name", "fontSize").to_f
    page.current_window.resize_to(1600, 800)

    expect(style("h1.p-name", "fontSize").to_f).to be > narrow
  end

  it "draws the glasses after the body" do
    expect(evaluate_script("document.querySelector('.endmark .glasses').getBoundingClientRect().width")).to be_positive
  end

  describe "the table of contents" do
    before do
      sections = %w[One Two Three Four].map { "## #{it}\n\n#{Array.new(80) { 'Words fill the page. ' }.join}" }
      create(:post, :published, slug: "long", body: sections.join("\n\n"))
      page.current_window.resize_to(1280, 800)
      visit "/writing/long"
    end

    it "marks the first heading before any scrolling" do
      expect(page).to have_css(".toc a[aria-current='location']", text: "One")
    end

    it "marks the heading scrolled into view and keeps the list in view", :aggregate_failures do
      execute_script("document.getElementById('three').scrollIntoView()")

      expect(page).to have_css(".toc a[aria-current='location']", text: "Three")
      expect(page).to have_css(".toc a[aria-current]", count: 1)
      expect(evaluate_script("document.querySelector('.toc').getBoundingClientRect().top")).to be_within(1).of(92)
    end

    it "hides the list below 1100px" do
      page.current_window.resize_to(1000, 800)

      expect(page).to have_no_css(".toc")
    end
  end
end
