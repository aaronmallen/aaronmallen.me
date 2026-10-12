# frozen_string_literal: true

RSpec.describe "Admin bulk menus", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  def fields(form) = form.all("input", visible: :all).map { [it[:name], it.value] }

  def head = page.find("[data-context-menu] > .ctx-head").text

  def items = page.all(".ctx-label", visible: :all).map { it.text(:all) }

  def menu_form(label, within: page)
    within.find(".ctx-item", exact_text: label, visible: :all).ancestor("form", visible: :all)
  end

  def submenu(label) = page.find("[aria-haspopup]", text: label, visible: :all).sibling("[role=menu]", visible: :all)

  describe "signed out" do
    it "sends me to sign in" do
      get "/admin/tasks/bulk/menu", ids: [create(:task).id]

      expect(last_response).to be_redirect
    end
  end

  describe "signed in" do
    before { sign_in_to_admin }

    %w[tasks posts webmentions].each do |kind|
      it "answers 404 for #{kind} with nothing picked" do
        get "/admin/#{kind}/bulk/menu", ids: ["nope"]

        expect(last_response.status).to eq(404)
      end
    end

    describe "for tasks" do
      let(:tasks) { %w[one two three].map { create(:task, title: it) } }

      before do
        create(:tag, :private, name: "home")
        create(:tag, :private, name: "work")
        create(:tag, name: "ruby")
        Tasks::Slice["repos.task_mutations"].replace_tags(tasks.first.id, ["work"])
        get "/admin/tasks/bulk/menu", ids: tasks.map(&:id), filter: "next", q: "o", page: "2"
      end

      it "names how many tasks it acts on" do
        expect(head).to eq("3 tasks picked")
      end

      it "holds every bulk action" do
        expect(items).to include("Complete", "Move to", "Add tag", "Remove tag", "Cancel", "Delete", "Clear selection")
      end

      it "posts each action to the bulk route with every picked task and the list's place", :aggregate_failures do
        form = menu_form("Complete")

        expect(form[:action]).to eq("/admin/tasks/bulk")
        expect(fields(form)).to include(
          *tasks.map { ["ids[]", it.id.to_s] }, %w[act complete], %w[filter next], %w[q o], %w[page 2],
        )
      end

      it "moves to a list" do
        expect(fields(menu_form("Someday"))).to include(%w[act move], %w[to someday])
      end

      it "adds only private tags and removes the ones the picked tasks hold", :aggregate_failures do
        expect(fields(menu_form("#home", within: submenu("Add tag")))).to include(%w[act tag], %w[tag home])
        expect(fields(menu_form("#work", within: submenu("Remove tag")))).to include(%w[act untag], %w[tag work])
        expect(submenu("Remove tag")).to have_no_text("#home", wait: 0)
        expect(items).not_to include("#ruby")
      end

      it "asks before it deletes" do
        expect(page).to have_css("button[data-confirm-inline='Click again to delete']", text: "Delete")
      end

      it "clears the picks in the browser" do
        expect(page).to have_css("button[type=button][data-bulk-clear=task-bulk]", text: "Clear selection")
      end
    end

    describe "for posts" do
      let(:posts) { [create(:post, :draft), create(:post, :draft)] }

      before do
        create(:tag, name: "ruby")
        create(:tag, :private, name: "home")
        get "/admin/posts/bulk/menu", ids: posts.map(&:id), status: "draft"
      end

      it "names how many posts it acts on" do
        expect(head).to eq("2 posts picked")
      end

      it "adds only public tags and holds no remove when no post has a tag", :aggregate_failures do
        expect(fields(menu_form("#ruby"))).to include(%w[act tag], %w[tag ruby], %w[status draft])
        expect(items).not_to include("#home", "Remove tag")
      end

      it "deletes every picked post on a second click", :aggregate_failures do
        form = menu_form("Delete")

        expect(fields(form)).to include(*posts.map { ["ids[]", it.id.to_s] }, %w[act delete])
        expect(form).to have_css("button[data-confirm-inline]", visible: :all)
      end
    end

    describe "for webmentions" do
      let(:mentions) { [create(:webmention), create(:webmention)] }

      before { get "/admin/webmentions/bulk/menu", ids: mentions.map(&:id), status: "pending" }

      it "names how many webmentions it acts on" do
        expect(head).to eq("2 webmentions picked")
      end

      it "offers each verdict the list has not reached", :aggregate_failures do
        expect(items).to eq(%w[Approve Ignore Spam])
        expect(fields(menu_form("Approve"))).to include(*mentions.map { ["ids[]", it.id.to_s] }, %w[act approved])
      end

      it "leaves out the verdict of the list it opened on" do
        get "/admin/webmentions/bulk/menu", ids: mentions.map(&:id), status: "spam"

        expect(items).to eq(%w[Approve Ignore])
      end
    end

    describe "bulk bars" do
      it "carry the tasks menu with the list's place" do
        create(:task)
        get "/admin/tasks", filter: "next"

        expect(page).to have_css("form#task-bulk[data-bulk-menu='/admin/tasks/bulk/menu?filter=next']")
      end

      it "carry the posts menu" do
        create(:post, :draft)
        get "/admin/posts"

        expect(page).to have_css("form#post-bulk[data-bulk-menu^='/admin/posts/bulk/menu']")
      end

      it "carry the webmentions menu" do
        create(:webmention)
        get "/admin/webmentions"

        expect(page).to have_css("form#webmention-bulk[data-bulk-menu^='/admin/webmentions/bulk/menu']")
      end
    end
  end
end
