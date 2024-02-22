extends Node2D
## A container of all glyphs that are currently selected

var is_holding_glyphs = false
var is_selecting_glyphs = false

var editing_enabled = false


func _ready():
	Event_Bus.glyph_editing_requested.connect(func(): attempt_to_set_editing_mode(true))
	Event_Bus.stop_glyph_editing.connect(func(): attempt_to_set_editing_mode(false))
	Event_Bus.glyph_type_saving_attemped.connect(attempt_to_save_glyph_type)
	Event_Bus.request_to_be_held.connect(overwrite_hold)
	#Event_Bus.request_to_be_held.connect(func(node): overwrite_hold(node, false))

# Track the mouse position
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		update_mouse_position()

func update_mouse_position():
	if not is_selecting_glyphs:
		set_position(get_global_mouse_position())


#func set_by_name(glyph_name):
	#remove_all()
	#if glyph_name in Glyph_List.glyphs:
		#var glyph_type = Glyph_List.glyphs[glyph_name]
		#var node = glyph_instance_scene.instantiate()
		#node.init(glyph_type)
		#add_child(node)


func signal_stop_holding_child(child):
	var lambda_self = self
	Undo_Redo.add_do_method(func stop_holding_child():
		if lambda_self.get_child_count() == 0:
			lambda_self.signal_stop_holding()
		)
	Undo_Redo.add_do_method(child.stop_hold)
	Undo_Redo.add_undo_method(lambda_self.signal_start_holding)
	Undo_Redo.add_undo_method(child.start_hold)

func signal_start_holding_child(child):
	var lambda_self = self
	Undo_Redo.add_do_method(lambda_self.signal_start_holding)
	Undo_Redo.add_do_method(child.start_hold)
	Undo_Redo.add_undo_method(func undo_start_holding_child():
		if lambda_self.get_child_count() == 0:
			lambda_self.signal_stop_holding()
		)
	Undo_Redo.add_undo_method(child.stop_hold)

func signal_stop_holding():
	is_holding_glyphs = false
	Event_Bus.stopped_holding_glyphs.emit()

func signal_start_holding():
	is_holding_glyphs = true
	Event_Bus.started_holding_glyphs.emit(self.get_children())

func remove_child_without_undo_redo(child, delete_after_removing = true):
	assert(child in get_children())
	remove_child(child)
	if delete_after_removing:
		child.free()

# Remove all children (without having pointers to them)
func remove_all_without_undo_redo(delete_after_removing = true):
	for child in get_children():
		remove_child_without_undo_redo(child, delete_after_removing)

func delete_child_without_undo_redo(child):
	remove_child_without_undo_redo(child, true)

func delete_all_without_undo_redo():
	remove_all_without_undo_redo(true)


func remove_all(delete_after_removing = true):
	# TODO: undoing deletion of selected glyphs doesn't work
	if get_child_count() > 0:
		var restore_all_children_function = get_restore_all_children_function()
		var lambda_self = self
		for child in get_children():
			var child_name = child.name
			Undo_Redo.add_do_method(func():
				# TODO: is this future-proof?
				# Will there eventually be other places that the glyph could have
				# been reparented to that aren't contained in the Canvas node?
				lambda_self.remove_node_from_parent_by_name_without_undo_redo(child_name, delete_after_removing))
		Undo_Redo.add_undo_method(deselect_all)
		Undo_Redo.add_undo_method(restore_all_children_function)
		if is_holding_glyphs:
			Undo_Redo.add_do_property(self, "is_holding_glyphs", false)
			Undo_Redo.add_undo_property(self, "is_holding_glyphs", true)
			Undo_Redo.add_do_method(func(): Event_Bus.stopped_holding_glyphs.emit())
			Undo_Redo.add_undo_method(func(): Event_Bus.started_holding_glyphs.emit(lambda_self.get_children()))
		if is_selecting_glyphs:
			Undo_Redo.add_do_property(self, "is_selecting_glyphs", false)
			Undo_Redo.add_undo_property(self, "is_selecting_glyphs", true)
			# Also restore this node's position so the selection appears in the right place on undo.
			var lambda_position = Vector2(position)
			Undo_Redo.add_undo_property(self, "position", lambda_position)

