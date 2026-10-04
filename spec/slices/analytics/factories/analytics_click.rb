# frozen_string_literal: true

Spec::DB::Factories.define(:analytics_click) do |f|
  f.event_id { Spec::DB::Factories.create(:analytics_event).id }
  f.link_host "docs.example"
  f.link_path "/guide"
  f.occurred_at { Time.now }
end
