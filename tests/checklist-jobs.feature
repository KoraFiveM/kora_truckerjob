# Converted from the communitybot legacy tests by kora-qa-panel/scripts/convert-legacy.mjs.
# The """ block under each Scenario is the original test text, verbatim. Review before applying.
Feature: kora_truckerjob — Jobs

  @kora_truckerjob @checklist @checklist:kora_truckerjob:depot-blip @cat:jobs @manual
  Scenario: Freight Depot blip
    """
    Checklist test: Check map for the 'Freight Depot' blip (sprite 477) near the docks (153,-3211); open to anyone, no job needed.
    """
    When I manually: open the map and look near the docks for the Freight Depot blip
    Then I confirm: a blip named 'Freight Depot' with sprite 477 is shown near the docks
    And I confirm: the blip is visible without any job

  @kora_truckerjob @checklist @checklist:kora_truckerjob:dispatch-open @cat:jobs
  Scenario: Open freight dispatch at job station
    """
    Checklist test: Target the job station sphere at the depot ('Open freight dispatch') to open the dispatch app.
    """
    When I manually: go to the freight depot job station near the docks
    And I manually: target the job station sphere
    And I select the "Open freight dispatch" target option
    Then the "qbtruckerjob:dispatch" app opens

  @kora_truckerjob @checklist @checklist:kora_truckerjob:contracts-tab @cat:jobs
  Scenario: Contracts tab: list and accept contract
    """
    Checklist test: Contracts tab lists generated jobs (cargo, distance, est. pay, cargo level); 'Accept contract' disabled if skills do not qualify.
    """
    When I manually: open the freight dispatch app and go to the Contracts tab
    Then the "qbtruckerjob:dispatch" app should be open
    And I confirm: the Contracts tab lists generated jobs with cargo, distance, estimated pay and cargo level
    And I confirm: 'Accept contract' is disabled for contracts my skills do not qualify for

  @kora_truckerjob @checklist @checklist:kora_truckerjob:job-generation @cat:jobs
  Scenario: Contracts are generated over time
    """
    Checklist test: Wait ~2 min; new jobs appear. At least starter jobs (tier 1) are always listed for a fresh trucker.
    """
    When I manually: open the freight dispatch app and note the listed contracts
    And I wait 120 seconds
    And I manually: refresh the Contracts tab
    Then I confirm: new jobs have appeared in the list
    And I confirm: at least tier 1 starter jobs are listed for a fresh trucker

  @kora_truckerjob @checklist @checklist:kora_truckerjob:truck-spawn @cat:jobs
  Scenario: Dispatched truck spawns and keys given
    """
    Checklist test: After accepting, your selected truck (default Hauler) spawns at a depot bay and you get keys via kora_vehiclekeys.
    """
    When I manually: accept a contract in the freight dispatch app
    Then I should see a notification containing "Contract accepted."
    And I confirm: my selected truck (default Hauler) spawns at a depot bay
    And I confirm: I received keys to the truck (only applies when Config.GiveKeys is enabled; otherwise mark Pass if no keys are given)

  @kora_truckerjob @checklist @checklist:kora_truckerjob:trailer-dispatch @cat:jobs
  Scenario: Dispatch assigned trailer (E)
    """
    Checklist test: Go to the trailer locator (858,-3202); prompt 'Press E to dispatch your assigned trailer' or eye target; trailer spawns in Bay K#.
    """
    When I manually: go to the trailer locator near the docks
    Then I confirm: the prompt 'Press E to dispatch your assigned trailer' is shown, or the eye target is available
    When I press the "E" key
    Then I should see a notification containing "Your trailer is in Bay K"
    And I confirm: the trailer spawns in the bay named in the notification

  @kora_truckerjob @checklist @checklist:kora_truckerjob:hitch-and-drive @cat:jobs
  Scenario: Hitch trailer and drive to destination
    """
    Checklist test: Attach the trailer to the truck and follow the route to the delivery point; arrival notification shown.
    """
    When I manually: attach the trailer to the truck
    And I manually: follow the route to the delivery point
    Then I should see a notification containing "Back the trailer into the marked bay"

  @kora_truckerjob @checklist @checklist:kora_truckerjob:delivery-bay @cat:jobs
  Scenario: Reverse into marker and detach (H)
    """
    Checklist test: Back the trailer into the marker (green when aligned) and press H to detach and deliver; payout by distance (1.7/m).
    """
    When I manually: back the trailer into the marker
    Then I confirm: the marker turns green when the trailer is aligned
    When I press the "H" key
    Then I confirm: the trailer is detached and the delivery is completed
    And I confirm: my cash payout matches the distance times 1.7 per metre

  @kora_truckerjob @checklist @checklist:kora_truckerjob:penalties @cat:jobs @manual
  Scenario: Late and damage penalties
    """
    Checklist test: Deliver late (timed jobs) or with trailer under 30% health: 10% penalty each, reducing pay/XP.
    """
    When I manually: deliver a timed job late
    Then I confirm: a 10% penalty is applied to pay and XP
    When I manually: deliver a job with the trailer under 30% health
    Then I confirm: a 10% damage penalty is applied to pay and XP

  @kora_truckerjob @checklist @checklist:kora_truckerjob:return-truck @cat:jobs
  Scenario: Return the truck to the depot
    """
    Checklist test: Drive truck to return point (187,-3219), exit vehicle when prompted: 'Truck returned to the depot.'; wrong place shows hint.
    """
    When I manually: drive the truck to the depot return point
    And I get out of the vehicle
    Then I should see a notification containing "Truck returned to the depot."
    When I manually: leave the truck outside the return zone
    Then I should see a notification containing "Return the truck to the depot return point."

  @kora_truckerjob @checklist @checklist:kora_truckerjob:skills-tab @cat:jobs
  Scenario: Skills tab: spend skill points
    """
    Checklist test: Skills tab shows XP/skill points; upgrade Distance, Cargo, Expedited (max level 4) to unlock longer, fragile and timed jobs.
    """
    When I manually: open the freight dispatch app and go to the Skills tab
    Then the "qbtruckerjob:dispatch" app should be open
    And I confirm: the Skills tab shows XP and skill points
    When I manually: upgrade Distance, Cargo and Expedited skills up to level 4
    Then I confirm: longer, fragile and timed jobs unlock as skills are upgraded
    And I confirm: no skill can be upgraded above level 4

  @kora_truckerjob @checklist @checklist:kora_truckerjob:xp-reward @cat:jobs @manual
  Scenario: XP for completed jobs
    """
    Checklist test: Complete a job: 75 XP, multiplied x1.5 for fragile/timed cargo delivered clean and on time.
    """
    When I manually: complete a job
    Then I confirm: I received 75 XP
    When I manually: complete a fragile or timed job cleanly and on time
    Then I confirm: the XP reward is multiplied by 1.5

  @kora_truckerjob @checklist @checklist:kora_truckerjob:trucks-tab @cat:jobs
  Scenario: Trucks tab: buy and select trucks
    """
    Checklist test: Trucks tab: Hauler free, Phantom 25k, Packer 50k, Phantom Custom 100k; Purchase then 'Use this truck'; shows top speed and price.
    """
    When I manually: open the freight dispatch app and go to the Trucks tab
    Then the "qbtruckerjob:dispatch" app should be open
    And I confirm: Hauler is free, Phantom costs 25000, Packer costs 50000 and Phantom Custom costs 100000
    And I confirm: each truck shows its top speed and price
    When I manually: purchase a truck and press 'Use this truck'
    Then I confirm: the purchased truck is selected

  @kora_truckerjob @checklist @checklist:kora_truckerjob:cancel-contract @cat:jobs
  Scenario: Cancel active contract
    """
    Checklist test: Dispatch app > cancel active contract, then return your truck to the depot.
    """
    When I manually: open the freight dispatch app and cancel the active contract
    And I manually: return my truck to the depot
    Then I should see a notification containing "Truck returned to the depot."
    And I confirm: the contract is cancelled

  @kora_truckerjob @checklist @checklist:kora_truckerjob:truck-lost @cat:jobs
  Scenario: Truck deleted ends contract gracefully
    """
    Checklist test: Delete/lose the job truck (or trailer destroyed): notice 'Your truck is gone. The contract has been closed.' with no penalty.
    """
    When I manually: delete the job truck or destroy the trailer during a contract
    Then I should see a notification containing "Your truck is gone. The contract has been closed."
    And I confirm: no penalty is applied
