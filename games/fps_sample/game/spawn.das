require engine.core
require health
require character_look

class SpawnPoint : Component {
    //! A position where a player respawns. Add it to an empty node in the level prefab

    @hint = "Index of the team the spawned characters belong to"
    team : int
}

class PlayerInfo : Component {
    //! Information about a player, not about the character - a nickname or a score belongs here too

    @hint = "Index of the team this player belongs to"
    team : int

    @hint = "Delay before respawning after death"
    respawnDelay : float = 3.

    @hint = "Time before respawn, or -1 while alive"
    respawnTimer : float = -1.
}

def spawn_at_team_point(nodeId : NodeId, team : int) {
    for (spot in find_components(type<SpawnPoint>)) {
        if (spot.team != team) {
            continue
        }

        nodeId.worldPosition = spot.nodeId.worldPosition

        // direction of the spawn point
        get_component(nodeId) $(var look : CharacterLook?) {
            look.setDirection(spot.nodeId.worldForward)
        }
        return
    }
}

def update_respawns() {
    for (r in find_components(type<PlayerInfo>)) {
        var health = get_component(r.nodeId, type<Health>)
        if (health == null || !health.isDead) {
            continue
        }

        // start of the respawn timer
        if (r.respawnTimer < 0.) {
            r.respawnTimer = r.respawnDelay
            continue
        }

        r.respawnTimer -= get_delta_time()
        if (r.respawnTimer <= 0.) {
            // back on the spawn point, alive again
            spawn_at_team_point(r.nodeId, r.team)
            health.revive()
            r.respawnTimer = -1.
        }
    }
}
