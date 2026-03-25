require engine.core

require strings
require pixelRenderer


var sprites : Bitmap
let sprite_size = int2(16, 16)

let directions = fixed_array(int2(0, 1), int2(0, -1), int2(1, 0), int2(-1, 0))

enum GameState {
    Menu
    PlayerVsPlayer
    PlayerVsAI
    AIvsAI
    Scores
}


enum UnitState {
    None
    Alive
    Dead
    WaitingForRespawn
    GameOver
}


var global_anim_frame = 0
var global_incremental_anim_frame = 0

let SPRITE_EMPTY = 0
let SPRITE_MAN_DOWN_0 = 1
let SPRITE_MAN_DOWN_1 = 2
let SPRITE_MAN_UP_0 = 3
let SPRITE_MAN_UP_1 = 4
let SPRITE_MAN_RIGHT_0 = 5
let SPRITE_MAN_RIGHT_1 = 6
let SPRITE_MAN_LEFT_0 = 7
let SPRITE_MAN_LEFT_1 = 8
let SPRITE_MAN_DEAD = 9
let SPRITE_GHOST_LEFT = 10
let SPRITE_GHOST_RIGHT = 11
let SPRITE_GHOST_DEAD = 12
let SPRITE_BOMB_0 = 13
let SPRITE_BOMB_1 = 14
let SPRITE_PERMANENT_BLOCK = 15
let SPRITE_DESTRUCTIBLE_BLOCK = 16
let SPRITE_BONUS_EXTRA_BOMB = 17
let SPRITE_BONUS_EXTRA_RANGE = 18
let SPRITE_EXPLOSION_0 = 19
let SPRITE_EXPLOSION_CENTER_0 = 20
let SPRITE_EXPLOSION_CENTER_1 = 21
let SPRITE_EXPLOSION_LEFT_END_0 = 22
let SPRITE_EXPLOSION_LEFT_END_1 = 23
let SPRITE_EXPLOSION_LEFT_0 = 24
let SPRITE_EXPLOSION_LEFT_1 = 25
let SPRITE_EXPLOSION_RIGHT_END_0 = 26
let SPRITE_EXPLOSION_RIGHT_END_1 = 27
let SPRITE_EXPLOSION_RIGHT_0 = 28
let SPRITE_EXPLOSION_RIGHT_1 = 29
let SPRITE_EXPLOSION_UP_END_0 = 30
let SPRITE_EXPLOSION_UP_END_1 = 31
let SPRITE_EXPLOSION_UP_0 = 32
let SPRITE_EXPLOSION_UP_1 = 33
let SPRITE_EXPLOSION_DOWN_END_0 = 34
let SPRITE_EXPLOSION_DOWN_END_1 = 35
let SPRITE_EXPLOSION_DOWN_0 = 36
let SPRITE_EXPLOSION_DOWN_1 = 37
let SPRITE_0 = 38
let SPRITE_1 = 39
let SPRITE_2 = 40
let SPRITE_3 = 41
let SPRITE_4 = 42
let SPRITE_5 = 43
let SPRITE_6 = 44
let SPRITE_7 = 45
let SPRITE_8 = 46
let SPRITE_9 = 47
let SPRITE_P = 48
let SPRITE_HEART = 49
let SPRITE_MENU_BACKGROUND = 50


let sprite_pos = fixed_array(
  int2(7, 6),  //SPRITE_EMPTY
  int2(0, 0),  //SPRITE_MAN_DOWN_0
  int2(1, 0),  //SPRITE_MAN_DOWN_1
  int2(2, 0),  //SPRITE_MAN_UP_0
  int2(3, 0),  //SPRITE_MAN_UP_1
  int2(4, 0),  //SPRITE_MAN_RIGHT_0
  int2(5, 0),  //SPRITE_MAN_RIGHT_1
  int2(6, 0),  //SPRITE_MAN_LEFT_0
  int2(7, 0),  //SPRITE_MAN_LEFT_1
  int2(2, 1),  //SPRITE_MAN_DEAD
  int2(0, 3),  //SPRITE_GHOST_LEFT
  int2(1, 3),  //SPRITE_GHOST_RIGHT
  int2(2, 3),  //SPRITE_GHOST_DEAD
  int2(0, 1),  //SPRITE_BOMB_0
  int2(1, 1),  //SPRITE_BOMB_1
  int2(0, 4),  //SPRITE_PERMANENT_BLOCK
  int2(2, 4),  //SPRITE_DESTRUCTIBLE_BLOCK
  int2(3, 4),  //SPRITE_BONUS_EXTRA_BOMB
  int2(4, 4),  //SPRITE_BONUS_EXTRA_RANGE
  int2(3, 3),  //SPRITE_EXPLOSION_0
  int2(4, 3),  //SPRITE_EXPLOSION_CENTER_0
  int2(5, 3),  //SPRITE_EXPLOSION_CENTER_1
  int2(3, 1),  //SPRITE_EXPLOSION_LEFT_END_0
  int2(3, 2),  //SPRITE_EXPLOSION_LEFT_END_1
  int2(4, 1),  //SPRITE_EXPLOSION_LEFT_0
  int2(4, 2),  //SPRITE_EXPLOSION_LEFT_1
  int2(5, 1),  //SPRITE_EXPLOSION_RIGHT_END_0
  int2(5, 2),  //SPRITE_EXPLOSION_RIGHT_END_1
  int2(4, 1),  //SPRITE_EXPLOSION_RIGHT_0
  int2(4, 2),  //SPRITE_EXPLOSION_RIGHT_1
  int2(6, 1),  //SPRITE_EXPLOSION_UP_END_0
  int2(7, 1),  //SPRITE_EXPLOSION_UP_END_1
  int2(6, 2),  //SPRITE_EXPLOSION_UP_0
  int2(7, 2),  //SPRITE_EXPLOSION_UP_1
  int2(6, 3),  //SPRITE_EXPLOSION_DOWN_END_0
  int2(7, 3),  //SPRITE_EXPLOSION_DOWN_END_1
  int2(6, 2),  //SPRITE_EXPLOSION_DOWN_0
  int2(7, 2),  //SPRITE_EXPLOSION_DOWN_1
  int2(0, 5),  //SPRITE_0
  int2(1, 5),  //SPRITE_1
  int2(2, 5),  //SPRITE_2
  int2(3, 5),  //SPRITE_3
  int2(4, 5),  //SPRITE_4
  int2(5, 5),  //SPRITE_5
  int2(6, 5),  //SPRITE_6
  int2(7, 5),  //SPRITE_7
  int2(9, 6),  //SPRITE_8
  int2(1, 6),  //SPRITE_9
  int2(2, 6),  //SPRITE_P
  int2(3, 6),  //SPRITE_HEART
  int2(6, 4),  //SPRITE_MENU_BACKGROUND
)


