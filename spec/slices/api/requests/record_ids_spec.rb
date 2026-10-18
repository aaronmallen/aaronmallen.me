# frozen_string_literal: true

RSpec.describe "API record IDs", type: :request do
  def bodies
    {
      "add_decision_comment" => { body: "A note" },
      "add_decision_option" => { title: "Rent" },
      "add_memory_fact" => { type: "gotcha", text: "A note" },
      "add_shares_to_group" => { ids: [1] },
      "add_task_comment" => { body: "A note" },
      "add_work_session" => { started_at: "2026-10-01T09:00", ended_at: "2026-10-01T10:00" },
      "drop_decision" => { reason: "Moot" },
      "edit_decision_comment" => { body: "A note" },
      "edit_task_comment" => { body: "A note" },
      "link_records" => { other_kind: "post", other_id: 1 },
      "link_tasks" => { kind: "relates", other_id: 1 },
      "mark_mail_thread" => { status: "read" },
      "moderate_webmention" => { verdict: "approved" },
      "move_memory_file" => { scope: "global" },
      "move_task" => { list: "next" },
      "reopen_decision" => { reason: "Back" },
      "reorder_task" => { direction: "up" },
      "resolve_decision" => { option_id: 1, reason: "Cheaper" },
      "schedule_task" => { sprint_on: "" },
      "stage_task" => { stage: "ready" },
      "tag_decision" => { tags: ["house"] },
      "update_post_edit_note" => { note: "Typo" },
      "update_share" => { filename: "notes.txt" },
      "update_share_group" => { name: "Trip" },
      "update_share_group_file" => { filename: "notes.txt" },
      "update_work_session" => { started_at: "2026-10-01T09:00" },
    }
  end

  def call(operation, values)
    _, verb, path = operation
    filled = path.gsub(/\{(\w+)\}/) { |field| values.fetch(field[1..-2]) { fillers.fetch(it, 1) } }
    call_api(verb.to_sym, filled, bodies.fetch(operation.first, {}))
  end

  def fillers = { "kind" => "post", "other_kind" => "post", "scope" => "public", "tag" => "house" }

  def self.id_fields(path) = path.scan(/\{(\w+)\}/).flatten.select { it.end_with?("id") }

  API::OperationTable::OPERATIONS.to_h { [it, id_fields(it[2])] }.reject { _2.empty? }.each do |operation, fields|
    describe "#{operation[1].upcase} #{operation[2]}" do
      it "answers an unknown #{fields.first} with a 404" do
        answer = call(operation, fields.first => 999_999)

        expect([answer.fetch("error"), answer.fetch("message"), last_response.status])
          .to match(["not_found", include("999999"), 404])
      end

      fields.each do |field|
        it "refuses a #{field} that is not a number with a 422" do
          answer = call(operation, field => "abc")

          expect([answer.fetch("errors").keys, last_response.status]).to eq([[field], 422])
        end
      end
    end
  end
end
