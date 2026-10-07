# frozen_string_literal: true

module Social
  module Repos
    class PersonMutations < DB::Repo
      root :people

      stamped_commands :create, :update
      commands delete: :by_pk
    end
  end
end
