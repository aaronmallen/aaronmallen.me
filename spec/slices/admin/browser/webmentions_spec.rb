# frozen_string_literal: true

RSpec.describe "Admin webmentions", type: :feature do
  before do
    sign_in_to_admin
    visit "/admin/webmentions"
  end

  it "saves a setting turned off without a button" do
    uncheck "Receive webmentions"

    expect(page).to have_css(".toast", text: "Settings saved")
  end
end