func delete_all():
	remove_all(true)


func place_child(child, new_parent, actually_reparent = true):
	var parent_after_placing = child.get_parent_after_placing()
	var keep_global_transform = child.get_keep_global_transform()
	if parent_after_placing != null:
		new_parent = parent_after_placing
	change_node_parent_by_name(child, new_parent, actually_reparent, keep_global_transform)
	signal_stop_holding_child(child)

func place_all(new_parent):
	Undo_Redo.add_undo_method(deselect_all)
	for child in get_children():
		place_child(child, new_parent, true)
		var keep_selected = false
		if child.has_method("get_keep_selected"):
			keep_selected = child.get_keep_selected()
		if keep_selected:
			# TODO: using call_deferred here to get around the "delay" in Undo_Redo is not great.
			# It could be avoided, but it looks like several other functions would need reworking.
			select_instance.call_deferred(child)


func get_restore_all_children_function():
	var restore_function_list = []
	for child in get_children():
		restore_function_list.append(get_restore_child_function(child))
	var restore_all_children_function = func restore_all_children_function():
		for restore_function in restore_function_list:
			restore_function.call()
	return restore_all_children_function

func get_restore_child_function(child, make_self_parent = false):
	var lambda_self = self
	var restore_func = child.get_restore_function()
	var old_position = Vector2(position)
	
	var restore_child_function = func restore_child_function():
		#var instance = lambda_glyph_instance_scene.instantiate()
		#instance.restore_from_dict(restore_dict)
		var instance = restore_func.call()
		if make_self_parent:
			lambda_self.add_child(instance)
			#instance.set_real_parent(lambda_self)
		else:
			instance.set_position(old_position)
			assert(instance.real_parent != null)
			instance.real_parent.add_child(instance)
	
	return restore_child_function


func restore_child(child, make_self_parent = false):
	Undo_Redo.add_do_method(get_restore_child_function(child, make_self_parent))
	var lambda_self = self
	Undo_Redo.add_undo_method(func(): lambda_self.remove_child_by_name_without_undo_redo(child.name))

func remove_node_from_parent_by_name_without_undo_redo(node_name, delete_after_removing = true):
	get_parent().remove_descendant_by_name_without_undo_redo(node_name, delete_after_removing)

func remove_child_by_name_without_undo_redo(node_name, delete_after_removing = true):
	var node_path = NodePath(node_name)
	#Undo_Redo.add_do_method(func(): lambda_self.get_node(node_path).reparent(new_parent)) # Doesn't preserve position on redo
	var node = get_node(node_path)
	assert(node != null)
	
	remove_child_without_undo_redo(node, delete_after_removing)


func overwrite_hold(new_instance, make_self_parent = true):
	Undo_Redo.add_do_method(deselect_all)
	Undo_Redo.add_undo_method(deselect_all)
	if is_holding_glyphs:
		delete_all()
	if new_instance.get_keep_global_transform():
		change_node_parent_by_name(new_instance, self, true, true)
	else:
		restore_child(new_instance, make_self_parent)
		#(func(): new_instance.free()).call_deferred() # TODO: should this be called always?
	signal_start_holding_child(new_instance)


