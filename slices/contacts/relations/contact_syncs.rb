# frozen_string_literal: true

module Contacts
  module Relations
    class ContactSyncs < Blog::DB::Relation
      schema :contact_syncs, infer: true
    end
  end
end
