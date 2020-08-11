# Industrial Revolition

![logo](IndustrialRevolution/logo.png "")

This mod makes civilian transport ships more important.
(... and more industrial / eco stuff planned)

- Resource connections rely directly on arriving trade ships.
  When trade ships are destroyed the connection they represent will be disabled until the next ship actually arrives.

- No more random Civilian Traders in your neighbouring systems, wasting precious cargo space for sight seeing tours

# done
- more asteroids (more shards, resource asteroids got companions too. needs tuning)
- changed civilian trade ship navigation
    - asteroids spawn trade ships (which can be destroyed, thus blockaded)
    - added "Blockaded Export" status, the specific resource is blockaded if ships are shot down until new ones arrive
      old "Blockaded" status still applies to the target planet, if the ship was carrying goods from a trade station
    - trade ships don't reassign to random planets after delivering inter-system resources anymore.
      mostly.. it chooses the next (blockaded) planet if the global civLimit isn't reached, or despawns.
- moved trade stations to be at 'exit points' of systems, renamed to "Customs Office [Systemname]"
- civilians (from a foreign empire) are enemies too for AI (colony ships apparently too)

# todo (ideas)
- add Statuses to Asteroids (so we can stop hack-disabling the resource manually)
- only spawn customs office if there's actual export to that system
    - add upgrades (through planet buildings or orbitals)
      currently they start MAX size, they could start min and be upgraded in steps
- rework pirates (smaller, more of them, camping on lanes, interceptable, more stashes, occasional raid)
- maybe multiple ships per route (1/min/route)
- change ore asteroids to use a mining station like a resource
    - with shards there would be one main roid per group where a mining station has to be built to start operations (maybe w/ fake ships).
    - like a resource, as soon as you connect it it's available, with a random yield ore/min on the receiving planet (or global)
    - maybe add upgrades (planet buildings or orbitals)
- ask Dalo about global ore trickery (maybe can port from RS)
    - more ore requirements (it's easier to get)
- change AI to care for all this (prob no pirates for them or fake ones)
- add inter-trade-station traffic as tech (for more income, maybe inter-empire as treaty, check treaty code functionality)
- complete rewrite of civilian navigation is needed, to be more readable. (currently one messy if-cascade)
- fix ships heading for dead stations