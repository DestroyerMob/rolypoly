extends StaticBody3D

signal weight_changed(weight: float, id: StringName)

@export var scale_id: StringName = &""

@onready var detection: Area3D = $Detection
@onready var display: Label3D = %WeightDisplay


func _ready() -> void:
	display.text = "0.00 kg"
	detection.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is RigidBody3D:
		body.max_contacts_reported = maxi(body.max_contacts_reported, 32)
		body.sleeping = false


func _physics_process(_delta: float) -> void:
	var total_mass := 0.0
	for body in detection.get_overlapping_bodies():
		if not body is RigidBody3D or body.freeze:
			continue
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if state == null:
			continue
		for contact in range(state.get_contact_count()):
			if state.get_contact_collider(contact) == get_rid() and state.get_contact_local_normal(contact).dot(global_basis.y.normalized()) > 0.5:
				total_mass += body.mass
				break
	var weight := snappedf(total_mass, 0.01)
	var readout := "%.2f kg" % weight
	if display.text != readout:
		display.text = readout
		weight_changed.emit(weight, scale_id)
