# frozen_string_literal: true

RSpec.describe "Admin work history", type: :feature do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:repo) { Projects::Slice["repos.work_entry_queries"] }

  before do
    sign_in_to_admin
    visit "/admin/projects"
    find(".seg-option", text: "work").click
  end

  it "submits the segment" do
    expect(page).to have_current_path("/admin/projects?filter=work")
  end

  describe "the add form" do
    it "starts with Add role disabled" do
      expect(page).to have_button("Add role", disabled: true)
    end

    it "keeps it disabled with only the organization" do
      fill_in "work_entry[org]", with: "Rackspace"

      expect(page).to have_button("Add role", disabled: true)
    end

    it "keeps it disabled with only the role" do
      fill_in "work_entry[role]", with: "Software Engineer"

      expect(page).to have_button("Add role", disabled: true)
    end

    it "enables it once both are filled" do
      fill_in "work_entry[org]", with: "Rackspace"
      fill_in "work_entry[role]", with: "Software Engineer"

      expect(page).to have_button("Add role", disabled: false)
    end

    it "disables it again when one is only spaces" do
      fill_in "work_entry[org]", with: "Rackspace"
      fill_in "work_entry[role]", with: "Software Engineer"
      fill_in "work_entry[org]", with: "   "

      expect(page).to have_button("Add role", disabled: true)
    end
  end

  describe "adding a role" do
    before do
      fill_in "work_entry[org]", with: "Rackspace"
      fill_in "work_entry[role]", with: "Software Engineer"
      fill_in "work_entry[from_year]", with: "2018"
      click_button "Add role"
    end

    it "says what happened" do
      expect(page).to have_css("[data-toast]", text: "Role added to /projects")
    end

    it "lists the role" do
      expect(page).to have_css(".work-row-title", text: "Software Engineer")
    end

    it "reads a role with no end year as current" do
      expect(page).to have_css(".work-row-meta", text: "Rackspace · 2018–Present")
    end

    it "shows the role on the public page" do
      page.assert_selector("[data-toast]", text: "Role added to /projects")
      visit "/about"

      expect(page).to have_css(".rows .row h3", text: "Software Engineer")
    end
  end

  describe "removing a role" do
    let!(:entry) { create(:work_entry, org: "Rackspace", role: "Software Engineer") }

    before do
      visit "/admin/projects?filter=work"
      find(".work-row").hover
    end

    it "asks with the confirmation text" do
      message = confirm_no { click_button "Remove" }
      confirm = i18n.t("ui.components.work_entries.row.confirm_remove", org: "Rackspace", role: "Software Engineer")

      expect(message).to eq(confirm)
    end

    it "keeps the role when I don't confirm" do
      confirm_no { click_button "Remove" }

      expect(repo.all.map(&:id)).to eq([entry.id])
    end

    it "removes the role once I confirm" do
      confirm_yes { click_button "Remove" }

      expect(page).to have_css("[data-toast]", text: "Role removed from /projects")
    end

    it "takes the role off the list" do
      confirm_yes { click_button "Remove" }

      expect(page).to have_no_css(".work-row-title", text: "Software Engineer")
    end

    it "takes the role off the public page" do
      confirm_yes { click_button "Remove" }
      page.assert_selector("[data-toast]", text: "Role removed from /projects")
      visit "/about"

      expect(page).to have_css("h1.page-title").and have_no_css(".rows .row")
    end
  end
end
