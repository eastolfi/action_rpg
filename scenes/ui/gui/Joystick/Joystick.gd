extends Control

class_name Joystick

# If the joystick is receiving inputs.
var is_working := false

# The joystick output.
var output := Vector2.ZERO

# Current input finger. For each finger touching the screen, the index increments by 1
var _current_index = -1

# Flag to control if we are within a valid event (finger index, inside the boundaries, etc)
var _is_valid_event = false

# FIXED: The joystick doesn't move.
# DYNAMIC: Every time the joystick area is pressed, the joystick position is set on the touched position.
# FOLLOWING: If the finger moves outside the joystick background, the joystick follows it.
enum Joystick_mode {FIXED, DYNAMIC, FOLLOWING}

export(Joystick_mode) var joystick_mode := Joystick_mode.FIXED

# REAL: return a vector with a lenght beetween 0 (deadzone) and 1; useful for implementing different velocity or acceleration.
# NORMALIZED: return a normalized vector.
enum Vector_mode {REAL, NORMALIZED}

export(Vector_mode) var vector_mode := Vector_mode.REAL

# The color of the button when the joystick is in use.
export(Color) var _pressed_color := Color.gray

# The number of directions, e.g. a D-pad is joystick with 4 directions, keep 0 for a free joystick.
export(int, 0, 12) var directions := 0

# It changes the angle of simmetry of the directions.
export(int, -180, 180) var simmetry_angle := 90

#If the handle is inside this range, in proportion to the background size, the output is zero.
export(float, 0, 0.5) var dead_zone := 0.2;

#The max distance the handle can reach, in proportion to the background size.
export(float, 0.5, 2) var clamp_zone := 1;

onready var _background := $Background
onready var _handle := $Background/Handle
onready var _original_color : Color = _handle.modulate
onready var _original_position : Vector2 = _background.rect_position

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and _is_valid_index(event.index) and \
    (joystick_mode == Joystick_mode.DYNAMIC or joystick_mode == Joystick_mode.FOLLOWING):
        if event.is_pressed() and _is_within_rect(event.position):
            var new_pos = event.position - _background.rect_size / 2
            _background.rect_position = new_pos
            _set_input_index(event.index)
            _is_valid_event = true
        else:
            _background.rect_position = _original_position
            _reset_input_index()
            _is_valid_event = false

    _check_background_input(event)

func _check_background_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and _is_valid_index(event.index):
        if event.pressed and _is_within_background_rect(event.position):
            _handle.modulate = _pressed_color
            _is_valid_event = true
            _set_input_index(event.index)
        elif not event.pressed:
            is_working = false
            output = Vector2.ZERO
            _set_handle_center_position(_background.rect_size / 2)
            _handle.modulate = _original_color
            _reset_input_index()
            _is_valid_event = false
    
    if event is InputEventScreenDrag and _is_valid_index(event.index) and _is_valid_event:
        var event_position = event.position - _background.rect_global_position
        var vector : Vector2 = event_position - _background.rect_size / 2
        var dead_size = dead_zone * _background.rect_size.x / 2
        if vector.length() < dead_size:
            is_working = false
            output = Vector2.ZERO
            _set_handle_center_position(_background.rect_size / 2)
            return
        _update_output(vector)
        is_working = true
        if joystick_mode == Joystick_mode.FOLLOWING:
            _following(vector)

func _set_handle_center_position(new_position : Vector2) -> void:
    _handle.rect_position = new_position - _handle.rect_size / 2

func _update_output(vector: Vector2) -> void:
    var dead_size = dead_zone * _background.rect_size.x / 2
    var clamp_size = clamp_zone * _background.rect_size.x / 2
    vector = vector.clamped(clamp_size)
    if directions > 0:
        vector = _directional_vector(vector, directions, deg2rad(simmetry_angle))
    output = vector.normalized()
    if vector_mode == Vector_mode.REAL and vector.length() < clamp_size:
        output *= (vector.length() - dead_size) / (clamp_size - dead_size)
    _set_handle_center_position(output * clamp_size + _background.rect_size / 2)

func _following(vector: Vector2) -> void:
    var clamp_size = clamp_zone * _background.rect_size.x / 2
    if vector.length() > clamp_size:
        var radius = vector.normalized() * clamp_size
        var delta = vector - radius
        var new_pos = _background.rect_position + delta
        new_pos.x = clamp(new_pos.x, -_background.rect_size.x / 2, rect_size.x - _background.rect_size.x / 2)
        new_pos.y = clamp(new_pos.y, -_background.rect_size.y / 2, rect_size.y - _background.rect_size.y / 2)
        _background.rect_position = new_pos

func _directional_vector(vector: Vector2, n_directions: int, simmetry_angle := PI/2) -> Vector2:
    var angle := (vector.angle() + simmetry_angle) / (PI / n_directions)
    angle = floor(angle) if angle >= 0 else ceil(angle)
    if abs(angle) as int % 2 == 1:
        angle = angle + 1 if angle >= 0 else angle - 1
    angle *= PI / n_directions
    angle -= simmetry_angle
    return Vector2(cos(angle), sin(angle)) * vector.length()

func _is_within_rect(position: Vector2) -> bool:
    # Improve to handle the circle instead a square
    var is_within_x = position.x > rect_position.x and position.x < (rect_position.x + rect_size.x)
    var is_within_y = position.y > rect_position.y and position.y < (rect_position.y + rect_size.y)

    if is_within_x and is_within_y:
        return true

    return false

func _is_within_background_rect(_position: Vector2) -> bool:
    # Improve to handle the circle instead a square
    var is_within_x: bool = _position.x >= _background.rect_global_position.x and _position.x <= (_background.rect_global_position.x + _background.rect_size.x)
    var is_within_y: bool = _position.y >= _background.rect_global_position.y and _position.y <= (_background.rect_global_position.y + _background.rect_size.y)

    if is_within_x and is_within_y:
        return true

    return false

func _set_input_index(index: int):
    _current_index = index

func _reset_input_index():
    _current_index = -1

func _is_valid_index(index: int) -> bool:
    return _current_index == -1 or _current_index == index
