# frozen_string_literal: true

RSpec.describe "Admin projects", type: :feature do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:repo) { Projects::Slice["repos.project_repo"] }

  let!(:live) { create(:project, :featured, name: "live-one") }

  before do
    create(:project, :archived, name: "gone")
    sign_in_to_admin
    visit "/admin/projects"
  end

  it "lists the live projects" do
    expect(page).to have_css(".li", count: 1).and have_css(".li-title", text: "live-one")
  end

  describe "choosing archived" do
    before { find(".seg-option", text: "archived").click }

    it "submits the segment" do
      expect(page).to have_current_path("/admin/projects?filter=archived")
    end

    it "lists only the archived projects", :aggregate_failures do
      expect(page).to have_css(".li-title", text: "gone")
      expect(page).to have_no_css(".li-title", text: "live-one")
    end

    it "keeps archived chosen" do
      expect(page).to have_checked_field("filter", with: "archived", visible: :all)
    end

    it "restores a project" do
      click_button "Restore"

      expect(page).to have_css("[data-toast]", text: "Restored to /projects")
    end

    it "takes the restored project off the archived list" do
      click_button "Restore"

      expect(page).to have_no_css(".li-title", text: "gone")
    end
  end

  describe "reordering" do
    let!(:below) { create(:project, :featured, name: "live-two", position: live.position + 100) }

    before { visit "/admin/projects" }

    def names = page.all(".li-title").map(&:text)

    it "lists the projects in position order" do
      expect(names).to eq(%w[live-one live-two])
    end

    it "moves a project up" do
      find("[aria-label='Move live-two up']").click

      expect(names).to eq(%w[live-two live-one])
    end

    it "moves a project down" do
      find("[aria-label='Move live-one down']").click

      expect(names).to eq(%w[live-two live-one])
    end

    it "moves a project back where it came from" do
      find("[aria-label='Move live-two up']").click
      find("[aria-label='Move live-two down']").click

      expect(names).to eq(%w[live-one live-two])
    end

    it "reorders the public page" do
      find("[aria-label='Move live-two up']").click
      page.assert_selector("[aria-label='Move live-two up'][disabled]")
      visit "/projects"

      expect(page.all(".projs .proj .n").map(&:text)).to eq(%w[live-two live-one])
    end

    it "disables the first up and the last down", :aggregate_failures do
      expect(find("[aria-label='Move live-one up']")).to be_disabled
      expect(find("[aria-label='Move live-two down']")).to be_disabled
    end

    it "dims a disabled caret" do
      expect(find("[aria-label='Move live-one up']").style("opacity")).to eq("opacity" => "0.3")
    end

    it "keeps the position of the project it swapped with" do
      find("[aria-label='Move live-two up']").click
      page.assert_selector("[aria-label='Move live-two up'][disabled]")

      expect(repo.by_id(below.id).position).to eq(live.position)
    end
  end

  describe "archiving" do
    before { click_button "Archive" }

    it "says what happened" do
      expect(page).to have_css("[data-toast]", text: "Archived · removed from /projects")
    end

    it "takes the project off the live list" do
      expect(page).to have_css(".empty", text: i18n.t("ui.views.projects.index.empty.live"))
    end

    it "unfeatures the project" do
      page.assert_selector("[data-toast]", text: "Archived · removed from /projects")

      expect(repo.by_id(live.id)).to have_attributes(status: "archived", featured: false)
    end

    it "shows the project on the archived list" do
      find(".seg-option", text: "archived").click

      expect(page).to have_css(".li-title", text: "live-one")
    end
  end
end
