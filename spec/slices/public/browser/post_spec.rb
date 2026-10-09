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
end
