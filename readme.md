# Industrial Revolution
_A mod for Star Ruler 2_

![logo](IndustrialRevolution/logo.png "")

A major economy overhaul focussed on empire enhancement and eye-candy. 

**Depends on having the SR2-Community-Patch installed (not activated)**

**Highly recommendet to be played with a dark background**
like _Dark Skies_ or [Milkyway](https://github.com/scitor/SR2-Milkyway).

# Version: 0.2-testing
I didn't test any MP functionality and AI is partly broken.
Most probably there will be a game breaking (unfinished) mechanic change or some other misbalance, bug or oddity which renders a normal play impossible, but testing is possible ;)

You have been warned.

## What's different? (summary)

- **Resource connections are only active while there is cargo to consume**
  Regular resources generate Cargo, which has to be transported for the resource effects (pressure, etc.) to work.
  Long routes and fast reassigning are to be avoided, multiple ships fly per route. Secure your territory!
  Planets do not immediately level up, it takes quite some time to establish a stable connection.

- **Trade ships / stations generate income depending on transported resource value**
  Recalculated values of most resources depending on level, rarity and generated pressure
  (check [resources.txt](resources.txt), uses hacks, needs rework).
  By "Holding" a resource civilians generate trade income over time, or a direct payout (cargo value) when shot down.

- **Customs Office (Orbital, somewhat) for faster trading**
  Customs offices can be built on planets for faster trade ship spawning. The building then spawns an orbital
  (no StarChildren yet, needs rework, hacky)

- **Sytem scaling defaults to 10x, sublight speed limit and rebalanced FTL**
  Everything takes a lot longer, seriously! There is a maximum sublight speed which can only be overtaken by FTL technology.
  It should not cripple sublight races as it's not that slow and there is an alternative building for lategame compensation.
  FTL costs rebalanced due to distance changes (most probably not all cases covered)
  Default FTL storage and regeneration removed (Theocrats have storage) and FTL generation mechanic adapted to cargo.
  (unfinished, AI  mostly fails to ftl)
  
- **Tier IV and V Resources, changed planet requirements and resources**
  Planets requirements changed, resource distribution adapted accordingly.
  Added 2 new tiers of 20+ new resources (preliminary). T4 and T5 are planned to be manufactured resources, not naturally occurring.
  High-tier cargo will be used for production (different subsystems could need different stuff, etc) or other enhancements
  
- **Changed Gas/Map generation, new Stars**
  All maps should have more gasses/nebulas. Spiral map has color mode and a reworked blackhole. (setting)
  Made system planes transparent and trade-lanes less prominent, icon sizes and orbital planes altered.

- **Changed graphics and GUI**
  Changed many GUI details (pixel values), rearranged some panels, reworked many tooltips/popups.
  Added ability to animate surface buildings (super basic, just rotates through spritesheet with a given fps)

- **Experimental balance changes**
  Added 'Base Income' to budget overview (was 'Planet Income' before) and reduced from 550 to 500.
  Changed home planet conditions (1 food, 1 hydro, moon, less money, labor storage) and system compositions.
  Star Children generate labor instead of 15k per population (needs rework, sync with tech tree).
  The First have a different homeworld resource, due to resource changes.
  Civilian trade ships use native (free) FTL technology and use altered navigation, ColonyShips & Missionaries too (to an extent).
  Heralds civs do use jumpdrives.
  SS/WH extend trade areas like Gates.
  Remnants are always aggressive.
  Altered game settings page to default to 100% (since it doesn't matter if it's 0.3 or 0.2... But it does matter if it's 'normal' or 'tweaked up/down' and by how much).
  Added ability to colonize with a L0 planet (aka let the people move, instead of perish)

  many other fixes not really worth listing or already listed below, commit history should reflect all changes..  outdated changes below marked

# Version: 0.1-testing

## What's different? (summary)

- **Trade ships / stations generate more income when dealing with higher value resources**
  Recalculated values of most resources depending on level, rarity and generated pressure (check [resources.txt](resources.txt))

- **Resource connections rely directly on arriving trade ships**
  When trade ships are destroyed the connection they represent will be disabled until the next ship actually arrives.

- **Customs Offices for faster trading**
  Planets automatically* spawn customs offices easing space access and improving trade ship spawning, for a small fee.

- **No more random traders in your empty systems**
  ...wasting precious cargo space for sightseeing tours. There _is_ more trade traffic, but for another reason...

- Improved performance / code of trade ship navigation (didn't benchmark but it feels like quite a bit)

## Details
- each trade ship or station can hold one resource type and has a cargo depending on its size ~~(currently 50% in IR of its size are cargo space, 100% in vanilla)~~ (needs rework)
- each resource has a defined worth, which is then multiplied by the cargo amount and set as the ships worth.
- ships/stations earn 10% of their cargo worth each cycle (update 0.2: minus upkeep)
 
### New Trade Ship / Station mechanic

- A trade ship spawns and travels the actual route for every resource a planet / asteroid is exporting, every 3 minutes
- There will be multiple ships if the route is long enough, leading to roughly 3 times as many as in vanilla (depending on empire size and play style etc)
- The amount of trade stations still depends on the trade ships passed in that system, but since there are more ships per planet there are more trade stations as well.
- The income of a ship / station depends on its size * cargo worth (check [resources.txt](resources.txt))
- ~~When a ship is destroyed the exporting planet immediately receives a blockaded status, disabling all exports.~~ (replaced by actual cargo mechanic)
- ~~Arriving ships remove that status, which often leads to a race-condition where earlier ships clear that status again.
  This is left in deliberately since an actual blockade will quickly have a real impact but a small interruption won't hurt much (or at all) and can be seen as a warning to secure that part of the empire again.~~
- Trade ships have an indicator for their status, being either on their `main run`, or `trading`. (icons in the popup)
- Main run meaning transporting their actual resource to the designated planet. Trade run starts after this is complete.
- Trade ships have a chance to go to a trade station before continuing their journey, to `sell` their resource.
  `Selling` just means replacing that resource in a stations display, depending on a chance comparing their respective values.
  In essence: _the more relative value a resource has, the more likely it is to be `sold`_.
  The code should be easily readable now [Civilian.as](IndustrialRevolution/scripts/server/objects/Civilian.as#L566).
- Since income depends on the resource worth, higher value resources in cargo will generate more income over time.
- When on their trade run, ships also `buy` resources from planets, asteroids or stations. (same mechanic)

- \* ~~Planets spawn Customs Offices as soon as they're colonized. Ships generally try to route there first but also can reach the planet directly.~~ (replaced by Building)
- Customs Offices increase the trade ship spawn rate by 33% but have a fixed upkeep of 10k. ~~(planned as tech, to be able to choose)~~ (Building)

### Asteroids

Like planets, resource asteroids also spawn trade ships and can be blockaded. They also accept trade traffic, but don't have customs offices.
Ore asteroids are planned to work just like resource asteroids, where trade ships will transport actual amounts of ore.
