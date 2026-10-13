## The master list of all registered gameplay tags in the project.
##
## Stored as a serialized Array of StringNames for optimized memory 
## and comparison. Auto-formats and validates tags upon entry.
##
## @meta_addon: GodotGAS
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@tool
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name GameplayTagRegistry extends Resource

## The master list of all registered tags in the project.
## Stored as an Array of StringNames for optimized memory and comparison.
@export var tags: Array[StringName] = []


#region Tag Management
## Automatically scans the existing tag array and injects any missing parent hierarchy tags.
## e.g. If "A.B.C" exists but "A.B" does not, it adds "A.B" to prevent orphans.
func validate_tag_hierarchy() -> void:
	var changed: bool = false
	var existing_set: Dictionary = {}
	var new_tags: Array[StringName] = []
	
	for t in tags:
		existing_set[t] = true
		
	for t in tags:
		var t_str = String(t)
		var parts = t_str.split(".")
		var current_path = ""
		
		for part in parts:
			current_path = part if current_path.is_empty() else current_path + "." + part
			var step_name = StringName(current_path)
			
			if not existing_set.has(step_name):
				existing_set[step_name] = true
				new_tags.append(step_name)
				changed = true
				
	if changed:
		tags.append_array(new_tags)
		tags.sort_custom(func(a, b): return String(a) < String(b))
		emit_changed()
		GameplayTagGenerator.generate_tags_file(tags)
		
		if not resource_path.is_empty():
			ResourceSaver.save(self, resource_path)
			
		print("GodotGAS: Validated tag hierarchy and safely injected %d missing parent tags." % new_tags.size())


## Attempts to add a new tag. Auto-formats casing and registers all explicit parent levels.
## Returns the formatted tag on success, or a string starting with "Error:" on failure.
func add_tag(tag_string: String) -> String:
	var clean_tag = tag_string.strip_edges()
	
	if clean_tag.is_empty():
		return "Error: Cannot add an empty tag."
		
	# 1. Auto-formatting (e.g., test.test -> Test.Test, Test.TesTest -> Test.Testest)
	var parts = clean_tag.split(".")
	var formatted_parts: Array[String] = []
	
	for part in parts:
		if part.is_empty():
			formatted_parts.append("") # Let the Regex catch double dots
		else:
			var p = part.to_lower()
			# Capitalize only the first letter, leave the rest lowercase
			var formatted_part = p.substr(0, 1).to_upper() + p.substr(1)
			formatted_parts.append(formatted_part)
			
	var formatted_tag = ".".join(formatted_parts)
	
	# 2. Regex Enforcement
	var regex = RegEx.new()
	regex.compile("^([A-Z][a-zA-Z0-9]*)(\\.[A-Z][a-zA-Z0-9]*)*$")
	
	if not regex.search(formatted_tag):
		return "Error: Invalid format '%s'. Must use alphanumeric characters and dots." % formatted_tag
		
	# 3. Hierarchy Injection (The Unreal Method)
	var current_path = ""
	var changed = false
	
	for part in formatted_parts:
		current_path = part if current_path.is_empty() else current_path + "." + part
		var step_name = StringName(current_path)
		
		if not has_tag(step_name):
			tags.append(step_name)
			changed = true
			
	if not changed:
		return "Error: Tag '%s' already exists." % formatted_tag
		
	tags.sort_custom(func(a, b): return String(a) < String(b))
	
	emit_changed()
	GameplayTagGenerator.generate_tags_file(tags)
	
	if not resource_path.is_empty():
		ResourceSaver.save(self, resource_path)
	
	return formatted_tag # Return the beautiful string back to the UI


## Removes a tag, sweeping downwards to delete children, and upwards to prune orphaned parents.
func remove_tag(tag_name: StringName) -> void:
	var target_str = String(tag_name)
	var changed = false

	# 1. Downward Sweep (Remove exact target and ALL its children)
	for i in range(tags.size() - 1, -1, -1):
		var t_str = String(tags[i])
		if t_str == target_str or t_str.begins_with(target_str + "."):
			tags.remove_at(i)
			changed = true

	# 2. Upward Sweep (Smart Pruning of orphaned parents)
	var parts = target_str.split(".")
	for i in range(parts.size() - 1, 0, -1):
		var parent_str = ""
		for j in range(i):
			parent_str += parts[j] + ("." if j < i - 1 else "")

		var parent_name = StringName(parent_str)
		if has_tag(parent_name):
			# Does this parent still have any other active children?
			var has_children = false
			var prefix = parent_str + "."
			for t in tags:
				if String(t).begins_with(prefix):
					has_children = true
					break

			# If it's an empty folder now, delete it too!
			if not has_children:
				tags.erase(parent_name)
				changed = true
			else:
				break # Stop pruning upward; this parent is still holding active children

	if changed:
		emit_changed()
		GameplayTagGenerator.generate_tags_file(tags)
		if not resource_path.is_empty():
			ResourceSaver.save(self, resource_path)
#endregion


#region Tag Queries
## Checks if the exact tag exists in the registry.
func has_tag(tag_name: StringName) -> bool:
	return tags.has(tag_name)


## Returns all tags that fall under a specific parent.
## e.g., get_child_tags("Status") might return ["Status.Stunned", "Status.Burning"].
func get_child_tags(parent_tag: StringName) -> Array[StringName]:
	var children: Array[StringName] = []
	var prefix = String(parent_tag) + "."
	
	for tag in tags:
		if String(tag).begins_with(prefix):
			children.append(tag)
			
	return children
#endregion
