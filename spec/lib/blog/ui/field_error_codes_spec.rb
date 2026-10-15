# frozen_string_literal: true

RSpec.describe Blog::UI::FieldError do
  forms = {
    "Admin::UI::Components::Calendar::FieldError" => [%w[Calendar::Contracts::EventContract]],
    "Admin::UI::Components::Decisions::FieldError" => [
      %w[
        Decisions::Contracts::DecisionCommentContract Decisions::Contracts::DecisionContract
        Decisions::Contracts::DecisionOptionContract Decisions::Contracts::ReasonContract
        Decisions::Contracts::ResolutionContract
      ],
    ],
    "Admin::UI::Components::Files::FieldError" => [%w[Shares::Contracts::ShareContract]],
    "Admin::UI::Components::Journal::FieldError" => [
      %w[Record::Contracts::JournalEditContract Record::Contracts::JournalEntryContract],
    ],
    "Admin::UI::Components::Links::FieldError" => [%w[Shares::Contracts::ShortLinkContract]],
    "Admin::UI::Components::Mail::FieldError" => [%w[Mail::Contracts::SendContract], %i[thread]],
    "Admin::UI::Components::People::FieldError" => [%w[Social::Contracts::PersonContract]],
    "Admin::UI::Components::Posts::FieldError" => [
      %w[Posts::Contracts::EditNoteContract Posts::Contracts::PostContract], %i[syndication_targets],
    ],
    "Admin::UI::Components::Projects::FieldError" => [%w[Projects::Contracts::ProjectContract]],
    "Admin::UI::Components::RecordLinks::FieldError" => [%w[Links::Contracts::RecordLinkContract]],
    "Admin::UI::Components::Social::FieldError" => [
      %w[Social::Contracts::ComposeSocialPostContract Social::Contracts::SocialPostContract],
      %i[connection_ids mode post_id status],
    ],
    "Admin::UI::Components::Tags::FieldError" => [%w[Tags::Contracts::TagContract]],
    "Admin::UI::Components::TaskRules::FieldError" => [%w[Tasks::Contracts::TaskRuleContract]],
    "Admin::UI::Components::Tasks::FieldError" => [
      %w[
        Tasks::Contracts::TaskCadenceContract Tasks::Contracts::TaskCommentContract Tasks::Contracts::TaskContract
        Tasks::Contracts::TaskLinkContract Tasks::Contracts::WorkSessionContract Tasks::Contracts::WorkedContract
      ],
      %i[tracked],
    ],
    "Admin::UI::Components::Tokens::FieldError" => [%w[API::Contracts::TokenContract]],
    "Admin::UI::Components::WorkEntries::FieldError" => [%w[Projects::Contracts::WorkEntryContract]],
    "Public::UI::Components::ContactFieldError" => [%w[Mail::Contracts::MessageContract]],
  }

  def missing(form, contract, unshown)
    error = Object.const_get(form)
    view = error.allocate
    i18n = error.slice["i18n"]
    ContractCodes.call(Object.const_get(contract)).except(*unshown).flat_map do |field, codes|
      keys = codes.map { error::OVERRIDES.dig(field, it) || ".#{field}.#{it}" }
      keys.reject { i18n.exists?(view.send(:_resolve_i18n_key, it)) }
    end
  end

  forms.each do |form, (contracts, unshown)|
    contracts.each do |contract|
      it "words every code #{contract} can return in #{form}" do
        expect(missing(form, contract, unshown)).to be_empty
      end
    end
  end
end
