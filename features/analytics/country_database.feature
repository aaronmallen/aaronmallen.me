Feature: The country database
  The site looks up each visitor's country, and the owner's sign-in place, in a
  GeoLite2 database kept on this server. The Today page says when it cannot.

  Background:
    Given these analytics posts:
      | slug  | published |
      | hello | today-30  |

  Scenario: A view stores the country of the network its address falls in
    Given the country database holds the test networks
    When "Chrome" from "1.2.3.4" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    And "Chrome" from "81.2.69.160" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    And "Chrome" from "2001:db8::1" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    And "Chrome" from "8.8.8.8" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    And "Chrome" from "10.0.0.1" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    Then the analytics_events rows are:
      | country_code | country_name   |
      | US           | United States  |
      | GB           | United Kingdom |
      | DE           | Germany        |
      | none         | none           |
      | none         | none           |

  Scenario: A view reads a database that replaced the one the lookup had open
    Given the country database holds the test networks
    When "Chrome" from "1.2.3.4" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    And the country database holds "1.2.3.0/24" as "CA"
    And "Chrome" from "1.2.3.5" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    Then the analytics_events rows are:
      | country_code |
      | CA           |
      | US           |

  Scenario: A view is stored with no country and the Today page says no database is on disk
    When "Chrome" from "1.2.3.4" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    And I am signed in to the admin
    And I visit "/admin" in the admin
    Then the analytics_events rows are:
      | country_code |
      | none         |
    And the screen parts ".sync-failures .sync-failure" read:
      | Country lookup · No database on disk |

  Scenario: A view is stored with no country and the Today page says the file is no database
    Given the country database file holds "not a database"
    When "Chrome" from "1.2.3.4" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    And I am signed in to the admin
    And I visit "/admin" in the admin
    Then the analytics_events rows are:
      | country_code |
      | none         |
    And the screen parts ".sync-failures .sync-failure" read:
      | Country lookup · The database won't open |

  Scenario: A view is still accepted when the database cannot be read
    Given the country database holds the test networks
    And the country database cannot be read
    When "Chrome" from "1.2.3.4" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello"}
      """
    Then the server answered 202
    And the analytics_events rows are:
      | country_code |
      | none         |
    When I am signed in to the admin
    And I visit "/admin" in the admin
    Then the screen parts ".sync-failures .sync-failure" read:
      | Country lookup · The database won't open |

  Scenario: The Today page says nothing while the country database reads
    Given I am signed in to the admin
    And the country database holds the test networks
    When I visit "/admin" in the admin
    Then the screen holds no ".sync-failures .sync-failure:has-text('Country lookup')"

  Scenario: A sign-in stores the city and country of its address
    Given the country database holds the test networks
    When the owner signs in from "81.2.69.160"
    And the owner signs in from "1.2.3.4"
    And the owner signs in from "198.51.100.7"
    And the owner signs in from "8.8.8.8"
    And the owner signs in from "not an address"
    Then the sign_ins rows where "address <> '127.0.0.1'" are:
      | address        | city    | country | country_name   |
      | 81.2.69.160    | London  | GB      | United Kingdom |
      | 1.2.3.4        | none    | US      | United States  |
      | 198.51.100.7   | Nowhere | none    | none           |
      | 8.8.8.8        | none    | none    | none           |
      | not an address | none    | none    | none           |
