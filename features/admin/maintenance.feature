Feature: Admin maintenance mode
  The owner takes the site down from Settings or the palette, and brings it back up from the maintenance page.

  Background:
    Given I am signed in to the admin

  Scenario: The Settings button asks first and changes nothing when I decline
    When I visit "/admin/settings/security"
    Then pressing "Activate maintenance mode" asks "Take the site down? Every request gets the maintenance page and jobs hold back."
    When I visit "/admin/settings/security"
    And I press "Activate maintenance mode" and decline
    Then the maintenance flag file is gone

  Scenario: The Settings button takes the site down once I confirm
    When I visit "/admin/settings/security"
    And I press "Activate maintenance mode" and confirm
    Then the maintenance flag file is there
    And my browser holds a maintenance cookie
    And I see "Down for maintenance"

  Scenario: Activating writes the flag, signs the owner cookie and sends me to Settings, which is down
    When I post to "/admin/maintenance"
    Then the maintenance flag file is there
    And the answer sets the maintenance cookie signed for the flag, kept from scripts and other sites
    And the answer sends me to "/admin/settings/security"
    When I send GET "/admin/settings/security"
    Then the answer is 503
    And the answer shows "Down for maintenance"

  Scenario: The cookie it set brings the site back up and lands on Settings
    When I post to "/admin/maintenance"
    And I send POST "/maintenance/deactivate"
    Then the maintenance flag file is gone
    And my browser holds no maintenance cookie
    When I follow the answer
    Then I am on "/admin/settings/security"
    And the page heading is "Settings"

  Scenario: A flag it cannot write keeps the site up and says why
    Given the maintenance flag cannot be written
    When I post to "/admin/maintenance"
    And I follow the answer
    Then the page's toast reads "Couldn't write the maintenance flag · the site is still up"
    And the page heading is "Settings"
    And my browser holds no maintenance cookie

  Scenario: Activating without the form's token changes nothing
    When I post to "/admin/maintenance" without a CSRF token
    Then the maintenance flag file is gone

  Scenario: The palette command asks first, asks again once I type, and changes nothing when I close it
    When I visit "/admin/settings/security"
    And I open the palette and run "maintenance"
    Then the palette's maintenance row reads "Take the site down? Every request gets the maintenance page and jobs hold back."
    And the maintenance flag file is gone
    When I press Backspace in the palette
    Then the palette's maintenance row reads "Activate maintenance mode"
    When I press Escape in the palette
    Then the palette is shut
    And the maintenance flag file is gone
    And my browser holds no maintenance cookie

  Scenario: The palette command takes the site down once I confirm
    When I visit "/admin/settings/security"
    And I open the palette and run "maintenance"
    And I press Enter in the palette
    Then I see "Down for maintenance"
    And the maintenance flag file is there