let {
    sound_set_bomb = request_sound("assets/sounds/set_bomb.wav")
    sound_explosion = request_sound("assets/sounds/explosion.wav")
    sound_man_scream = request_sound("assets/sounds/scream.wav")
    sound_bonus = request_sound("assets/sounds/bonus.wav")
    sound_ghost_scream = request_sound("assets/sounds/ghost_scream.wav")
    sound_game_over = request_sound("assets/sounds/game_over.wav")
}

var time_after_explosion_sound = 1.0

def level_position_to_pan(pos : int2) : float {
    return cvt(float(pos.x), 0.0, float(LEVEL_WIDTH + 1), 0.3, -0.3)
}


def text_char_to_source_coord(c : int) : int2 {
    if (c >= '0' && c <= '7') {
        return int2(c - '0', 5)
    } elif (c >= '8' && c <= '9') {
        return int2(c - '8', 6)
    } elif (c >= 'A' && c <= 'Z') {
        return int2((c - 'A') % 8, 7 + (c - 'A') / 8)
    } elif (c >= 'a' && c <= 'z') {
        return int2((c - 'a') % 8, 7 + (c - 'a') / 8)
    } elif (c == '*') {// heart
        return int2(3, 6)
    } elif (c == '>') {// selecttion arrow
        return int2(4, 6)
    } else {
        return int2(0, 0)
    }
}


def draw_sprite(screen_pos : int2, sprite : int, transparency : bool = false, tint_color : uint = 0xFFFFFFFF) {
    copy_image_rect(canvas.bitmap, sprites, screen_pos, sprite_pos[sprite] * sprite_size, sprite_size, transparency, tint_color)
}


def draw_sprite(screen_pos : int2, sprite : int2, transparency : bool = false, tint_color : uint = 0xFFFFFFFF) {
    copy_image_rect(canvas.bitmap, sprites, screen_pos, sprite * sprite_size, sprite_size, transparency, tint_color)
}


def draw_text(pos : int2, text : string, color : uint) {
    var x = pos.x
    var y = pos.y
    for (c in text) {
        if (c == '\n') {
            x = pos.x
            y += sprite_size.y
        } elif (c == ' ') {
            x += sprite_size.x
        } else {
            let coord = text_char_to_source_coord(c)
            draw_sprite(int2(x, y), coord, true, color)
            x += sprite_size.x - 1
        }
    }
}


def set_debug_status_string(str) {
    update_debug_text(statusNode, str)
}



let LEVEL_WIDTH = 29
let LEVEL_HEIGHT = 15
let MAX_EXPLOSIONS = 80
let MAX_GHOSTS = 20
let MAX_PLAYERS = 4

let firstPlayerSetName = "player1"
let secondPlayerSetName = "player2"


var level : int[LEVEL_HEIGHT][LEVEL_WIDTH]

var levels = fixed_array(
    "#############################" +
    "#1 . . ... . .o o. . ... . 4#" +
    "# # # # # # # # # # # # # # #" +
    "#. ... @ . ...o o... . ... .#" +
    "# #.#.#.#.#.#.#@#.#.#.#.#.# #" +
    "#... . . . ...o o... @ . ...#" +
    "# #o#o#o#o#o#o# #o#o#o#o#o# #" +
    "#o   @         o      @    o#" +
    "# #o#o#o#o#o#o# #o#o#o#o#o# #" +
    "#... . . @ ...o o... . . ...#" +
    "# #.#.#.#.#.#.#@#.#.#.#.#.# #" +
    "#. ... . . ...o o... @ ... .#" +
    "# # # # # # # # # # # # # # #" +
    "#3 . ... . . .o o. ... . . 2#" +
    "#############################"
)

enum ControlType {
    None
    Player
    Ai
}

struct PlayerActions {
    moveName : string
    placeBombName : string
}

let playerToActions : table<string, PlayerActions> = {
    firstPlayerSetName => PlayerActions(moveName = "move1", placeBombName = "placeBomb1"),
    secondPlayerSetName => PlayerActions(moveName = "move2", placeBombName = "placeBomb2")
}


struct Player {
    state : UnitState
    pos : float2
    lastDirection : int2
    wishDirection : int2
    maxBombs : int
    bombsPlaced : int
    bombRange : int
    control : ControlType
    actionSetName : string
    placeBomb : bool
    prevPlaceBomb : bool
    timeToRespawn : float
    lives : int
    score : int
    color : uint
    playerId : int
    animFrame : int
    timeToChangeAnimFrame : float
    timeToNextState : float
}


struct Ghost {
    state : UnitState
    pos : float2
    nextPos : float2
    direction : int2
    transition : float
    timeToDeath : float
    color : uint
    timeToNextState : float
}


struct Explosion {
    active : bool
    pos : int2
    animFrame : int
    timeToExplode : float
    timeToDisappear : float
    initialRange : int
    rangeLeft : int
    rangeRight : int
    rangeUp : int
    rangeDown : int
    playerId : int
}


var players : Player[MAX_PLAYERS]
var ghosts : Ghost[MAX_GHOSTS]
var explosions : Explosion[MAX_EXPLOSIONS]
var powerups : array<int3> // x, y, type

def allocate_explosion() : int {
    for (i in range(MAX_EXPLOSIONS)) {
        if (!explosions[i].active) {
            return i
        }
    }
    return -1
}

def allocate_ghost() : int {
    for (i in range(MAX_GHOSTS)) {
        if (ghosts[i].state == UnitState.None) {
            return i
        }
    }
    return -1
}

def spawn_player(var p : Player&, position) {
    p.pos = float2(position)
    p.lastDirection = int2(0, 0)
    p.wishDirection = int2(0, 0)
    p.maxBombs = 1
    p.bombsPlaced = 0
    p.bombRange = 1
    p.state = UnitState.Alive
    p.timeToRespawn = 0.0
    p.placeBomb = false
    p.prevPlaceBomb = false
    p.animFrame = 0
    p.timeToChangeAnimFrame = 0.0
    p.timeToNextState = 0.0
}

def spawn_ghost(var g : Ghost&, position) {
    g.pos = position
    g.nextPos = position
    g.transition = 0.0
    g.timeToDeath = 0.0
    g.direction = int2(0, 0)
    g.color = 0xFFFFFFFF
    g.state = UnitState.Alive
    g.timeToNextState = 0.0
}

def init_player(var p : Player&, control : ControlType, playerId : int, color : uint, actionSetName : string) {
    spawn_player(p, float2())
    p.control = control
    p.lives = 30
    p.score = 0
    p.color = color
    p.playerId = playerId
    p.state = UnitState.None
    p.actionSetName = actionSetName
}


var cell_score : float[LEVEL_HEIGHT][LEVEL_WIDTH] // < 0.0 - dangerous
var danger_cells : bool[LEVEL_HEIGHT][LEVEL_WIDTH]

