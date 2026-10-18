# frozen_string_literal: true

RSpec.describe API::Helpers::Wording do
  Dir[Hanami.app.root.join("slices/api/endpoints/*.rb").to_s].each do |path|
    Object.const_get(API::Slice.autoloader.cpath_expected_at(path))
  end

  let(:unreached) do
    act = "the endpoint sets act itself"
    enum = "the schema takes only the values it lists"
    ids = "the schema takes one to #{Blog::Contract::MAX_IDS} IDs"
    integer = "the schema takes only an integer in range"
    listed = "the schema takes only a list of IDs"
    scoped = "the scope rule fails repo, project_id or task_id, never scope"
    unsent = "the endpoint never sends this field"

    {
      "Artifacts" => { "session_id.format" => integer, "type.format" => enum },
      "BulkMailThreadEndpoint" => {
        "act.format" => act, "ids.format" => ids, "ids.long" => ids, "label.format" => unsent, "to.format" => unsent,
      },
      "BulkPostEndpoint" => { "act.format" => act, "ids.format" => ids, "ids.long" => ids },
      "BulkTaskEndpoint" => { "act.format" => act, "ids.format" => ids, "ids.long" => ids, "to.format" => enum },
      "ClearInbox" => { "messages.format" => listed, "tasks.format" => listed, "webmentions.format" => listed },
      "Memory" => {
        "project_id.format" => integer, "scope.extra" => scoped, "scope.format" => enum, "scope.missing" => scoped,
        "session_id.format" => integer, "task_id.format" => "the endpoint turns a task's label into its ID first",
        "type.format" => enum,
      },
      "Posts" => { "syndication_targets.format" => enum },
      "SavedViews" => {
        "filters.format" => "the schema takes only text, and an object of text for types", "screen.format" => enum,
      },
      "SnoozeInbox" => { "messages.format" => listed, "tasks.format" => listed, "webmentions.format" => listed },
      "SnoozeMailThreads" => {
        "messages.format" => ids, "tasks.format" => unsent, "webmentions.format" => unsent,
      },
      "SocialPostEndpoint" => {
        "photos.duplicate" => unsent, "photos.many" => unsent, "photos.missing" => unsent,
        "photos.silent_part" => unsent,
      },
      "StartSession" => { "task_ids.format" => "the schema takes tasks by ID or label", "task_ids.long" => ids },
      "SuggestEdits" => {
        "edits.format" => "the schema takes part as an integer",
        "edits.many" => "the schema takes #{Blog::Constants::SUGGESTION_EDITS_MAX} edits at most",
      },
      "TaskRules" => { "provider.format" => enum },
      "Tasks" => {
        "cadence.format" => enum, "every.format" => integer, "month.format" => integer, "tracked.format" => unsent,
        "week.format" => enum, "weekday.format" => integer,
      },
      "UpdateShare" => { "code.format" => unsent },
      "UpdateShareGroup" => { "code.format" => unsent, "filename.format" => unsent },
      "UpdateShareGroupFile" => { "code.format" => unsent },
    }
  end

  endpoints = API::Endpoints.constants.sort.to_h { [it.to_s, API::Endpoints.const_get(it)] }.select { _2.is_a?(Module) }
  worded = %i[COMPLAINTS ERRORS]

  def codes(endpoint)
    endpoint::CONTRACTS.flat_map do |contract|
      ContractCodes.call(contract).flat_map { |field, field_codes| field_codes.map { "#{field}.#{it}" } }
    end.uniq
  end

  def worded?(endpoint, field, code)
    return API::Slice["i18n"].exists?("#{endpoint::ERRORS}.#{code}") if endpoint.const_defined?(:ERRORS, false)

    table = endpoint.const_defined?(:COMPLAINTS) ? endpoint::COMPLAINTS : Blog::Constants::EMPTY_HASH
    table.dig(field.to_sym, code) || table[code] || API::Helpers::Wording::SHARED[code]
  end

  endpoints.each do |name, endpoint|
    next unless worded.any? { endpoint.const_defined?(it, false) }

    it "names the contracts #{name} words" do
      expect(endpoint.const_defined?(:CONTRACTS, false)).to be(true)
    end

    next unless endpoint.const_defined?(:CONTRACTS, false)

    it "words every code #{name}'s contracts can return" do
      skipped = unreached.fetch(name, Blog::Constants::EMPTY_HASH)
      unworded = codes(endpoint).reject { skipped.key?(it) || worded?(endpoint, *it.split(".")) }

      expect(unworded).to eq([])
    end
  end

  it "skips only codes an endpoint's contracts can return" do
    stale = unreached.flat_map do |name, skipped|
      (skipped.keys - codes(API::Endpoints.const_get(name))).map { "#{name} #{it}" }
    end

    expect(stale).to eq([])
  end
end
