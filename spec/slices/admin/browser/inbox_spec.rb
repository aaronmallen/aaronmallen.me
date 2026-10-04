# frozen_string_literal: true

RSpec.describe "Admin inbox", type: :feature do
  let(:task) { create(:task, title: "Fix the feed", list: "external") }

  before do
    create(:task_source, task:)
    create(:message, subject: "A question")
    create(:webmention, author_name: "Ada Lovelace")
    sign_in_to_admin
    visit "/admin/inbox"
  end

  it "drops a message marked read" do
    find(".li", text: "A question").click_button("Read")

    expect(page).to have_no_css(".li-title", text: "A question")
  end

  it "drops an approved webmention" do
    find(".li", text: "Ada Lovelace").click_button("Approve")

    expect(page).to have_no_css(".li-title", text: "Ada Lovelace")
  end

  it "drops a synced issue marked seen", :aggregate_failures do
    find(".li", text: "Fix the feed").click_button("Seen")

    expect(page).to have_css("[data-toast]", text: "Marked seen")
    expect(page).to have_no_css(".li-title", text: "Fix the feed")
  end

  it "drops a synced issue once tagged" do
    within(".li", text: "Fix the feed") do
      find("input[name='tags']").set("feeds")
      click_button "Tag"
    end

    expect(page).to have_no_css(".li-title", text: "Fix the feed")
  end
end
