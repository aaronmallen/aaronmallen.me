# frozen_string_literal: true

RSpec.describe "Admin projects", type: :feature do
  let!(:live) { create(:project, :featured, name: "live-one") }

  before do
    create(:project, :archived, name: "gone")
    sign_in_to_admin
    visit "/admin/projects"
  end

  it "submits the segment once archived is chosen" do
    find(".seg-option", text: "archived").click

    expect(page).to have_current_path("/admin/projects?filter=archived")
  end

  describe "reordering" do
    before do
      create(:project, :featured, name: "live-two", position: live.position + 100)
      visit "/admin/projects"
    end

    it "dims a disabled caret" do
      expect(find("[aria-label='Move live-one up']").style("opacity")).to eq("opacity" => "0.3")
    end
  end
end