def print_cell_scores() {
    for (y in range(LEVEL_HEIGHT)) {
        var s : string
        for (x in range(LEVEL_WIDTH)) {
            s = s + "{cell_score[y][x]} "
        }
        print("{s}\n")
    }
}

def clear_cell_score() {
    for (y in range(LEVEL_HEIGHT)) {
        for (x in range(LEVEL_WIDTH)) {
            cell_score[y][x] = 0.0
        }
    }
}

def update_cell_score() {
    // blur and fade
    var blured_score : float[LEVEL_HEIGHT][LEVEL_WIDTH]

    for (y in range(0, LEVEL_HEIGHT)) {
        for (x in range(0, LEVEL_WIDTH)) {
            danger_cells[y][x] = false
        }
    }

    for (y in range(1, LEVEL_HEIGHT - 1)) {
        for (x in range(1, LEVEL_WIDTH - 1)) {
            if (!is_walkable(int2(x, y))) {
                continue
            }
            var v = cell_score[y][x]
            var cnt = 1.0
            for (dir in directions) {
                if (is_walkable(dir + int2(x, y)) || is_destructible(dir + int2(x, y))) {
                    v += cell_score[y + dir.y][x + dir.x]
                    cnt += 1.0
                }
            }
            v = v * 0.6 / cnt
            blured_score[y][x] = v
        }
    }

    for (y in range(1, LEVEL_HEIGHT - 1)) {
        for (x in range(1, LEVEL_WIDTH - 1)) {
            cell_score[y][x] = blured_score[y][x]
        }
    }

    // targets
    for (y in range(LEVEL_HEIGHT)) {
        for (x in range(LEVEL_WIDTH)) {
            let v = level[y][x]
            if (v == SPRITE_BONUS_EXTRA_BOMB) {
                cell_score[y][x] = 100.0
            } elif (v == SPRITE_BONUS_EXTRA_RANGE) {
                cell_score[y][x] = 101.0
            } elif (v == SPRITE_DESTRUCTIBLE_BLOCK) {
                cell_score[y][x] = 10.0
            }
        }
    }

    cell_score[1][1] -= 1.0
    cell_score[1][LEVEL_WIDTH - 2] -= 1.0
    cell_score[LEVEL_HEIGHT - 2][1] -= 1.0
    cell_score[LEVEL_HEIGHT - 2][LEVEL_WIDTH - 2] -= 1.0

    // dangers
    for (g in ghosts) {
        if (g.state == UnitState.Alive) {
            cell_score[int(g.pos.y)][int(g.pos.x)] = -100.0
            for (dir in directions) {
                if (is_walkable(dir + int2(g.pos))) {
                    cell_score[int(g.pos.y) + dir.y][int(g.pos.x) + dir.x] -= 10.0
                    danger_cells[int(g.pos.y) + dir.y][int(g.pos.x) + dir.x] = true
                }
            }
        }
    }

    for (e in explosions) {
        if (e.active) {
            let ipos = int2(e.pos)
            cell_score[ipos.y][ipos.x] -= 1500.0
            if (e.timeToExplode < 0.7) {
                danger_cells[ipos.y][ipos.x] = true
            }
            for (dir in directions) {
                var neverStepHere = true
                for (i in range(1, e.initialRange + 1)) {
                    if (i > 0 && !is_walkable(ipos + dir * i)) {
                        break
                    }
                    if (i > 0 && (is_walkable(ipos + dir * i + int2(dir.y, -dir.x)) || is_walkable(ipos + dir * i + int2(-dir.y, dir.x)))) {
                        neverStepHere = false
                    }
                    if (i == e.initialRange && is_walkable(ipos + dir * (i + 1))) {
                        neverStepHere = false
                    }
                    var k = (3.0 - e.timeToExplode)
                    cell_score[e.pos.y + dir.y * i][e.pos.x + dir.x * i] -= (150.0 + float(i) * 10.0) * k
                }

                if (e.timeToExplode < 0.5) {
                    neverStepHere = true
                }

                for (i in range(1, e.initialRange + 1)) {
                    if (i > 0 && !is_walkable(ipos + dir * i)) {
                        break
                    }
                    for (g in ghosts) {
                        if (g.state == UnitState.Alive && length(g.pos - float2(ipos + dir * i)) < 2.5) {
                            neverStepHere = true
                        }
                    }
                }

                if (neverStepHere) {
                    for (i in range(1, e.initialRange + 1)) {
                        cell_score[e.pos.y + dir.y * i][e.pos.x + dir.x * i] -= 500.0
                        danger_cells[e.pos.y + dir.y * i][e.pos.x + dir.x * i] = true
                        if (i > 0 && !is_walkable(dir * i + int2(e.pos))) {
                            break
                        }
                    }
                }
            }
        }
    }
}


def update_ai(var p : Player&) {
    if (p.state != UnitState.Alive) {
        return
    }
    let ipos = int2(p.pos)

    var targetPos = ipos
    var bestScore = cell_score[ipos.y][ipos.x]

    var canPlaceBomb = false
    var freeCells = 0

    for (dir in directions) {
        let pos = ipos + dir
        if (pos.x < 0 || pos.x >= LEVEL_WIDTH || pos.y < 0 || pos.y >= LEVEL_HEIGHT) {
            continue
        }
        if (level[pos.y][pos.x] == SPRITE_DESTRUCTIBLE_BLOCK) {
            canPlaceBomb = true
        }
        if (p.bombRange >= 2) {
            if (pos.x > 1 && pos.x < LEVEL_WIDTH - 2 && pos.y > 1 && pos.y < LEVEL_HEIGHT - 2) {
                if (level[pos.y][pos.x] == 0 && level[ipos.y + dir.y * 2][ipos.x + dir.x * 2] == SPRITE_DESTRUCTIBLE_BLOCK) {
                    canPlaceBomb = true
                }
            }
        }
        if (is_walkable(pos) && !danger_cells[pos.y][pos.x]) {
            let score = cell_score[pos.y][pos.x]
            if (score > bestScore) {
                bestScore = score
                targetPos = pos
            }
        }
    }

    p.wishDirection = targetPos - ipos

    if (p.wishDirection == int2(0, 0) && length(p.pos - (float2(ipos) + float2(0.5))) > 0.1) {
        p.wishDirection.x = int(sign((float(ipos.x) + 0.5 - p.pos.x)))
        p.wishDirection.y = int(sign((float(ipos.y) + 0.5 - p.pos.y)))
    }

    if (targetPos == ipos) {
        var otherPlayerIsNear = false
        for (other in players) {
            if (other.state == UnitState.Alive && other.playerId != p.playerId) {
                if (length(other.pos - p.pos) < 3.0) {
                    canPlaceBomb = true
                }
                if (length(other.pos - p.pos) < 2.0) {
                    otherPlayerIsNear = true
                    break
                }
            }
        }
        if (otherPlayerIsNear) {
            for (i in range(length(directions))) {
                let dir = directions[(i + p.playerId + global_anim_frame) % length(directions)]
                let pos = ipos + dir
                if (is_walkable(pos) && !danger_cells[pos.y][pos.x] && dir.x * p.lastDirection.x + dir.y * p.lastDirection.y >= 0) {
                    p.wishDirection = dir
                    break
                }
            }
        }
    }

    for (g in ghosts) {
        if (g.state == UnitState.Alive && length(g.pos - p.pos) < 3.0 + float(p.bombRange)) {
            if (int(g.pos.x) == ipos.x && int(g.pos.y) == ipos.y) {
                canPlaceBomb = true
            }
        }
    }


    if (canPlaceBomb) {
        if (danger_cells[ipos.y][ipos.x]) {
            canPlaceBomb = false
        }
        for (dir in directions) {
            if (danger_cells[ipos.y + dir.y][ipos.x + dir.x]) {
                canPlaceBomb = false
            }
        }
    }

    if (canPlaceBomb && p.bombsPlaced < p.maxBombs) {
        p.placeBomb = true
    }
}