func change_node_parent_by_name(node, new_parent, actually_reparent = true, keep_global_transform = false):
	# If not actually_reparent, the child's real_parent will be set but it won't physically be reparented.
	var lambda_self = self
	var glyph_name = node.name
	var node_path = NodePath(glyph_name)
	var old_parent = node.get_parent()
	var old_position = Vector2(node.get_position())
	var old_real_parent = node.get_real_parent()
	
	var new_position
	if keep_global_transform:
		new_position = Vector2()
	else:
		new_position = new_parent.to_local(node.global_position)
	var do_method = func do_method():
		var do_node = old_parent.get_node(node_path)
		if new_parent == lambda_self:
			do_node.reparent(new_parent, keep_global_transform)
			if keep_global_transform:
				do_node.position = Vector2()
			lambda_self.update_mouse_position()
		else:
			if actually_reparent:
				if not keep_global_transform:
					do_node.position = new_position
				do_node.permanent_reparent(new_parent, keep_global_transform)
			else:
				do_node.set_real_parent(new_parent)
	Undo_Redo.add_do_method(do_method)
	
	var undo_method = func undo_method():
		var current_parent = new_parent
		if not actually_reparent:
			current_parent = lambda_self
		var undo_node = current_parent.get_node(node_path)
		if old_real_parent != null:
			undo_node.set_real_parent(old_real_parent)
		undo_node.reparent(old_parent)
		if old_parent == lambda_self:
			lambda_self.update_mouse_position()
		if old_position != null:
			undo_node.set_position(old_position)
	Undo_Redo.add_undo_method(undo_method)


#region Glyph selection methods
func deselect_instance(child):
	var real_parent = child.get_real_parent()
	if real_parent != null:
		child.reparent(real_parent)
		child.set_is_selected(false)
	else:
		delete_child_without_undo_redo(child)
	if get_child_count() == 0:
		Event_Bus.stopped_selecting_glyphs.emit(get_children())
		is_selecting_glyphs = false
	else:
		Event_Bus.started_selecting_glyphs.emit(get_children())
		# TODO: maybe use a separate signal instead of reusing this even when going from 2 to 1 children

func select_instance(child):
	child.reparent(self)
	child.set_is_selected(true)
	Event_Bus.started_selecting_glyphs.emit(get_children())
	is_selecting_glyphs = true

func deselect_all():
	if not is_selecting_glyphs: return
	attempt_to_set_editing_mode(false)
	is_selecting_glyphs = false
	for child in get_children():
		deselect_instance(child)

func attempt_to_overwrite_selection(new_instance):
	if is_holding_glyphs: return false
	if is_selecting_glyphs:
		deselect_all()
	select_instance(new_instance)
	is_selecting_glyphs = true
	Event_Bus.started_selecting_glyphs.emit(get_children())
	return true

func attempt_to_select_extra_instance(new_instance):
	if is_holding_glyphs: return false
	if new_instance.get_is_selected():
		deselect_instance(new_instance)
	else:
		select_instance(new_instance)
	return true
#endregion


func attempt_to_set_editing_mode(enabled):
	if editing_enabled == enabled:
		return
	if enabled and not can_start_editing_mode():
		return
	editing_enabled = enabled
	for child in get_children():
		child.set_editing_mode(editing_enabled)
	if editing_enabled:
		Event_Bus.glyph_editing_started.emit()
	else:
		Event_Bus.glyph_editing_stopped.emit()

func can_start_editing_mode():
	if ((Settings_Handler.get_setting("glyph editing", "allow_editing_multiple_glyphs") \
		and get_child_count() > 0) \
		or get_child_count() == 1) \
		and not is_holding_glyphs:
		return true
	return false

func signal_ability_to_start_editing_mode():
	if can_start_editing_mode():
		Event_Bus.became_able_to_start_glyph_editing.emit()
	else:
		Event_Bus.became_unable_to_start_glyph_editing.emit()

func _on_child_order_changed():
	signal_ability_to_start_editing_mode.call_deferred()

func _unhandled_key_input(event):
	if event is InputEventKey:
		if event.is_action_pressed("ui_accept"):
			attempt_to_set_editing_mode(true)


#region Save glyph types
func attempt_to_save_glyph_type():
	if get_child_count() != 1:
		return
	var instance = get_children()[0]
	instance.overwrite_own_glyph_type()
#endregion
