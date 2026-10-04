# frozen_string_literal: true

RSpec.describe Blog::Contract do
  include Dry::Monads[:result]

  def blank = "\u2003\u3000"

  def closed = @closed ||= create(:decision, status: "dropped")

  def decision = @decision ||= create(:decision)

  def edits(**fields) = [{ original: "Body", reason: "Tighter", replacement: "Text" }.merge(fields)]

  def op(slice, name) = Hanami.app.slices[slice]["operations.#{name}"]

  def option = create(:decision_option, decision_id: closed.id)

  def post_fields(**fields)
    { title: "A post", slug: "a-post", tags: "", summary: "", body: "Body", publish_at: "" }.merge(fields)
  end

  def published = @published ||= create(:post, :published)

  before { connect_social_networks }

  {
    "an API token name" => [:name, -> { op(:api, :mint_token).call(name: blank) }],
    "a decision title" => [:title, -> { op(:decisions, :open_decision).call(title: blank, problem: "Jobs") }],
    "a decision problem" => [:problem, -> { op(:decisions, :open_decision).call(title: "Queue", problem: blank) }],
    "a decision note" => [
      :note, -> { op(:decisions, :edit_decision).call(closed.id, title: "New", problem: "Jobs", note: blank) },
    ],
    "a decision option title" => [
      :title, -> { op(:decisions, :add_decision_option).call(decision.id, title: blank, body: "") },
    ],
    "a decision option note" => [
      :note, -> { op(:decisions, :edit_decision_option).call(closed.id, option.id, title: "New", note: blank) },
    ],
    "a decision comment" => [:body, -> { op(:decisions, :add_decision_comment).call(decision.id, body: blank) }],
    "a decision reason" => [:reason, -> { op(:decisions, :drop_decision).call(decision.id, reason: blank) }],
    "a journal entry" => [:body, -> { op(:record, :save_journal_entry).call({ body: blank, tags: "" }) }],
    "a journal edit" => [
      :body, -> { op(:record, :update_journal_entry).call(create(:journal_entry).id, body: blank, tags: "") },
    ],
    "a post title" => [:title, -> { op(:posts, :save_post).call(post_fields(title: blank, slug: "a-post")) }],
    "a post edit note" => [
      :edit_note, -> { op(:posts, :save_post).call(post_fields(body: "New", edit_note: blank), id: published.id) },
    ],
    "a revised edit note" => [
      :note, lambda {
        op(:posts, :revise_edit_note).call(published.id, create(:post_edit, post_id: published.id).id, note: blank)
      },
    ],
    "a project name" => [:name, -> { op(:projects, :save_project).call({ name: blank, tags: "" }) }],
    "a work entry organization" => [
      :org, -> { op(:projects, :add_work_entry).call(org: blank, role: "Dev", from_year: "2020") },
    ],
    "a work entry role" => [
      :role, -> { op(:projects, :add_work_entry).call(org: "Acme", role: blank, from_year: "2020") },
    ],
    "a saved view name" => [:name, -> { op(:saved_views, :create_saved_view).call(name: blank, screen: "tasks") }],
    "a person name" => [
      :name, -> { op(:social, :save_person).call({ name: blank, key: "ada", mastodon_handle: "@ada@ruby.social" }) },
    ],
    "a social post part" => [
      :parts, -> { op(:social, :compose_social_post).call({ parts: ["Hello", blank], targets: %w[mastodon] }) },
    ],
    "a saved social post part" => [
      :parts, -> { op(:social, :save_social_post).call(parts: [blank], targets: %w[mastodon], status: "draft") },
    ],
    "a task title" => [:title, -> { op(:tasks, :capture_task).call({ title: blank, note: "", tags: "" }) }],
    "a task comment" => [:body, -> { op(:tasks, :add_task_comment).call(create(:task).id, body: blank) }],
  }.each do |name, (field, write)|
    it "refuses #{name} with a field error" do
      expect(instance_exec(&write)).to eq(Failure([:invalid, { field => ["blank"] }]))
    end
  end

  {
    "the original" => :original,
    "the reason" => :reason,
  }.each do |name, field|
    it "refuses a suggestion with #{name} blank" do
      result = op(:suggestions, :replace_post_edits).call(create(:post).id, edits: edits(field => blank))

      expect(result).to eq(Failure([:invalid, { edits: { 0 => { field => ["blank"] } } }]))
    end
  end

  describe "around real words" do
    def typed = "\u2003Pick a queue\u00a0"

    it "keeps a task title as typed" do
      expect(op(:tasks, :capture_task).call({ title: typed, note: "", tags: "" }).value!.last.title).to eq(typed)
    end

    it "keeps a decision title as typed" do
      expect(op(:decisions, :open_decision).call(title: typed, problem: "Jobs").value!.title).to eq(typed)
    end

    it "keeps a social post part as typed" do
      saved = op(:social, :save_social_post).call(parts: [typed], targets: %w[mastodon], status: "draft").value!

      expect(saved.parts.map(&:body)).to eq([typed])
    end

    it "keeps a project name as typed" do
      expect(op(:projects, :save_project).call({ name: typed, tags: "" }).value!.name).to eq(typed)
    end
  end
end
