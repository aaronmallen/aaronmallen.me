# frozen_string_literal: true

RSpec.describe "Admin task types", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Tasks::Slice["repos.task_type_repo"] }
  let(:task_repo) { Tasks::Slice["repos.task_repo"] }

  def add(name, **) = post("/admin/tasks/types", _csrf_token: admin_csrf_token, type: { name:, ** })

  def icon_message = i18n.t("ui.components.tasks.field_error.icon.format")

  def message(key) = i18n.t(["ui.components.tasks.field_error.name", key].join("."))

  def named(name) = repo.all.find { it.name == name }

  def names = page.all(".li .inp[name='type[name]']").map { it["value"] }

  def send_to(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  describe "signed in" do
    before { sign_in_to_admin }

    it "reaches the screen from the tasks page" do
      get "/admin/tasks"

      expect(page).to have_link(href: "/admin/tasks/types")
    end

    describe "the list" do
      before { %w[Chore Errand Post].each { create(:task_type, name: it) } }

      it "shows every type in its own order" do
        get "/admin/tasks/types"

        expect(names).to eq(%w[Chore Errand Post])
      end

      it "counts them" do
        get "/admin/tasks/types"

        expect(page).to have_css(".page-head-sub", text: "3 types")
      end

      it "says how many tasks carry a type" do
        create(:task, task_type_id: named("Chore").id)
        get "/admin/tasks/types"

        expect(page).to have_css(".task-meta .pill", text: "1 task")
      end

      it "says nothing about a type no task carries" do
        get "/admin/tasks/types"

        expect(page).to have_no_css(".task-meta .pill", text: "task")
      end
    end

    it "says something useful when there is no type yet" do
      get "/admin/tasks/types"

      expect(page).to have_css(".empty")
    end

    describe "adding a type" do
      it "stores it" do
        add("Chore")

        expect(repo.all.map(&:name)).to eq(%w[Chore])
      end

      it "says so" do
        add("Chore")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Type added")
      end

      it "refuses a blank name" do
        add(" ")

        expect(last_response.status).to eq(422)
      end

      it "says why it refused a blank name" do
        add(" ")

        expect(page).to have_css(".field-error", text: message("blank"))
      end

      it "says why it refused a name another type holds" do
        create(:task_type, name: "Chore")
        add("chore")

        expect(page).to have_css(".field-error", text: message("taken"))
      end

      it "keeps what was typed after a refusal" do
        create(:task_type, name: "Chore")
        add("chore")

        expect(page).to have_css("#type-name[value='chore']")
      end

      it "takes the colour and the icon that were picked" do
        add("Chore", color: "mk-violet", icon: "broom")

        expect(named("Chore")).to have_attributes(color: "mk-violet", icon: "broom")
      end

      it "picks a colour for a type named without one" do
        add("Chore", color: "", icon: "")

        expect(Blog::Types::TagColor.values).to include(named("Chore").color)
      end

      it "offers the six colours to pick from" do
        get "/admin/tasks/types"

        expect(page.all(".task-capture input[name='type[color]']", visible: :all).map { it["value"] })
          .to eq(Blog::Types::TagColor.values)
      end

      it "suggests every free solid icon for the icon field", :aggregate_failures do
        get "/admin/tasks/types"
        list = page.find(".task-capture input[name='type[icon]']")["list"]

        expect(page.all("datalist##{list} option", visible: :all).map { it["value"] })
          .to eq(Blog::Types::TaskTypeIcon.values)
        expect(page).to have_no_select("type[icon]")
      end

      it "links to the free solid icon gallery" do
        get "/admin/tasks/types"

        expect(page).to have_css(".task-capture a[href='https://fontawesome.com/search?ic=free&s=solid']")
      end

      it "takes an icon typed from the full solid set" do
        add("Chore", icon: "rocket")

        expect(named("Chore").icon).to eq("rocket")
      end

      it "refuses an icon Font Awesome has no solid for", :aggregate_failures do
        add("Chore", icon: "rocket-ship")

        expect(last_response.status).to eq(422)
        expect(repo.all).to be_empty
      end

      it "says why it refused the icon" do
        add("Chore", icon: "rocket-ship")

        expect(page).to have_css("#type-icon-error", text: icon_message)
      end

      it "keeps the icon that was typed after a refusal" do
        add("Chore", icon: "rocket-ship")

        expect(page).to have_css("#type-icon[value='rocket-ship']")
      end
    end

    describe "changing a type's icon" do
      let(:type) { create(:task_type, name: "Chore", color: "mk-blue", icon: "broom") }

      def change(icon) = send_to("/admin/tasks/types/#{type.id}", type: { name: type.name, icon: })

      it "offers the icon it holds on the row, with the same suggestions", :aggregate_failures do
        type
        get "/admin/tasks/types"
        field = page.find(".li input[name='type[icon]']")

        expect(field["value"]).to eq("broom")
        expect(field["list"]).to eq(page.find(".task-capture input[name='type[icon]']")["list"])
      end

      it "sets an icon on a type that had none" do
        bare = create(:task_type, name: "Errand", icon: nil)
        send_to("/admin/tasks/types/#{bare.id}", type: { name: bare.name, icon: "feather" })

        expect(repo.by_id(bare.id).icon).to eq("feather")
      end

      it "stores the new icon" do
        change("rocket")

        expect(repo.by_id(type.id).icon).to eq("rocket")
      end

      it "draws the new icon in the tag" do
        change("rocket")
        get "/admin/tasks/types"

        expect(page).to have_css(".task-meta .pill i.fa-rocket", visible: :all)
      end

      it "clears the icon when the field comes back blank" do
        change(" ")

        expect(repo.by_id(type.id).icon).to be_nil
      end

      it "draws the tag with no icon once cleared" do
        change("")
        get "/admin/tasks/types"

        expect(page).to have_no_css(".task-meta .pill i", visible: :all)
      end

      it "keeps the name and colour it held" do
        change("rocket")

        expect(repo.by_id(type.id)).to have_attributes(name: "Chore", color: "mk-blue")
      end

      it "refuses a name Font Awesome has no solid for", :aggregate_failures do
        change("rocket-ship")

        expect(last_response.status).to eq(422)
        expect(repo.by_id(type.id).icon).to eq("broom")
      end

      it "says why it refused, against the row it refused", :aggregate_failures do
        change("rocket-ship")

        expect(page).to have_css("#type-#{type.id}-icon-error", text: icon_message)
        expect(page).to have_css("#type-#{type.id}-icon[value='rocket-ship']")
      end
    end

    describe "recolouring a type" do
      let(:type) { create(:task_type, name: "Chore", color: "mk-blue", icon: "broom") }

      it "stores the colour that was clicked" do
        send_to("/admin/tasks/types/#{type.id}", type: { name: type.name, color: "mk-orange" })

        expect(repo.by_id(type.id).color).to eq("mk-orange")
      end

      it "keeps the name it already held" do
        send_to("/admin/tasks/types/#{type.id}", type: { name: type.name, color: "mk-orange" })

        expect(repo.by_id(type.id).name).to eq("Chore")
      end

      it "keeps the icon it already held" do
        send_to("/admin/tasks/types/#{type.id}", type: { name: type.name, color: "mk-orange" })

        expect(repo.by_id(type.id).icon).to eq("broom")
      end

      it "offers a swatch for each colour on the row" do
        type

        get "/admin/tasks/types"

        expect(page.all(".li button[name='type[color]']").map { it["value"] }).to eq(Blog::Types::TagColor.values)
      end

      it "marks the colour the type already holds" do
        type

        get "/admin/tasks/types"

        expect(page).to have_css(".li button[name='type[color]'][value='mk-blue'][aria-pressed='true']")
      end

      it "draws the type as a pill in its own colour, with its own icon" do
        type

        get "/admin/tasks/types"

        expect(page).to have_css(".task-meta .pill.blue i.fa-broom", visible: :all)
      end
    end

    describe "renaming a type" do
      let(:type) { create(:task_type, name: "Chore") }

      it "rewrites the name" do
        send_to("/admin/tasks/types/#{type.id}", type: { name: "Errand" })

        expect(repo.by_id(type.id).name).to eq("Errand")
      end

      it "says so" do
        send_to("/admin/tasks/types/#{type.id}", type: { name: "Errand" })
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Type renamed")
      end

      it "keeps the tasks on the type they were already on" do
        task = create(:task, task_type_id: type.id)
        send_to("/admin/tasks/types/#{type.id}", type: { name: "Errand" })

        expect(task_repo.by_id(task.id).task_type_id).to eq(type.id)
      end

      it "reads the new name back on the tasks screen" do
        create(:task, task_type_id: type.id)
        send_to("/admin/tasks/types/#{type.id}", type: { name: "Errand" })
        get "/admin/tasks", filter: "next"

        expect(page).to have_css(".task-meta .pill", text: "Errand")
      end

      it "leaves a search for the old name finding nothing" do
        create(:task, task_type_id: type.id, title: "Email the accountant")
        send_to("/admin/tasks/types/#{type.id}", type: { name: "Errand" })
        get "/admin/tasks", filter: "next", q: "type:chore"

        expect(page.all(".task-title").map(&:text)).to be_empty
      end

      it "answers a search for the new name with the same tasks" do
        create(:task, task_type_id: type.id, title: "Email the accountant")
        send_to("/admin/tasks/types/#{type.id}", type: { name: "Errand" })
        get "/admin/tasks", filter: "next", q: "type:errand"

        expect(page.all(".task-title").map(&:text)).to eq(["Email the accountant"])
      end

      it "refuses a blank name" do
        send_to("/admin/tasks/types/#{type.id}", type: { name: " " })

        expect(last_response.status).to eq(422)
      end

      it "says why it refused, against the row it refused" do
        send_to("/admin/tasks/types/#{type.id}", type: { name: " " })

        expect(page).to have_css("##{"type-#{type.id}-name"}-error")
      end

      it "answers 404 for a type that isn't there" do
        send_to("/admin/tasks/types/0", type: { name: "Errand" })

        expect(last_response.status).to eq(404)
      end
    end

    describe "reordering a type" do
      before { %w[Chore Errand].each { create(:task_type, name: it) } }

      it "moves a type up past the one above it" do
        send_to("/admin/tasks/types/#{repo.all.last.id}/reorder/up")

        expect(repo.all.map(&:name)).to eq(%w[Errand Chore])
      end

      it "moves a type down past the one below it" do
        send_to("/admin/tasks/types/#{repo.all.first.id}/reorder/down")

        expect(repo.all.map(&:name)).to eq(%w[Errand Chore])
      end

      it "holds the caret that has nowhere to go", :aggregate_failures do
        get "/admin/tasks/types"
        carets = page.all(".task-caret")

        expect(carets.first).to be_disabled
        expect(carets.last).to be_disabled
      end

      it "redirects back to the list at the top rather than failing" do
        send_to("/admin/tasks/types/#{repo.all.first.id}/reorder/up")

        expect(last_response).to be_redirect
      end

      it "answers 404 for a direction that isn't one" do
        send_to("/admin/tasks/types/#{repo.all.first.id}/reorder/sideways")

        expect(last_response.status).to eq(404)
      end

      it "answers 404 for a type that isn't there" do
        send_to("/admin/tasks/types/0/reorder/up")

        expect(last_response.status).to eq(404)
      end
    end

    describe "removing a type" do
      let(:type) { create(:task_type, name: "Chore") }

      def carried = 2.times { create(:task, task_type_id: type.id) }

      it "takes away a type nothing carries" do
        send_to("/admin/tasks/types/#{type.id}/delete")

        expect(repo.by_id(type.id)).to be_nil
      end

      it "asks first" do
        type
        get "/admin/tasks/types"

        expect(page).to have_css("form[action$='/delete'][data-confirm]")
      end

      it "names the type it is about to take away" do
        type
        get "/admin/tasks/types"

        expect(page.find("form[action$='/delete']")["data-confirm"]).to include("Chore")
      end

      it "answers 404 for a type that isn't there" do
        send_to("/admin/tasks/types/0/delete")

        expect(last_response.status).to eq(404)
      end

      it "keeps a type two tasks carry" do
        carried
        send_to("/admin/tasks/types/#{type.id}/delete")

        expect(repo.by_id(type.id)).not_to be_nil
      end

      it "says how many tasks kept it" do
        carried
        send_to("/admin/tasks/types/#{type.id}/delete")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Kept · 2 tasks still carry it")
      end

      it "leaves the tasks that kept it typed" do
        carried
        send_to("/admin/tasks/types/#{type.id}/delete")

        expect(task_repo.in_list("next").map(&:task_type_id)).to all(eq(type.id))
      end

      it "holds the button while tasks carry the type" do
        carried
        get "/admin/tasks/types"

        expect(page.find("form[action$='/delete'] button")).to be_disabled
      end

      it "says why the button is held" do
        carried
        get "/admin/tasks/types"

        expect(page.find("form[action$='/delete']")["title"]).to include("2 tasks carry this type")
      end
    end

    describe "a name holding HTML" do
      let(:markup) { "<script>alert('x')</script>" }

      before do
        create(:task_type, name: markup)
        get "/admin/tasks/types"
      end

      it "reads it back as the text it is rather than as markup" do
        expect(page.find(".li .inp[name='type[name]']")["value"]).to eq(markup)
      end

      it "keeps a quoted name inside the attribute that carries it" do
        create(:task_type, name: 'Ask "why"')
        get "/admin/tasks/types"

        expect(page.all("form[action$='/delete']").map { it["data-confirm"] }).to include(include('Ask "why"'))
      end
    end

    describe "a forged CSRF token" do
      it "refuses the add" do
        post "/admin/tasks/types", _csrf_token: "forged", type: { name: "Chore" }

        expect(last_response.status).to eq(403)
      end

      it "writes nothing" do
        post "/admin/tasks/types", _csrf_token: "forged", type: { name: "Chore" }

        expect(repo.all).to be_empty
      end

      it "refuses the rename" do
        type = create(:task_type, name: "Chore")
        post "/admin/tasks/types/#{type.id}", _csrf_token: "forged", type: { name: "Errand" }

        expect(repo.by_id(type.id).name).to eq("Chore")
      end

      it "refuses the removal" do
        type = create(:task_type, name: "Chore")
        post "/admin/tasks/types/#{type.id}/delete", _csrf_token: "forged"

        expect(repo.by_id(type.id)).not_to be_nil
      end
    end
  end

  describe "signed out" do
    let(:type) { create(:task_type, name: "Chore") }

    it "keeps the screen off the screen" do
      get "/admin/tasks/types"

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
    end

    it "shows no type to anybody who has not signed in" do
      type
      get "/admin/tasks/types"

      expect(last_response.body).not_to include("Chore")
    end

    it "adds nothing" do
      post "/admin/tasks/types", type: { name: "Errand" }

      expect(repo.all).to be_empty
    end

    {
      "" => { type: { name: "Renamed" } },
      "/delete" => {},
      "/reorder/up" => {},
    }.each do |suffix, params|
      it "writes nothing through POST /admin/tasks/types/:id#{suffix}" do
        id = type.id
        post "/admin/tasks/types/#{id}#{suffix}", params

        expect(repo.by_id(id)).to have_attributes(name: "Chore")
      end
    end
  end
end
