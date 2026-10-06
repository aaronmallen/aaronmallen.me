# frozen_string_literal: true

RSpec.describe "API visible text", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def blank = "\u2003\u3000"

  def call_api(verb, path, fields = nil)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    public_send(verb, "/api/v1/#{path}", fields && JSON.generate(fields), headers)
    JSON.parse(last_response.body)
  end

  def closed = @closed ||= create(:decision, status: "dropped")

  def decision = @decision ||= create(:decision)

  def option = create(:decision_option, decision_id: closed.id)

  def post_edit_path
    published = create(:post, :published)
    "posts/#{published.id}/edits/#{create(:post_edit, post_id: published.id).id}"
  end

  {
    "a decision title" => ["title", -> { [:post, "decisions", { title: blank, problem: "Jobs" }] }],
    "a decision problem" => ["problem", -> { [:post, "decisions", { title: "Queue", problem: blank }] }],
    "a decision note" => ["note", -> { [:patch, "decisions/#{closed.id}", { title: "New", note: blank }] }],
    "a decision option title" => ["title", -> { [:post, "decisions/#{decision.id}/options", { title: blank }] }],
    "a decision option note" => [
      "note", -> { [:patch, "decisions/#{closed.id}/options/#{option.id}", { title: "New", note: blank }] },
    ],
    "a decision comment" => ["body", -> { [:post, "decisions/#{decision.id}/comments", { body: blank }] }],
    "a decision reason" => ["reason", -> { [:post, "decisions/#{decision.id}/drop", { reason: blank }] }],
    "a journal entry" => ["body", -> { [:post, "journal_entries", { body: blank }] }],
    "a journal edit" => ["body", -> { [:patch, "journal_entries/#{create(:journal_entry).id}", { body: blank }] }],
    "a revised edit note" => ["note", -> { [:patch, post_edit_path, { note: blank }] }],
    "a saved view name" => ["name", -> { [:post, "saved_views", { name: blank, screen: "tasks" }] }],
    "a person name" => ["name", lambda {
      [:post, "people", { name: blank, key: "ada", mastodon_handle: "@ada@ruby.social" }]
    }],
    "a task title" => ["title", -> { [:post, "tasks", { title: blank }] }],
  }.each do |name, (field, request)|
    it "refuses #{name} made only of Unicode spaces with a 422 naming the field" do
      refusal = call_api(*instance_exec(&request))

      expect([refusal.fetch("errors").keys, last_response.status]).to eq([[field], 422])
    end
  end

  describe "around real words" do
    def typed = "\u2003Pick a queue\u00a0"

    it "keeps a task title as typed" do
      id = call_api(:post, "tasks", { title: typed }).fetch("id")

      expect(call_api(:get, "tasks/#{id}").fetch("title")).to eq(typed)
    end

    it "keeps a decision title as typed" do
      id = call_api(:post, "decisions", { title: typed, problem: "Jobs" }).fetch("id")

      expect(call_api(:get, "decisions/#{id}").fetch("title")).to eq(typed)
    end
  end
end
