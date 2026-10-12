## A resource container for a single gameplay attribute.
##
## Holds the permanent base value, the accumulated runtime delta from instant/periodic
## effects, and the temporary current value of an attribute. The ASC derives current
## from the working base (base_value + runtime_delta) and active effects.
##
## @meta_addon: GodotGAS
## @meta_author: YulRun (https://YulRun.Dev)
## @meta_license: MIT

@tool
@icon("res://addons/GodotGAS/icons/godot_gas_asc.svg")
class_name AttributeData extends Resource

## The permanent, unbuffed archetype stat (e.g., your naked Max Health).
@export var base_value: float = 0.0 : set = _set_base_value
## The temporary, buffed/debuffed stat used for actual gameplay math.
@export var current_value: float = 0.0 : set = _set_current_value

## The net permanent offset accumulated from Instant and Periodic effects at runtime.
## Keeping this separate preserves base_value for respawning and object pooling.
var runtime_delta: float = 0.0

## Internal guard flag so ASC recalculations do not overwrite runtime_delta.
var _is_internal_update: bool = false


#region Initialization
func _init(initial_value: float = 0.0) -> void:
	base_value = initial_value
	runtime_delta = 0.0
	_set_current_value_internal(initial_value)
#endregion


#region Setters & Math
func _set_base_value(new_value: float) -> void:
	base_value = new_value
	runtime_delta = 0.0
	
	# Direct writes to base_value reset the runtime offset and sync current_value.
	_set_current_value_internal(new_value)


func _set_current_value(new_value: float) -> void:
	current_value = new_value
	
	# If external code writes to current_value directly (e.g., manual respawn reset),
	# synchronize runtime_delta so subsequent ASC recalculations respect the change.
	if not _is_internal_update:
		runtime_delta = new_value - base_value


## Used exclusively by the ASC during aggregation so temporary active buffs
## update current_value without polluting runtime_delta.
func _set_current_value_internal(new_value: float) -> void:
	_is_internal_update = true
	current_value = new_value
	_is_internal_update = false


## Returns the permanent base stat combined with accumulated instant/periodic changes.
func get_working_base() -> float:
	return base_value + runtime_delta


## Updates runtime_delta so that (base_value + runtime_delta) equals new_working_base.
func set_working_base(new_working_base: float) -> void:
	runtime_delta = new_working_base - base_value


## Resets accumulated runtime changes and restores current_value to base_value.
func reset() -> void:
	runtime_delta = 0.0
	_set_current_value_internal(base_value)
#endregion
