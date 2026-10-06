# frozen_string_literal: true

RSpec.describe "Admin task tag rules", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }

  def add(pattern, tags, provider: "github") = send_to("/admin/tasks/rules", rule: { pattern:, provider:, tags: })

  def message(field, key) = i18n.t(["ui.components.task_tag_rules.field_error", field, key].join("."))

  def rule(pattern, tags, provider: nil)
    Tasks::Slice["operations.save_task_tag_rule"].call({ pattern:, provider:, tags: }).value!
  end

  def rules = Tasks::Slice["queries.task_tag_rules"].call

  def send_to(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  def sourced(repo)
    create(:task, :external).tap do |task|
      create(:task_source, task:, provider: "github", url: "https://github.com/#{repo}/issues/1")
    end
  end

  def sourced_from_linear(workspace, key)
    create(:task, :external).tap do |task|
      create(:task_source, task:, provider: "linear", url: "https://linear.app/#{workspace}/issue/#{key}/a-title")
    end
  end

  def stored(id) = rules.find { it.id == id }

  def tag_names(task) = Tasks::Slice["repos.task_repo"].by_id(task.id).tags.map(&:name)

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

      it "shows each rule's provider" do
        rule("acme/ENG", "work", provider: "linear")
        get "/admin/tasks/rules"

        expect(page.all(".rule-row").map { it.find(".rule-provider").text })
          .to eq(%w[GitHub GitHub Linear])
      end

      it "counts them" do
        get "/admin/tasks/rules"

        expect(page).to have_css(".page-head-sub", text: "2 rules")
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

      it "sits under the tasks section" do
        get "/admin/tasks/rules"

        expect(page).to have_css(".ctx-where", text: %r{Daily\s+/\s+tasks})
      end
    end

    it "says something useful when there is no rule yet" do
      get "/admin/tasks/rules"

      expect(page).to have_css(".empty")
    end

    it "is linked from the external tab" do
      get "/admin/tasks", filter: "external"

      expect(page).to have_link("Tag rules", href: "/admin/tasks/rules")
    end

    it "says adding a rule tags tasks already imported, and editing one does not", :aggregate_failures do
      rule("aaronmallen/*", "projects")
      get "/admin/tasks/rules"

      expect(page.find(".rule-capture")).to have_text("also tags every task already imported")
      expect(page.find(".rule-editor")).to have_text("Tasks already imported keep the tags they have")
    end

    describe "adding a rule" do
      it "offers GitHub or Linear, with GitHub chosen", :aggregate_failures do
        get "/admin/tasks/rules"
        select = page.find(".rule-capture select[name='rule[provider]']")

        expect(select.all("option").map { [it.value, it.text] }).to eq([%w[github GitHub], %w[linear Linear]])
        expect(select.find("option[selected]").value).to eq("github")
      end

      it "stores the provider it is given" do
        add("acme/ENG", "work", provider: "linear")

        expect(rules.map { [it.provider, it.pattern] }).to eq([%w[linear acme/eng]])
      end

      it "tags only the Linear tasks a Linear rule matches", :aggregate_failures do
        eng = sourced_from_linear("acme", "ENG-12")
        ops = sourced_from_linear("acme", "OPS-3")
        github = sourced("acme/eng")
        add("acme/eng", "work", provider: "linear")

        expect([tag_names(eng), tag_names(ops), tag_names(github)]).to eq([%w[work], [], []])
      end

      it "holds a GitHub rule and a Linear rule for the same pattern" do
        add("acme/*", "work")
        add("acme/*", "work", provider: "linear")

        expect(rules.map(&:provider)).to contain_exactly("github", "linear")
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

      it "tags the tasks already imported from a matching repo", :aggregate_failures do
        site = sourced("aaronmallen/aaronmallen.me")
        stranger = sourced("octocat/hello-world")
        add("aaronmallen/*", "projects")

        expect(tag_names(site)).to eq(%w[projects])
        expect(tag_names(stranger)).to be_empty
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

      it "says why it refused a rule with no tags" do
        add("aaronmallen/*", " , ")

        expect(page).to have_css("#rule-tags-error", text: message(:tags, "blank"))
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
    end

    describe "editing a rule" do
      let!(:existing) { rule("aaronmallen/*", "projects") }

      it "rewrites the pattern and tags" do
        send_to("/admin/tasks/rules/#{existing.id}", rule: { pattern: "aaronmallen/aaronmallen.me", tags: "ruby" })

        expect([stored(existing.id).pattern, stored(existing.id).tags.map(&:name)])
          .to eq(["aaronmallen/aaronmallen.me", %w[ruby]])
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

      it "tags no task already imported" do
        site = sourced("aaronmallen/aaronmallen.me")
        send_to("/admin/tasks/rules/#{existing.id}", rule: { pattern: "aaronmallen/*", tags: "projects, ruby" })

        expect(tag_names(site)).to be_empty
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

      it "leaves every task's tags as they were" do
        site = sourced("aaronmallen/aaronmallen.me")
        Tasks::Slice["repos.task_repo"].replace_tags(site.id, %w[projects])
        send_to("/admin/tasks/rules/#{existing.id}/delete")

        expect(tag_names(site)).to eq(%w[projects])
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
    let!(:existing) { rule("aaronmallen/*", "projects") }

    it "redirects the list to sign in", :aggregate_failures do
      get "/admin/tasks/rules"

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
      expect(last_response.body).not_to include("aaronmallen/*")
    end

    it "adds nothing" do
      post "/admin/tasks/rules", rule: { pattern: "octocat/*", tags: "ruby" }

      expect(rules.map(&:pattern)).to eq(%w[aaronmallen/*])
    end

    it "edits nothing" do
      post "/admin/tasks/rules/#{existing.id}", rule: { pattern: "octocat/*", tags: "ruby" }

      expect(stored(existing.id).pattern).to eq("aaronmallen/*")
    end

    it "deletes nothing" do
      post "/admin/tasks/rules/#{existing.id}/delete"

      expect(stored(existing.id)).not_to be_nil
    end
  end
end
