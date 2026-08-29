# frozen_string_literal: true

RSpec.describe "Admin project editor", type: :feature do
  let(:repo) { Projects::Slice["repos.project_repo"] }

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

      expect(page).to have_css(".proj .n", text: "sai")
    end

    it "shows the tagline in the preview card as it is typed" do
      fill_in "project[tagline]", with: "Terminal colors"

      expect(page).to have_css(".proj p", text: "Terminal colors")
    end

    it "shows the repository under the name as it is typed" do
      fill_in "project[repo]", with: "aaronmallen/sai"

      expect(page).to have_css(".page-head-sub", text: "aaronmallen/sai")
    end

    it "creates the project" do
      fill_in "project[name]", with: "sai"
      fill_in "project[repo]", with: "aaronmallen/sai"
      click_button "Create project"

      expect(page).to have_css("[data-toast]", text: "Project created")
    end

    it "fills the url from the repository on save" do
      fill_in "project[name]", with: "sai"
      fill_in "project[repo]", with: "aaronmallen/sai"
      click_button "Create project"

      expect(page).to have_field("project[url]", with: "https://github.com/aaronmallen/sai")
    end
  end

  describe "an existing project" do
    let!(:project) do
      create(:project, :featured, name: "sai", repo: "aaronmallen/sai", url: "https://github.com/aaronmallen/sai")
    end

    before { visit "/admin/projects/#{project.id}/edit" }

    it "keeps the preview card out of the tab order" do
      expect(page).to have_css("a.proj[tabindex='-1']")
    end

    it "saves the changes" do
      fill_in "project[tagline]", with: "Terminal colors"
      click_button "Save project"

      expect(repo.by_id(project.id).tagline).to eq("Terminal colors")
    end

    it "archives from the editor" do
      click_button "Archive"

      expect(repo.by_id(project.id)).to have_attributes(status: "archived", featured: false)
    end

    it "lands on the archived list after archiving" do
      click_button "Archive"

      expect(page).to have_current_path("/admin/projects?filter=archived")
    end

    it "restores from the editor" do
      click_button "Archive"
      find(".li-side a", text: "Edit").click
      click_button "Restore"

      expect(repo.by_id(project.id).status).to eq("active")
    end

    it "reaches the editor from the list" do
      visit "/admin/projects"
      find(".li-side a", text: "Edit").click

      expect(page).to have_field("project[name]", with: "sai")
    end

    it "reaches the new editor from the list" do
      visit "/admin/projects"
      click_link "New project"

      expect(page).to have_button("Create project", disabled: true)
    end
  end
end
