# frozen_string_literal: true

RSpec.describe "Admin tag summary", type: :request do
  def card(kind) = page.find(".card", text: says("kinds.#{kind}"))

  def journal_path(entry)
    day = entry.entry_date.iso8601
    "/admin/journal?to=#{day}#day-#{day}"
  end

  def page = Capybara.string(last_response.body)

  def says(key, **) = Admin::Slice["i18n"].t(["ui.views.tags.show", key].join("."), **)

  def tag_named(name, scope) = Tags::Slice["repos.tag_queries"].all_in(scope).find { it.name == name }

  describe "signed in" do
    before { sign_in_to_admin }

    describe "a name both scopes hold" do
      let!(:post_record) { create(:post, :published, title: "Ruby on a Pi", tags: %w[ruby]) }
      let!(:project) { create(:project, name: "ruby-gem", tags: %w[ruby]) }
      let!(:task) { create(:task, title: "Bump ruby", tags: %w[ruby]) }
      let!(:entry) { create(:journal_entry, body: "\nWrote some ruby\n\nall day", tags: %w[ruby]) }
      let!(:decision) { create(:decision, title: "Pick a ruby", tags: %w[ruby]) }

      before do
        create(:post, :published, title: "Rust on a Pi", tags: %w[rust])
        create(:task, title: "Bump rust", tags: %w[rust])
        get "/admin/tags/ruby"
      end

      it "groups every kind with the name and nothing else", :aggregate_failures do
        expect(titles_in(:posts)).to eq(["Ruby on a Pi"])
        expect(titles_in(:projects)).to eq(["ruby-gem"])
        expect(titles_in(:tasks)).to eq(["Bump ruby"])
        expect(titles_in(:journal_entries)).to eq(["Wrote some ruby"])
        expect(titles_in(:decisions)).to eq(["Pick a ruby"])
      end

      it "draws the public tag on public kinds and the private tag on private kinds", :aggregate_failures do
        public_tag, private_tag = %w[public private].map { |scope| tag_named("ruby", scope) }

        expect(card(:posts)).to have_css(".tag.#{public_tag.color.delete_prefix('mk-')}", text: "#ruby")
        expect(card(:tasks)).to have_css(".tag.#{private_tag.color.delete_prefix('mk-')}", text: "#ruby")
        expect(card(:decisions)).to have_css(".tag.#{private_tag.color.delete_prefix('mk-')}", text: "#ruby")
      end

      it "links each item to its own admin page", :aggregate_failures do
        expect(page).to have_link("Ruby on a Pi", href: "/admin/posts/#{post_record.id}/edit")
        expect(page).to have_link("ruby-gem", href: "/admin/projects/#{project.id}/edit")
        expect(page).to have_link("Bump ruby", href: "/admin/tasks/#{task.id}")
        expect(page).to have_link("Wrote some ruby", href: journal_path(entry))
        expect(page).to have_link("Pick a ruby", href: "/admin/decisions/#{decision.id}")
      end

      it "counts what carries the name" do
        expect(page).to have_css(".page-head-sub", text: says("count", count: 5))
      end
    end

    describe "finished and hidden items" do
      before do
        create(:post, :draft, title: "A ruby draft", tags: %w[ruby])
        create(:project, :archived, name: "old-gem", tags: %w[ruby])
        create(:task, :done, title: "Shipped ruby", tags: %w[ruby])
        create(:task, :canceled, title: "Dropped ruby", tags: %w[ruby])
        create(:decision, title: "Ruby or not", status: "dropped", tags: %w[ruby])
        get "/admin/tags/ruby"
      end

      it "lists them", :aggregate_failures do
        expect(titles_in(:posts)).to eq(["A ruby draft"])
        expect(titles_in(:projects)).to eq(["old-gem"])
        expect(titles_in(:tasks)).to contain_exactly("Shipped ruby", "Dropped ruby")
        expect(titles_in(:decisions)).to eq(["Ruby or not"])
      end

      it "marks each status", :aggregate_failures do
        expect(card(:posts)).to have_css(".li", text: /A ruby draft.*Draft/im)
        expect(card(:projects)).to have_css(".li", text: /old-gem.*Archived/im)
        expect(card(:tasks)).to have_css(".li", text: /Shipped ruby.*Done/im)
        expect(card(:tasks)).to have_css(".li", text: /Dropped ruby.*Canceled/im)
        expect(card(:decisions)).to have_css(".li", text: /Ruby or not.*Dropped/im)
      end
    end

    it "cuts a long title to 80 characters" do
      create(:journal_entry, body: "a" * 85, tags: %w[ruby])

      get "/admin/tags/ruby"

      expect(titles_in(:journal_entries)).to eq(["#{'a' * 80}…"])
    end

    it "shows an empty state for a tag nothing carries", :aggregate_failures do
      create(:tag, :private, name: "unused")

      get "/admin/tags/unused"

      expect(last_response.status).to eq(200)
      expect(page).to have_css(".empty", text: says("empty"))
    end

    it "answers 404 for a name no tag holds" do
      get "/admin/tags/nothing"

      expect(last_response.status).to eq(404)
    end
  end

  def titles_in(kind) = card(kind).all(".li-title").map(&:text)
end
