# frozen_string_literal: true

RSpec.describe "Admin tags", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:post_repo) { Posts::Slice["repos.post_repo"] }
  let(:repo) { Tags::Slice["repos.tag_repo"] }

  def add(name, **) = post("/admin/tags", _csrf_token: admin_csrf_token, tag: { name: }, **)

  def confirm(**) = i18n.t("ui.components.tags.row.confirm_remove", **)

  def confirm_prompt = page.find("form[action$='/delete']")["data-confirm"]

  def every_tag = Blog::Types::TagScope.values.flat_map { repo.all_in(it) }

  def message(key) = i18n.t(["ui.components.tags.field_error.name", key].join("."))

  def named(name) = every_tag.find { it.name == name }

  def names = page.all(".tag-name").map(&:text)

  def send_to(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  def stored(id) = every_tag.find { it.id == id }

  describe "signed in" do
    before { sign_in_to_admin }

    describe "paging" do
      before do
        lower_page_size(:admin, to: 2)
        %w[ruby rust rails elixir go].each { create(:tag, name: it) }
        create(:tag, :private, name: "rest")
      end

      it "shows the first page and links to the next", :aggregate_failures do
        get "/admin/tags"

        expect(names).to eq(%w[#elixir #go])
        expect(page).to have_css("nav.pager a[rel='next'][href='/admin/tags?scope=public&page=2']", text: "Older")
      end

      it "keeps the scope and the search on a later page", :aggregate_failures do
        get "/admin/tags", q: "r", page: "2"

        expect(names).to eq(%w[#ruby #rust])
        expect(page).to have_css("nav.pager a[rel='prev'][href='/admin/tags?scope=public&q=r']", text: "Newer")
      end

      it "sends the page it is on with a rename" do
        get "/admin/tags", page: "2"

        expect(page).to have_css("#tag-#{named('ruby').id}-form input[name='page'][value='2']", visible: :all)
      end

      it "says why it refused a rename against a row on a later page" do
        send_to("/admin/tags/#{named('ruby').id}", tag: { name: " " }, page: "2")

        expect(page).to have_css("#tag-#{named('ruby').id}-name-error")
      end

      it "counts every tag that matches, not the page" do
        get "/admin/tags", q: "r"

        expect(page).to have_css(".page-head-sub", text: "4 tags")
      end

      it "draws no pager when one page holds every tag" do
        get "/admin/tags", scope: "private"

        expect(page).to have_no_css("nav.pager")
      end

      it "returns 404 for a page past the end" do
        get "/admin/tags", page: "4"

        expect(last_response).to be_not_found
      end
    end

    it "is a section of the command palette" do
      get "/admin"

      expect(page).to have_css("[data-palette-href='/admin/tags']", visible: :all)
    end

    describe "the list" do
      before { create(:post, tags: %w[ruby hanami]) }

      it "shows every tag in name order" do
        get "/admin/tags"

        expect(names).to eq(%w[#hanami #ruby])
      end

      it "counts them" do
        get "/admin/tags"

        expect(page).to have_css(".page-head-sub", text: "2 tags")
      end

      it "draws a tag in the colour it carries" do
        hue = Blog::UI::Components::Pill.for_tag_color(named("ruby").color)
        get "/admin/tags"

        expect(page).to have_css(".tag-name .tag.#{hue}", text: "#ruby")
      end

      it "links no tag anywhere" do
        get "/admin/tags"

        expect(page).to have_no_css(".tag-row a.tag")
      end

      it "says what carries a tag" do
        get "/admin/tags"

        expect(page).to have_css(".tag-uses", text: "1 post", count: 2)
      end

      it "counts each public kind a public tag is on" do
        create(:project, tags: %w[ruby])
        create(:task, tags: %w[ruby])
        get "/admin/tags"

        expect(page.find(".tag-row", text: "#ruby").find(".tag-uses").text).to eq("1 post · 1 project")
      end

      it "counts each private kind a private tag is on" do
        create(:task, tags: %w[ruby])
        create(:journal_entry, tags: %w[ruby])
        Decisions::Slice["repos.decision_repo"].replace_tags(create(:decision).id, %w[ruby])
        get "/admin/tags", scope: "private"

        expect(page.find(".tag-uses").text).to eq("1 journal entry · 1 task · 1 decision")
      end

      it "says a tag nothing carries is unused" do
        create(:tag, name: "elixir")
        get "/admin/tags"

        expect(page).to have_css(".tag-uses", text: "unused")
      end

      it "narrows the list to what the filter matches" do
        get "/admin/tags", q: "ru"

        expect(names).to eq(%w[#ruby])
      end

      it "says so when the filter matches nothing" do
        get "/admin/tags", q: "elixir"

        expect(page).to have_css(".empty", text: "elixir")
      end
    end

    describe "the scope switch" do
      before do
        create(:post, tags: %w[ruby])
        create(:task, tags: %w[chores])
      end

      it "opens on the public tags" do
        get "/admin/tags"

        expect(names).to eq(%w[#ruby])
      end

      it "lists only private tags on the private tab" do
        get "/admin/tags", scope: "private"

        expect(names).to eq(%w[#chores])
      end

      it "falls back to the public tags for a scope it does not know" do
        get "/admin/tags", scope: "secret"

        expect(names).to eq(%w[#ruby])
      end

      it "links to each tab, so it works with scripts off", :aggregate_failures do
        get "/admin/tags"

        expect(page).to have_link("Public", href: "/admin/tags?scope=public")
        expect(page).to have_link("Private", href: "/admin/tags?scope=private")
      end

      it "marks the tab it is on" do
        get "/admin/tags", scope: "private"

        expect(page).to have_css("a.seg-option.current[aria-current='page']", text: "Private")
      end

      it "keeps the search when it switches" do
        get "/admin/tags", q: "ch"

        expect(page).to have_link("Private", href: "/admin/tags?scope=private&q=ch")
      end

      it "searches inside the chosen scope" do
        get "/admin/tags", scope: "private", q: "r"

        expect(names).to eq(%w[#chores])
      end

      it "keeps the scope in the search form" do
        get "/admin/tags", scope: "private"

        expect(page).to have_css("form[role='search'] input[name='scope'][value='private']", visible: :all)
      end

      it "counts only the tags on the tab" do
        get "/admin/tags", scope: "private"

        expect(page).to have_css(".page-head-sub", text: "1 tag")
      end
    end

    it "says something useful when there is no tag yet" do
      get "/admin/tags"

      expect(page).to have_css(".empty")
    end

    describe "adding a tag" do
      it "stores it" do
        add("ruby")

        expect(every_tag.map(&:name)).to eq(%w[ruby])
      end

      it "says so" do
        add("ruby")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Tag added")
      end

      it "folds the name to one case" do
        add("Ruby")

        expect(every_tag.map(&:name)).to eq(%w[ruby])
      end

      it "gives it one of the six colours without being asked" do
        add("ruby")

        expect(Blog::Types::TagColor.values).to include(named("ruby").color)
      end

      it "spreads the colours over the tags it is given" do
        %w[one two three four five six].each { add(it) }

        expect(every_tag.map(&:color).uniq).to match_array(Blog::Types::TagColor.values)
      end

      it "refuses a blank name" do
        add(" ")

        expect(last_response.status).to eq(422)
      end

      it "says why it refused a blank name" do
        add(" ")

        expect(page).to have_css(".field-error", text: message("blank"))
      end

      it "says why it refused a name that is not a slug" do
        add("Machine Learning")

        expect(page).to have_css(".field-error", text: message("format"))
      end

      ["c++", "-ruby", "ruby-", "a/b", "open source"].each do |name|
        it "refuses #{name.inspect}, which is not a slug", :aggregate_failures do
          add(name)

          expect(page).to have_css(".field-error", text: message("format"))
          expect(every_tag).to be_empty
        end
      end

      it "says why it refused a name another tag holds" do
        create(:tag, name: "ruby")
        add("Ruby")

        expect(page).to have_css(".field-error", text: message("taken"))
      end

      it "adds a public tag from the public tab" do
        add("ruby")

        expect(named("ruby").scope).to eq("public")
      end

      it "adds a private tag from the private tab" do
        add("ruby", scope: "private")

        expect(named("ruby").scope).to eq("private")
      end

      it "goes back to the tab it added from" do
        add("ruby", scope: "private")

        expect(last_response.location).to end_with("/admin/tags?scope=private")
      end

      it "takes a name the other scope holds", :aggregate_failures do
        create(:tag, name: "ruby")
        add("ruby", scope: "private")

        expect(every_tag.map { [it.name, it.scope] }).to contain_exactly(%w[ruby public], %w[ruby private])
      end

      it "says why it refused a name the same private scope holds" do
        create(:tag, :private, name: "ruby")
        add("ruby", scope: "private")

        expect(page).to have_css(".field-error", text: message("taken"))
      end

      it "keeps the private tab after a refusal" do
        create(:tag, :private, name: "ruby")
        add("ruby", scope: "private")

        expect(page).to have_css("a.seg-option.current", text: "Private")
      end

      it "keeps what was typed after a refusal" do
        create(:tag, name: "ruby")
        add("ruby")

        expect(page).to have_css("#tag-name[value='ruby']")
      end
    end

    describe "renaming a tag" do
      let(:tag) { create(:tag, name: "ruby") }

      it "rewrites the name" do
        send_to("/admin/tags/#{tag.id}", tag: { name: "hanami" })

        expect(stored(tag.id).name).to eq("hanami")
      end

      it "says so" do
        send_to("/admin/tags/#{tag.id}", tag: { name: "hanami" })
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Tag renamed")
      end

      it "carries every tagged record with it, in one write" do
        article = create(:post, tags: %w[ruby])
        send_to("/admin/tags/#{named('ruby').id}", tag: { name: "hanami" })

        expect(post_repo.by_id(article.id).tags.map(&:name)).to eq(%w[hanami])
      end

      it "refuses a blank name" do
        send_to("/admin/tags/#{tag.id}", tag: { name: " " })

        expect(last_response.status).to eq(422)
      end

      it "says why it refused, against the row it refused" do
        send_to("/admin/tags/#{tag.id}", tag: { name: " " })

        expect(page).to have_css("#tag-#{tag.id}-name-error")
      end

      it "renames a private tag from the private tab" do
        tag = create(:tag, :private, name: "chores")
        send_to("/admin/tags/#{tag.id}", scope: "private", tag: { name: "errands" })

        expect(stored(tag.id).name).to eq("errands")
      end

      it "goes back to the tab it renamed from" do
        tag = create(:tag, :private, name: "chores")
        send_to("/admin/tags/#{tag.id}", scope: "private", tag: { name: "errands" })

        expect(last_response.location).to end_with("/admin/tags?scope=private")
      end

      it "takes a name the other scope holds" do
        create(:tag, :private, name: "hanami")
        send_to("/admin/tags/#{tag.id}", tag: { name: "hanami" })

        expect(stored(tag.id).name).to eq("hanami")
      end

      it "says why it refused a name the same scope holds" do
        create(:tag, name: "hanami")
        send_to("/admin/tags/#{tag.id}", tag: { name: "hanami" })

        expect(page).to have_css(".field-error", text: message("taken"))
      end

      it "answers 404 for a tag from the other scope" do
        send_to("/admin/tags/#{tag.id}", scope: "private", tag: { name: "hanami" })

        expect(last_response.status).to eq(404)
      end

      it "answers 404 for a tag that isn't there" do
        send_to("/admin/tags/0", tag: { name: "hanami" })

        expect(last_response.status).to eq(404)
      end
    end

    describe "recolouring a tag" do
      let(:tag) { create(:tag, name: "ruby", color: "mk-blue") }

      it "stores the colour that was clicked" do
        send_to("/admin/tags/#{tag.id}", tag: { name: tag.name, color: "mk-orange" })

        expect(stored(tag.id).color).to eq("mk-orange")
      end

      it "says so" do
        send_to("/admin/tags/#{tag.id}", tag: { name: tag.name, color: "mk-orange" })
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Tag recoloured")
      end

      it "keeps the name it already held" do
        send_to("/admin/tags/#{tag.id}", tag: { name: tag.name, color: "mk-orange" })

        expect(stored(tag.id).name).to eq("ruby")
      end

      it "offers a swatch for each colour on the row" do
        tag

        get "/admin/tags"

        expect(page.all(".tag-editor button[name='tag[color]']").map { it["value"] })
          .to eq(Blog::Types::TagColor.values)
      end

      it "marks the colour the tag already holds" do
        tag

        get "/admin/tags"

        expect(page).to have_css(".tag-editor button[name='tag[color]'][value='mk-blue'][aria-pressed='true']")
      end

      it "leaves the tag of the same name in the other scope alone" do
        twin = create(:tag, :private, name: "ruby", color: "mk-blue")
        send_to("/admin/tags/#{twin.id}", scope: "private", tag: { name: "ruby", color: "mk-orange" })

        expect(stored(tag.id).color).to eq("mk-blue")
      end

      it "carries the scope on every form in the row" do
        create(:tag, :private, name: "chores")
        get "/admin/tags", scope: "private"

        expect(page.all(".tag-row form input[name='scope']", visible: :all).map(&:value).uniq).to eq(%w[private])
      end

      it "refuses a colour that is not one of the six" do
        send_to("/admin/tags/#{tag.id}", tag: { name: tag.name, color: "papaya" })

        expect(stored(tag.id).color).to eq("mk-blue")
      end
    end

    describe "removing a tag" do
      let(:tag) { create(:tag, name: "ruby") }

      it "takes away a tag nothing carries" do
        send_to("/admin/tags/#{tag.id}/delete")

        expect(stored(tag.id)).to be_nil
      end

      it "says so" do
        send_to("/admin/tags/#{tag.id}/delete")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Tag removed")
      end

      it "asks first" do
        tag
        get "/admin/tags"

        expect(page).to have_css("form[action$='/delete'][data-confirm]")
      end

      it "names the tag it is about to take away" do
        tag
        get "/admin/tags"

        expect(page.find("form[action$='/delete']")["data-confirm"]).to include("ruby")
      end

      it "takes away a tag two records carry" do
        2.times { create(:post, tags: %w[ruby]) }
        send_to("/admin/tags/#{named('ruby').id}/delete")

        expect(named("ruby")).to be_nil
      end

      it "takes it off every public record that carried it", :aggregate_failures do
        post = create(:post, tags: %w[ruby rails])
        project = create(:project, tags: %w[ruby])
        send_to("/admin/tags/#{named('ruby').id}/delete")

        expect(post_repo.by_id(post.id).tags.map(&:name)).to eq(%w[rails])
        expect(Projects::Slice["repos.project_repo"].by_id(project.id).tags).to be_empty
      end

      it "takes it off every private record that carried it", :aggregate_failures do
        records = { journal_entry: create(:journal_entry, tags: %w[chores]), task: create(:task, tags: %w[chores]),
                    decision: create(:decision, tags: %w[chores]) }
        send_to("/admin/tags/#{named('chores').id}/delete", scope: "private")

        records.each { |kind, record| expect(Spec::DB::Tagging.repo_for(kind).by_id(record.id).tags).to be_empty }
      end

      it "leaves a published post that loses the tag as it was updated" do
        post = create(:post, :published, tags: %w[ruby])
        send_to("/admin/tags/#{named('ruby').id}/delete")

        expect(post_repo.by_id(post.id).updated_at).to eq(post.updated_at)
      end

      it "takes away a tag while other tags are in use" do
        create(:post, tags: %w[rails])
        send_to("/admin/tags/#{tag.id}/delete")

        expect(stored(tag.id)).to be_nil
      end

      it "says so for a tag records carry" do
        create(:post, tags: %w[ruby])
        send_to("/admin/tags/#{named('ruby').id}/delete")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Tag removed")
      end

      it "leaves the button on while a record carries the tag", :aggregate_failures do
        create(:post, tags: %w[ruby])
        get "/admin/tags"

        expect(page.find("form[action$='/delete'] button")).not_to be_disabled
        expect(page.find("form[action$='/delete']")["title"]).to be_nil
      end

      it "warns that nothing else loses a tag nothing carries" do
        tag
        get "/admin/tags"

        expect(confirm_prompt).to eq(confirm(tag: "ruby", count: 0))
      end

      it "counts each kind that loses the tag" do
        4.times { create(:post, tags: %w[ruby]) }
        create(:project, tags: %w[ruby])
        get "/admin/tags"

        expect(confirm_prompt).to eq(confirm(tag: "ruby", count: 5, uses: "4 posts and 1 project"))
      end

      it "counts one record that loses the tag" do
        create(:project, tags: %w[ruby])
        get "/admin/tags"

        expect(confirm_prompt).to eq(confirm(tag: "ruby", count: 1, uses: "1 project"))
      end

      it "lists three kinds of private record that lose the tag" do
        %i[journal_entry task task decision].each { create(it, tags: %w[chores]) }
        get "/admin/tags", scope: "private"

        expect(confirm_prompt).to eq(confirm(tag: "chores", count: 4, uses: "1 journal entry, 2 tasks and 1 decision"))
      end

      it "takes away a private tag from the private tab" do
        chores = create(:tag, :private, name: "chores")
        send_to("/admin/tags/#{chores.id}/delete", scope: "private")

        expect(stored(chores.id)).to be_nil
      end

      it "goes back to the tab it removed from" do
        chores = create(:tag, :private, name: "chores")
        send_to("/admin/tags/#{chores.id}/delete", scope: "private")

        expect(last_response.location).to end_with("/admin/tags?scope=private")
      end

      it "answers 404 for a tag from the other scope" do
        send_to("/admin/tags/#{tag.id}/delete", scope: "private")

        expect(last_response.status).to eq(404)
      end

      it "takes away a private tag a task carries" do
        create(:task, tags: %w[chores])
        chores = named("chores")
        send_to("/admin/tags/#{chores.id}/delete", scope: "private")

        expect(stored(chores.id)).to be_nil
      end

      it "answers 404 for a tag that isn't there" do
        send_to("/admin/tags/0/delete")

        expect(last_response.status).to eq(404)
      end
    end

    describe "a forged CSRF token" do
      it "refuses the add" do
        post "/admin/tags", _csrf_token: "forged", tag: { name: "ruby" }

        expect(last_response.status).to eq(403)
      end

      it "writes nothing" do
        post "/admin/tags", _csrf_token: "forged", tag: { name: "ruby" }

        expect(every_tag).to be_empty
      end

      it "refuses the rename" do
        tag = create(:tag, name: "ruby")
        post "/admin/tags/#{tag.id}", _csrf_token: "forged", tag: { name: "hanami" }

        expect(stored(tag.id).name).to eq("ruby")
      end

      it "refuses the removal" do
        tag = create(:tag, name: "ruby")
        post "/admin/tags/#{tag.id}/delete", _csrf_token: "forged"

        expect(stored(tag.id)).not_to be_nil
      end
    end
  end

  describe "signed out" do
    let(:tag) { create(:tag, name: "ruby") }

    it "keeps the screen off the screen" do
      get "/admin/tags"

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
    end

    it "shows no tag to anybody who has not signed in" do
      tag
      get "/admin/tags"

      expect(last_response.body).not_to include("ruby")
    end

    it "adds nothing" do
      post "/admin/tags", tag: { name: "ruby" }

      expect(every_tag).to be_empty
    end

    {
      "" => { tag: { name: "hanami" } },
      "/delete" => {},
    }.each do |suffix, params|
      it "writes nothing through POST /admin/tags/:id#{suffix}" do
        id = tag.id
        post "/admin/tags/#{id}#{suffix}", params

        expect(stored(id)).to have_attributes(name: "ruby")
      end
    end
  end
end
