# frozen_string_literal: true

RSpec.describe "Admin project tag summary", type: :request do
  let(:project) { create(:project, name: "blog", key: "BLOG") }
  let(:bug) { create(:tag, name: "bug", scope: "project", project_id: project.id, description: "something broke") }

  def card(kind) = page.find(".card", text: says("kinds.#{kind}"))

  def hold(table, owner_key, record, tag = bug)
    row = { owner_key => record.id, tag_id: tag.id, tag_scope: "project" }
    Tasks::Slice["relations.task_tags"].dataset.db[table].insert(row)
  end

  def says(key, **) = Admin::Slice["i18n"].t(["ui.views.tags.show", key].join("."), **)

  def titles_in(kind) = card(kind).all(".li-title").map(&:text)

  describe "signed in" do
    before { sign_in_to_admin }

    describe "a tag on every kind that takes one" do
      before do
        hold(:post_tags, :post_id, create(:post, :published, title: "Fixing the feed"))
        hold(:task_tags, :task_id, create(:task, title: "Fix the feed"))
        hold(:journal_entry_tags, :journal_entry_id, create(:journal_entry, body: "Chased the feed bug"))
        hold(:decision_tags, :decision_id, create(:decision, title: "Drop the feed"))
        other = create(:tag, name: "bug", scope: "project", project_id: create(:project, name: "pod").id)
        hold(:task_tags, :task_id, create(:task, title: "Another project's bug"), other)
        create(:task, title: "A private bug", tags: %w[bug])
        get "/admin/projects/blog/tags/bug"
      end

      it "groups every kind holding the project's tag and nothing else", :aggregate_failures do
        expect(titles_in(:posts)).to eq(["Fixing the feed"])
        expect(titles_in(:tasks)).to eq(["Fix the feed"])
        expect(titles_in(:journal_entries)).to eq(["Chased the feed bug"])
        expect(titles_in(:decisions)).to eq(["Drop the feed"])
      end

      it "has no projects card" do
        expect(page).to have_no_css(".card", text: says("kinds.projects"))
      end

      it "links the tag on each card to this page" do
        expect(card(:tasks)).to have_link("#bug", href: "/admin/projects/BLOG/tags/bug")
      end

      it "names the project on each card" do
        expect(card(:tasks)).to have_css(".card-label", text: "blog")
      end

      it "counts what carries the tag" do
        expect(page).to have_css(".page-head-sub", text: says("count", count: 4))
      end

      it "leads back to the project" do
        expect(page).to have_link("blog", href: "/admin/projects/#{project.id}")
      end

      it "leaves the project tag off the global page of the name" do
        get "/admin/tags/bug"

        expect(titles_in(:tasks)).to eq(["A private bug"])
      end
    end

    describe "a kind with more than the page shows" do
      let(:all_tasks) { "/admin/projects/BLOG/tags/bug?kind=tasks" }

      before do
        lower_page_size(:admin, to: 6)
        11.times { |n| hold(:task_tags, :task_id, create(:task, title: "Bug #{n}")) }
      end

      it "caps the kind and links to the rest", :aggregate_failures do
        get "/admin/projects/BLOG/tags/bug"

        expect(titles_in(:tasks).size).to eq(Admin::Actions::Tags::Show::CAP)
        expect(card(:tasks)).to have_link(says("all", count: 11), href: all_tasks)
      end

      it "pages that kind alone", :aggregate_failures do
        get all_tasks

        expect(titles_in(:tasks).size).to eq(6)
        expect(page).to have_link(href: "#{all_tasks}&page=2")
      end

      it "answers 404 past the last page" do
        get "#{all_tasks}&page=3"

        expect(last_response.status).to eq(404)
      end
    end

    it "says when nothing carries the tag" do
      bug
      get "/admin/projects/BLOG/tags/bug"

      expect(page).to have_text(says("empty"))
    end

    it "answers 404 for a project no key names" do
      bug
      get "/admin/projects/NOPE/tags/bug"

      expect(last_response.status).to eq(404)
    end

    it "answers 404 for a name the project lacks" do
      create(:tag, name: "bug", scope: "project", project_id: create(:project, name: "pod").id)
      get "/admin/projects/BLOG/tags/bug"

      expect(last_response.status).to eq(404)
    end

    it "answers 404 for a private tag of the name" do
      project
      create(:tag, :private, name: "bug")
      get "/admin/projects/BLOG/tags/bug"

      expect(last_response.status).to eq(404)
    end

    it "answers 404 for the projects kind" do
      bug
      get "/admin/projects/BLOG/tags/bug", kind: "projects"

      expect(last_response.status).to eq(404)
    end

    it "links each tag in the project's tag manager to its page" do
      bug
      get "/admin/projects/#{project.id}"

      expect(page.find_by_id("project-tags", visible: :all))
        .to have_link("#bug", href: "/admin/projects/BLOG/tags/bug", visible: :all)
    end
  end
end
