# frozen_string_literal: true

RSpec.describe "Privacy layout", type: :feature do
  before { visit "/privacy" }

  it "sets the body in the serif face" do
    expect(evaluate_script("getComputedStyle(document.querySelector('.prose')).fontFamily")).to start_with("Newsreader")
  end
end
