extends GridContainer

var rows = []
var glyph_instance


func update(new_instance):
	create_attribute_list_from_instance(new_instance)


func create_attribute_list_from_instance(new_instance):
	destroy_attribute_list()
	
	# TODO: Find some way to check if the received child is a Glyph_Instance or some other not-yet-implemented class (like a rel line)
	#if not new_instance.is_class("Glyph_Instance"): return
	glyph_instance = new_instance
	create_attribute_list()

func create_attribute_list():
	var bp_list = glyph_instance.get_binding_points()
	for bp in bp_list:
		add_simple_attribute_row(bp, "name")

func destroy_attribute_list():
	for row in rows:
		row.free_children()
		row.free()
	rows = []


func add_simple_attribute_row(bp, attribute_name):
	var get_new_value = func get_new_value():
		#return bp.get_instance_attribute(attribute_name)
		return bp.dict[attribute_name]
	#var on_change = func on_change(new_text):
		#bp.set_instance_attribute(attribute_name, new_text)
		#return true
	#var new_row = Grid_Row_With_Line_Edit.new(self, attribute_name, get_new_value, on_change)
	var new_row = Grid_Row_With_Line_Edit.new(self, attribute_name, get_new_value)
	
	new_row.add_to_grid(self)
	new_row.update_text()
	rows.append(new_row)


#func _on_container_glyph_instance_set(new_instance):
	#glyph_instance = new_instance
	#create_attribute_list()
	#for row in rows:
		#row.update_text()
