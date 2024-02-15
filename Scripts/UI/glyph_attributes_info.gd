extends GridContainer

var rows = []
var glyph_instance


func _ready():
	Event_Bus.started_holding_glyphs.connect(create_attribute_list_from_children)
	Event_Bus.stopped_holding_glyphs.connect(create_attribute_list_from_children)
	Event_Bus.started_selecting_glyphs.connect(create_attribute_list_from_children)
	Event_Bus.stopped_selecting_glyphs.connect(create_attribute_list_from_children)


func create_attribute_list_from_children(children = null):
	destroy_attribute_list()
	if children == null or len(children) != 1:
		return
	var new_instance = children[0]
	# TODO: Find some way to check if the received child is a Glyph_Instance or some other not-yet-implemented class (like a rel line)
	#if not new_instance.is_class("Glyph_Instance"): return
	glyph_instance = new_instance
	create_attribute_list()

func create_attribute_list():
	var attributes = glyph_instance.get_instance_attributes()
	for attribute_name in attributes:
		add_simple_attribute_row(attribute_name)

func destroy_attribute_list():
	for row in rows:
		row.free_children()
		row.free()
	rows = []


func add_simple_attribute_row(attribute_name):
	var get_new_value = func get_new_value():
		return self.glyph_instance.get_instance_attribute(attribute_name)
	var on_change = func on_change(new_text):
		self.glyph_instance.set_instance_attribute(attribute_name, new_text)
		return true
	var new_row = Grid_Row_With_Line_Edit.new(self, attribute_name, get_new_value, on_change)
	
	new_row.add_to_grid(self)
	new_row.update_text()
	rows.append(new_row)


#func _on_container_glyph_instance_set(new_instance):
	#glyph_instance = new_instance
	#create_attribute_list()
	#for row in rows:
		#row.update_text()