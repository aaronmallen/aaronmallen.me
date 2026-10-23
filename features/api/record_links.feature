Feature: API record links
  The API links any two records, lists a record's links by kind and removes a link, and the MCP tools answer as it does.

  Background:
    Given an API token with the scopes "read suggest write publish delete health mail agents notes contacts"
    And a record link post titled "On hosting"
    And a record link commit titled "Move the server"

  Scenario: Linking answers 201 with the record and its links, and the link shows from the other record
    When I call the API with "POST /api/v1/links/post/1" and:
      """
      { "other_kind": "commit", "other_id": 1 }
      """
    Then the call answers 201
    And the answer matches:
      """
      {
        "kind": "post",
        "id": 1,
        "links": {
          "commit": [{ "kind": "commit", "id": 1, "title": "Move the server", "day": "2026-09-30", "url": "/admin/commits/1" }]
        }
      }
      """
    When I call the record links API with "GET /api/v1/links/commit/1"
    Then the record links API lists the titles "post: On hosting"

  Scenario: Linking the same pair twice is refused with a 422 naming the field
    Given the record links tie the post 1 to the commit 1
    When I call the API with "POST /api/v1/links/commit/1" and:
      """
      { "other_kind": "post", "other_id": 1 }
      """
    Then the call answers 422
    And the answer's "errors" is:
      """
      { "other_id": ["these two records are already linked"] }
      """

  Scenario: Linking a record to itself is refused with a 422
    When I call the API with "POST /api/v1/links/post/1" and:
      """
      { "other_kind": "post", "other_id": 1 }
      """
    Then the call answers 422
    And the answer's "message" is "other_id: a record cannot link to itself"

  Scenario: Linking two tasks is refused and points at link_tasks
    Given a record link task titled "One"
    And a record link task titled "Two"
    When I call the API with "POST /api/v1/links/task/1" and:
      """
      { "other_kind": "task", "other_id": 2 }
      """
    Then the answer's "errors" is:
      """
      { "other_id": ["two tasks take link_tasks, which gives the link a type"] }
      """

  Scenario: Linking a record that is gone on the other side is refused with a 422
    When I call the API with "POST /api/v1/links/post/1" and:
      """
      { "other_kind": "commit", "other_id": 999999 }
      """
    Then the call answers 422
    And the answer's "errors" is:
      """
      { "other_id": ["that record is gone, so find another"] }
      """

  Scenario: Linking a kind it does not know is refused with a 422 that names every kind it links
    When I call the record links API with "POST /api/v1/links/post/1" and:
      """
      { "other_kind": "person", "other_id": 1 }
      """
    Then the record links API answers 422 with errors only on "other_kind"
    And the record links API message names the kinds "task, post, social_post, journal_entry, commit, project, work_entry, decision, pull_request, mail_thread, memory_file, artifact, note, note_folder"

  Scenario: Linking any two kinds shows the link from both sides
    When the record links API links every pair of kinds
    Then the record links API shows each record linked to every other kind

  Scenario: Linking a mail thread with the mail scope works from either side
    Given a record link mail_thread titled "Lunch on Friday"
    When I call the API with "POST /api/v1/links/mail_thread/1" and:
      """
      { "other_kind": "post", "other_id": 1 }
      """
    Then the call answers 201
    And the answer matches:
      """
      { "kind": "mail_thread", "id": 1, "links": { "post": [{ "id": 1, "title": "On hosting" }] } }
      """
    When I call the record links API with "GET /api/v1/links/post/1"
    Then the record links API lists the titles "mail_thread: Lunch on Friday"

  Scenario: Linking a mail thread on either side without the mail scope is refused, naming mail
    Given a record link mail_thread titled "Lunch on Friday"
    And an API token with the scopes "read write delete"
    When I call the record links API with "POST /api/v1/links/post/1" and:
      """
      { "other_kind": "mail_thread", "other_id": 1 }
      """
    Then the record links API refuses for want of the "mail" scope
    When I call the record links API with "POST /api/v1/links/mail_thread/1" and:
      """
      { "other_kind": "post", "other_id": 1 }
      """
    Then the record links API refuses for want of the "mail" scope
    And the database answers "0" for:
      """
      select count(*) from record_links
      """

  Scenario: Linking a note or folder on either side without the notes scope is refused, naming notes
    Given a record link note titled "Draft ideas"
    And a record link note_folder titled "work"
    And an API token with the scopes "read suggest write publish delete health mail agents contacts"
    When I call the record links API with "POST /api/v1/links/post/1" and:
      """
      { "other_kind": "note", "other_id": 1 }
      """
    Then the record links API refuses for want of the "notes" scope
    When I call the record links API with "POST /api/v1/links/note_folder/1" and:
      """
      { "other_kind": "post", "other_id": 1 }
      """
    Then the record links API refuses for want of the "notes" scope
    And the database answers "0" for:
      """
      select count(*) from record_links
      """

  Scenario: Linking a note with the notes scope stores the link
    Given a record link note titled "Draft ideas"
    When I call the API with "POST /api/v1/links/post/1" and:
      """
      { "other_kind": "note", "other_id": 1 }
      """
    Then the call answers 201
    And the database answers "1" for:
      """
      select count(*) from record_links
      """

  Scenario: Linking from an unknown record answers 404
    When I call the API with "POST /api/v1/links/journal_entry/999999" and:
      """
      { "other_kind": "commit", "other_id": 1 }
      """
    Then the call answers 404
    And the answer's "message" is "no journal entry has the ID 999999"

  Scenario: Removing a link works from whichever side
    Given the record links tie the post 1 to the commit 1
    When I call the API with "DELETE /api/v1/links/commit/1/post/1"
    Then the call answers 200
    And the answer's "links" is:
      """
      {}
      """
    And the database answers "0" for:
      """
      select count(*) from record_links
      """

  Scenario: Removing a pair with no link answers 404
    When I call the API with "DELETE /api/v1/links/post/1/commit/1"
    Then the call answers 404
    And the answer's "message" is "post 1 has no link to commit 1"

  Scenario: Removing a link to a mail thread works with the mail scope
    Given a record link mail_thread titled "Lunch on Friday"
    And the record links tie the post 1 to the mail_thread 1
    When I call the API with "DELETE /api/v1/links/mail_thread/1/post/1"
    Then the call answers 200
    And the answer's "links" is:
      """
      {}
      """
    And the database answers "0" for:
      """
      select count(*) from record_links
      """

  Scenario: Removing a link to a mail thread without the mail scope is refused, naming mail
    Given a record link mail_thread titled "Lunch on Friday"
    And the record links tie the post 1 to the mail_thread 1
    And an API token with the scopes "read write delete"
    When I call the record links API with "DELETE /api/v1/links/post/1/mail_thread/1"
    Then the record links API refuses for want of the "mail" scope
    And the database answers "1" for:
      """
      select count(*) from record_links
      """

  Scenario: Removing a link to a kind it does not know is refused with a 422
    When I call the record links API with "DELETE /api/v1/links/post/1/person/1"
    Then the record links API answers 422 with errors only on "other_kind"

  Scenario: Listing groups a record's links by kind, in the order of the kinds
    Given a record link decision titled "Pick a host"
    And a record link task titled "Order the Pi"
    And the record links tie the decision 1 to the commit 1
    And the record links tie the decision 1 to the task 1
    When I call the record links API with "GET /api/v1/links/decision/1"
    Then the record links API lists the titles "task: Order the Pi; commit: Move the server"

  Scenario: Listing leaves a linked mail thread out without the mail scope
    Given a record link task titled "Answer Sam"
    And a record link mail_thread titled "Lunch on Friday"
    And the record links tie the task 1 to the mail_thread 1
    And an API token with the scopes "read write delete"
    When I call the API with "GET /api/v1/links/task/1"
    Then the answer's "links" is:
      """
      {}
      """

  Scenario: Listing leaves a linked note and folder out without the notes scope
    Given a record link note titled "Draft ideas"
    And a record link note_folder titled "work"
    And the record links tie the post 1 to the note 1
    And the record links tie the post 1 to the note_folder 1
    And an API token with the scopes "read suggest write publish delete health mail agents contacts"
    When I call the API with "GET /api/v1/links/post/1"
    Then the answer's "links" is:
      """
      {}
      """

  Scenario: Listing shows a linked note and folder with the notes scope
    Given a record link note titled "Draft ideas"
    And a record link note_folder titled "work"
    And the record links tie the post 1 to the note 1
    And the record links tie the post 1 to the note_folder 1
    When I call the record links API with "GET /api/v1/links/post/1"
    Then the record links API lists the titles "note: Draft ideas; note_folder: work"

  Scenario: Listing the links of a mail thread without the mail scope is refused
    Given a record link mail_thread titled "Lunch on Friday"
    And an API token with the scopes "read write delete"
    When I call the record links API with "GET /api/v1/links/mail_thread/1"
    Then the record links API refuses for want of the "mail" scope

  Scenario: Listing cuts a long title to 120 characters
    Given the database runs:
      """
      insert into journal_entries (entry_date, entry_time, body, body_html)
        values ('2026-09-30', '09:00', repeat('word ', 100), '<p>words</p>');
      insert into record_links (left_kind, left_id, right_kind, right_id) values ('post', 1, 'journal_entry', 1)
      """
    When I call the record links API with "GET /api/v1/links/post/1"
    Then the record links API title at "links.journal_entry.0.title" runs to 120 characters

  Scenario: Listing a record with no links answers no groups
    When I call the API with "GET /api/v1/links/post/1"
    Then the call answers 200
    And the answer's "links" is:
      """
      {}
      """

  Scenario: Listing a kind it does not know is refused with a 422
    When I call the record links API with "GET /api/v1/links/person/1"
    Then the record links API answers 422 with errors only on "kind"

  Scenario: Listing an unknown record answers 404
    When I call the API with "GET /api/v1/links/post/999999"
    Then the call answers 404
    And the answer's "message" is "no post has the ID 999999"

  Scenario: The MCP tools link, unlink and list as the API does
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write delete"
    Then the record MCP tool "link_records" answers as "POST /api/v1/links/post/1" does once "DELETE /api/v1/links/post/1/commit/1" undoes it, given:
      """
      { "kind": "post", "id": 1, "other_kind": "commit", "other_id": 1 }
      """
    And the record MCP tool "list_links" answers as "GET /api/v1/links/commit/1" does, given:
      """
      { "kind": "commit", "id": 1 }
      """
    And the record MCP tool "unlink_records" answers as "DELETE /api/v1/links/post/1/commit/1" does once 'POST /api/v1/links/post/1 {"other_kind": "commit", "other_id": 1}' undoes it, given:
      """
      { "kind": "post", "id": 1, "other_kind": "commit", "other_id": 1 }
      """

  Scenario: The MCP tools give the message the API gives for an unknown record or a pair linked twice
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write delete"
    And the record links tie the post 1 to the commit 1
    Then the record MCP tool "list_links" gives the message "GET /api/v1/links/post/999999" answers, given:
      """
      { "kind": "post", "id": 999999 }
      """
    And the record MCP tool "link_records" gives the message "POST /api/v1/links/post/1" answers, given:
      """
      { "kind": "post", "id": 1, "other_kind": "commit", "other_id": 1 }
      """
