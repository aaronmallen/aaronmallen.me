# frozen_string_literal: true

RSpec.describe "Admin post, social, project and person row menus", type: :feature do
  def item(label) = menu.first(".ctx-item", text: label)

  def keep_page = execute_script("window.kept = true")

  def kept_page? = evaluate_script("window.kept === true")

  def menu = find("[data-context-menu]")

  def open_menu(row) = find(row).right_click

  before { sign_in_to_admin }

  describe "a post" do
    let(:post_record) { create(:post, :draft, title: "Hello") }

    before do
      create(:tag, name: "ruby")
      create(:tag, :private, name: "home")
      post_record
      visit "/admin/posts"
      keep_page
      open_menu(".li[data-menu] .pill")
    end

    it "lists only public tags" do
      item("Tags").hover

      expect(menu).to have_css("[role=menuitemcheckbox]", text: "#ruby").and have_no_text("#home")
    end

    it "tags it in place on a tick", :aggregate_failures do
      item("Tags").hover
      item("#ruby").click

      expect(page).to have_css(".toast", text: "Tagged 1 post ruby")
      expect(page).to have_css(".li .tag", text: "ruby")
      expect(kept_page?).to be(true)
    end

    it "asks for a second click before it deletes" do
      item("Delete draft").click

      expect(item("Click again to delete")).to be_truthy
    end

    it "deletes the draft in place on the second click", :aggregate_failures do
      item("Delete draft").click
      item("Click again to delete").click

      expect(page).to have_css(".toast", text: "Deleted 1 draft")
      expect(page).to have_no_css(".li[data-menu]")
      expect(kept_page?).to be(true)
    end
  end

  describe "a project" do
    let(:project) { create(:project, name: "Hanami") }

    before do
      create(:tag, name: "ruby")
      Projects::Slice["repos.project_mutations"].add_tag(project.id, "ruby")
      visit "/admin/projects"
      keep_page
      open_menu(".project-card")
    end

    it "untags it in place on an untick", :aggregate_failures do
      item("Tags").hover
      item("#ruby").click

      expect(page).to have_css(".toast", text: "Took ruby off")
      expect(Projects::Slice["repos.project_queries"].by_id(project.id).tags).to be_empty
      expect(kept_page?).to be(true)
    end

    it "archives it in place" do
      item("Archive").click

      expect(page).to have_css(".toast", text: Admin::Slice["i18n"].t("projects_page.toasts.archived"))
    end
  end

  describe "a queued social post" do
    before do
      create(:social_post, :scheduled)
      visit "/admin/social"
      keep_page
      open_menu(".sq-item")
      item("Remove from queue").click
      item("Click again to remove").click
    end

    it "removes it in place on the second click", :aggregate_failures do
      expect(page).to have_css(".toast", text: Admin::Slice["i18n"].t("social_page.toasts.removed"))
      expect(page).to have_no_css(".sq-item")
      expect(kept_page?).to be(true)
    end
  end

  describe "a person" do
    before do
      create(:person, key: "matz")
      visit "/admin/people"
      watch_clipboard
      open_menu(".person-row")
    end

    it "copies the mention and shows a toast", :aggregate_failures do
      item("Copy mention").click

      expect(page).to have_css(".toast", text: "Mention copied")
      expect(evaluate_script("window.copiedKeys")).to eq(["@{matz}"])
    end

    it "removes the person on the second click", :aggregate_failures do
      item("Remove").click
      item("Click again to remove").click

      expect(page).to have_css(".toast", text: Admin::Slice["i18n"].t("people_page.toasts.removed"))
      expect(page).to have_no_css(".person-row")
    end
  end
end
