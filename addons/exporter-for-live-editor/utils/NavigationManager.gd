extends Node

const RegExp = preload("./RegExp.gd")

signal transition_in_completed
signal transition_out_completed

var _is_path_regex := RegExp.compile("^(?<prefix>user:\\/\\/|res:\\/\\/|\\.*?\\/+)(?<url>.*)")

# Stack of screens. Screens are pushed to the head, so index 0 represents the
# latest screen
var _screens_stack := []

# Used for transitions. We will probably replace this with an animation player
# or a shader
var _tween := Tween.new()

# Set this to load screens in a specific container. Defaults to tree root
var root_container: Node

# switch this off to remove transitions
var use_transitions := true

var current_url := ScreenUrl.new(_is_path_regex, "/")

# Can contain shortcuts to scenes. Match a string with a scene
# @type Dictionary[String, PackedScene Path]
export var matches := {}


func _ready() -> void:
	add_child(_tween)
	get_tree().set_auto_accept_quit(false)
	_on_ready_listen_to_browser_changes()


# Connects links in a rich text so they open scenes
func connect_rich_text_links(rich_text: RichTextLabel) -> void:
	rich_text.connect("meta_clicked", self, "open_url")


# Loads a scene and adds it to the stack.
# a url is of the form res://scene.tscn, user://scene.tscn, //scene.tscn,  or 
# /scene.tscn ("res:" will be appended automatically)
func open_url(data: String) -> void:
	data = matches[data] if (data and data in matches) else data
	if not data:
		push_warning("no url provided")
		return
	var url = ScreenUrl.new(_is_path_regex, data)
	if not url.is_valid:
		return
	var scene: PackedScene = load(url.href)
	var screen: CanvasItem = scene.instance()
	current_url = url
	_push_screen(screen)
	_push_javascript_state(url.href)


# Pushes a screen on top of the stack and transitions it in
func _push_screen(screen: Node) -> void:
	var previous_node := _get_topmost_child()
	_screens_stack.push_front(screen)
	_add_child_to_root_container(screen)
	_transition(screen)
	if previous_node:
		yield(self, "transition_in_completed")
		remove_child_from_root_container(previous_node)


# Transitions a screen in. This is there as a placeholder, we probably want 
# something prettier.
# Anything can go in there, as long as "transition_in_completed" or 
# "transition_out_completed" are emitted at the end
# 'Screen' is assumed to be a CanvasItem, this method will have issues otherwise 
# turn transitions off by setting `use_transitions` to false to skip transitions
func _transition(screen: CanvasItem, direction_in := true) -> void:
	var signal_name := "transition_in_completed" if direction_in else "transition_out_completed"
	if not use_transitions:
		yield(get_tree(), "idle_frame")
		emit_signal(signal_name)
		return
	var start = get_viewport().size.x
	var end = 0.0
	var property = "position:x" if screen is Node2D else (
		"rect_position:x" if screen is Control else ""
	)
	if not property:
		return
	var trans := Tween.TRANS_ELASTIC
	var eas := Tween.EASE_OUT
	var duration := 0.5
	if direction_in:
		_tween.interpolate_property(screen, property, start, end, duration, trans, eas)
	else:
		_tween.interpolate_property(screen, property, end, start, duration, trans, eas)
	_tween.start()
	yield(_tween, "tween_all_completed")
	emit_signal(signal_name)


# If there are no more screens to pops, exits the application,
# otherwise, pops the last screen.
# Intended to be used in mobile environments  
func back_or_quit() -> void:
	if _screens_stack.size() > 1:
		back()
	else:
		get_tree().quit()


# Pops the last screen from the stack
func back() -> void:
	if _screens_stack.size() < 1:
		push_warning("No screen to pop")
		return
	
	var previous_node: Node = _screens_stack.pop_front()
	
	var next_in_queue := _get_topmost_child()
	if next_in_queue:
		_add_child_to_root_container(next_in_queue)
		current_url = ScreenUrl.new(_is_path_regex, next_in_queue.filename)
	else:
		current_url = ScreenUrl.new(_is_path_regex, "res://")

	_transition(previous_node, false)
	yield(self, "transition_out_completed")
	remove_child_from_root_container(previous_node)
	previous_node.queue_free()
	

# Returns the root container. If no root container is explicitely set, returns
# the tree root
func get_root_container() -> Node:
	if root_container:
		return root_container
	return get_tree().root


# Appends a new child to the root container in deferred mode
func _add_child_to_root_container(child: Node) -> void:
	get_root_container().call_deferred("add_child", child)


# Removes a child from the root container in deferred mode
func remove_child_from_root_container(child: Node) -> void:
	get_root_container().call_deferred("remove_child", child)



# Appends a new child to the root container in deferred mode
func _get_topmost_child() -> Node:
	if _screens_stack.size() > 0:
		return _screens_stack[0] as Node
	return null


# Handle back requests
func _notification(what: int) -> void:
	if \
		what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST \
		or \
		what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST \
	:
		back_or_quit()


################################################################################
#
# UNTESTED, EXPERIMENTAL JS SUPPORT
# 

var _js_available := OS.has_feature('JavaScript')
var _js_window := JavaScript.get_interface("window") if _js_available else null
var _js_history := JavaScript.get_interface("history") if _js_available else null
var _js_popstate_listener_ref := JavaScript.create_callback(self, "_js_popstate_listener") if _js_available else null

# Changes the browser's URL
func _push_javascript_state(url: String) -> void:
	if not _js_available:
		return
	_js_history.pushState(url, '', url)
	#JavaScript.eval("history && 'pushState' in history && history.pushState(\"%s\", '', \"%s\")"%[url], true)


# Handles user pressing back button in browser
func _js_popstate_listener(args) -> void:
	var event = args[0]
	var url = event.state
	prints("js asks to go back to:", url)
	back()


# Registers the js listener
func _on_ready_listen_to_browser_changes() -> void:
	if not _js_available:
		return
	_js_window.addEventListener('popstate', _js_popstate_listener_ref)


# If a url is set on the page, uses that
func _load_current_browser_url() -> void:
	if not _js_available:
		return
	var state = _js_history.state
	if state:
		var url = state.url
		open_url(url)
	if _js_window.location.pathname:
		open_url(_js_window.location.pathname)


class ScreenUrl:
	
	var path: String
	var protocol: String
	var href: String setget , _to_string
	var is_valid := true
	
	
	func _init(_is_path_regex: RegEx, data: String) -> void:
		var regex_result := _is_path_regex.search(data)
		protocol = regex_result.get_string("prefix")
		path = regex_result.get_string("url")
		if regex_result:
			if protocol == "//" or protocol == "/":
				protocol = "res://" 
		else:
			is_valid = false
	
	func _to_string() -> String:
		return protocol + path