def update_player_controls(var p : Player&) {
    p.placeBomb = false

    if (p.control == ControlType.Player) {
        playerToActions.get(p.actionSetName, $(actionNames) {
            let moveDir = get_action_vector2(actionNames.moveName)
            p.wishDirection = int2(0, 0)

            if (abs(moveDir.x) > 0.15) {
                p.wishDirection.x += moveDir.x > 0f ? 1 : -1
            }
            if (abs(moveDir.y) > 0.15) {
                p.wishDirection.y += moveDir.y > 0f ? -1 : 1
            }

            if (is_action_just_pressed(actionNames.placeBombName)) {
                p.placeBomb = true
            }
        })
    } elif (p.control == ControlType.Ai) {
        update_ai(p)
    }
}


def spawn_bomb(ipos : int2, bomb_range : int, playerId : int) {
    let index = allocate_explosion()
    if (index == -1) {
        return
    }

    set_volume(play_sound(sound_set_bomb), 0.5) |> set_pan(level_position_to_pan(ipos))

    var e : Explosion& = explosions[index]
    e.active = true
    e.timeToExplode = 3.0
    e.timeToDisappear = 0.5
    e.pos = ipos
    e.initialRange = bomb_range
    e.playerId = playerId

    if (level[ipos.y][ipos.x] == 0) {
        level[ipos.y][ipos.x] = SPRITE_BOMB_0
    }
}


def trace_explosion_ray(start_pos, dir : int2, initial_range : int, var final_range : int&) {
    final_range = initial_range
    for (i in range(1, initial_range + 1)) {
        let pos = start_pos + dir * i
        for (e in explosions) {
            if (e.active && e.pos == pos && e.timeToExplode > 0.08) {
                e.timeToExplode = 0.08
            }
        }

        let v = level[pos.y][pos.x]
        if (v != 0) {
            if (v == SPRITE_BOMB_0) {
                continue
            }
            if (v == SPRITE_PERMANENT_BLOCK) {
                final_range = i - 1
                break
            } elif (v != 0) {
                final_range = i
                break
            }
        }
    }
}


def destroy_units_on_ray(owner : int, start_pos, dir : int2, length : int) {
    for (i in range(0, length + 1)) {
        let pos = start_pos + dir * i
        for (p in players) {
            if (p.state == UnitState.Alive && int2(p.pos) == pos) {
                set_volume(play_sound(sound_man_scream), 0.5) |> set_pan(level_position_to_pan(pos))
                p.state = UnitState.Dead
                p.timeToNextState = 0.8
                if (owner != p.playerId) {
                    players[owner].score += 50
                }
            }
        }

        for (g in ghosts) {
            if (g.state == UnitState.Alive && int2(g.pos) == pos) {
                set_volume(play_sound(sound_ghost_scream), 0.5) |> set_pan(level_position_to_pan(pos))
                g.state = UnitState.Dead
                g.timeToNextState = 0.8
                players[owner].score += 20
            }
        }
    }
}


def destruct_cells_on_ray(owner : int, start_pos, dir : int2, length : int) {
    for (i in range(1, length + 1)) {
        let pos = start_pos + dir * i
        if (level[pos.y][pos.x] == SPRITE_DESTRUCTIBLE_BLOCK) {
            players[owner].score += 1
        }
        level[pos.y][pos.x] = 0

        //set_debug_status_string("{length(powerups)}")
        for (k in range(length(powerups))) {
            if (powerups[k].xy == pos) {
                level[pos.y][pos.x] = powerups[k].z
                erase(powerups, k)
                break
            }
        }
    }
}


def update_explosion(var e : Explosion&, dt : float) {
    if (!e.active) {
        return
    }
    if (e.timeToExplode > 0.0) {
        players[e.playerId].bombsPlaced++
        e.timeToExplode -= dt
        if (e.timeToExplode <= 0.0) {
            if (time_after_explosion_sound > 0.2) {
                set_volume(play_sound(sound_explosion), 0.25) |> set_pan(level_position_to_pan(e.pos))
            }
            time_after_explosion_sound = 0.0
            e.timeToExplode = 0.0
            level[e.pos.y][e.pos.x] = 0
            trace_explosion_ray(e.pos, int2(-1, 0), e.initialRange, e.rangeLeft)
            trace_explosion_ray(e.pos, int2(1, 0), e.initialRange, e.rangeRight)
            trace_explosion_ray(e.pos, int2(0, -1), e.initialRange, e.rangeUp)
            trace_explosion_ray(e.pos, int2(0, 1), e.initialRange, e.rangeDown)
            e.animFrame = 0
        }
    } elif (e.timeToDisappear > 0.0) {
        e.timeToDisappear -= dt
        e.animFrame = int(e.timeToDisappear * 12.5) & 1

        destroy_units_on_ray(e.playerId, e.pos, int2(-1, 0), e.rangeLeft)
        destroy_units_on_ray(e.playerId, e.pos, int2(1, 0), e.rangeRight)
        destroy_units_on_ray(e.playerId, e.pos, int2(0, -1), e.rangeUp)
        destroy_units_on_ray(e.playerId, e.pos, int2(0, 1), e.rangeDown)

        if (e.timeToDisappear <= 0.0) {
            e.timeToDisappear = 0.0
            destruct_cells_on_ray(e.playerId, e.pos, int2(-1, 0), e.rangeLeft)
            destruct_cells_on_ray(e.playerId, e.pos, int2(1, 0), e.rangeRight)
            destruct_cells_on_ray(e.playerId, e.pos, int2(0, -1), e.rangeUp)
            destruct_cells_on_ray(e.playerId, e.pos, int2(0, 1), e.rangeDown)
            e.active = false
        }
    }
}



