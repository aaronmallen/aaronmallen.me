# frozen_string_literal: true

RSpec.describe "Admin project editor", type: :feature do
  before { sign_in_to_admin }

  describe "a new project" do
    before { visit "/admin/projects/new" }

    it "starts with the primary action disabled" do
      expect(page).to have_button("Create project", disabled: true)
    end

    it "enables the primary action once the name is typed" do
      fill_in "project[name]", with: "sai"

      expect(page).to have_button("Create project", disabled: false)
    end

    it "disables it again when the name is only spaces" do
      fill_in "project[name]", with: "sai"
      fill_in "project[name]", with: "   "

      expect(page).to have_button("Create project", disabled: true)
    end

    it "shows the name in the preview card as it is typed" do
      fill_in "project[name]", with: "sai"

      expect(page).to have_css(".pc .pn", text: "sai")
    end

    it "shows the tagline in the preview card as it is typed" do
      fill_in "project[tagline]", with: "Terminal colors"

      expect(page).to have_css(".pc p", text: "Terminal colors")
    end

    it "shows the repository under the name as it is typed" do
      fill_in "project[repo]", with: "aaronmallen/sai"

      expect(page).to have_css(".page-head-sub", text: "aaronmallen/sai")
    end

    it "creates the project" do
      fill_in "project[name]", with: "sai"
      fill_in "project[repo]", with: "aaronmallen/sai"
      select "Public", from: "project[visibility]"
      click_button "Create project"

      expect(page).to have_css("[data-toast]", text: "Project created")
    end

    it "fills the url from the repository on save" do
      fill_in "project[name]", with: "sai"
      fill_in "project[repo]", with: "aaronmallen/sai"
      select "Public", from: "project[visibility]"
      click_button "Create project"

      expect(page).to have_field("project[url]", with: "https://github.com/aaronmallen/sai")
    end
  end

  describe "an existing project" do
    let!(:project) do
      create(:project, name: "sai", repo: "aaronmallen/sai", url: "https://github.com/aaronmallen/sai")
    end

    before { visit "/admin/projects/#{project.id}/edit" }

    it "keeps the preview card out of the tab order" do
      expect(page).to have_css("a.pc[tabindex='-1']")
    end
  end
end
