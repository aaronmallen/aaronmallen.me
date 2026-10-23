Feature: Records linked to notes and folders
  A note or a folder links other records, and a note shows the links of every folder above it.

  Background:
    Given I am signed in to the admin
    And the note folder "work/clients"
    And the notes:
      | title | folder       |
      | Acme  | work/clients |
    And a task "Index the activities table"

  Scenario: A note shows its links and the links of the folders above it
    Given a published post "Kickoff"
    And the note folder "elsewhere"
    And the note "Acme" links the task "Index the activities table"
    And the note_folder "work" links the task "Index the activities table"
    And the note_folder "work/clients" links the post "Kickoff"
    And the note_folder "elsewhere" links the post "Kickoff"
    When I open the note "Acme"
    Then the linked records list "Index the activities table"
    And the note links from folders list "Index the activities tablevia work, Kickoffvia clients"

  Scenario: A note in no linked folder shows no links from folders
    When I open the note "Acme"
    Then the note shows no links from folders
    And the linked records list nothing

  Scenario: I link a task to a note and unlink it
    When I open the note "Acme"
    And I link the task "Index the activities table" from the record picker
    Then the toast says "Record linked"
    And I am on the note "Acme"
    And the linked records list "Index the activities table"
    When I unlink "Index the activities table" from the linked records
    Then the toast says "Link removed"
    And I am on the note "Acme"
    And the linked records list nothing

  Scenario: Linking a record that is gone keeps the note open
    When I open the note "Acme"
    And I post to "/admin/notes/1/records" from the page with:
      | record[other_kind] | task   |
      | record[other_id]   | 999999 |
    Then the server answers 422
    And the answer shows "That record is gone. Find another."

  Scenario: Another record's picker finds notes and folders and links back
    When I visit "/admin/tasks/1?record_q=Acme"
    Then the record picker finds "Notes"
    Given the task "Index the activities table" links the note "Acme"
    And the task "Index the activities table" links the note_folder "work/clients"
    When I visit "/admin/tasks/1"
    Then the linked records link "Acme" to the note "Acme"
    And the linked records link "clients" to the note folder "work/clients"

  Scenario: A folder page shows its links and the links of its parents
    Given the note_folder "work" links the task "Index the activities table"
    When I open the note folder "work/clients"
    Then I see "Links here apply to every note in clients (1), including subfolders."
    And the parent folder links list "Index the activities table" from "work"
    When I open the note folder "work"
    Then the linked records list "Index the activities table"
    And the folder page shows no parent folder links

  Scenario: I link a task to a folder and unlink it
    When I open the note folder "work/clients"
    And I link the task "Index the activities table" from the record picker
    Then I am on the note folder "work/clients"
    And the linked records list "Index the activities table"
    When I unlink "Index the activities table" from the linked records
    Then I am on the note folder "work/clients"
    And the linked records list nothing