def is_walkable(v : int) : bool {
    return v == 0 || v == SPRITE_BONUS_EXTRA_BOMB || v == SPRITE_BONUS_EXTRA_RANGE
}

def is_walkable(pos : int2) : bool {
    if (pos.x < 0 || pos.y < 0 || pos.x >= LEVEL_WIDTH || pos.y >= LEVEL_HEIGHT) {
        return false
    }
    return is_walkable(level[pos.y][pos.x])
}

def is_destructible(v : int) : bool {
    return v == SPRITE_BONUS_EXTRA_BOMB || v == SPRITE_BONUS_EXTRA_RANGE || v == SPRITE_DESTRUCTIBLE_BLOCK || v == SPRITE_BOMB_0
}

def is_destructible(pos : int2) : bool {
    if (pos.x < 0 || pos.y < 0 || pos.x >= LEVEL_WIDTH || pos.y >= LEVEL_HEIGHT) {
        return false
    }
    return is_destructible(level[pos.y][pos.x])
}


def pickup_powerups(var p : Player&) {
    let ipos = int2(p.pos)
    let v = level[ipos.y][ipos.x]
    if (v == SPRITE_BONUS_EXTRA_BOMB) {
        set_volume(play_sound(sound_bonus), 0.7) |> set_pan(level_position_to_pan(ipos))
        p.maxBombs += 1
        p.score += 5
        level[ipos.y][ipos.x] = 0
    } elif (v == SPRITE_BONUS_EXTRA_RANGE) {
        set_volume(play_sound(sound_bonus), 0.7) |> set_pan(level_position_to_pan(ipos))
        p.bombRange += 1
        p.score += 5
        level[ipos.y][ipos.x] = 0
    }
}


def update_player_move(var p : Player&, dt : float) {
    if (p.state != UnitState.Alive) {
        return
    }
    let ipos = int2(p.pos)

    pickup_powerups(p)

    let speed = 3.0
    let step = dt * speed

    if (p.placeBomb && !p.prevPlaceBomb && p.bombsPlaced < p.maxBombs) {
        spawn_bomb(int2(p.pos), p.bombRange, p.playerId)
    }
    p.prevPlaceBomb = p.placeBomb

    if (p.wishDirection != int2(0, 0)) {
        p.timeToChangeAnimFrame -= dt
        if (p.timeToChangeAnimFrame <= 0.0) {
            p.timeToChangeAnimFrame += 0.08
            p.animFrame = 1 - p.animFrame
        }

        p.lastDirection = p.wishDirection
        if (abs(p.wishDirection.x) > 0 && (is_walkable(floori(p.pos - float2(p.wishDirection.x, 0) * (0.5 - step)) + int2(p.wishDirection.x, 0)))
                || (!is_walkable(floori(p.pos)) && is_walkable(floori(p.pos) + int2(p.wishDirection.x, 0)))) {
            if (abs(p.pos.y - float(ipos.y) - 0.5) < 0.01) {
                p.pos.y = float(ipos.y) + 0.5
                p.pos.x += float(p.wishDirection.x) * dt * speed
            } else {
                p.pos.y = move_to(p.pos.y, float(ipos.y) + 0.5, dt, speed)
            }
        } elif (abs(p.wishDirection.y) > 0 && (is_walkable(floori(p.pos - float2(0, p.wishDirection.y) * (0.5 - step)) + int2(0, p.wishDirection.y)))
                || (!is_walkable(floori(p.pos)) && is_walkable(floori(p.pos) + int2(0, p.wishDirection.y)))) {
            if (abs(p.pos.x - float(ipos.x) - 0.5) < 0.01) {
                p.pos.x = float(ipos.x) + 0.5
                p.pos.y += float(p.wishDirection.y) * dt * speed
            } else {
                p.pos.x = move_to(p.pos.x, float(ipos.x) + 0.5, dt, speed)
            }
        }
    }
    //set_debug_status_string("{p.wishDirection} last = {p.lastDirection}; pos = {p.pos}; frame = {p.animFrame}")
    p.bombsPlaced = 0
}



def add_level_powerups(range_count, bomb_count : int) {
    var allPositions : array<int2>
    for (y in range(1, LEVEL_HEIGHT - 1)) {
        for (x in range(1, LEVEL_WIDTH - 1)) {
            if (level[y][x] == SPRITE_DESTRUCTIBLE_BLOCK) {
                push(allPositions, int2(x, y))
            }
        }
    }

    for (i in range(range_count)) {
        if (!empty(allPositions)) {
            let index = random_range(0, length(allPositions))
            let pos = allPositions[index]
            erase(allPositions, index)
            push(powerups, int3(pos.x, pos.y, SPRITE_BONUS_EXTRA_RANGE))
        }
    }

    for (i in range(bomb_count)) {
        if (!empty(allPositions)) {
            let index = random_range(0, length(allPositions))
            let pos = allPositions[index]
            erase(allPositions, index)
            push(powerups, int3(pos.x, pos.y, SPRITE_BONUS_EXTRA_BOMB))
        }
    }

    delete allPositions
}


def load_level(index : int) {
    let level_str = levels[index]
    var x = 0
    var y = 0
    for (c in level_str) {
        level[y][x] = 0
        if (c == '#') {
            level[y][x] = SPRITE_PERMANENT_BLOCK
        } elif (c >= '1' && c <= '1' + length(players) - 1) {
            var p : Player& = players[c - '1']
            if (p.control == ControlType.None) {
                p.state = UnitState.None
            } else {
                spawn_player(p, float2(x, y) + float2(0.5))
            }
        } elif (c == 'o') {
            level[y][x] = SPRITE_DESTRUCTIBLE_BLOCK
        } elif (c == '.') {
            level[y][x] = random_bool() ? SPRITE_DESTRUCTIBLE_BLOCK : 0
        } elif (c == '@') {
            let i = allocate_ghost()
            if (i >= 0) {
                spawn_ghost(ghosts[i], float2(x, y) + float2(0.5))
            }
        }
        x += 1
        if (x == LEVEL_WIDTH) {
            x = 0
            y += 1
        }
    }

    add_level_powerups(15, 15)
}


def render_explosion_ray(center, dir : int2, length : int, line_sprite, end_sprite, anim_frame : int) {
    if (length == 0) {
        return
    }
    let offs = sprite_size / 2
    draw_sprite(sprite_size * (center + dir * length) + offs, end_sprite + anim_frame, true)
    for (i in range(1, length)) {
        draw_sprite(sprite_size * (center + dir * i) + offs, line_sprite + anim_frame, true)
    }
}


var menu_pos = 0

var prev_up_pressed = false
var prev_down_pressed = false
var prev_fire_pressed = false

