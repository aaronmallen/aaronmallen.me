Feature: Notes through MCP
  An agent with the notes permission reads and writes the owner's notes and folders.

  Background:
    Given the note folder "work"

  Scenario: list_notes lists every note by title with its folder and pin
    Given the notes:
      | title | folder | pinned |
      | Zebra |        |        |
      | Alpha | work   | yes    |
    And an MCP client connected with the scopes "read notes"
    When I call the MCP tool "list_notes"
    Then the MCP answer holds:
      """
      {"count": 2, "notes": [{"title": "Alpha", "folder_id": 1, "pinned": true}, {"title": "Zebra", "folder_id": null, "pinned": false}]}
      """

  Scenario: search_notes finds notes by their words, folder path and tag
    Given the notes:
      | title    | body           | folder       | tags |
      | Retro    | What went well |              |      |
      | Invoice  |                | work/clients |      |
      | Gem list |                |              | ruby |
    And an MCP client connected with the scopes "read notes"
    When I call the MCP tool "search_notes" with:
      """
      {"query": "went well"}
      """
    Then the MCP answer holds:
      """
      {"notes": [{"title": "Retro"}]}
      """
    When I call the MCP tool "search_notes" with:
      """
      {"query": "work/clients"}
      """
    Then the MCP answer holds:
      """
      {"notes": [{"title": "Invoice"}]}
      """
    When I call the MCP tool "search_notes" with:
      """
      {"query": "#ruby"}
      """
    Then the MCP answer holds:
      """
      {"notes": [{"title": "Gem list"}]}
      """

  Scenario: read_note reads a note with its tags, version, links and linked records
    Given the notes:
      | title   | body                        | tags |
      | Plan    | See [[Brief]] and [[Later]] | ruby |
      | Brief   |                             |      |
      | Kickoff | Read [[Plan]]               |      |
    And a task "Write the brief"
    And the note "Plan" links the task "Write the brief"
    And an MCP client connected with the scopes "read notes"
    When I call the MCP tool "read_note" with:
      """
      {"id": 1}
      """
    Then the MCP answer holds:
      """
      {
        "title": "Plan", "body": "See [[Brief]] and [[Later]]", "tags": ["ruby"], "version": 1,
        "backlinks": [{"id": 3, "title": "Kickoff"}],
        "links_out": [{"id": 2, "title": "Brief"}, {"id": null, "title": "Later"}],
        "record_links": {"task": [{"title": "Write the brief"}]}
      }
      """
    When I call the MCP tool "read_note" with:
      """
      {"id": 999999}
      """
    Then the MCP tool refuses with "no note has the ID 999999"

  Scenario: create_note writes a note marked as an agent's
    Given the note "Plan"
    And an MCP client connected with the scopes "read notes"
    When I call the MCP tool "create_note" with:
      """
      {"title": "Steps", "body": "After [[Plan]]", "folder_id": 1, "tags": ["ruby"]}
      """
    Then the MCP answer holds:
      """
      {"title": {"untrusted": true, "text": "Steps"}, "body": {"untrusted": true, "text": "After [[Plan]]"}, "folder_id": 1, "tags": ["ruby"]}
      """
    And the note "Steps" was written by an agent
    When I call the MCP tool "read_note" with:
      """
      {"id": 1}
      """
    Then the MCP answer holds:
      """
      {"backlinks": [{"id": 2, "title": {"untrusted": true, "text": "Steps"}}]}
      """
    When I call the MCP tool "create_note"
    Then the MCP answer holds:
      """
      {"title": {"untrusted": true, "text": "Untitled"}}
      """
    When I call the MCP tool "create_note" with:
      """
      {"title": "plan"}
      """
    Then the MCP tool refuses with "title: another note has that title"
    When I call the MCP tool "create_note" with:
      """
      {"title": "Other", "folder_id": 999999}
      """
    Then the MCP tool refuses with "folder_id: no note folder has that ID"

  Scenario: edit_note saves an edit against the version it read
    Given the notes:
      | title   | body          |
      | Plan    | Steps         |
      | Kickoff | Read [[Plan]] |
    And an MCP client connected with the scopes "read notes"
    When I call the MCP tool "edit_note" with:
      """
      {"id": 1, "version": 1, "body": "New steps", "tags": ["ruby"]}
      """
    Then the MCP answer holds:
      """
      {"body": {"untrusted": true, "text": "New steps"}, "tags": ["ruby"], "version": 2}
      """
    When I call the MCP tool "edit_note" with:
      """
      {"id": 1, "version": 1, "body": "Stale"}
      """
    Then the MCP tool refuses with "version: the note changed since you read it; read_note gives the new version to edit"
    And the note "Plan" reads "New steps"
    When I call the MCP tool "edit_note" with:
      """
      {"id": 1, "version": 2, "title": "Roadmap"}
      """
    Then the MCP answer holds:
      """
      {"relinked": 1}
      """
    And the note "Kickoff" reads "Read [[Roadmap]]"
    When I call the MCP tool "edit_note" with:
      """
      {"id": 999999, "version": 1, "body": "x"}
      """
    Then the MCP tool refuses with "no note has the ID 999999"

  Scenario: rename_note retitles a note and rewrites the links to it
    Given the notes:
      | title   | body          |
      | Plan    |               |
      | Kickoff | Read [[Plan]] |
    And an MCP client connected with the scopes "read notes"
    When I call the MCP tool "rename_note" with:
      """
      {"id": 1, "title": "Roadmap"}
      """
    Then the MCP answer holds:
      """
      {"title": {"untrusted": true, "text": "Roadmap"}, "relinked": 1}
      """
    When I call the MCP tool "read_note" with:
      """
      {"id": 2}
      """
    Then the MCP answer holds:
      """
      {"body": {"untrusted": true, "text": "Read [[Roadmap]]"}}
      """
    When I call the MCP tool "rename_note" with:
      """
      {"id": 1, "title": " "}
      """
    Then the MCP tool refuses with "title: give the note a title"
    When I call the MCP tool "rename_note" with:
      """
      {"id": 999999, "title": "Roadmap"}
      """
    Then the MCP tool refuses with "no note has the ID 999999"

  Scenario: move_note files a note in a folder and back at the top level
    Given the note "Plan"
    And an MCP client connected with the scopes "read notes"
    When I call the MCP tool "move_note" with:
      """
      {"id": 1, "folder_id": 1}
      """
    Then the MCP answer holds:
      """
      {"folder_id": 1}
      """
    When I call the MCP tool "move_note" with:
      """
      {"id": 1, "folder_id": null}
      """
    Then the MCP answer holds:
      """
      {"folder_id": null}
      """
    When I call the MCP tool "move_note" with:
      """
      {"id": 1, "folder_id": 999999}
      """
    Then the MCP tool refuses with "folder_id: no note folder has that ID"

  Scenario: pin_note pins and unpins a note
    Given the note "Plan"
    And an MCP client connected with the scopes "read notes"
    When I call the MCP tool "pin_note" with:
      """
      {"id": 1, "pinned": true}
      """
    Then the MCP answer holds:
      """
      {"pinned": true}
      """
    When I call the MCP tool "pin_note" with:
      """
      {"id": 1, "pinned": false}
      """
    Then the MCP answer holds:
      """
      {"pinned": false}
      """

  Scenario: duplicate_note copies a note under a free title and keeps an agent's mark
    Given the notes:
      | title | body  | folder |
      | Plan  | Steps | work   |
    And an MCP client connected with the scopes "read notes"
    When I call the MCP tool "duplicate_note" with:
      """
      {"id": 1}
      """
    Then the MCP answer holds:
      """
      {"title": "Plan copy", "body": "Steps", "folder_id": 1}
      """
    When I call the MCP tool "create_note" with:
      """
      {"title": "Draft", "body": "Mine"}
      """
    And I call the MCP tool "duplicate_note" with:
      """
      {"id": 3}
      """
    Then the MCP answer holds:
      """
      {"body": {"untrusted": true, "text": "Mine"}}
      """
    When I call the MCP tool "duplicate_note" with:
      """
      {"id": 999999}
      """
    Then the MCP tool refuses with "no note has the ID 999999"

  Scenario: tag_note and untag_note add and take off tags
    Given the notes:
      | title | tags |
      | Plan  | ruby |
    And an MCP client connected with the scopes "read notes"
    When I call the MCP tool "tag_note" with:
      """
      {"id": 1, "tag": "hanami"}
      """
    Then the MCP answer holds:
      """
      {"tags": ["hanami", "ruby"]}
      """
    When I call the MCP tool "tag_note" with:
      """
      {"id": 1, "tag": "Two Words"}
      """
    Then the MCP tool refuses with "a tag is lowercase words joined by hyphens"
    When I call the MCP tool "untag_note" with:
      """
      {"id": 1, "tag": "ruby"}
      """
    Then the MCP answer holds:
      """
      {"tags": ["hanami"]}
      """
    When I call the MCP tool "untag_note" with:
      """
      {"id": 1, "tag": "ruby"}
      """
    Then the MCP tool refuses with "note 1 has no tag ruby"
    When I call the MCP tool "tag_note" with:
      """
      {"id": 999999, "tag": "ruby"}
      """
    Then the MCP tool refuses with "no note has the ID 999999"

  Scenario: delete_note deletes a note for good
    Given the note "Plan"
    And an MCP client connected with the scopes "read notes delete"
    When I call the MCP tool "delete_note" with:
      """
      {"id": 1}
      """
    Then the MCP answer holds:
      """
      {"id": 1, "deleted": true}
      """
    And there is no note "Plan"
    When I call the MCP tool "delete_note" with:
      """
      {"id": 999999}
      """
    Then the MCP tool refuses with "no note has the ID 999999"

  Scenario: A note an agent wrote comes back plain once the owner saves it
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read notes"
    When I call the MCP tool "create_note" with:
      """
      {"title": "Plan", "body": "Steps"}
      """
    And I edit the note "Plan"
    And I type "Steps." in the note body
    Then the note "Plan" reads "Steps."
    When I call the MCP tool "read_note" with:
      """
      {"id": 1}
      """
    Then the MCP answer holds:
      """
      {"title": "Plan", "body": "Steps."}
      """

  Scenario: The folder tools list, make, rename, move, describe and remove folders
    Given the note folder "work/clients/acme"
    And the notes:
      | title   | folder       |
      | Invoice | work/clients |
    And an MCP client connected with the scopes "read notes delete"
    When I call the MCP tool "describe_note_folder" with:
      """
      {"id": 2, "description": "Paid work"}
      """
    Then the MCP answer holds:
      """
      {"description": "Paid work"}
      """
    When I call the MCP tool "list_note_folders"
    Then the MCP answer holds:
      """
      {"folders": [{"id": 3, "name": "acme", "parent_id": 2}, {"id": 2, "name": "clients", "description": "Paid work", "parent_id": 1}, {"id": 1, "name": "work", "description": "", "parent_id": null}]}
      """
    When I call the MCP tool "create_note_folder" with:
      """
      {"path": "work/drafts/old"}
      """
    Then the MCP answer holds:
      """
      {"name": "old", "parent_id": 4}
      """
    And the note folders are "acme, clients, drafts, old, work"
    When I call the MCP tool "create_note_folder" with:
      """
      {"path": " / "}
      """
    Then the MCP tool refuses with "name the folder first"
    When I call the MCP tool "rename_note_folder" with:
      """
      {"id": 4, "name": "jobs"}
      """
    Then the MCP answer holds:
      """
      {"name": "jobs"}
      """
    When I call the MCP tool "rename_note_folder" with:
      """
      {"id": 999999, "name": "jobs"}
      """
    Then the MCP tool refuses with "no note folder has the ID 999999"
    When I call the MCP tool "move_note_folder" with:
      """
      {"id": 1, "parent_id": 2}
      """
    Then the MCP tool refuses with "parent_id: a folder cannot move inside itself or a folder within it"
    When I call the MCP tool "move_note_folder" with:
      """
      {"id": 4, "parent_id": null}
      """
    Then the MCP answer holds:
      """
      {"parent_id": null}
      """
    When I call the MCP tool "remove_note_folder" with:
      """
      {"id": 2}
      """
    Then the MCP answer holds:
      """
      {"id": 2, "removed": true}
      """
    And the note "Invoice" sits in "work"
    And the note folder "acme" sits in "work"
    When I call the MCP tool "remove_note_folder" with:
      """
      {"id": 999999}
      """
    Then the MCP tool refuses with "no note folder has the ID 999999"
    When I call the MCP tool "describe_note_folder" with:
      """
      {"id": 999999, "description": "Gone"}
      """
    Then the MCP tool refuses with "no note folder has the ID 999999"

  Scenario: A token without notes sees no notes
    Given the note "Zeppelin sketches"
    And a task "Write the brief"
    And the task "Write the brief" links the note "Zeppelin sketches"
    And an MCP client connected with the scopes "read write delete"
    Then the MCP tools leave out "list_notes"
    And the MCP tools leave out "read_note"
    And the MCP tools leave out "edit_note"
    And the MCP tools leave out "delete_note"
    And the MCP tools leave out "remove_note_folder"
    When I call the MCP tool "read_task" with:
      """
      {"id": 1}
      """
    Then the MCP answer has no "record_links.note"
    When I call the MCP tool "search" with:
      """
      {"query": "zeppelin"}
      """
    Then the MCP answer holds:
      """
      {"results": []}
      """
