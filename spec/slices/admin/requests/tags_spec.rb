# frozen_string_literal: true

RSpec.describe "Admin tags", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:post_repo) { Posts::Slice["repos.post_repo"] }
  let(:repo) { Tags::Slice["repos.tag_repo"] }

  def add(name, **) = post("/admin/tags", _csrf_token: admin_csrf_token, tag: { name:, ** })

  def message(key) = i18n.t(["ui.components.tags.field_error.name", key].join("."))

  def named(name) = repo.all.find { it.name == name }

  def names = page.all(".tag-name").map(&:text)

  def send_to(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  describe "signed in" do
    before { sign_in_to_admin }

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

        expect(page).to have_css(".tag-name.#{hue}", text: "#ruby")
      end

      it "says what carries a tag" do
        get "/admin/tags"

        expect(page).to have_css(".tag-uses", text: "1 post", count: 2)
      end

      it "counts each kind a tag is on" do
        create(:task, tags: %w[ruby])
        create(:journal_entry, tags: %w[ruby])
        get "/admin/tags"

        expect(page).to have_css(".tag-uses", text: "1 post · 1 journal entry · 1 task")
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

    it "says something useful when there is no tag yet" do
      get "/admin/tags"

      expect(page).to have_css(".empty")
    end

    describe "adding a tag" do
      it "stores it" do
        add("ruby")

        expect(repo.all.map(&:name)).to eq(%w[ruby])
      end

      it "says so" do
        add("ruby")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Tag added")
      end

      it "folds the name to one case" do
        add("Ruby")

        expect(repo.all.map(&:name)).to eq(%w[ruby])
      end

      it "gives it one of the six colours without being asked" do
        add("ruby")

        expect(Blog::Types::TagColor.values).to include(named("ruby").color)
      end

      it "spreads the colours over the tags it is given" do
        %w[one two three four five six].each { add(it) }

        expect(repo.all.map(&:color).uniq).to match_array(Blog::Types::TagColor.values)
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
          expect(repo.all).to be_empty
        end
      end

      it "says why it refused a name another tag holds" do
        create(:tag, name: "ruby")
        add("Ruby")

        expect(page).to have_css(".field-error", text: message("taken"))
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

        expect(repo.by_id(tag.id).name).to eq("hanami")
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

      it "answers 404 for a tag that isn't there" do
        send_to("/admin/tags/0", tag: { name: "hanami" })

        expect(last_response.status).to eq(404)
      end
    end

    describe "recolouring a tag" do
      let(:tag) { create(:tag, name: "ruby", color: "mk-blue") }

      it "stores the colour that was clicked" do
        send_to("/admin/tags/#{tag.id}", tag: { name: tag.name, color: "mk-orange" })

        expect(repo.by_id(tag.id).color).to eq("mk-orange")
      end

      it "says so" do
        send_to("/admin/tags/#{tag.id}", tag: { name: tag.name, color: "mk-orange" })
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Tag recoloured")
      end

      it "keeps the name it already held" do
        send_to("/admin/tags/#{tag.id}", tag: { name: tag.name, color: "mk-orange" })

        expect(repo.by_id(tag.id).name).to eq("ruby")
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

      it "refuses a colour that is not one of the six" do
        send_to("/admin/tags/#{tag.id}", tag: { name: tag.name, color: "papaya" })

        expect(repo.by_id(tag.id).color).to eq("mk-blue")
      end
    end

    describe "removing a tag" do
      let(:tag) { create(:tag, name: "ruby") }

      it "takes away a tag nothing carries" do
        send_to("/admin/tags/#{tag.id}/delete")

        expect(repo.by_id(tag.id)).to be_nil
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

      it "keeps a tag two records carry" do
        2.times { create(:post, tags: %w[ruby]) }
        send_to("/admin/tags/#{named('ruby').id}/delete")

        expect(named("ruby")).not_to be_nil
      end

      it "says how many records kept it" do
        2.times { create(:post, tags: %w[ruby]) }
        send_to("/admin/tags/#{named('ruby').id}/delete")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Kept · 2 records still carry it")
      end

      it "holds the button while a record carries the tag" do
        create(:post, tags: %w[ruby])
        get "/admin/tags"

        expect(page.find("form[action$='/delete'] button")).to be_disabled
      end

      it "says why the button is held" do
        create(:post, tags: %w[ruby])
        get "/admin/tags"

        expect(page.find("form[action$='/delete']")["title"]).to include("1 record carries this tag")
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

        expect(repo.all).to be_empty
      end

      it "refuses the rename" do
        tag = create(:tag, name: "ruby")
        post "/admin/tags/#{tag.id}", _csrf_token: "forged", tag: { name: "hanami" }

        expect(repo.by_id(tag.id).name).to eq("ruby")
      end

      it "refuses the removal" do
        tag = create(:tag, name: "ruby")
        post "/admin/tags/#{tag.id}/delete", _csrf_token: "forged"

        expect(repo.by_id(tag.id)).not_to be_nil
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

      expect(repo.all).to be_empty
    end

    {
      "" => { tag: { name: "hanami" } },
      "/delete" => {},
    }.each do |suffix, params|
      it "writes nothing through POST /admin/tags/:id#{suffix}" do
        id = tag.id
        post "/admin/tags/#{id}#{suffix}", params

        expect(repo.by_id(id)).to have_attributes(name: "ruby")
      end
    end
  end
end
