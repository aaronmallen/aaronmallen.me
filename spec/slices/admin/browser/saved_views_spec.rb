# frozen_string_literal: true

RSpec.describe "Admin saved views", type: :feature do
  let(:repo) { SavedViews::Slice["repos.saved_view_queries"] }

  def bar = find(".saved-views")

  def confirm_dialog = find("dialog#confirm-dialog[open]")

  def manage(name)
    find(".saved-view", text: name).find("summary").click
    find(".saved-view", text: name).find(".saved-view-panel")
  end

  def save_view(name)
    bar.find("summary", text: "Save view").click
    panel = bar.find("details[open] > .saved-view-panel")
    panel.fill_in("Name", with: name)
    panel.click_on("Save view")
  end

  before { sign_in_to_admin }

  {
    "tasks" => ["/admin/tasks?filter=next&q=accountant", "/admin/tasks?filter=someday"],
    "posts" => ["/admin/posts?status=draft", "/admin/posts?status=published"],
    "journal" => ["/admin/journal?q=commute", "/admin/journal?q=ruby"],
    "activity" => ["/admin/activity?q=ship", "/admin/activity?q=deploy"],
  }.each do |screen, (first, second)|
    describe "on the #{screen} screen" do
      before do
        visit first
        save_view("Weekly")
        find(".saved-view-link", text: "Weekly")
      end

      it "saves the filters under the name", :aggregate_failures do
        view = repo.all.first

        expect(view).to have_attributes(name: "Weekly", screen:)
        expect(page).to have_current_path(first)
      end

      it "opens the view with its filters set" do
        visit second.split("?").first
        click_on "Weekly"

        expect(page).to have_current_path(first)
      end

      it "renames the view" do
        panel = manage("Weekly")
        panel.fill_in("Name", with: "Monthly")
        panel.click_on("Rename")

        expect(page).to have_css(".saved-view-link", text: "Monthly")
      end

      it "changes the view to the filters on screen" do
        visit second
        manage("Weekly").click_on("Use current filters")
        find(".toast", text: "View now holds these filters")

        expect(page).to have_link("Weekly", href: second)
      end

      it "deletes the view, and it leaves the list" do
        manage("Weekly").click_on("Delete")
        confirm_dialog.click_on("Yes")

        expect(page).to have_no_css(".saved-view-link")
      end
    end
  end
end
