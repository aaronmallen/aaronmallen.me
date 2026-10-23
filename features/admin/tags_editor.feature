Feature: Admin tag editor in the browser
  On the tagging tab, a tag's edit button opens its editor in the side panel in place of the aside. The editor
  renames the tag, recolours it on a swatch click, and shuts on cancel. The filter narrows the list as it is typed.

  Background:
    Given I am signed in to the admin
    And the tag manager holds these tags:
      | name   | color    |
      | ruby   | mk-blue  |
      | hanami | mk-green |
    When I visit "/admin/settings/tagging"

  Scenario: The tag editor stays shut until the edit button is clicked
    Then the tag manager shows no visible ".tag-editor"
    And the tag manager shows "aside.settings-side .settings-aside" visibly, reading "Click a tag"

  Scenario: The tag opens its page
    When I click the link "#ruby"
    Then the tag manager lands on "/admin/tags/ruby"

  Scenario: The edit button opens the one tag's editor in the side panel, in place of the aside
    When I open the tag editor for "ruby"
    Then 1 tag editor is open
    And the open tag editor's name holds "ruby"
    And the tag manager shows "aside.settings-side .tag-editor" visibly, reading "#ruby"
    And the tag manager shows no visible "aside.settings-side .settings-aside"

  Scenario: The editor moves to the next tag clicked
    When I open the tag editor for "ruby"
    And I open the tag editor for "hanami"
    Then the open tag editor's name holds "hanami"

  Scenario: A refused rename keeps the editor open with the error
    When I open the tag editor for "ruby"
    And I fill the tag editor's name with "two words"
    And I click "Save" in the tag editor
    Then the tag manager shows "aside.settings-side .tag-editor .field-error" visibly
    And the open tag editor's name holds "two words"

  Scenario: The editor renames the tag
    When I open the tag editor for "ruby"
    And I fill the tag editor's name with "rails"
    And I click "Save" in the tag editor
    Then the tag manager shows ".tag-name" visibly, reading "#rails"

  Scenario: A swatch click recolours the tag
    When I open the tag editor for "ruby"
    And I click the orange swatch in the tag editor
    Then the tag manager shows "[data-toast]" reading "Tag recoloured"
    And the database soon answers "mk-orange" for:
      """
      select color from tags where name = 'ruby'
      """

  Scenario: The editor shuts again on cancel
    When I open the tag editor for "ruby"
    And I click "Cancel" in the tag editor
    Then 0 tag editors are open

  Scenario: The filter narrows the list as the query is typed
    When I type "han" in the tag filter
    Then the tag manager shows ".tag-name" visibly, reading "#hanami"
    And the tag manager shows no visible ".tag-name:has-text('#ruby')"