def render_menu() {
    var color = (0x010101 * uint(clamp(time_to_next_game_state * 512.0 + 1.0, 0.0, 255.0)))
    if (time_to_next_game_state <= 0.0) {
        color = 0xFFFFFFFF
    }

    for (y in range(LEVEL_HEIGHT + 3)) {
        for (x in range(-1, LEVEL_WIDTH + 2)) {
            draw_sprite(sprite_size * int2(x, y), SPRITE_MENU_BACKGROUND, false, color)
        }
    }

    var pos = int2((LEVEL_WIDTH / 2 - 4) * sprite_size.x, 40)
    let lineStep = 30
    draw_text(pos, "BLASTERMAN", 0xFFA02000)
    pos = int2((LEVEL_WIDTH / 2 - 7) * sprite_size.x, 110)
    if (global_anim_frame == 0) {
        draw_text(pos + int2(-20, menu_pos * lineStep), ">", 0x0)
    }
    draw_text(pos, "1 PLAYER VS PLAYER", 0x0)
    pos.y += lineStep
    draw_text(pos, "2 PLAYER VS AI", 0x0)
    pos.y += lineStep
    draw_text(pos, "3 AI VS AI", 0x0)
    pos.y += lineStep
}


def update_menu() {
    if (time_to_next_game_state > 0.0) {
        return
    }

    let up_pressed = (is_action_pressed("up"))
    let down_pressed = (is_action_pressed("down"))
    var fire_pressed = (is_action_just_pressed("ok"))

    if (up_pressed && !prev_up_pressed) {
        set_volume(play_sound(sound_set_bomb), 0.1) |> set_pitch(2.0)
        menu_pos -= 1
    }
    if (down_pressed && !prev_down_pressed) {
        set_volume(play_sound(sound_set_bomb), 0.1) |> set_pitch(2.0)
        menu_pos += 1
    }
    menu_pos = clamp(menu_pos, 0, 2)
    if (is_action_just_pressed("firstMenuOption")) {
        menu_pos = 0
        fire_pressed = true
    } elif (is_action_just_pressed("secondMenuOption")) {
        menu_pos = 1
        fire_pressed = true
    } elif (is_action_just_pressed("thirdMenuOption")) {
        menu_pos = 2
        fire_pressed = true
    }

    if (fire_pressed && !prev_fire_pressed) {
        set_volume(play_sound(sound_bonus), 0.5) |> set_pitch(2.0)
        time_to_next_game_state = 0.5
        if (menu_pos == 0) {
            next_game_state = GameState.PlayerVsPlayer
        } elif (menu_pos == 1) {
            next_game_state = GameState.PlayerVsAI
        } elif (menu_pos == 2) {
            next_game_state = GameState.AIvsAI
        }
    }

    prev_up_pressed = up_pressed
    prev_down_pressed = down_pressed
    prev_fire_pressed = fire_pressed
}


def render_gameplay_ui() {
    fill_rect(canvas.bitmap, 0, pixel_resolution.y - 24, pixel_resolution.x, 24, 0xFF000000)
    if (game_state == GameState.PlayerVsPlayer) {
        for (i, p in range(2), players) {
            let pos = int2(20 + i * 290, pixel_resolution.y - 20)
            let score = min(p.score, 9999)
            draw_text(pos, "P{i + 1} {score:04d}  {p.lives}", p.color)
            draw_text(pos + int2(120, 0), "*", 0xFFFFFFFF)
        }
    } elif (game_state == GameState.PlayerVsAI || game_state == GameState.AIvsAI) {
        for (i, p in range(MAX_PLAYERS), players) {
            let pos = int2(20 + i * 126, pixel_resolution.y - 20)
            let score = min(p.score, 9999)
            draw_text(pos, "{score:04d}", p.color)
        }
    }
}


def render_scores() {
    fill_rect(canvas.bitmap, 0, 0, pixel_resolution.x, pixel_resolution.y, 0xFF000000)
    var pos = int2((LEVEL_WIDTH / 2 - 4) * sprite_size.x, 40)
    let lineStep = 30

    var scores <- [for (p in players); int2(p.score, p.playerId)]
    sort(scores) $(a, b) {
        return a.x > b.x
    }

    draw_text(pos, "FINAL SCORE", 0xFFB05050)
    pos = int2((LEVEL_WIDTH / 2 - 2) * sprite_size.x, 110)
    var count = 1
    for (rec in scores) {
        assume player = players[rec.y]
        if (player.control == ControlType.None) {
            continue
        }
        let score = min(player.score, 9999)
        draw_text(pos, "P{rec.y + 1} {score:04d}", player.color)
        pos.y += lineStep
        count++
    }
}


def render_gameplay_scene() {
    for (y in range(LEVEL_HEIGHT + 1)) {
        for (x in range(LEVEL_WIDTH + 1)) {
            draw_sprite(sprite_size * int2(x, y), int2(7, 4))
        }
    }

    for (y in range(LEVEL_HEIGHT)) {
        for (x in range(LEVEL_WIDTH)) {
            if (level[y][x] != 0) {
                var c = level[y][x]
                if (c == SPRITE_BOMB_0) {
                    c += global_anim_frame
                }
                draw_sprite(sprite_size * int2(x, y) + sprite_size / 2, c, true)
            }
        }
    }

    for (e in explosions) {
        let offs = sprite_size / 2
        if (e.active && e.timeToExplode < 0.08) {
            draw_sprite(sprite_size * e.pos + offs, SPRITE_EXPLOSION_0, true)
        }
        if (e.active && e.timeToExplode <= 0.0) {
            draw_sprite(sprite_size * e.pos + offs, SPRITE_EXPLOSION_CENTER_0 + e.animFrame, true)

            render_explosion_ray(e.pos, int2(-1, 0), e.rangeLeft, SPRITE_EXPLOSION_LEFT_0,
                SPRITE_EXPLOSION_LEFT_END_0, e.animFrame)
            render_explosion_ray(e.pos, int2(1, 0), e.rangeRight, SPRITE_EXPLOSION_RIGHT_0,
                SPRITE_EXPLOSION_RIGHT_END_0, e.animFrame)
            render_explosion_ray(e.pos, int2(0, -1), e.rangeUp, SPRITE_EXPLOSION_UP_0,
                SPRITE_EXPLOSION_UP_END_0, e.animFrame)
            render_explosion_ray(e.pos, int2(0, 1), e.rangeDown, SPRITE_EXPLOSION_DOWN_0,
                SPRITE_EXPLOSION_DOWN_END_0, e.animFrame)
        }
    }

    for (p in players) {
        if (p.state == UnitState.Alive) {
            var c = SPRITE_MAN_DOWN_0
            if (p.lastDirection.y > 0) {
                c = SPRITE_MAN_DOWN_0 + p.animFrame
            }
            if (p.lastDirection.y < 0) {
                c = SPRITE_MAN_UP_0 + p.animFrame
            }
            if (p.lastDirection.x < 0) {
                c = SPRITE_MAN_LEFT_0 + p.animFrame
            }
            if (p.lastDirection.x > 0) {
                c = SPRITE_MAN_RIGHT_0 + p.animFrame
            }
            if (p.timeToNextState <= 0.0 || (global_anim_frame & 1) == 1) {
                draw_sprite(int2(float2(sprite_size) * p.pos), c, true, p.color)
            }
        } elif (p.state == UnitState.Dead) {
            if ((global_anim_frame & 1) == 1) {
                draw_sprite(int2(float2(sprite_size) * p.pos), SPRITE_MAN_DEAD, true, p.color)
            }
        }
    }

    for (g in ghosts) {
        if (g.state == UnitState.Alive) {
            var c = g.direction.x > 0 ? SPRITE_GHOST_LEFT : SPRITE_GHOST_RIGHT
            draw_sprite(int2(float2(sprite_size) * g.pos), c, true, g.color)
        } elif (g.state == UnitState.Dead) {
            if ((global_anim_frame & 1) == 1) {
                draw_sprite(int2(float2(sprite_size) * g.pos), SPRITE_GHOST_DEAD, true, g.color)
            }
        }
    }

    render_gameplay_ui()
}


