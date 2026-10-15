# frozen_string_literal: true

RSpec.describe "Admin task rules", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }

  def add(pattern, tags, provider: "github", projects: nil)
    send_to("/admin/tasks/rules", rule: { pattern:, provider:, tags:, projects: }.compact)
  end

  def message(field, key) = i18n.t(["ui.components.task_rules.field_error", field, key].join("."))

  def rule(pattern, tags, provider: nil, projects: nil)
    Tasks::Slice["operations.save_task_rule"].call({ pattern:, provider:, tags:, projects: }).value!
  end

  def rules = Tasks::Slice["repos.task_rule_queries"].all

  def send_to(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  def stored(id) = rules.find { it.id == id }

  def ticked(id)
    page.find("form[action='/admin/tasks/rules/#{id}']").all("input[name='rule[projects][]'][checked]").map(&:value)
  end

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the list" do
      before do
        rule("aaronmallen/*", "projects")
        rule("aaronmallen/aaronmallen.me", "ruby, hanami")
      end

      it "shows each rule's pattern in order" do
        get "/admin/tasks/rules"

        expect(page.all(".rule-pattern").map(&:text)).to eq(%w[aaronmallen/* aaronmallen/aaronmallen.me])
      end

      it "shows each rule's tags" do
        get "/admin/tasks/rules"

        expect(page.all(".rule-tags").map { it.all(".tag").map(&:text) }).to eq([%w[#projects], %w[#hanami #ruby]])
      end

      it "links each rule's tags to their summaries" do
        get "/admin/tasks/rules"

        expect(page.all(".rule-tags a.tag").map { it[:href] })
          .to eq(%w[/admin/tags/projects /admin/tags/hanami /admin/tags/ruby])
      end

      it "shows each rule's provider" do
        rule("acme/ENG", "work", provider: "linear")
        get "/admin/tasks/rules"

        expect(page.all(".rule-row").map { it.find(".rule-provider").text })
          .to eq(%w[GitHub GitHub Linear])
      end

      it "counts them" do
        get "/admin/tasks/rules"

        expect(page).to have_css(".card-side", exact_text: "2 rules")
      end

      it "fills each editor with the rule it edits", :aggregate_failures do
        get "/admin/tasks/rules"
        form = page.find("form[action='/admin/tasks/rules/#{rules.last.id}']")

        expect(form.find("input[name='rule[pattern]']").value).to eq("aaronmallen/aaronmallen.me")
        expect(form.find("input[name='rule[tags]']").value).to eq("hanami, ruby")
      end

      it "fills each editor with the rule's provider" do
        linear = rule("acme/*", "work", provider: "linear")
        get "/admin/tasks/rules"
        form = page.find("form[action='/admin/tasks/rules/#{linear.id}']")

        expect(form.find("select[name='rule[provider]'] option[selected]").value).to eq("linear")
      end

      it "shows each rule's project by name" do
        rule("octocat/*", "", projects: [create(:project, name: "Blog").id])
        get "/admin/tasks/rules"

        expect(page.find(".rule-row", text: "octocat/*").all(".rule-project").map(&:text)).to eq(%w[Blog])
      end

      it "ticks each rule's projects in its editor" do
        blog = %w[Blog Atlas].map { create(:project, name: it) }.first
        linked = rule("octocat/*", "", projects: [blog.id])
        get "/admin/tasks/rules"

        expect(ticked(linked.id)).to eq([blog.id.to_s])
      end

      it "sits under the settings tabs" do
        get "/admin/tasks/rules"

        expect(page).to have_css(".screen-tab[aria-current='page']", text: "task rules")
      end
    end

    it "says something useful when there is no rule yet" do
      get "/admin/tasks/rules"

      expect(page).to have_css(".empty")
    end

    it "is linked from the external tab" do
      get "/admin/tasks", filter: "external"

      expect(page).to have_link("Task rules", href: "/admin/tasks/rules")
    end

    describe "the blurb" do
      let(:blog) { create(:project) }

      def synced
        id = Tasks::Slice["relations.task_sources"].pluck(:task_id).first
        Tasks::Slice["repos.task_queries"].by_id(id).then { [it.tags.map(&:name), it.project_id] }
      end

      before do
        rule("aaronmallen/*", "ruby", projects: [blog.id.to_s])
        connect_github_token
        stub_github(GitHubGraphQL::ASSIGNED_QUERY, github_issue_search(github_issue("I_seven", number: 7)))
        stub_github(GitHubGraphQL::ISSUES_QUERY, github_issue_nodes)
        Tasks::Jobs::SyncIssues.new.perform("github")
        get "/admin/tasks/rules"
      end

      it "says a rule tags the issues it matches as they sync and gives them a project", :aggregate_failures do
        expect(synced).to eq([%w[ruby], blog.id])
        expect(page).to have_css(".card-blurb", exact_text: i18n.t("ui.views.task_rules.index.sub"))
      end
    end

    describe "the notes" do
      let(:blog) { create(:project) }
      let!(:task) { create(:task, :external).tap { create(:task_source, task: it, url: "https://github.com/x/blog/issues/1") } }

      def edit_then_delete(id)
        send_to("/admin/tasks/rules/#{id}", rule: { pattern: "x/*", tags: "ruby" })
        send_to("/admin/tasks/rules/#{id}/delete")
      end

      def held = Tasks::Slice["repos.task_queries"].by_id(task.id).then { [it.tags.map(&:name), it.project_id] }

      it "says adding a rule tags the tasks already imported and gives them its project", :aggregate_failures do
        add("x/*", "projects", projects: [blog.id.to_s])
        follow_redirect!

        expect(held).to eq([%w[projects], blog.id])
        expect(page.find(".rule-capture .hint")).to have_text(i18n.t("ui.components.task_rules.capture.note"))
      end

      it "says editing or deleting a rule leaves what tasks hold", :aggregate_failures do
        add("x/*", "projects", projects: [blog.id.to_s])
        edit_then_delete(rules.first.id)
        follow_redirect!

        expect(held).to eq([%w[projects], blog.id])
        expect(page).to have_css("p.hint", exact_text: i18n.t("ui.views.task_rules.index.note"))
      end

      it "states the edit note once, under the list and not in each editor" do
        rule("aaronmallen/*", "projects")
        get "/admin/tasks/rules"

        expect(page).to have_css(".hint", exact_text: i18n.t("ui.views.task_rules.index.note"), count: 1)
      end
    end

    describe "adding a rule" do
      it "offers GitHub or Linear, with GitHub chosen", :aggregate_failures do
        get "/admin/tasks/rules"
        select = page.find(".rule-capture select[name='rule[provider]']")

        expect(select.all("option").map { [it.value, it.text] }).to eq([%w[github GitHub], %w[linear Linear]])
        expect(select.find("option[selected]").value).to eq("github")
      end

      it "offers every project, private or archived among them, by name" do
        create(:project, :private, name: "Blog")
        create(:project, :archived, name: "Atlas")
        get "/admin/tasks/rules"

        expect(page.find(".rule-capture").all(".rule-projects .choice").map(&:text)).to eq(["Atlas archived", "Blog"])
      end

      it "stores the projects it is given, with no tags" do
        blog = create(:project, name: "Blog")
        add("aaronmallen/*", "", projects: [blog.id.to_s])

        expect(rules.map { [it.tags, it.projects.map(&:id)] }).to eq([[[], [blog.id]]])
      end

      it "puts the tasks already imported that it matches in its project" do
        blog = create(:project)
        task = create(:task, :external)
        create(:task_source, task:, url: "https://github.com/aaronmallen/blog/issues/1")
        add("aaronmallen/*", "", projects: [blog.id.to_s])

        expect(Tasks::Slice["relations.tasks"].by_pk(task.id).pluck(:project_id)).to eq([blog.id])
      end

      it "stores the provider it is given" do
        add("acme/ENG", "work", provider: "linear")

        expect(rules.map { [it.provider, it.pattern] }).to eq([%w[linear acme/eng]])
      end

      it "stores it" do
        add("AaronMallen/*", "projects, ruby")

        expect(rules.map { [it.pattern, it.tags.map(&:name)] }).to eq([["aaronmallen/*", %w[projects ruby]]])
      end

      it "says so" do
        add("aaronmallen/*", "projects")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Rule added")
      end

      %w[aaronmallen */foo aaronmallen/foo/bar].each do |pattern|
        it "refuses #{pattern}, says why and saves nothing", :aggregate_failures do
          add(pattern, "ruby")

          expect(last_response.status).to eq(422)
          expect(page).to have_css("#rule-pattern-error", text: message(:pattern, "format"))
          expect(rules).to be_empty
        end
      end

      it "creates no tag for a pattern it refuses" do
        add("aaronmallen", "brand-new")

        expect(Tasks::Slice["relations.tags"].where(name: "brand-new").count).to eq(0)
      end

      it "says why it refused a blank pattern" do
        add(" ", "ruby")

        expect(page).to have_css("#rule-pattern-error", text: message(:pattern, "blank"))
      end

      it "says why it refused a pattern another rule holds" do
        rule("aaronmallen/*", "ruby")
        add("AaronMallen/*", "projects")

        expect(page).to have_css("#rule-pattern-error", text: message(:pattern, "taken"))
      end

      it "says why it refused a rule with no tags or projects" do
        add("aaronmallen/*", " , ")

        expect(page).to have_css("#rule-tags-error", text: message(:tags, "blank"))
      end

      it "says why it refused a project that is gone" do
        add("aaronmallen/*", "", projects: ["999999"])

        expect(page).to have_css("#rule-projects-error", text: message(:projects, "missing"))
      end

      it "says why it refused a second project and saves nothing", :aggregate_failures do
        add("aaronmallen/*", "", projects: [create(:project), create(:project)].map { it.id.to_s })

        expect(page).to have_css("#rule-projects-error", text: message(:projects, "one"))
        expect(rules).to be_empty
      end

      it "says why it refused a tag that is not a slug" do
        add("aaronmallen/*", "c++")

        expect(page).to have_css("#rule-tags-error", text: message(:tags, "format"))
      end

      it "keeps what was typed after a refusal", :aggregate_failures do
        add("aaronmallen", "ruby", provider: "linear")

        expect(page).to have_css("#rule-provider option[value='linear'][selected]")
        expect(page).to have_css("#rule-pattern[value='aaronmallen']")
        expect(page).to have_css("#rule-tags[value='ruby']")
      end

      it "keeps the projects that were ticked after a refusal" do
        blog = create(:project)
        add("aaronmallen", "", projects: [blog.id.to_s])

        expect(page.find(".rule-capture")).to have_css("input[name='rule[projects][]'][value='#{blog.id}'][checked]")
      end
    end

    describe "editing a rule" do
      let!(:existing) { rule("aaronmallen/*", "projects") }

      it "rewrites the pattern and tags" do
        send_to("/admin/tasks/rules/#{existing.id}", rule: { pattern: "aaronmallen/aaronmallen.me", tags: "ruby" })

        expect([stored(existing.id).pattern, stored(existing.id).tags.map(&:name)])
          .to eq(["aaronmallen/aaronmallen.me", %w[ruby]])
      end

      it "replaces the projects" do
        blog = create(:project)
        send_to(
          "/admin/tasks/rules/#{existing.id}", rule: { pattern: "aaronmallen/*", tags: "", projects: [blog.id.to_s] },
        )

        expect(stored(existing.id).then { [it.tags, it.projects.map(&:id)] }).to eq([[], [blog.id]])
      end

      it "takes every project out when none is ticked" do
        rule = rule("octocat/*", "ruby", projects: [create(:project).id])
        send_to("/admin/tasks/rules/#{rule.id}", rule: { pattern: "octocat/*", tags: "ruby" })

        expect(stored(rule.id).projects).to be_empty
      end

      it "changes the provider" do
        send_to("/admin/tasks/rules/#{existing.id}", rule: { pattern: "acme/*", provider: "linear", tags: "ruby" })

        expect(stored(existing.id).provider).to eq("linear")
      end

      it "says so" do
        send_to("/admin/tasks/rules/#{existing.id}", rule: { pattern: "aaronmallen/*", tags: "ruby" })
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Rule saved")
      end

      it "refuses a bad pattern and keeps the rule as it was", :aggregate_failures do
        send_to("/admin/tasks/rules/#{existing.id}", rule: { pattern: "aaronmallen", tags: "ruby" })

        expect(last_response.status).to eq(422)
        expect([stored(existing.id).pattern,
                stored(existing.id).tags.map(&:name)]).to eq(["aaronmallen/*", %w[projects]])
      end

      it "says why it refused, against the row it refused, with what was typed", :aggregate_failures do
        send_to("/admin/tasks/rules/#{existing.id}", rule: { pattern: "aaronmallen", tags: "ruby" })

        expect(page).to have_css("#rule-#{existing.id}-pattern-error", text: message(:pattern, "format"))
        expect(page).to have_css("#rule-#{existing.id}-pattern[value='aaronmallen']")
        expect(page).to have_css("#rule-#{existing.id}-edit[checked]", visible: :all)
      end

      it "answers 404 for a rule that isn't there" do
        send_to("/admin/tasks/rules/999999", rule: { pattern: "aaronmallen/*", tags: "ruby" })

        expect(last_response.status).to eq(404)
      end
    end

    describe "deleting a rule" do
      let!(:existing) { rule("aaronmallen/*", "projects") }

      it "takes it away" do
        send_to("/admin/tasks/rules/#{existing.id}/delete")

        expect(rules).to be_empty
      end

      it "says so" do
        send_to("/admin/tasks/rules/#{existing.id}/delete")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Rule deleted")
      end

      it "asks first, naming the rule" do
        get "/admin/tasks/rules"

        expect(page.find("form[action='/admin/tasks/rules/#{existing.id}/delete']")["data-confirm"])
          .to include("aaronmallen/*")
      end

      it "answers 404 for a rule that isn't there" do
        send_to("/admin/tasks/rules/0/delete")

        expect(last_response.status).to eq(404)
      end
    end

    describe "a forged CSRF token" do
      it "refuses the add" do
        post "/admin/tasks/rules", _csrf_token: "forged", rule: { pattern: "aaronmallen/*", tags: "ruby" }

        expect([last_response.status, rules]).to eq([403, []])
      end

      it "refuses the delete" do
        existing = rule("aaronmallen/*", "ruby")
        post "/admin/tasks/rules/#{existing.id}/delete", _csrf_token: "forged"

        expect(stored(existing.id)).not_to be_nil
      end
    end
  end

  describe "signed out" do
    before { rule("aaronmallen/*", "projects") }

    it "redirects the list to sign in", :aggregate_failures do
      get "/admin/tasks/rules"

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
      expect(last_response.body).not_to include("aaronmallen/*")
    end
  end
end
