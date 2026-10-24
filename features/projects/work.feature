Feature: Work history
  The work tab of the projects screen lists the roles that /about shows, adds them and removes them.

  Background:
    Given I am signed in to the admin

  Scenario: The work tab lists the roles in order
    Given the work entries:
      | role     | org       | from | to   | blurb        | position |
      | Second   | Globex    | 2021 |      |              | 2        |
      | First    | Rackspace | 2018 | 2021 | Built things | 1        |
    And the projects:
      | name     |
      | live-one |
    When I visit "/admin/projects"
    And I click the page part ".seg-option:has-text('work')"
    Then I am on "/admin/projects?filter=work"
    And the work tab is chosen
    And I do not see "live-one"
    And the work rows read:
      | role   | meta                     |
      | First  | Rackspace · 2018–2021    |
      | Second | Globex · 2021–Present    |
    And the work row "First" shows the blurb "Built things"
    And the work row "Second" shows no blurb
    And each work row offers Remove with the trash icon and no Archive
    And removing the work row "First" asks "Remove First at Rackspace? You can't undo this."
    And the page has no axe breaches in light or dark

  Scenario: The work tab says when there are no roles
    When I open the work tab
    Then I see "No roles yet."
    And the work tab holds one work form, posting to "/admin/projects/work"
    And Add role is disabled

  Scenario: Add role waits for an organization and a role
    When I open the work tab
    And I fill in the organization with "Rackspace"
    Then Add role is disabled
    When I fill in the role "Software Engineer" at "Rackspace"
    Then Add role is enabled
    When I fill in the organization with "   "
    Then Add role is disabled

  Scenario: Adding a role lists it here and on the about page
    When I open the work tab
    And I fill in the role "Software Engineer" at "Rackspace"
    And I fill in the start year with "2018"
    And I click "Add role"
    Then the toast says "Role added to /projects"
    And the work rows read:
      | role              | meta                     |
      | Software Engineer | Rackspace · 2018–Present |
    And I see "Leave To empty for a role you still hold."
    And the about page lists the roles "Software Engineer"
    And the about page dates the role "Software Engineer" "2018–Present"

  Scenario: Each added role goes to the end, and the way back is the work tab
    When I open the work tab
    And I add a role with:
      | org       | Rackspace    |
      | role      | First        |
      | from_year | 2018         |
      | to_year   | 2021         |
      | return_to | /admin/posts |
    Then the answer sends me to "/admin/projects?filter=work"
    When I add a role with:
      | org       | Rackspace |
      | role      | Second    |
      | from_year | 2018      |
    Then the work entries are "First, Second"
    And the about page dates the role "First" "2018–2021"

  Scenario Outline: A role with a bad field is refused
    Given the work entries:
      | role |
      | Kept |
    When I open the work tab
    And I add a role with:
      | org       | <org>  |
      | role      | <role> |
      | from_year | <from> |
      | to_year   | <to>   |
    Then the server answers 422
    And the refused page says "<error>"
    And the work entries are "Kept"

    Examples:
      | org       | role     | from | to   | error                                      |
      | " "       | Engineer | 2018 | 2021 | Name the organization.                     |
      | " "  | Engineer | 2018 | 2021 | Name the organization.                     |
      | Rackspace | " "      | 2018 | 2021 | Name the role.                             |
      | Rackspace | "　" | 2018 | 2021 | Name the role.                             |
      | Rackspace | Engineer |      | 2021 | Add the year this started.                 |
      | Rackspace | Engineer | 18   | 2021 | Use a four digit year, as 2018.            |
      | Rackspace | Engineer | 0000 | 2021 | Use a four digit year, as 2018.            |
      | Rackspace | Engineer | 2018 | 21   | Use a four digit year, as 2021.            |
      | Rackspace | Engineer | 2021 | 2018 | The end year falls before the start year.  |

  Scenario: A refused role keeps what I typed and points the field at its error
    Given the work entries:
      | role |
      | Kept |
    When I open the work tab
    And I add a role with:
      | org       | " "               |
      | role      | Software Engineer |
      | from_year | 2018              |
    Then the server answers 422
    And the refused page says "Name the organization." under "Organization"
    And the refused page keeps "Software Engineer" in "Role or project"
    And the refused page lists the roles "Kept"

  Scenario: No other screen draws a work log dialog
    When I visit "/admin/posts?status=draft"
    Then the page draws no work log dialog

  Scenario: Removing a role asks first, then takes it off here and on the about page
    Given the work entries:
      | role              | org       | position |
      | Software Engineer | Rackspace | 1        |
      | Kept              | Globex    | 9        |
    When I open the work tab
    And I click Remove on the work row "Software Engineer"
    Then the question reads "Remove Software Engineer at Rackspace? You can't undo this."
    When I say no to the question
    Then the work entries are "Software Engineer, Kept"
    When I click Remove on the work row "Software Engineer"
    And I say yes to the question
    Then the toast says "Role removed from /projects"
    And I do not see "Rackspace ·"
    And the work entries are "Kept"
    And the about page lists the roles "Kept"

  Scenario: Removing the last role empties the about page's list
    Given the work entries:
      | role              |
      | Software Engineer |
    When I open the work tab
    And I post to "/admin/projects/work/{work_entry:Software Engineer}/delete" from the page
    Then the answer sends me to "/admin/projects?filter=work"
    And the about page lists the roles ""