def render() {
    if (game_state == GameState.Menu) {
        render_menu()
    } elif (game_state == GameState.PlayerVsPlayer || game_state == GameState.PlayerVsAI || game_state == GameState.AIvsAI) {
        render_gameplay_scene()
    } elif (game_state == GameState.Scores) {
        render_scores()
    }
}


def can_spawn_in_position(pos : int2) : bool {
    if (level[pos.y][pos.x] != 0) {
        return false
    }

    var freeAround = 0
    for (dir in directions) {
        if (level[pos.y + dir.y][pos.x + dir.x] == 0 &&
                level[clamp(pos.y + dir.y * 2, 0, LEVEL_HEIGHT - 1)][clamp(pos.x + dir.x * 2, 0, LEVEL_WIDTH - 1)] == 0) {
            freeAround++
        }
    }

    if (freeAround < 2) {
        return false
    }

    for (p in players) {
        if (p.state == UnitState.Alive && length(p.pos - float2(pos)) < 6.0) {
            return false
        }
    }
    for (g in ghosts) {
        if (g.state == UnitState.Alive && length(g.pos - float2(pos)) < 3.0) {
            return false
        }
    }
    for (e in explosions) {
        if (e.active && (e.pos.x == pos.x || e.pos.y == pos.y)) {
            return false
        }
    }
    return true
}


def select_spawn_position() : int2 {
    for (i in range(10000)) {
        var pos = int2(random_range(1, LEVEL_WIDTH - 1), random_range(1, LEVEL_HEIGHT - 1))
        if (can_spawn_in_position(pos)) {
            return pos
        }
    }
    return int2(1, 1)
}


def update_player_state(var p : Player&, dt : float) {
    if (p.state == UnitState.None || p.timeToNextState <= 0.0 || p.control == ControlType.None) {
        return
    }
    p.timeToNextState -= dt
    if (p.timeToNextState <= 0.0) {
        if (p.state == UnitState.Dead) {
            p.lives--
            if (p.lives > 0) {
                p.state = UnitState.WaitingForRespawn
                p.timeToNextState = 1.0
            } else {
                p.state = UnitState.GameOver
            }
        } elif (p.state == UnitState.WaitingForRespawn) {
            spawn_player(p, float2(select_spawn_position()) + float2(0.5))
            p.timeToNextState = 0.7 // blinking time
        }
    }
}


def update_ghost_state(var g : Ghost&, dt : float) {
    if (g.state == UnitState.None || g.timeToNextState <= 0.0) {
        return
    }
    g.timeToNextState -= dt
    if (g.timeToNextState <= 0.0) {
        if (g.state == UnitState.Dead) {
            g.state = UnitState.None
        }
    }
}


def update_ghost_move(var g : Ghost&, dt : float) {
    if (g.state != UnitState.Alive) {
        return
    }
    g.pos += normalize(g.nextPos - g.pos) * dt * 2.0
    if (dot(g.pos - g.nextPos, float2(g.direction)) >= 0.0 || g.direction == int2(0, 0)) {
        let overrun = length(g.pos - g.nextPos)
        g.pos = g.nextPos
        var foundDir = int2(0, 0)
        for (_ in range(8)) {
            let tryDir = directions[random_range(0, 4)]
            if (tryDir != -g.direction && level[int(g.pos.y) + tryDir.y][int(g.pos.x) + tryDir.x] == 0) {
                foundDir = tryDir
                break
            }
        }

        if (foundDir == int2(0, 0)) {
            foundDir = -g.direction
        }

        g.direction = foundDir
        g.nextPos = floor(g.pos) + float2(g.direction) + float2(0.5f)
        g.pos += normalize(g.nextPos - g.pos) * overrun
    }

    for (p in players) {
        if (p.state == UnitState.Alive && length(p.pos - g.pos) < 0.5) {
            set_volume(play_sound(sound_man_scream), 0.5) |> set_pan(level_position_to_pan(int2(p.pos)))
            p.state = UnitState.Dead
            p.timeToNextState = 0.7
        }
    }
}



var canvas : BitMapWithTexture

