# frozen_string_literal: true

RSpec.describe "Admin search screen", type: :feature do
  before do
    create(:message, subject: "Zeppelin sighting")
    sign_in_to_admin
    visit "/admin/search?q=zeppelin"
  end

  it "submits the filter with the query once a kind is chosen" do
    select("Messages", from: "kind")

    expect(page).to have_current_path("/admin/search?q=zeppelin&kind=message")
  end
end
