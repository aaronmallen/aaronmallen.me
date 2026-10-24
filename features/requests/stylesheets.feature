Feature: Stylesheets
  The public site and the admin each link a sheet of their own, and only the public site preloads its fonts.

  Scenario: A public page links the public sheet alone and preloads its Latin faces
    When I visit "/privacy"
    Then the page has 1 of "link[rel='stylesheet']"
    And the page has "link[rel='stylesheet'][href='{asset:public/app.css}']"
    And the page has 2 of "link[rel='preload'][as='font']"
    And the page has "link[rel='preload'][as='font'][crossorigin='anonymous'][href='{asset:newsreader/newsreader-latin-opsz-normal.woff2}']"
    And the page has "link[rel='preload'][as='font'][crossorigin='anonymous'][href='{asset:bricolage-grotesque/bricolage-grotesque-latin-opsz-normal.woff2}']"

  Scenario: An admin page links the admin sheet alone and preloads no fonts
    Given I am signed in to the admin
    When I visit "/admin"
    Then the page has 1 of "link[rel='stylesheet']"
    And the page has "link[rel='stylesheet'][href='{asset:admin/app.css}']"
    And the page has no "link[rel='preload'][as='font']"

  Scenario: The public sheet leaves out the admin's styles and Font Awesome
    When I request "{asset:public/app.css}"
    Then the body does not include ".adm-main"
    And the body does not include "Font Awesome"
    And the body does not match "fa-(brands|regular|solid)-\d+"

  Scenario: The admin sheet keeps Font Awesome
    When I request "{asset:admin/app.css}"
    Then the body includes "fa-solid-900"
