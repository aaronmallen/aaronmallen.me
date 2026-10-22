# frozen_string_literal: true

RSpec.describe "Admin post, social, project and person row menus", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  def act(path, **) = admin_post(path, return_to: "/admin/x?y=1", **)

  def copies
    page.all("[data-copy]", visible: :all).to_h { [it.find(".ctx-label", visible: :all).text(:all), it["data-copy"]] }
  end

  def field(route, name) = page.find("form[action='#{route}'] input[name='#{name}']", visible: :all).value

  def menu(path) = get(path, return_to: "/admin/x?y=1")

  shared_examples "a row menu" do
    it "posts every action by fetch and morph back to the page it opened on", :aggregate_failures do
      forms = page.all("[data-context-menu] form", visible: :all)

      expect(page).to have_no_css("[data-context-menu] form:not([data-morph])", visible: :all)
      expect(forms.map { it.find("input[name=return_to]", visible: :all).value }.uniq).to eq(["/admin/x?y=1"])
    end
  end

  describe "signed in" do
    before { sign_in_to_admin }

    %w[posts social projects people].each do |kind|
      it "answers 404 for a #{kind} row that is gone" do
        get "/admin/#{kind}/0/menu"

        expect(last_response.status).to eq(404)
      end
    end

    describe "a published post" do
      let(:post_record) { create(:post, :published, title: "Hello", slug: "hello") }

      before do
        create(:tag, name: "ruby")
        create(:tag, name: "elixir")
        create(:tag, :private, name: "home")
        Posts::Slice["repos.post_mutations"].add_tag(post_record.id, "ruby")
        menu("/admin/posts/#{post_record.id}/menu")
      end

      it_behaves_like "a row menu"

      it "draws the menu headed by the post" do
        expect(page).to have_css("[data-context-menu] > .ctx-head", text: "Hello")
      end

      it "holds what a published post takes", :aggregate_failures do
        expect(menu_items).to include("Edit", "Analytics", "View on site", "Tags", "Copy link")
        expect(menu_items).not_to include("Keep writing", "Delete draft")
      end

      it "copies and opens the public link", :aggregate_failures do
        expect(copies.fetch("Copy link")).to end_with("/writing/hello")
        expect(page).to have_css("a.ctx-item[target=_blank][href$='/writing/hello']")
      end

      it "lists only public tags, ticked when the post has them", :aggregate_failures do
        expect(page).to have_css("[role=menuitemcheckbox][aria-checked=true]", text: "#ruby", visible: :all)
        expect(page).to have_css("[role=menuitemcheckbox][aria-checked=false]", text: "#elixir", visible: :all)
        expect(page).to have_no_css("[role=menuitemcheckbox]", text: "#home", visible: :all)
      end

      it "unticks and ticks through the bulk route", :aggregate_failures do
        fields = page.all("form[action='/admin/posts/bulk']", visible: :all).map do |form|
          form.all("input", visible: :all).to_h { [it[:name], it.value] }.slice("act", "ids[]", "tag")
        end

        expect(fields).to include({ "act" => "untag", "ids[]" => post_record.id.to_s, "tag" => "ruby" },
                                  { "act" => "tag", "ids[]" => post_record.id.to_s, "tag" => "elixir" })
      end
    end

    describe "a draft post" do
      let(:draft) { create(:post, :draft) }

      before { get "/admin/posts/#{draft.id}/menu", status: "draft", page: 2, return_to: "/admin/x?y=1" }

      it "offers keep writing and delete, and nothing that needs it live", :aggregate_failures do
        expect(menu_items).to include("Keep writing", "Tags", "Delete draft")
        expect(menu_items).not_to include("Edit", "Analytics", "View on site", "Copy link")
      end

      it "asks before it deletes" do
        expect(page).to have_css("button[data-confirm-inline='Click again to delete']", text: "Delete draft")
      end

      it "deletes through the bulk route with the list it opened on, so a gone page steps back" do
        form = page.find("form:has(button[data-confirm-inline])")
        fields = form.all("input", visible: :all).to_h { [it[:name], it.value] }

        expect(fields.except("_csrf_token"))
          .to eq("act" => "delete", "ids[]" => draft.id.to_s, "status" => "draft", "page" => "2")
      end
    end

    describe "a queued social post" do
      let(:social_post) { create(:social_post, :scheduled) }

      before { get "/admin/social/#{social_post.id}/menu", filter: "queued", return_to: "/admin/x?y=1" }

      it "holds what an unsent post takes", :aggregate_failures do
        expect(menu_items).to eq(["Edit", "Linked records", "Copy text", "Remove from queue"])
        expect(page).to have_css("a.ctx-item[href='/admin/social?filter=queued&edit=#{social_post.id}#social-links']")
      end

      it "copies the text" do
        expect(copies.fetch("Copy text")).to eq(social_post.parts.first.body)
      end

      it "asks before it removes, posting the queue it opened on", :aggregate_failures do
        form = page.find("form:has(button[data-confirm-inline])")

        expect(form).to have_button("Remove from queue")
        expect(form.all("input", visible: :all).map { it[:name] }).to contain_exactly("_csrf_token", "filter")
      end
    end

    describe "a draft social post" do
      it "deletes the draft" do
        menu("/admin/social/#{create(:social_post, :draft).id}/menu")

        expect(menu_items).to include("Delete draft")
      end
    end

    describe "a posted social post" do
      it "offers only the copy" do
        menu("/admin/social/#{create(:social_post, :posted).id}/menu")

        expect(menu_items).to eq(["Copy text"])
      end
    end

    describe "a live project" do
      let(:project) { create(:project, name: "Hanami", repo: "hanami/hanami", url: "https://hanamirb.org") }

      before do
        create(:tag, name: "ruby")
        create(:tag, :private, name: "home")
        Projects::Slice["repos.project_mutations"].add_tag(project.id, "ruby")
        menu("/admin/projects/#{project.id}/menu")
      end

      it_behaves_like "a row menu"

      it "holds what a live project takes", :aggregate_failures do
        expect(menu_items).to eq(["Open board", "Edit", "Open repo", "Open site", "Tags", "#ruby", "Copy repo",
                                  "Archive"])
      end

      it "opens and copies the repo", :aggregate_failures do
        expect(page).to have_css("a.ctx-item[target=_blank][href='https://github.com/hanami/hanami']")
        expect(page).to have_css("a.ctx-item[target=_blank][href='https://hanamirb.org']")
        expect(copies.fetch("Copy repo")).to eq("hanami/hanami")
      end

      it "lists only public tags and unticks through the untag route", :aggregate_failures do
        expect(page).to have_no_css("[role=menuitemcheckbox]", text: "#home", visible: :all)
        expect(field("/admin/projects/#{project.id}/tags/delete", "tag")).to eq("ruby")
      end

      it "tags through the tag route from the new tag field" do
        field = "form[action='/admin/projects/#{project.id}/tags'] input[name=tag][pattern]"

        expect(page).to have_css(field, visible: :all)
      end
    end

    describe "an archived project with no repo" do
      it "offers restore and nothing that needs the repo", :aggregate_failures do
        menu("/admin/projects/#{create(:project, :archived, repo: nil, url: nil).id}/menu")

        expect(menu_items).to include("Edit", "Tags", "Restore")
        expect(menu_items).not_to include("Archive", "Open repo", "Open site", "Copy repo")
      end
    end

    describe "a person" do
      let(:person) { create(:person, name: "Matz", key: "matz") }

      before { menu("/admin/people/#{person.id}/menu") }

      it_behaves_like "a row menu"

      it "holds edit, copy mention and remove", :aggregate_failures do
        expect(menu_items).to eq(["Edit", "Copy mention", "Remove"])
        expect(copies.fetch("Copy mention")).to eq("@{matz}")
      end

      it "asks before it removes" do
        expect(page).to have_css("button[data-confirm-inline='Click again to remove']", text: "Remove")
      end
    end

    describe "rows" do
      it "carry the menu on posts" do
        post_record = create(:post)
        get "/admin/posts"

        expect(page).to have_css(".li[data-menu='/admin/posts/#{post_record.id}/menu?status=all']")
      end

      it "carry the menu in the social queue" do
        social_post = create(:social_post, :scheduled)
        get "/admin/social"

        expect(page).to have_css(".sq-item[data-menu='/admin/social/#{social_post.id}/menu?filter=queued']")
      end

      it "carry the menu on projects" do
        project = create(:project)
        get "/admin/projects"

        expect(page).to have_css(".project-card[data-menu='/admin/projects/#{project.id}/menu']")
      end

      it "carry the menu on people" do
        person = create(:person)
        get "/admin/settings/webmentions"

        expect(page).to have_css(".person-row[data-menu='/admin/people/#{person.id}/menu']")
      end
    end

    describe "acting from a menu" do
      it "tags a post and lands back", :aggregate_failures do
        post_record = create(:post)
        act("/admin/posts/bulk", act: "untag", ids: [post_record.id], tag: "ruby")

        expect(last_response.location).to eq("/admin/x?y=1")
      end

      it "archives and restores a project and lands back", :aggregate_failures do
        project = create(:project)
        act("/admin/projects/#{project.id}/archive")
        expect(last_response.location).to eq("/admin/x?y=1")

        act("/admin/projects/#{project.id}/restore")
        expect(last_response.location).to eq("/admin/x?y=1")
      end

      it "removes a person and lands back" do
        act("/admin/people/#{create(:person).id}/delete")

        expect(last_response.location).to eq("/admin/x?y=1")
      end

      it "removes a person from the webmentions tab and lands on its section" do
        act("/admin/people/#{create(:person).id}/delete", return_to: "/admin/settings/webmentions")

        expect(last_response.location).to eq("/admin/settings/webmentions#people")
      end

      it "ignores a return path outside the admin" do
        act("/admin/people/#{create(:person).id}/delete", return_to: "https://example.com/")

        expect(last_response.location).to eq("/admin/settings/webmentions#people")
      end
    end
  end
end
