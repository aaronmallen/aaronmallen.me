Feature: Share groups in the admin
  The owner keeps groups of files under one link: names them, edits their files, moves files in and out, and
  deletes them.

  Background:
    Given I am signed in to the admin
    And the share group of:
      | filename | type       | body          |
      | a.txt    | text/plain | a             |
      | shot.png | image/png  | a 30 by 30 png |

  Scenario: A group shows as one card with its file count, link, views and first image, before single files
    Given the share "hello.txt" of type "text/plain"
    When I open the files
    Then the file cards read "2 files, hello.txt"
    And the file card "2 files" reads "shares.localhost/[group code]"
    And the file card "2 files" reads "0 views"
    And the file card thumbnail of "2 files" shows "http://shares.localhost/[group code]/[id of shot.png]?preview"
    And the page has no axe breaches in light or dark

  Scenario: A named group shows by its name in the list and its drawer
    Given the share group is named "Beach trip"
    When I open the files
    Then the file cards read "Beach trip"
    When I open the file card "Beach trip"
    Then the file drawer reads "Beach trip"

  Scenario: The search finds a group by a file in it or by its code, and the image filter keeps a group with an image
    Given the share group of:
      | filename | type          |
      | notes.md | text/markdown |
    When I open the files at "?search=shot"
    Then the file cards read "2 files"
    When I open the files at "?search=1"
    Then the file cards read "2 files"
    When I open the files at "?kind=images"
    Then the file cards read "2 files"
    When I open the files at "?search=nothing"
    Then I see "No files match."

  Scenario: Past the first page the group counts among the matches but shows no card
    Given 13 shares stored straight in the database
    And the shared file "s12.txt" is stored under the name "shot-12.txt"
    When I open the files at "?search=s&page=2"
    Then I see "14 matches"
    And the file cards read "s0.txt"

  Scenario: The drawer shows the views, zip downloads and each file's downloads, and edits names, code and alt text
    Given the share group has 7 views and 3 zip downloads
    And the shared file "shot.png" has 2 downloads
    When I open the files
    And I open the file card "2 files"
    Then the file drawer reads "7 views"
    And the file drawer reads "3 zip downloads"
    And the grouped file "shot.png" reads "2 downloads"
    And the file drawer field "Name" holds ""
    And the file drawer field "Short code" holds "[group code]"
    And the file drawer for the group has 2 name fields and 1 alt text field
    And the file drawer reads "Add files to this group"
    And the page has no axe breaches in light or dark

  Scenario: The edit page works without scripts and answers 404 for a missing group
    Given the admin scripts do not load
    When I open the edit page of the share group
    And I fill in "Short code" with "beach-trip"
    And I click "Save"
    And I fetch "/beach-trip" from the share host
    Then the share host answers 200
    When I fetch "/1" from the share host
    Then the share host answers 404
    When I open the edit page of the share group
    Then I see "The part after shares.localhost/. Save a new one and the old link stops working at once."
    And I see "The group's page uses it for the image."
    When I visit "/admin/files/groups/0/edit"
    Then the server answers 404

  Scenario: Naming a group titles its page, and a blank name clears it
    When I open the files
    And I open the file card "2 files"
    And I set the file drawer field "Name" to " Beach trip "
    And I click "Save" in the file drawer
    Then the toast says "Group saved"
    And the share group is named "Beach trip" in the store
    When I open "/[group code]" on the share host
    Then the share page is titled "Beach trip"
    When I open the files
    And I open the file card "Beach trip"
    And I set the file drawer field "Name" to " "
    And I click "Save" in the file drawer
    Then the share group is named "" in the store

  Scenario: A form that sends no name keeps the name
    Given the share group is named "Beach trip"
    When I open the files
    And I post to "/admin/files/groups/1" from the files page with:
      | group[code] | trip |
    Then the share group is named "Beach trip" in the store

  Scenario: Renaming a group file keeps its link, and alt text sets on an image only
    When I open the files
    And I open the file card "2 files"
    And I set the "File name" of the grouped file "shot.png" to "cat.png"
    And I set the "Alt text" of the grouped file "shot.png" to "A cat"
    And I click "Save" in the file drawer
    Then the toast says "Group saved"
    And the shared file "shot.png" is named "cat.png"
    And the shared file "cat.png" has the alt text "A cat" stored
    When I open "/[group code]" on the share host
    Then the share page carousel shows the images "A cat"
    When I open the files
    And I post to "/admin/files/groups/1" from the files page with:
      | group[code]                     | 1     |
      | group[files][[id of a.txt]][alt_text] | Words |
    Then the shared file "a.txt" has the alt text "" stored

  Scenario: The drawer refuses a blank file name, a taken code and a bad alt text and changes nothing
    Given the share "hello.txt" of type "text/plain"
    When I open the files
    And I post to "/admin/files/groups/1" from the files page with:
      | group[code]                       | trip       |
      | group[name]                       | Beach trip |
      | group[files][[id of shot.png]][filename] |     |
    Then the files page answers 422
    And the files page says "Give it a name."
    When I post to "/admin/files/groups/1" from the files page with:
      | group[code] | [code of hello.txt] |
    Then the files page answers 422
    And the files page says "Another file or short link already uses that code."
    When I post to "/admin/files/groups/1" from the files page with:
      | group[code]                       | trip       |
      | group[files][[id of shot.png]][alt_text] | A\u0000cat |
    Then the files page answers 422
    And the share group is named "" in the store
    And the shared file "shot.png" is named "shot.png"
    And the shared file "shot.png" has the alt text "" stored
    When I fetch "/1" from the share host
    Then the share host answers 200

  Scenario: Adding files to a group stores each one and makes no new share or group
    When I open the files
    And I add the file "deck.pdf" holding "%PDF" to the share group
    Then the files page says "Added to the group"
    And the shared file "deck.pdf" sits in the share group
    And the share store holds the file "deck.pdf" as "%PDF"
    And there is 1 share group
    When I visit "/admin/files"
    Then the file cards read "3 files"

  Scenario: Adding files to a missing group answers 404
    When I open the files
    And I add the file "b.txt" holding "b" to the share group 999999
    Then the files page answers 404

  Scenario: Removing a file asks first, then drops it and its stored file and keeps the group
    When I open the files
    And I open the file card "2 files"
    And I click "Remove a.txt" on the grouped file "a.txt"
    Then the file drawer asks "Remove a.txt? Its link stops working at once."
    When I confirm in the file drawer
    Then the toast says "File removed from the group"
    And there is 1 share group
    And the share store holds 2 files

  Scenario: Removing an image drops its preview, and the last file takes the group and its code with it
    When I open the files
    And I post to "/admin/files/groups/1/files/[id of shot.png]/delete" from the files page
    Then the share store holds 1 file
    When I post to "/admin/files/groups/1/files/[id of a.txt]/delete" from the files page
    Then no shares or share groups are left
    And the share store holds 0 files
    When I fetch "/1" from the share host
    Then the share host answers 404

  Scenario: Removing a file of another group answers 404
    Given the share group of:
      | filename | type       |
      | b.txt    | text/plain |
    When I open the files
    And I post to "/admin/files/groups/1/files/[id of b.txt]/delete" from the files page
    Then the files page answers 404

  Scenario: Deleting a group asks first, then removes it, its code, its files and their stored files
    When I open the files
    And I open the file card "2 files"
    And I click "Delete group" in the file drawer
    Then the file drawer asks "Delete this group and its 2 files? Its link stops working at once."
    When I click "Delete group" in the file drawer
    Then the toast says "Group deleted"
    And no shares or share groups are left
    And the share store holds 0 files

  Scenario: The list ticks single shares into the bulk form and offers each group by its code
    Given the share "one.txt" of type "text/plain"
    When I open the files
    And I click "Select"
    And I tick the file card "one.txt"
    Then I see "Make a group"
    And the bulk form offers the share group "[group code]"
    When I open the file card "2 files"
    Then the grouped file "a.txt" offers "Move a.txt out of the group"

  Scenario: Making a group gathers the ticked shares, keeps their downloads and frees their codes
    Given the share "one.txt" of type "text/plain" holding "one"
    And the share "two.txt" of type "text/plain" holding "two"
    And the shared file "one.txt" has 3 downloads
    When I open the files
    And I click "Select"
    And I tick the file card "one.txt"
    And I tick the file card "two.txt"
    And I click "Make a group"
    Then the toast says "Grouped 2 files under"
    And there are 2 share groups
    And the shared file "one.txt" sits in the share group
    And the shared file "two.txt" sits in the share group
    And the shared file "one.txt" counts 3 downloads
    And the short code "2" is free
    And the short code "3" is free

  Scenario: Making a group of one file, of a file that is gone, or of a group's file moves nothing
    Given the share "one.txt" of type "text/plain"
    When I open the files
    And I post to "/admin/files/bulk" from the files page with:
      | act   | group |
      | ids[] | 3     |
    Then the files page says "Nothing moved · tick two or more files to make a group"
    When I post to "/admin/files/bulk" from the files page with:
      | act   | group  |
      | ids[] | 999999 |
    Then there is 1 share group
    And the shared file "one.txt" stands alone

  Scenario: Making a group of a ticked share that is gone says so
    Given the share "one.txt" of type "text/plain"
    When I open the files
    And I post the bulk form to group the files "3, 999999"
    Then the files page says "Nothing moved · a file or the group is gone"
    And the shared file "one.txt" stands alone
    When I post the bulk form to group the files "3, 1"
    Then there is 1 share group

  Scenario: Adding ticked shares to a group moves them in and frees their codes
    Given the share "one.txt" of type "text/plain"
    And the share "two.txt" of type "text/plain"
    When I open the files
    And I click "Select"
    And I tick the file card "one.txt"
    And I tick the file card "two.txt"
    And I pick the share group "[group code]" to add to
    Then the toast says "Moved 2 files into 1"
    And the shared file "one.txt" sits in the share group
    And the short code "2" is free

  Scenario: Adding with no group picked or no file ticked moves nothing
    Given the share "one.txt" of type "text/plain"
    When I open the files
    And I post the bulk form to add the files "3" to the group ""
    Then the files page says "Nothing moved · pick a group first"
    When I post the bulk form to add the files "" to the group "1"
    Then the files page says "Nothing moved · tick a file first"

  Scenario: Pulling a file out gives it a new code, keeps its downloads and keeps the group while it holds files
    Given the shared file "a.txt" has 2 downloads
    When I open the files
    And I open the file card "2 files"
    And I click "Move a.txt out of the group" on the grouped file "a.txt"
    And I confirm in the file drawer
    Then the toast says "Moved out of the group under a new link"
    And the shared file "a.txt" stands alone
    And the shared file "a.txt" counts 2 downloads
    And there is 1 share group

  Scenario: Pulling the last file out deletes the group and frees its code
    When I open the files
    And I post to "/admin/files/groups/1/files/[id of a.txt]/ungroup" from the files page
    And I post to "/admin/files/groups/1/files/[id of shot.png]/ungroup" from the files page
    Then there are 0 share groups
    When I fetch "/1" from the share host
    Then the share host answers 404

  Scenario: Pulling out a file outside the group answers 404
    Given the share "one.txt" of type "text/plain"
    When I open the files
    And I post to "/admin/files/groups/1/files/[id of one.txt]/ungroup" from the files page
    Then the files page answers 404

  Scenario: Adding files the store refuses adds nothing
    Given the share store fails every PUT
    When I open the files
    And I add the file "b.txt" holding "b" to the share group
    Then the share group holds 2 files

  Scenario: Removing a file the store will not let go of keeps it and says so
    Given the share store fails the DELETE of the shared file "a.txt"
    When I open the files
    And I post to "/admin/files/groups/1/files/[id of a.txt]/delete" from the files page
    Then the files page says "Nothing deleted · the share store isn't answering"
    And the share group holds 2 files

  Scenario Outline: Deleting a group still deletes it and its other files when the store fails on <filename>
    Given the share store fails the DELETE of the shared file "<filename>"
    When I open the files
    And I post to "/admin/files/groups/1/delete" from the files page
    Then the files page says "Group deleted"
    And no shares or share groups are left
    And the share store holds 1 file

    Examples:
      | filename |
      | a.txt    |
      | shot.png |
