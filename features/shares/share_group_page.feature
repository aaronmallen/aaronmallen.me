Feature: A share group on the share host
  A group of files shares one link: a page that shows its images and lists its files, each file's own link, and
  a zip of them all.

  Background:
    Given the share group of:
      | filename  | type            | body       |
      | beach.jpg | image/jpeg      | beach.jpg  |
      | dunes.png | image/png       | dunes.png  |
      | notes.txt | text/plain      | notes.txt  |
      | paper.pdf | application/pdf | 0123456789 |

  Scenario: The group's page shows its images in a carousel and lists its other files
    Given the shared file "beach.jpg" has the alt text "A wide beach"
    When I open "/[group code]" on the share host
    Then the share page carousel shows the images "A wide beach, dunes.png"
    And the share page carousel links "/[group code]/[id of beach.jpg]?preview, /[group code]/[id of dunes.png]?preview" as sources
    And the share page carousel links "/[group code]/[id of beach.jpg], /[group code]/[id of dunes.png]" as links
    And the share page lists the files "notes.txt /[group code]/[id of notes.txt], paper.pdf /[group code]/[id of paper.pdf]"
    And the share page offers "Download all" at "/[group code].zip"
    And the page has no axe breaches in light or dark

  Scenario: The group's page is HTML no cache keeps and loads nothing from another host
    When I fetch "/[group code]" from the share host
    Then the share host answers 200
    And the share host header "Content-Type" is "text/html; charset=utf-8"
    And the share host header "Cache-Control" is "private, no-store"
    And the share host header "Content-Security-Policy" starts with "default-src 'none'"

  Scenario: A head request for the group's page answers with no body and counts no view
    When a browser asks the share host for the head of "/[group code]"
    Then the share host answers 200 with nothing
    And the share group counts 0 views and 0 zip downloads

  Scenario: A name titles the group's page and a blank one falls back to the plain title
    Given the share group is named "Beach trip"
    When I open "/[group code]" on the share host
    Then the share page is titled "Beach trip"
    Given the share group is named " "
    When I open "/[group code]" on the share host
    Then the share page is titled "Shared files"

  Scenario: A prefix of the group's code opens neither its page, zip nor files
    Given the share group has the code "grpabcde"
    When I fetch "/grp" from the share host
    Then the share host answers 404
    When I fetch "/grp.zip" from the share host
    Then the share host answers 404
    When I fetch "/grp/[id of notes.txt]" from the share host
    Then the share host answers 404

  Scenario: A renamed file lists and downloads under its new name at the same link
    Given the shared file "notes.txt" is renamed "todo.txt" in the group
    When I open "/[group code]" on the share host
    Then the share page lists the files "todo.txt /[group code]/[id of todo.txt], paper.pdf /[group code]/[id of paper.pdf]"
    When I fetch "/[group code]/[id of todo.txt]" from the share host
    Then the share host header "Content-Disposition" holds 'filename="todo.txt"'

  Scenario: A file's link returns its bytes inline by its type and no cache keeps them
    When I fetch "/[group code]/[id of paper.pdf]" from the share host
    Then the share host answers 200 with "0123456789"
    And the share host header "Content-Type" is "application/pdf"
    And the share host header "Cache-Control" is "private, no-store"
    And the share host header "Content-Disposition" is:
      """
      inline; filename="paper.pdf"; filename*=UTF-8''paper.pdf
      """

  Scenario: A file's link answers a range with 206
    When a browser fetches "/[group code]/[id of paper.pdf]" from the share host with the range "bytes=2-5"
    Then the share host answers 206 with "2345"

  Scenario: A browser download counts against that file alone
    When a browser fetches "/[group code]/[id of paper.pdf]" from the share host
    Then the shared file "paper.pdf" counts 1 download
    And the shared file "notes.txt" counts 0 downloads
    And the share group counts 0 views and 0 zip downloads

  Scenario: A file's range probe, preview and bot fetch count no download
    When a browser fetches "/[group code]/[id of paper.pdf]" from the share host with the range "bytes=0-1"
    And a browser fetches "/[group code]/[id of paper.pdf]?preview" from the share host
    And the agent "curl/8.4.0" fetches "/[group code]/[id of paper.pdf]" from the share host
    Then the shared file "paper.pdf" counts 0 downloads

  Scenario: A browser view of the page counts once
    When a browser fetches "/[group code]" from the share host
    Then the share group counts 1 view and 0 zip downloads

  Scenario: A bot, a head request and a preview of the page count no view
    When the agent "Slackbot-LinkExpanding 1.0" fetches "/[group code]" from the share host
    And a browser asks the share host for the head of "/[group code]"
    And a browser fetches "/[group code]?preview" from the share host
    Then the share group counts 0 views and 0 zip downloads

  Scenario: The zip holds every file under its own name and downloads as an attachment no cache keeps
    When I fetch "/[group code].zip" from the share host
    Then the share zip holds:
      | beach.jpg | beach.jpg  |
      | dunes.png | dunes.png  |
      | notes.txt | notes.txt  |
      | paper.pdf | 0123456789 |
    And the share host header "Content-Type" is "application/zip"
    And the share host header "Cache-Control" is "private, no-store"
    And the share host header "Content-Disposition" is:
      """
      attachment; filename="[group code].zip"; filename*=UTF-8''[group code].zip
      """
    And the share store holds 4 files

  Scenario: A named group's zip downloads under its name and holds renamed files under their new names
    Given the share group is named "Beach trip"
    And the shared file "notes.txt" is renamed "todo.txt" in the group
    When I fetch "/[group code].zip" from the share host
    Then the share host header "Content-Disposition" is:
      """
      attachment; filename="Beach trip.zip"; filename*=UTF-8''Beach%20trip.zip
      """
    And the share zip holds:
      | beach.jpg | beach.jpg  |
      | dunes.png | dunes.png  |
      | todo.txt  | notes.txt  |
      | paper.pdf | 0123456789 |

  Scenario: The zip gives a second file of the same name a name of its own
    Given the shared file "dunes.png" is stored under the name "beach.jpg"
    When I fetch "/[group code].zip" from the share host
    Then the share zip holds:
      | beach.jpg     | beach.jpg  |
      | beach (1).jpg | dunes.png  |
      | notes.txt     | notes.txt  |
      | paper.pdf     | 0123456789 |

  Scenario: The zip writes a stored name with a folder part as a bare name
    Given the shared file "beach.jpg" is stored under the name "../../beach.jpg"
    And the shared file "dunes.png" is stored under the name "/tmp/dunes.png"
    And the shared file "notes.txt" is stored under the name ".."
    When I fetch "/[group code].zip" from the share host
    Then the share zip holds:
      | .._.._beach.jpg | beach.jpg  |
      | _tmp_dunes.png  | dunes.png  |
      | __              | notes.txt  |
      | paper.pdf       | 0123456789 |

  Scenario: A browser's zip download counts against the zip alone, and a bot's or a head request counts none
    When a browser fetches "/[group code].zip" from the share host
    Then the share group counts 0 views and 1 zip download
    And the shared file "notes.txt" counts 0 downloads
    When the agent "curl/8.4.0" fetches "/[group code].zip" from the share host
    And a browser asks the share host for the head of "/[group code].zip"
    Then the share host answers 200 with nothing
    And the share group counts 0 views and 1 zip download

  Scenario: A single share's code has no zip and no files under it
    Given the share "solo.txt" of type "text/plain"
    When I fetch "/[code of solo.txt].zip" from the share host
    Then the share host answers 404
    When I fetch "/[code of solo.txt]/[id of notes.txt]" from the share host
    Then the share host answers 404

  Scenario Outline: The share host answers 404 for <suffix> under the group's code
    When I fetch "/[group code]<suffix>" from the share host
    Then the share host answers 404

    Examples:
      | suffix |
      | /0     |
      | /01    |
      | /x     |
      | /1/2   |
      | /5     |

  Scenario: An image's preview serves a small copy, and the original when no copy is left
    Given the share group of:
      | filename  | type       | body                 |
      | wide.jpg  | image/jpeg | a 3000 by 1500 jpeg  |
      | words.txt | text/plain | words                |
    When I fetch "/[group code]/[id of wide.jpg]?preview" from the share host
    Then the share host answers 200
    And the share host sends a preview 1280 pixels wide
    And the share host header "Cache-Control" is "private, no-store"
    And the share store holds a preview 1280 pixels wide for "wide.jpg"
    And the shared file "words.txt" has no preview stored
    Given the share store lost the preview of "wide.jpg"
    When I fetch "/[group code]/[id of wide.jpg]?preview" from the share host
    Then the share host sends the original "wide.jpg"
    Given the shared file "wide.jpg" has no preview
    When I fetch "/[group code]/[id of wide.jpg]?preview" from the share host
    Then the share host sends the original "wide.jpg"

  Scenario: A deleted group stops serving at once and its files leave the store
    Given the share group of:
      | filename | type       | body                 |
      | wide.jpg | image/jpeg | a 3000 by 1500 jpeg  |
    And an API token
    When I DELETE "/share_groups/2" through the API
    And I fetch "/2/5?preview" from the share host
    Then the share host answers 404
    And the share store holds 4 files

  Scenario: A share that joins a group moves under the group's code with its downloads kept
    Given the shares:
      | filename | type       | body |
      | one.txt  | text/plain | one  |
      | two.txt  | text/plain | two  |
    And the shared file "one.txt" has 4 downloads
    And an API token
    When I POST "/shares/bulk/group" through the API with:
      """
      {"ids": [5, 6]}
      """
    And I fetch "/2" from the share host
    Then the share host answers 404
    And the short code "2" is free
    When a browser fetches "/[group code]/[id of one.txt]" from the share host
    Then the share host answers 200 with "one"
    And the shared file "one.txt" counts 5 downloads

  Scenario: A file that leaves a group gets its own code with its downloads kept, and the rest keep their links
    Given the shared file "notes.txt" has 4 downloads
    And an API token
    When I POST "/share_groups/1/files/3/ungroup" through the API
    And a browser fetches "/[code of notes.txt]" from the share host
    Then the share host answers 200 with "notes.txt"
    And the shared file "notes.txt" counts 5 downloads
    When I fetch "/[group code]/[id of notes.txt]" from the share host
    Then the share host answers 404
    When I fetch "/[group code]/[id of paper.pdf]" from the share host
    Then the share host answers 200 with "0123456789"

  Scenario: A group file keeps its link when shares join the group
    Given the share "three.txt" of type "text/plain"
    And an API token
    When I POST "/share_groups/1/files" through the API with:
      """
      {"ids": [5]}
      """
    And I fetch "/[group code]/[id of paper.pdf]" from the share host
    Then the share host answers 200 with "0123456789"
    When I fetch "/[group code]/[id of three.txt]" from the share host
    Then the share host answers 200 with "0123456789"
