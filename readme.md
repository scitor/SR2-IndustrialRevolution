# Industrial Revolution
_A mod for Star Ruler 2_

![logo](IndustrialRevolution/logo.png "")

This mod makes civilian transport ships more important.
(... and more industrial / eco stuff planned)

Version: 0.1-testing
**Depends on having the SR2-Community-Patch installed (not activated)**

# What's different? (summary)

- **Trade ships / stations generate more income when dealing with higher value resources**
  Recalculated values of most resources depending on level, rarity and generated pressure (check [resources.txt](resources.txt))

- **Resource connections rely directly on arriving trade ships**
  When trade ships are destroyed the connection they represent will be disabled until the next ship actually arrives.

- **Customs Offices for faster trading**
  Planets automatically* spawn customs offices easing space access and improving trade ship spawning, for a small fee.

- **No more random traders in your empty systems**
  ...wasting precious cargo space for sightseeing tours. There _is_ more trade traffic, but for another reason...

- Improved performance / code of trade ship navigation (didn't benchmark but it feels like quite a bit)

# Details
## New Trade Ship / Station mechanic

- A trade ship spawns and travels the actual route for every resource a planet / asteroid is exporting, every 3 minutes
- There will be multiple ships if the route is long enough, leading to roughly 3 times as many as in vanilla (depending on empire size and play style etc)
- The amount of trade stations still depends on the trade ships passed in that system, but since there are more ships per planet there are more trade stations as well.
- The income of a ship / station depends on its size * cargo worth (check [resources.txt](resources.txt))
- When a ship is destroyed the exporting planet immediately receives a blockaded status, disabling all exports.
- Arriving ships remove that status, which often leads to a race-condition where earlier ships clear that status again.
  This is left in deliberately since an actual blockade will quickly have a real impact but a small interruption won't hurt much (or at all) and can be seen as a warning to secure that part of the empire again.
- Trade ships have an indicator for their status, being either on their `main run`, or `trading`. (icons in the popup)
- Main run meaning transporting their actual resource to the designated planet. Trade run starts after this is complete.
- Trade ships have a chance to go to a trade station before continuing their journey, to `sell` their resource.
  `Selling` is essentially just setting that resource on a station, depending on a chance comparing their respective values.
  The exact formula can be seen in `server/../Civilian.as` in essence: _the more relative value a resource has, the more likely it is to be `sold`._
  Since income depends on the resource worth, higher value resources will generate more income over time.
- When on their trade run, ships also `buy` resources from planets, asteroids or stations. (same mechanic)

- \* Planets spawn Customs Offices as soon as they're colonized. Ships generally try to route there first but also can reach the planet directly.
- Customs Offices increase the trade ship spawn rate by 33% but have a fixed upkeep of 10k. (planned as tech, to be able to choose)

## Asteroids

Like planets, resource asteroids also spawn trade ships and can be blockaded. They also accept trade traffic, but don't have customs offices.
Ore asteroids are planned to work just like resource asteroids, where trade ships will transport discrete amounts of Ore.

# Changes
(probably outdated, check commit history)
## done
- more asteroids (more shards, resource asteroids got companions too. needs tuning)
- changed civilian trade ship navigation
    - asteroids with mining bases spawn trade ships (which can be destroyed, thus blockaded)
    - added "Blockaded Export" status, the specific resource is blockaded if ships are shot down until new ones arrive
      old "Blockaded" status still applies to the target planet, if the ship was carrying goods from a trade station (currently disabled)
    - trade ships don't reassign to random planets after delivering inter-system resources anymore.
- moved trade stations to be at 'exit points' of systems, repurposed back to trading
- every planet has a "Customs Office" now, will not spawn ships until CO is present
- civilians (from a foreign empire) are enemies too for AI (Remnants attack Civs now)
- added Statuses to Asteroids
- multiple ships per route (1/min/route)
- almost complete restructure of civilian navigation
- removes blockaded status when a planet/asteroid changes export target.
  (in case its still under siege it will regain status quickly)

## todo (ideas)
- handle racism (lol, as in, modifiers for different races since Mechanoid doesn't have that many planets/traffic, First have base mats, etc)
- add upgrades to customs offices (through planet buildings or orbitals)
      currently they start MAX size, they could start min and be upgraded in steps
- rework pirates (smaller, more of them, camping on lanes, interceptable, more stashes, occasional raid)
- change ore asteroids to use a mining bases like a resource (like OreRate resource)
    - with shards there would be one main roid per group where a mining base has to be built to start operations (maybe w/ fake ships).
    - like a resource, as soon as you connect it it's available, with a random yield ore/min on the receiving planet (or global)
    - maybe add upgrades (planet buildings or orbitals)
- ask Dalo about global ore trickery (maybe can port from RS)
    - add more ore requirements to buildings (easier to get ore)
- change AI to care for all this (prob no pirates for them or fake ones)
- add inter-trade-station traffic as tech (for more income, maybe inter-empire as treaty, check treaty code functionality)
- change "MoveCargoWhenResourceExported" trait to use destroyable ships, with discrete cargo
- change customs offices to be invul (or super-recharge) as long as there are supports around (so they can't be sniped)
- try to add new category (or whatever) to let player design it's civilian ships with hexes (miner/trader/hauler/etc), maybe spawn like supports