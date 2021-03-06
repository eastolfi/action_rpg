#### SPLIT THIS CLASS INTO SMALLER ONES AND PRELOAD THEM AT START ####

extends Node

signal player_stats_updated(stats)

const FadeIn = preload("res://scenes/effects/FadeIn.tscn")
const avalaible_langs = [Constants.LANGUAGES.SPANISH, Constants.LANGUAGES.ENGLISH]

var player_info = {
    name = "Player",
    net_id = Constants.HOST_PLAYER_ID,
    actor_path = "res://scenes/characters/Player.tscn",
    char_color = Color(1, 1, 1)
}
var player_stats = {
    health = 4,
    max_health = 4
}

func _ready():
    _load_user_language()

func change_language(locale: String):
    if locale in avalaible_langs:
        TranslationServer.set_locale(locale)
        Settings.save_single_setting(Constants.SETTINGS_SECTIONS.GENERAL, "language", locale)

func get_user_language() -> String:
    var lang: String = Settings.get_setting(Constants.SETTINGS_SECTIONS.GENERAL, "language")
    
    if lang != "":
        return lang
    else:
        return TranslationServer.get_locale()

func _load_user_language():
    var lang: String = get_user_language()
    if lang and lang.length() > 0:
        change_language(lang)

func change_scene(path: String, options: Dictionary = {}, params: Dictionary = {}):
    if options.has("with_transition") and options.with_transition == true:
        var fade_in = FadeIn.instance()
        fade_in.connect("fade_ended", self, "_on_FadeIn_fade_ended", [path, params])
        get_tree().current_scene.add_child(fade_in)
        fade_in.fade_in()
    else:
        call_deferred("_change_scene_deferred", path, params)

func _change_scene_deferred(path: String, _params: Dictionary):
    var next_scene = load(path)
    var scene = next_scene.instance()
    if scene:
        get_tree()._change_scene(scene)
        
        if _params.size() > 0 and scene.has_method("initialize"):
            scene.initialize(_params)

func update_player_stats(new_stats):
    for stat in new_stats:
        player_stats[stat] = new_stats[stat]
    
    emit_signal("player_stats_updated", new_stats)

func _on_FadeIn_fade_ended(path: String, scene_params: Dictionary = {}):
    change_scene(path, {}, scene_params)


### SAVE GAME ###

func _notification(event):
    if event == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
        print("quit")
#        print(get_tree().current_scene.get_groups())
        save_game_state()
    elif event == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST:
        print("back")

func get_save_information() -> Dictionary:
    var save_data := {}
    var nodes_to_save = get_tree().get_nodes_in_group("Persist")
    for node in nodes_to_save:
        if node.filename.empty():
            print("persistent node '%s' is not an instanced scene, skipped" % node.name)
            continue

        if not node.has_method("save"):
            print("persistent node '%s' is missing a save() function, skipped" % node.name)
            continue

        var node_data = node.call("save")
        save_data[node.get_path()] = node_data
    
    return save_data

func persist_save_data(save_data: Dictionary):
    if save_data.keys().size() > 0:
        var save_game = File.new()
        save_game.open(Constants.SAVE_FILE, File.WRITE)
        
        save_game.store_line(to_json(save_data))
        
        save_game.close()

func save_game_state():
    var save_data = get_save_information()
    persist_save_data(save_data)

func has_saved_game() -> bool:
    var save_game := File.new()
    return save_game.file_exists(Constants.SAVE_FILE)

func read_game_state() -> Dictionary:
    var save_game = File.new()
    if not save_game.file_exists(Constants.SAVE_FILE):
        # Error! We don't have a save to load.
        return {}

    save_game.open(Constants.SAVE_FILE, File.READ)
    var save_data: Dictionary = parse_json(save_game.get_as_text())
    save_game.close()

    return save_data
    

func restore_game_state(save_data: Dictionary):
    for node_path in save_data.keys():
        var node = get_node(node_path)
        
        var node_data = save_data[node_path]
        for attribute in node_data:
            var value = node_data[attribute]
            if attribute == "pos_x":
                (node as Node2D).position.x = value
            if attribute == "pos_y":
                (node as Node2D).position.y = value
            
            if not attribute in ["pos_x", "pos_y", "filename"]:
                node[attribute] = value

func load_game_state():
    var save_data = read_game_state()
    restore_game_state(save_data)
