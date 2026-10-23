Feature: API visible text
  A field made only of Unicode spaces is refused, naming the field, and real words keep the spaces around them.

  Background:
    Given an API token that may do all but "nothing"
    And the owner calls POST "decisions" with:
      """
      { "title": "Queue", "problem": "Jobs" }
      """
    And I keep the answer's "id" as "decision"
    And the owner calls POST "decisions" with:
      """
      { "title": "Closed", "problem": "Jobs" }
      """
    And I keep the answer's "id" as "closed"
    And the owner calls POST "decisions/{closed}/options" with:
      """
      { "title": "Sidekiq" }
      """
    And I keep the answer's "id" as "option"
    And the owner calls POST "decisions/{closed}/drop" with:
      """
      { "reason": "No need" }
      """
    And the owner calls POST "journal_entries" with:
      """
      { "body": "Shipped it" }
      """
    And I keep the answer's "id" as "entry"
    And the owner calls POST "posts" with:
      """
      { "title": "Hello", "body": "First" }
      """
    And I keep the answer's "id" as "post"
    And the owner calls POST "posts/{post}/publish"
    And the owner calls PATCH "posts/{post}" with:
      """
      { "body": "Second", "edit_note": "Fixed a word" }
      """
    And I keep the post's newest edit as "edit"

  Scenario Outline: <what> made only of Unicode spaces is refused with a 422 naming <field>
    When I call the API <method> "<path>" with the body '<body>'
    Then the API answers 422
    And the API answer's errors are only "<field>"

    Examples:
      | what                    | field   | method | path                            | body                                                                       |
      | a decision title        | title   | POST   | decisions                       | {"title": " 　", "problem": "Jobs"}                               |
      | a decision problem      | problem | POST   | decisions                       | {"title": "Queue", "problem": " 　"}                              |
      | a decision note         | note    | PATCH  | decisions/{closed}              | {"title": "New", "note": " 　"}                                   |
      | a decision option title | title   | POST   | decisions/{decision}/options    | {"title": " 　"}                                                  |
      | a decision option note  | note    | PATCH  | decisions/{closed}/options/{option} | {"title": "New", "note": " 　"}                               |
      | a decision comment      | body    | POST   | decisions/{decision}/comments   | {"body": " 　"}                                                   |
      | a decision reason       | reason  | POST   | decisions/{decision}/drop       | {"reason": " 　"}                                                 |
      | a journal entry         | body    | POST   | journal_entries                 | {"body": " 　"}                                                   |
      | a journal edit          | body    | PATCH  | journal_entries/{entry}         | {"body": " 　"}                                                   |
      | a revised edit note     | note    | PATCH  | posts/{post}/edits/{edit}       | {"note": " 　"}                                                   |
      | a saved view name       | name    | POST   | saved_views                     | {"name": " 　", "screen": "tasks"}                                |
      | a person name           | name    | POST   | people                          | {"name": " 　", "key": "ada", "mastodon_handle": "@ada@ruby.social"} |
      | a task title            | title   | POST   | tasks                           | {"title": " 　"}                                                  |

  Scenario Outline: <what> around real words is kept as typed
    When I call the API POST "<path>" with the body '<body>'
    And I keep the answer's "id" as "made"
    And I GET "/<path>/{made}" through the API
    Then the API answer at "title" is "\" Pick a queue \""

    Examples:
      | what              | path      | body                                                   |
      | A task title      | tasks     | {"title": " Pick a queue "}                  |
      | A decision title  | decisions | {"title": " Pick a queue ", "problem": "Jobs"} |
