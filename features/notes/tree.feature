Feature: The notes tree
  The notes tab lists the owner's notes in a tree of folders, with a search box above it.

  Background:
    Given I am signed in to the admin

  Scenario: The notes tab counts the notes and folders
    Given the note "First"
    And the note "Second"
    When I open the notes
    Then I see "2 notes in 0 folders"
    And the notes tab is open with a count of 2
    And the switcher links the notes with a note icon
    And the page has no axe breaches in light or dark

  Scenario: The tree nests folders and lists pinned notes first
    Given the note folder "work/clients"
    And the note folder "empty"
    And the notes:
      | title      | folder       | pinned |
      | Pinned one |              | yes    |
      | Acme       | work/clients |        |
      | Plan       | work         |        |
    When I open the notes
    Then the note tree lists the pinned note "Pinned one" first
    And the note tree lists "Acme, Plan, Pinned one"
    And the note folder "work" shows 2 notes in the tree
    And the note folder "clients" shows 1 notes in the tree
    And the note folder "empty" is marked empty with a way to remove it
    And the note folder "work" offers no way to remove it
    And the note folder "work/clients" offers a new note and a new subfolder

  Scenario: The notes home lists the eight notes edited last
    Given 9 more notes edited an hour ago
    And the notes:
      | title  | folder       | edited |
      | Newest | work/clients | 0      |
    When I open the notes
    Then the notes home lists 8 recent notes, the first in "work/clients"
    And the page has no axe breaches in light or dark

  Scenario: I make a nested folder from the tree
    Given the note folder "work"
    When I open the notes
    And I make the note folder "work/clients" from the tree
    Then the tree holds the note folder "clients"
    And the note folder "clients" sits in "work"

  Scenario: Clicking a folder in the tree opens its page
    Given the note folder "work"
    When I open the notes
    And I click "work"
    Then I am on the note folder "work"

  Scenario: The tree keeps a folder I fold shut
    Given the note folder "work"
    When I open the notes
    And I fold the note folder "work"
    And I open the notes
    Then the note folder "work" is folded

  Scenario: A new note takes the next free Untitled title and opens to edit
    Given the note "Untitled"
    When I open the notes
    And I click "New note at the top level"
    Then I am editing the note "Untitled 2"
    And the page has no axe breaches in light or dark

  Scenario: A note made in a folder lands in that folder
    Given the note folder "work"
    When I open the notes
    And I click "New note in work"
    Then I am editing the note "Untitled"
    And the note "Untitled" sits in "work"

  Scenario: The root menu offers new notes and folders and folds the tree
    When I open the notes
    And I right-click the notes sidebar
    Then the menu offers "New note, New folder, Collapse all, Expand all"