[export]
def on_initialize() {

    canvas <- initialize_pixel_renderer(pixel_resolution)

    load_pixel_image("assets/blasterman_sprites.png", true) $(var bmp) {
        sprites <- bmp
    }

    randomize_seed()
    clear(powerups)

    add_action_set(firstPlayerSetName, {
        "move1" => Action(
            joystickActions = JoystickAction(
                keyboardDPads = [KeyboardDPadInput(leftIdx=KeyCode.Left, rightIdx=KeyCode.Right, upIdx=KeyCode.Up, downIdx=KeyCode.Down), KeyboardDPadInput(leftIdx=KeyCode.A, rightIdx=KeyCode.D, upIdx=KeyCode.W, downIdx=KeyCode.S)],
                gamepadDPads = [GamepadDPadInput(leftIdx=GamepadButton.Left, rightIdx=GamepadButton.Right, upIdx=GamepadButton.Up, downIdx=GamepadButton.Down)],
                sticks = [GamepadStickInput(xIdx=GamepadAxis.LThumbH, yIdx=GamepadAxis.LThumbV)],
            )
        ),
        "placeBomb1" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Space)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
            )
        )
    })

    add_action_set(secondPlayerSetName, {
        "move2" => Action(
            joystickActions = JoystickAction(
                keyboardDPads = [KeyboardDPadInput(leftIdx=KeyCode.Numpad4, rightIdx=KeyCode.Numpad6, upIdx=KeyCode.Numpad8, downIdx=KeyCode.Numpad5), KeyboardDPadInput(leftIdx=KeyCode.J, rightIdx=KeyCode.L, upIdx=KeyCode.I, downIdx=KeyCode.K)],
                gamepadDPads = [GamepadDPadInput(leftIdx=GamepadButton.Left, rightIdx=GamepadButton.Right, upIdx=GamepadButton.Up, downIdx=GamepadButton.Down, gamepadIdx=ControllerIndex.Device1)],
                sticks = [GamepadStickInput(xIdx=GamepadAxis.LThumbH, yIdx=GamepadAxis.LThumbV, gamepadIdx=ControllerIndex.Device1)],
            )
        ),
        "placeBomb2" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Return)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A, gamepadIdx=ControllerIndex.Device1)]
            )
        )
    })

    add_and_activate_action_set("ui", {
        "back" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Back)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Back), GamepadButtonInput(idx=GamepadButton.Back, gamepadIdx=ControllerIndex.Device1)]
            )
        ),
        "up" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Up), KeyboardButtonInput(idx=KeyCode.W), KeyboardButtonInput(idx=KeyCode.Numpad8)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Up), GamepadButtonInput(idx=GamepadButton.Up, gamepadIdx=ControllerIndex.Device1)]
            )
        ),
        "down" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Down), KeyboardButtonInput(idx=KeyCode.S), KeyboardButtonInput(idx=KeyCode.Numpad5)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Down), GamepadButtonInput(idx=GamepadButton.Down, gamepadIdx=ControllerIndex.Device1)]
            )
        ),
        "ok" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Space), KeyboardButtonInput(idx=KeyCode.Return)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A), GamepadButtonInput(idx=GamepadButton.A, gamepadIdx=ControllerIndex.Device1)]
            )
        ),
        "firstMenuOption" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode._1)],
            )
        ),
        "secondMenuOption" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode._2)],
            )
        ),
        "thirdMenuOption" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode._3)],
            )
        )
    })


    init_player(players[0], ControlType.None, 0, 0xFFA0B0FF, firstPlayerSetName)
    init_player(players[1], ControlType.None, 1, 0xFFFFB0A0, secondPlayerSetName)
    init_player(players[2], ControlType.None, 2, 0xFFFFFFA0, "")
    init_player(players[3], ControlType.None, 3, 0xFFFFB0FF, "")
    load_level(0)
    clear_cell_score()
}


var game_state = GameState.Menu
var next_game_state = GameState.Menu
var time_to_next_game_state = 0.0


def clear_gameplay_objects() {
    clear(powerups)
    for (g in ghosts) {
        g.state = UnitState.None
    }
    for (e in explosions) {
        e.active = false
    }
    for (p in players) {
        p.score = 0
        p.control = ControlType.None
    }
}


def on_game_state_changed() {
    randomize_seed()

    if (game_state == GameState.PlayerVsAI) {
        clear_gameplay_objects()
        players[0].control = ControlType.Player
        activate_action_set(firstPlayerSetName)
        deactivate_action_set(secondPlayerSetName)
        players[1].control = ControlType.Ai
        players[2].control = ControlType.Ai
        players[3].control = ControlType.Ai
        load_level(0)
        for (p in players) {
            p.lives = 9999
        }
        clear_cell_score()
    } elif (game_state == GameState.PlayerVsPlayer) {
        clear_gameplay_objects()
        players[0].control = ControlType.Player
        players[1].control = ControlType.Player
        activate_action_set(firstPlayerSetName)
        activate_action_set(secondPlayerSetName)
        load_level(0)
        for (p in players) {
            p.lives = 3
        }
        clear_cell_score()
    } elif (game_state == GameState.AIvsAI) {
        clear_gameplay_objects()
        deactivate_action_set(firstPlayerSetName)
        deactivate_action_set(secondPlayerSetName)
        players[0].control = ControlType.Ai
        players[1].control = ControlType.Ai
        players[2].control = ControlType.Ai
        players[3].control = ControlType.Ai
        load_level(0)
        for (p in players) {
            p.lives = 9999
        }
        clear_cell_score()
    } elif (game_state == GameState.Scores) {
        deactivate_action_set(firstPlayerSetName)
        deactivate_action_set(secondPlayerSetName)
        next_game_state = GameState.Menu
        time_to_next_game_state = 10.0
    }
}


def update_game_state(dt : float) {
    if (next_game_state != game_state) {
        time_to_next_game_state -= dt
        if (time_to_next_game_state <= 0.0) {
            game_state = next_game_state
            time_to_next_game_state = 0.0
            on_game_state_changed()
        }
    }
}


def check_for_game_over() {
    if (time_to_next_game_state > 0.0) {
        return
    }

    var alivePlayers = 0
    var blocks = 0

    for (p in players) {
        if (p.lives > 0 && p.control != ControlType.None) {
            alivePlayers++
        }
    }

    for (y in range(LEVEL_HEIGHT)) {
        for (x in range(LEVEL_WIDTH)) {
            if (level[y][x] == SPRITE_DESTRUCTIBLE_BLOCK) {
                blocks++
            }
        }
    }

    if (alivePlayers <= 1 || blocks == 0) {
        set_volume(play_sound(sound_game_over), 0.) |> set_volume(1., 0.2) // smooth fade-in
        next_game_state = GameState.Scores
        time_to_next_game_state = 1.6
    }
}


var time_to_next_global_anim_frame = 0.0


def guaranteed_step_update(dt : float) {
    if (dt > 1.0 / 20.0) {// guard against too big dt
        guaranteed_step_update(dt * 0.5)
        guaranteed_step_update(dt * 0.5)
        return
    }

    update_game_state(dt)
    time_to_next_global_anim_frame -= dt
    var animFrameChanged = false
    if (time_to_next_global_anim_frame <= 0.0) {
        time_to_next_global_anim_frame += 0.08
        global_anim_frame = 1 - global_anim_frame
        global_incremental_anim_frame++
        animFrameChanged = true
    }

    if (is_action_just_pressed("back")) {
        if (game_state != GameState.Menu) {
            next_game_state = GameState.Menu
            time_to_next_game_state = 0.0
        }
    }

    if (game_state == GameState.Menu) {
        update_menu()
    } elif (game_state == GameState.PlayerVsAI || game_state == GameState.PlayerVsPlayer || game_state == GameState.AIvsAI) {
        if (animFrameChanged) {
            update_cell_score()
        }
        for (p in players) {
            update_player_state(p, dt)
            update_player_controls(p)
            update_player_move(p, dt)
        }
        for (g in ghosts) {
            update_ghost_state(g, dt)
            update_ghost_move(g, dt)
        }
        for (e in explosions) {
            update_explosion(e, dt)
        }
        check_for_game_over()
        time_after_explosion_sound += dt
    }
}



[export]
def on_update() {
    guaranteed_step_update(get_delta_time())
    render()
    update_texture(canvas.bitmap, canvas.textureId)
}

