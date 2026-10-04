# frozen_string_literal: true

RSpec.describe "Admin projects", type: :feature do
  before do
    create(:project, :featured, name: "live-one")
    create(:project, :archived, name: "gone")
    sign_in_to_admin
    visit "/admin/projects"
  end

  it "submits the segment once archived is chosen" do
    find(".seg-option", text: "archived").click

    expect(page).to have_current_path("/admin/projects?filter=archived")
  end
end
