Feature: Admin decision edit notes
  A closed decision asks for a note in a modal before it saves a new problem or option.

  Background:
    Given I am signed in to the admin
    And a decision "Pick a queue" with the problem "Jobs pile up"
    And the decision "Pick a queue" has the option "Sidekiq" with the body "Runs today"
    And I post to the decisions admin at "/admin/decisions/1/drop" with:
      | decision[reason] | No need |

  Scenario: A new title saves without asking
    When I visit "/admin/decisions/1/edit"
    And I fill the decision field "Title" with "Pick a job queue"
    And I click the button "Save"
    Then I see "Decision saved"

  Scenario: A new problem asks for the note in a modal and saves nothing yet
    When I visit "/admin/decisions/1/edit"
    And I fill the decision field "Problem" with "Jobs pile up fast"
    And I click the button "Save"
    Then the decision edit note dialog asks what changed
    And the database answers "Jobs pile up" for:
      """
      select problem from decisions
      """

  Scenario: A new problem saves with the note once confirmed
    When I visit "/admin/decisions/1/edit"
    And I fill the decision field "Problem" with "Jobs pile up fast"
    And I click the button "Save"
    And I note "Measured it" in the decision edit note dialog
    Then I see "Decision saved"
    And the database answers "Measured it" for:
      """
      select string_agg(note, ' | ') from decision_events where note is not null
      """

  Scenario: A renamed option asks for the note in a modal and saves nothing yet
    When I visit "/admin/decisions/1"
    And I rename the decision option "Sidekiq" to "Sidekiq 8"
    Then the decision edit note dialog asks what changed
    And the database answers "Sidekiq" for:
      """
      select title from decision_options
      """

  Scenario: A renamed option saves with the note once confirmed
    When I visit "/admin/decisions/1"
    And I rename the decision option "Sidekiq" to "Sidekiq 8"
    And I note "Renamed it" in the decision edit note dialog
    Then I see "Option saved"
    And the database answers "Renamed it" for:
      """
      select string_agg(note, ' | ') from decision_events where note is not null
      """
