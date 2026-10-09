# frozen_string_literal: true

RSpec.describe "Heading anchors", type: :feature do
  before do
    filler = Array.new(40) { "filler" }.join("\n\n")
    create(:post, :published, slug: "hello", body: "#{filler}\n\n## Where it lands\n\n#{filler}")
    visit "/writing/hello#where-it-lands"
  end

  it "scrolls the heading to just below the top of the window" do
    top = evaluate_script("document.getElementById('where-it-lands').getBoundingClientRect().top")

    expect(top).to be_within(2).of(96)
  end
end
