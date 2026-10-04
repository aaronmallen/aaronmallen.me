# frozen_string_literal: true

RSpec.describe "Decisions" do
  let(:decision) { create(:decision, title: "Pick a queue", problem: "Jobs pile up") }
  let(:option) { create(:decision_option, decision_id: decision.id, title: "Sidekiq", body: "Runs today") }

  def call(name, *) = Decisions::Slice["operations.#{name}"].call(*)

  def drop(id = decision.id) = call(:drop_decision, id, { reason: "Not worth it" })

  def events(id) = Decisions::Slice["relations.decision_events"].where(decision_id: id).order(:id).to_a

  def kinds(id) = events(id).map { it[:kind] }

  def reload(id) = Decisions::Slice["repos.decision_repo"].by_id(id)

  def resolve(id = decision.id, option_id: option.id, reason: "It already runs")
    call(:resolve_decision, id, { option_id:, reason: })
  end

  def tag_names(id) = reload(id).tags.map(&:name)

  describe "opening a decision" do
    it "keeps the title and problem and records an opened event", :aggregate_failures do
      opened = call(:open_decision, { title: "Pick a queue", problem: "Jobs pile up\r\nOften" }).value!

      expect(opened).to have_attributes(title: "Pick a queue", problem: "Jobs pile up\nOften", status: "open")
      expect(events(opened.id)).to contain_exactly(include(kind: "opened", option_id: nil, reason: nil))
    end

    it "keeps its tags as private tags", :aggregate_failures do
      opened = call(:open_decision, { title: "Pick a queue", problem: "Jobs", tags: "Queues, ruby" }).value!

      expect(opened.tags.map(&:name)).to eq(%w[queues ruby])
      expect(opened.tags.map(&:scope)).to all(eq("private"))
    end

    it "refuses a blank problem and records nothing", :aggregate_failures do
      result = call(:open_decision, { title: "Pick a queue", problem: "  " })

      expect(result.failure).to eq([:invalid, { problem: ["blank"] }])
      expect(Decisions::Slice["relations.decisions"].count).to eq(0)
    end
  end

  describe "adding an option" do
    it "keeps the option and records an event", :aggregate_failures do
      added = call(:add_decision_option, decision.id, { title: "Sidekiq", body: "Runs **today**" }).value!

      expect(added).to have_attributes(decision_id: decision.id, title: "Sidekiq", body: "Runs **today**")
      expect(events(decision.id)).to contain_exactly(include(kind: "option_added", option_id: added.id))
    end

    it "takes an option with no body" do
      expect(call(:add_decision_option, decision.id, { title: "Do nothing" }).value!.body).to eq("")
    end

    it "refuses a closed decision" do
      drop

      expect(call(:add_decision_option, decision.id, { title: "Late idea", body: "" }).failure).to eq(:closed)
    end

    it "answers not found for a missing decision" do
      expect(call(:add_decision_option, 0, { title: "Sidekiq", body: "" }).failure).to eq(:not_found)
    end
  end

  describe "editing an option" do
    it "changes it in place and records an event with no note", :aggregate_failures do
      edited = call(:edit_decision_option, decision.id, option.id, { title: "Sidekiq 8", body: "Runs" }).value!

      expect(edited).to have_attributes(id: option.id, title: "Sidekiq 8", body: "Runs")
      expect(events(decision.id)).to contain_exactly(include(kind: "option_edited", note: nil))
    end

    it "records nothing when nothing changed" do
      call(:edit_decision_option, decision.id, option.id, { title: "Sidekiq", body: "Runs today" })

      expect(events(decision.id)).to be_empty
    end

    it "answers not found for another decision's option" do
      other = create(:decision_option)

      expect(call(:edit_decision_option, decision.id, other.id, { title: "Mine", body: "" }).failure).to eq(:not_found)
    end

    context "when the decision is closed" do
      before { resolve }

      it "needs a note", :aggregate_failures do
        result = call(:edit_decision_option, decision.id, option.id, { title: "Sidekiq", body: "Runs well" })

        expect(result.failure).to eq([:invalid, { note: ["blank"] }])
        expect(reload(decision.id).options.first.body).to eq("Runs today")
      end

      it "keeps the note on the event" do
        call(:edit_decision_option, decision.id, option.id, { title: "Sidekiq", body: "Runs well", note: "Typo" })

        expect(events(decision.id).last).to include(kind: "option_edited", option_id: option.id, note: "Typo")
      end
    end
  end

  describe "editing a decision" do
    it "records an edited event with no note while open", :aggregate_failures do
      edited = call(:edit_decision, decision.id, { title: "Pick a queue", problem: "Jobs pile up fast" }).value!

      expect(edited.problem).to eq("Jobs pile up fast")
      expect(events(decision.id)).to contain_exactly(include(kind: "edited", note: nil))
    end

    it "records nothing when nothing changed" do
      call(:edit_decision, decision.id, { title: "Pick a queue", problem: "Jobs pile up" })

      expect(events(decision.id)).to be_empty
    end

    it "answers not found for a missing decision" do
      expect(call(:edit_decision, 0, { title: "Pick a queue", problem: "Jobs" }).failure).to eq(:not_found)
    end

    describe "its tags" do
      def edit(**) = call(:edit_decision, decision.id, { title: "Pick a queue", problem: "Jobs pile up", ** })

      before { edit(tags: "hosting, queues") }

      it "adds them" do
        expect(tag_names(decision.id)).to eq(%w[hosting queues])
      end

      it "removes the ones left out" do
        edit(tags: "queues")

        expect(tag_names(decision.id)).to eq(%w[queues])
      end

      it "keeps them when the edit leaves them out" do
        edit

        expect(tag_names(decision.id)).to eq(%w[hosting queues])
      end

      it "records no event for a tag change" do
        expect(events(decision.id)).to be_empty
      end

      it "refuses a tag that is not a slug" do
        expect(edit(tags: "two words!").failure).to eq([:invalid, { tags: ["format"] }])
      end

      it "takes a tag change on a closed decision with no note" do
        drop
        edit(tags: "")

        expect(tag_names(decision.id)).to be_empty
      end
    end

    context "when the decision is closed" do
      before { drop }

      it "needs a note to change the problem", :aggregate_failures do
        result = call(:edit_decision, decision.id, { title: "Pick a queue", problem: "Jobs pile up fast" })

        expect(result.failure).to eq([:invalid, { note: ["blank"] }])
        expect(reload(decision.id).problem).to eq("Jobs pile up")
      end

      it "keeps the note on the event" do
        call(:edit_decision, decision.id, { title: "Pick a queue", problem: "Jobs pile up fast", note: "Clearer" })

        expect(events(decision.id).last).to include(kind: "edited", note: "Clearer")
      end

      it "takes a new title with no note" do
        call(:edit_decision, decision.id, { title: "Pick a job queue", problem: "Jobs pile up" })

        expect(events(decision.id).last).to include(kind: "edited", note: nil)
      end

      it "refuses a note over 500 characters" do
        result = call(:edit_decision, decision.id, { title: "Pick a queue", problem: "Fast", note: "a" * 501 })

        expect(result.failure).to match([:invalid, { note: [anything] }])
      end
    end
  end

  describe "resolving" do
    it "keeps the choice and records the reason", :aggregate_failures do
      resolved = resolve.value!

      expect(resolved).to have_attributes(status: "resolved", resolved_option_id: option.id)
      expect(events(decision.id).last).to include(kind: "resolved", option_id: option.id,
                                                  reason: "It already runs")
    end

    it "needs a reason" do
      expect(resolve(reason: " ").failure).to eq([:invalid, { reason: ["blank"] }])
    end

    it "refuses an option from another decision", :aggregate_failures do
      result = resolve(option_id: create(:decision_option).id)

      expect(result.failure).to eq([:invalid, { option_id: ["missing"] }])
      expect(reload(decision.id)).to have_attributes(status: "open", resolved_option_id: nil)
      expect(kinds(decision.id)).not_to include("resolved")
    end

    it "refuses a decision already closed" do
      drop

      expect(resolve.failure).to eq(:closed)
    end

    it "answers not found for a missing decision" do
      expect(resolve(0).failure).to eq(:not_found)
    end
  end

  describe "dropping" do
    it "closes with no choice and records the reason", :aggregate_failures do
      expect(drop.value!).to have_attributes(status: "dropped", resolved_option_id: nil)
      expect(events(decision.id).last).to include(kind: "dropped", option_id: nil, reason: "Not worth it")
    end

    it "needs a reason" do
      expect(call(:drop_decision, decision.id, { reason: "" }).failure).to eq([:invalid, { reason: ["blank"] }])
    end

    it "refuses a decision already closed" do
      resolve

      expect(drop.failure).to eq(:closed)
    end
  end

  describe "reopening" do
    it "clears the choice of a resolved decision and records the reason", :aggregate_failures do
      resolve
      reopened = call(:reopen_decision, decision.id, { reason: "Load grew" }).value!

      expect(reopened).to have_attributes(status: "open", resolved_option_id: nil)
      expect(events(decision.id).last).to include(kind: "reopened", reason: "Load grew")
    end

    it "opens a dropped decision" do
      drop

      expect(call(:reopen_decision, decision.id, { reason: "Back on" }).value!.status).to eq("open")
    end

    it "needs a reason" do
      drop

      expect(call(:reopen_decision, decision.id, { reason: nil }).failure).to eq([:invalid, { reason: ["blank"] }])
    end

    it "refuses an open decision" do
      expect(call(:reopen_decision, decision.id, { reason: "Again" }).failure).to eq(:open)
    end
  end

  describe "deleting an option" do
    it "deletes an option nothing chose, with its events", :aggregate_failures do
      added = call(:add_decision_option, decision.id, { title: "Resque", body: "" }).value!

      expect(call(:delete_decision_option, decision.id, added.id)).to be_success
      expect(reload(decision.id).options).to be_empty
      expect(events(decision.id)).to be_empty
    end

    it "refuses the option the resolution points at", :aggregate_failures do
      resolve

      expect(call(:delete_decision_option, decision.id, option.id).failure).to eq([:invalid, { id: ["chosen"] }])
      expect(reload(decision.id).options.map(&:id)).to eq([option.id])
    end

    it "deletes a once chosen option after a reopen" do
      resolve
      call(:reopen_decision, decision.id, { reason: "Load grew" })

      expect(call(:delete_decision_option, decision.id, option.id)).to be_success
    end

    it "answers not found for another decision's option" do
      expect(call(:delete_decision_option, decision.id, create(:decision_option).id).failure).to eq(:not_found)
    end
  end
end
