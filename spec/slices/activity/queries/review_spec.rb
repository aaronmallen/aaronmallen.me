# frozen_string_literal: true

RSpec.describe Activity::Queries::Review do
  let(:wednesday) { Date.new(2026, 9, 16) }

  def at(day, hour = 12, minute = 0) = Blog::TimeZone.local_time(day.year, day.month, day.day, hour, minute)

  def carried(*days) = create(:task, :in_sprint).tap { |task| days.each { carry(task, it) } }

  def carry(task, from, to = from + 1, at: at(to, 0, 5))
    create(:task_event, :carried, task_id: task.id, from_sprint_on: from, to_sprint_on: to, occurred_at: at)
  end

  def close(kind, day, decision: create(:decision), chosen: nil, reason: "Settled", hour: 12)
    option_id = chosen && create(:decision_option, decision_id: decision.id, title: chosen).id
    create(:decision_event, decision_id: decision.id, kind:, option_id:, reason:, created_at: at(day, hour))
    decision
  end

  def review(period = "week", on = wednesday) = Activity::Slice["queries.review"].call(period:, on:)

  def sprint_on(day) = create(:sprint, sprint_date: day)

  def work(from, to) = create(:work_session, task_id: create(:task).id, started_at: from, ended_at: to)

  describe "the period" do
    it "runs a week from Monday to Sunday" do
      expect([review.from, review.to]).to eq([Date.new(2026, 9, 14), Date.new(2026, 9, 20)])
    end

    it "runs a month from its first day to its last" do
      found = review("month", Date.new(2026, 2, 10))

      expect([found.from, found.to]).to eq([Date.new(2026, 2, 1), Date.new(2026, 2, 28)])
    end
  end

  describe "tasks done" do
    it "groups them by the local day they closed" do
      late = create(:task, :done, completed_at: at(Date.new(2026, 9, 15), 23, 30))
      early = create(:task, :done, completed_at: at(Date.new(2026, 9, 17), 0, 30))

      done = review.done.transform_values { it.map(&:task_id) }

      expect(done).to eq(Date.new(2026, 9, 15) => [late.id], Date.new(2026, 9, 17) => [early.id])
    end

    it "carries each task's stored total" do
      task = create(:task, :done, completed_at: at(wednesday), worked_seconds: 5400)
      create(:work_session, task_id: task.id, started_at: at(wednesday, 9), ended_at: at(wednesday, 10))

      expect(review.done.fetch(wednesday).map(&:worked_seconds)).to eq([5400])
    end

    it "leaves out tasks closed outside the week and canceled tasks" do
      create(:task, :done, completed_at: at(Date.new(2026, 9, 13), 23, 59))
      create(:task, :done, completed_at: at(Date.new(2026, 9, 21), 0, 1))
      create(:task, :canceled, completed_at: at(wednesday))
      create(:task, completed_at: nil)

      expect(review.done).to be_empty
    end
  end

  describe "tasks carried" do
    def carry_forward(day) = Tasks::Slice["operations.current_sprint"].call(now: at(day, 0, 5))

    it "lists the most carries first" do
      once = carried(Date.new(2026, 9, 14))
      four = carried(*(Date.new(2026, 9, 14)..Date.new(2026, 9, 17)))
      twice = carried(wednesday, Date.new(2026, 9, 17))

      expect(review.carried.map { [it.task_id, it.carried_count] }).to eq([[four.id, 4], [twice.id, 2], [once.id, 1]])
    end

    it "names the last sprint each task left in the week" do
      carried(Date.new(2026, 9, 14), wednesday)

      expect(review.carried.map(&:sprint_date)).to eq([wednesday])
    end

    it "counts only the carries out of sprints in the week" do
      task = carried(Date.new(2026, 9, 11), Date.new(2026, 9, 18), Date.new(2026, 9, 21))

      expect(review.carried.map { [it.task_id, it.carried_count] }).to eq([[task.id, 1]])
    end

    it "keeps a task carried out of the week after it is carried again the next week" do
      task = create(:task, list: nil, sprint_id: sprint_on(Date.new(2026, 9, 18)).id)
      [Date.new(2026, 9, 21), Date.new(2026, 9, 22)].each { carry_forward(it) }

      expect([review, review("week", Date.new(2026, 9, 23))].map { it.carried.map { [it.task_id, it.sprint_date] } })
        .to eq([[[task.id, Date.new(2026, 9, 18)]], [[task.id, Date.new(2026, 9, 21)]]])
    end

    it "leaves out a task carried before the week and later scheduled into it" do
      task = create(:task, list: nil, sprint_id: sprint_on(wednesday).id, carried_count: 3)
      [Date.new(2026, 9, 1), Date.new(2026, 9, 2), Date.new(2026, 9, 3)].each { carry(task, it) }

      expect(review.carried).to be_empty
    end

    describe "moves that are not carries" do
      let(:task) { create(:task, :in_sprint) }

      it "leaves out a task scheduled ahead into a later sprint" do
        carry(task, wednesday, Date.new(2026, 9, 18), at: at(wednesday))

        expect(review.carried).to be_empty
      end

      it "leaves out a task moved back to an earlier sprint" do
        carry(task, wednesday, Date.new(2026, 9, 15))

        expect(review.carried).to be_empty
      end

      it "leaves out a task moved off its sprint onto a list" do
        create(:task_event, :carried, task_id: task.id, from_sprint_on: wednesday, to_list: "next")

        expect(review.carried).to be_empty
      end
    end
  end

  describe "posts and social posts" do
    it "lists what went out in the week" do
      post = create(:post, :published, published_at: at(Date.new(2026, 9, 15)))
      social = create(:social_post, :posted, posted_at: at(Date.new(2026, 9, 19)))

      expect([review.posts.map(&:source_id), review.social_posts.map(&:source_id)]).to eq([[post.id], [social.id]])
    end

    it "leaves out drafts and what went out in another week" do
      create(:post, :draft)
      create(:post, :published, published_at: at(Date.new(2026, 9, 21)))
      create(:social_post, :draft)
      create(:social_post, :posted, posted_at: at(Date.new(2026, 9, 13)))

      expect([review.posts, review.social_posts]).to eq([[], []])
    end
  end

  describe "the journal" do
    before do
      create(:journal_entry, entry_date: Date.new(2026, 9, 14), body: "one two three")
      create(:journal_entry, entry_date: Date.new(2026, 9, 15), body: "four five")
      create(:journal_entry, entry_date: Date.new(2026, 9, 15), body: "six")
      create(:journal_entry, entry_date: Date.new(2026, 9, 17), body: "seven")
      create(:journal_entry, entry_date: Date.new(2026, 9, 13), body: "left out of the week")
    end

    it "lists the entries written in the week" do
      expect(review.journal.entries.map(&:occurred_on).uniq).to eq(
        [Date.new(2026, 9, 14), Date.new(2026, 9, 15), Date.new(2026, 9, 17)],
      )
    end

    it "counts their words" do
      expect(review.journal.words).to eq(7)
    end

    it "gives the longest run of days in a row" do
      expect(review.journal.streak).to eq(2)
    end
  end

  it "gives no streak for a week with no entries" do
    expect(review.journal.streak).to eq(0)
  end

  describe "commits" do
    before do
      create(:commit, repo: "aaronmallen/one", commit_date: Date.new(2026, 9, 14), additions: 10, deletions: 2)
      create(:commit, repo: "aaronmallen/one", commit_date: Date.new(2026, 9, 20), additions: 5, deletions: 1)
      create(:commit, repo: "aaronmallen/two", commit_date: wednesday, additions: 3, deletions: 0)
      create(:commit, repo: "aaronmallen/two", commit_date: Date.new(2026, 9, 21), additions: 99, deletions: 99)
    end

    it "totals them by repo for the week" do
      expect(review.commits).to eq(
        "aaronmallen/one" => { commits: 2, additions: 15, deletions: 3 },
        "aaronmallen/two" => { commits: 1, additions: 3, deletions: 0 },
      )
    end
  end

  describe "decisions" do
    it "lists those resolved in the week with the option chosen" do
      decision = close("resolved", wednesday, chosen: "Sidekiq", reason: "It is cheap")
      closed = { decision_id: decision.id, outcome: "resolved", chosen: "Sidekiq", reason: "It is cheap" }
      found = review.decisions.map { it.to_h.slice(*closed.keys, :closed_on) }

      expect(found).to eq([closed.merge(closed_on: wednesday)])
    end

    it "lists those dropped in the week with no option chosen" do
      close("dropped", Date.new(2026, 9, 15))

      expect(review.decisions.map { [it.outcome, it.chosen] }).to eq([["dropped", nil]])
    end

    it "lists them in the order they closed" do
      later = close("dropped", Date.new(2026, 9, 18))
      sooner = close("resolved", Date.new(2026, 9, 14), chosen: "Postgres")

      expect(review.decisions.map(&:decision_id)).to eq([sooner.id, later.id])
    end

    it "lists a decision closed twice in the week once, with how it last closed" do
      decision = close("resolved", Date.new(2026, 9, 14), chosen: "Redis")
      create(:decision_event, decision_id: decision.id, kind: "reopened", reason: "Too costly",
                              created_at: at(Date.new(2026, 9, 15)))
      close("dropped", wednesday, decision:)

      expect(review.decisions.map { [it.decision_id, it.outcome] }).to eq([[decision.id, "dropped"]])
    end

    it "leaves out decisions closed in another week and events that close nothing" do
      close("resolved", Date.new(2026, 9, 13), chosen: "Redis", hour: 23)
      close("dropped", Date.new(2026, 9, 21), hour: 0)
      create(:decision_event, kind: "opened", created_at: at(wednesday))

      expect(review.decisions).to be_empty
    end
  end

  describe "time worked" do
    it "sums the sessions on each day of the week" do
      work(at(wednesday, 9), at(wednesday, 10))
      work(at(wednesday, 14), at(wednesday, 14, 30))

      expect(review.worked.fetch(wednesday)).to eq(5400)
    end

    it "splits a session that crosses midnight between both days" do
      work(at(Date.new(2026, 9, 15), 23), at(wednesday, 1, 30))

      expect(review.worked.values_at(Date.new(2026, 9, 15), wednesday)).to eq([3600, 5400])
    end

    it "counts only the part of a session inside the week" do
      work(at(Date.new(2026, 9, 13), 23), at(Date.new(2026, 9, 14), 1))

      expect([review.worked.keys.first, review.worked_seconds]).to eq([Date.new(2026, 9, 14), 3600])
    end

    it "gives every day of the week, with zero for days not worked" do
      expect(review.worked).to eq((Date.new(2026, 9, 14)..Date.new(2026, 9, 20)).to_h { [it, 0] })
    end
  end

  describe "a month" do
    let(:september) { review("month") }
    let(:inside) { [Date.new(2026, 9, 1), Date.new(2026, 9, 30)] }

    def fill(day)
      create(:task, :done, completed_at: at(day), worked_seconds: 60)
      carried(day)
      create(:post, :published, published_at: at(day))
      create(:social_post, :posted, posted_at: at(day))
      create(:journal_entry, entry_date: day, body: "a day")
      create(:commit, repo: "aaronmallen/one", commit_date: day, additions: 1, deletions: 0)
      work(at(day, 9), at(day, 10))
      close("resolved", day, chosen: "Sidekiq")
    end

    describe "with records on each edge of the month" do
      before { [Date.new(2026, 8, 31), *inside, Date.new(2026, 10, 1)].each { fill(it) } }

      it "groups the tasks done inside it" do
        expect(september.done.keys).to eq(inside)
      end

      it "lists the tasks carried inside it" do
        expect(september.carried.map(&:sprint_date).sort).to eq(inside)
      end

      it "lists the posts and social posts published inside it" do
        expect([september.posts, september.social_posts].map { it.map(&:occurred_on) }).to eq([inside, inside])
      end

      it "lists the journal entries written inside it" do
        expect(september.journal.entries.map(&:occurred_on)).to eq(inside)
      end

      it "totals the commits made inside it" do
        expect(september.commits.dig("aaronmallen/one", :commits)).to eq(2)
      end

      it "lists the decisions closed inside it" do
        expect(september.decisions.map(&:closed_on)).to eq(inside)
      end

      it "sums the time worked inside it" do
        expect(september.worked.select { _2.positive? }.keys).to eq(inside)
      end
    end
  end
end
