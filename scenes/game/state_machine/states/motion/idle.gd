extends Motion

class_name Idle

var animation: AnimationTree
var animation_state: AnimationNodeStateMachinePlayback

func enter():
    if owner.has_node("AnimationTree"):
        animation = owner.get_node("AnimationTree")
        animation_state = animation.get("parameters/playback")
        animation_state.travel("idle")

func handle_physics_process(delta):
    motion = motion.move_toward(Vector2.ZERO, FRICTION * delta)

    pick_random_state()
