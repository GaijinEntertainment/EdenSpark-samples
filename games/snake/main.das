require engine.core

let COLS = 30
let ROWS = 20
let TILE_SIZE = int2(100)

struct Snake {
    pos, vel : int2
    len : int
    body : int[COLS][ROWS]
}

struct Food {
    pos : int2
}

var camera : NodeId
var canvas : NodeId
var fieldNode : NodeId
var gameOverNode : NodeId
var fieldItems : NodeId[COLS][ROWS]

var snake : Snake
var food : Food
var nextStep : float = 0.

def register_tile(node : NodeId, x, y : int) : NodeId {
    fieldItems[x][y] = node
    return node
}

def init_game() {
    gameOverNode.isActive = false
    snake = Snake(pos = int2(COLS / 2, ROWS / 2), vel = int2(1, 0), len = 2)
    init_food()
}

def init_food() {
    food = Food(pos = int2(random_range(0, COLS), random_range(0, ROWS)))
}

[export]
def on_initialize() {
    camera = create_node(NodeData(name = "camera")).add_component(new Camera(fovAxis = FovAxis.Horizontal, fov = TO_RAD * 90f)).nodeId

    let spacing = 4
    let fieldWidth = (TILE_SIZE.x + spacing) * COLS - spacing
    let fieldHeight = (TILE_SIZE.y + spacing) * ROWS - spacing

    canvas = canvas(float2(fieldWidth, fieldHeight) + float2(TILE_SIZE))

    fieldNode = hbox([for (x in 0..COLS);
        vbox([for (y in 0..ROWS); panel(TILE_SIZE).register_tile(x, y) ]).set_spacing(spacing)
                                                                         .set_alignment(LayoutAlignment.MiddleCenter)
                                                                         .set_frame_size(float2(TILE_SIZE.x, fieldHeight))
    ]) \
      .set_spacing(spacing) \
      .set_alignment(LayoutAlignment.MiddleCenter) \
      .set_frame_size(float2(fieldWidth, fieldHeight)) \
      .add_anchor(MIDDLE_CENTER_ANCHOR)

    gameOverNode = text("Game over.\nPress Enter/Select to restart").set_frame_size(float2(fieldWidth, fieldHeight)) \
        .set_text_font_size(64).set_text_color(BLUE_COLOR).add_anchor(MIDDLE_CENTER_ANCHOR)
    gameOverNode.isActive = false

    canvas.add_child(fieldNode)
    canvas.add_child(gameOverNode)

    add_and_activate_action_set("player", {
        "move" => Action(
            joystickActions = JoystickAction(
                keyboardDPads = [KeyboardDPadInput(leftIdx=KeyCode.Left, rightIdx=KeyCode.Right, upIdx=KeyCode.Up, downIdx=KeyCode.Down)],
                gamepadDPads = [GamepadDPadInput(leftIdx=GamepadButton.Left, rightIdx=GamepadButton.Right, upIdx=GamepadButton.Up, downIdx=GamepadButton.Down)]
            )
        ),
        "reset" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Return)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Back)]
            )
        )
    })

    init_game()
}

[export]
def on_update() {
    if (gameOverNode.isActive) {
        if (is_action_just_released("reset")) {
            init_game()
        }
        return
    }
    return if (get_time() < nextStep)
    nextStep = get_time() + (1. / 8.)

    let inputDir = get_action_vector2("move")
    if (inputDir.x != 0f && snake.vel.x == 0) {
        snake.vel = int2(inputDir.x > 0. ? 1 : -1, 0)
    } elif (inputDir.y != 0f && snake.vel.y == 0) {
        snake.vel = int2(0, inputDir.y < 0. ? 1 : -1)
    }

    snake.pos += snake.vel

    if (snake.pos.x < 0 || snake.pos.x >= COLS || snake.pos.y < 0 || snake.pos.y >= ROWS || snake.body[snake.pos.x][snake.pos.y] > 0) {
        gameOverNode.isActive = true
        return
    }
    if (food.pos == snake.pos) {
        ++snake.len
        init_food()
    }
    snake.body[snake.pos.x][snake.pos.y] = snake.len
    for (x in 0..COLS) {
        for (y in (0..ROWS)) {
            snake.body[x][y] = max(0, snake.body[x][y] - 1)
            set_image_color(fieldItems[x][y], snake.body[x][y] > 0 ? BLACK_COLOR : WHITE_COLOR)
        }
    }
    set_image_color(fieldItems[food.pos.x][food.pos.y], RED_COLOR)
}
