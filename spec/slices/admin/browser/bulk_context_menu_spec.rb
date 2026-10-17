# frozen_string_literal: true

RSpec.describe "Admin bulk context menu", type: :feature do
  def item(label) = menu.first(".ctx-item", exact_text: label)

  def menu = find("[data-context-menu]")

  def ticked = page.all("input[name='ids[]']:checked").size

  before { sign_in_to_admin }

  describe "on tasks" do
    let!(:tasks) do
      %w[first second third fourth].map.with_index(1) do |title, position|
        create(:task, title:, position:)
      end
    end

    def box(title) = row(title).find("input[name='ids[]']")

    def open_menu(title) = row(title).find(".record-key").right_click

    def row(title) = find(".task-title", exact_text: title).ancestor(".task")

    before do
      visit "/admin/tasks?filter=next"
      click_button("Select")
      %w[first second third].each { box(it).check }
    end

    it "opens a bulk menu on a picked row that names how many are picked" do
      open_menu("second")

      expect(menu).to have_css(".ctx-head", exact_text: "3 tasks picked")
    end

    it "completes every picked task", :aggregate_failures do
      open_menu("second")
      item("Complete").click

      expect(page).to have_css(".toast", text: "Finished 3 tasks")
      expect(open_tasks.map(&:title)).to eq(["fourth"])
    end

    it "moves every picked task" do
      open_menu("first")
      item("Move to").hover
      item("Someday").click

      expect(page).to have_css(".toast", text: "Moved 3 tasks")
    end

    it "tags every picked task" do
      create(:tag, :private, name: "home")
      open_menu("third")
      item("Add tag").hover
      item("#home").click

      expect(page).to have_css(".toast", text: "Tagged 3 tasks")
    end

    describe "deleting" do
      before do
        open_menu("first")
        item("Delete").click
      end

      it "asks for a second click" do
        expect(open_tasks.size).to eq(4)
      end

      it "deletes every picked task on the second click", :aggregate_failures do
        item("Click again to delete").click

        expect(page).to have_css(".toast", text: "Deleted 3 tasks")
        expect(open_tasks.map(&:title)).to eq(["fourth"])
      end
    end

    it "clears the selection", :aggregate_failures do
      open_menu("first")
      item("Clear selection").click

      expect(page).to have_no_css("[data-context-menu]")
      expect(ticked).to eq(0)
    end

    it "opens a row's own menu when the row is not picked" do
      open_menu("fourth")

      expect(menu).to have_css(".ctx-head", exact_text: "#{tasks.last.number} · fourth")
    end

    it "opens a row's own menu when it is the only one picked" do
      %w[first second].each { box(it).uncheck }
      open_menu("third")

      expect(menu).to have_css(".ctx-head", exact_text: "#{tasks[2].number} · third")
    end
  end

  describe "on posts" do
    let(:post_mutations) { Posts::Slice["repos.post_mutations"] }
    let(:post_queries) { Posts::Slice["repos.post_queries"] }

    def box(title) = row(title).find("input[name='ids[]']")

    def row(title) = find(".li", text: title)

    def titles = post_queries.all.map(&:title)

    before do
      create(:tag, name: "go")
      create(:tag, name: "ruby")
      %w[one two three].each { post_mutations.replace_tags(create(:post, :draft, title: "#{it} draft").id, ["ruby"]) }
      visit "/admin/posts"
      %w[one two three].each { box("#{it} draft").check }
      row("two draft").find(".li-sub").right_click
    end

    it "names how many posts are picked" do
      expect(menu).to have_css(".ctx-head", exact_text: "3 posts picked")
    end

    it "tags every picked post" do
      item("Add tag").hover
      item("#go").click

      expect(page).to have_css(".toast", text: "Tagged 3 posts")
    end

    it "untags every picked post" do
      item("Remove tag").hover
      item("#ruby").click

      expect(page).to have_css(".toast", text: "Took ruby off 3 posts")
    end

    it "deletes every picked post on a second click", :aggregate_failures do
      item("Delete").click
      expect(titles.size).to eq(3)

      item("Click again to delete").click
      expect(page).to have_css(".toast", text: "Deleted 3 drafts")
      expect(titles).to be_empty
    end
  end

  describe "on webmentions" do
    let(:relation) { Social::Slice["relations.webmentions"] }

    def box(author) = row(author).find("input[name='ids[]']")

    def row(author) = find(".wm-card", text: author)

    before do
      target = create(:post, :published)
      %w[Ada Grace Alan].each { create(:webmention, post_id: target.id, author_name: it) }
      visit "/admin/webmentions"
      %w[Ada Grace Alan].each { box(it).check }
      row("Grace").first(".wm-excerpt, blockquote, p").right_click
    end

    it "names how many webmentions are picked" do
      expect(menu).to have_css(".ctx-head", exact_text: "3 webmentions picked")
    end

    it "approves every picked webmention", :aggregate_failures do
      item("Approve").click

      expect(page).to have_css(".toast", text: "Approved 3 webmentions")
      expect(relation.where(status: "approved").count).to eq(3)
    end
  end
end
