extends CharacterBody2D
class_name Player

signal health_changed(new_health: int)
signal died

const SPEED = 300.0

var last_direction: Vector2 = Vector2.RIGHT
var is_attacking: bool = false
var is_mining: bool = false
var hitbox_offset: Vector2
var hitbox_mining_offset: Vector2
var alive: bool = true
var max_health: int
var health: int
var strength: int = 20
var pickaxe_strength: int = 1
var detected_rocks: Array = []

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var swing_sword_sound: AudioStreamPlayer2D = $SwingSword
@onready var pickaxe_hit_sound: AudioStreamPlayer2D = $PickaxeHitSound
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_mining: Area2D = $HitboxMining
@onready var take_damage_sound: AudioStreamPlayer2D = $TakeDamage
@onready var take_damage_cooldown: Timer = $TakeDamageCooldown
@onready var mining_timer: Timer = $MiningTimer

func _ready() -> void:
	# Load health from the singleton
	health = PlayerStats.health
	max_health = PlayerStats.max_health

	# Initialise hitbox offset
	hitbox_offset = hitbox.position
	
	# Initialise hitbox mining offset
	hitbox_mining_offset = hitbox_mining.position
	
func reset(pos: Vector2) -> void:
	position = pos

# MOVEMENT & ANIMATION
func _physics_process(_delta: float) -> void:
	# Disable hitbox until an attack is triggered
	hitbox.monitoring = false
	hitbox_mining.monitoring = false

	if alive:
		if Input.is_action_just_pressed("use_pickaxe") and not is_mining and mining_timer.is_stopped():
			use_pickaxe()
		if Input.is_action_just_pressed("attack") and not is_attacking:
			attack()
			
		#	Skip movement if attacking
		if is_attacking or is_mining:
			velocity = Vector2.ZERO
			return

		process_movement()
		process_animation()
		move_and_slide()

func process_movement() -> void:
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_vector("left", "right", "up", "down")
	if direction != Vector2.ZERO:
		velocity = direction * SPEED
		last_direction = direction
		update_hitbox_offset()
		update_hitbox_mining_offset()
	else:
		velocity = Vector2.ZERO

func process_animation() -> void:
	if is_attacking or is_mining:
		return
	if velocity != Vector2.ZERO:
		play_animation("run", last_direction)
	else:
		play_animation("idle", last_direction)

func play_animation(prefix: String, dir: Vector2) -> void:
	if dir.x != 0:
		animated_sprite_2d.flip_h = dir.x < 0
		animated_sprite_2d.play(prefix + "_right")
	elif dir.y < 0:
		animated_sprite_2d.flip_h = dir.x < 0
		animated_sprite_2d.play(prefix + "_up")
	elif dir.y > 0:
		animated_sprite_2d.flip_h = dir.x < 0
		animated_sprite_2d.play(prefix + "_down")
		
func use_pickaxe() -> void:
	detected_rocks.clear()
	is_mining = true
	hitbox_mining.monitoring = true
	mining_timer.start() # Start cooldown timer
	play_animation("swing_pickaxe", last_direction)

# ATTACK
func attack() -> void:
	is_attacking = true
	hitbox.monitoring = true
	swing_sword_sound.play()
	play_animation("attack", last_direction)


func _on_animated_sprite_2d_animation_finished() -> void:
	if is_attacking:
		is_attacking = false
	if is_mining:
		is_mining = false
		if detected_rocks.size() > 0:
			var rock_to_hit = get_most_overlapping_rock()
			rock_to_hit.take_damage(pickaxe_strength)
			pickaxe_hit_sound.play()

func get_most_overlapping_rock() -> Rock:
	var best_rock = detected_rocks[0]
	var best_dist = hitbox_mining.global_position.distance_to(best_rock.global_position)
	for rock in detected_rocks:
		var dist = hitbox_mining.global_position.distance_to(rock.global_position)
		if dist < best_dist:
			best_dist = dist
			best_rock = rock
	return best_rock

# HITBOX OFFSET
func update_hitbox_offset() -> void:
	var x := hitbox_offset.x
	var y := hitbox_offset.y
	
	match last_direction:
		Vector2.LEFT:
			hitbox.position = Vector2(-x, y)
		Vector2.RIGHT:
			hitbox.position = Vector2(x, y)
		Vector2.UP:
			hitbox.position = Vector2(y, -x)
		Vector2.DOWN:
			hitbox.position = Vector2(-y, x)

# HITBOX MINING OFFSET
func update_hitbox_mining_offset() -> void:
	var x := hitbox_mining_offset.x
	var y := hitbox_mining_offset.y
	
	match last_direction:
		Vector2.LEFT:
			hitbox_mining.position = Vector2(-x, y)
		Vector2.RIGHT:
			hitbox_mining.position = Vector2(x, y)
		Vector2.UP:
			hitbox_mining.position = Vector2(y + 16, -x)
		Vector2.DOWN:
			hitbox_mining.position = Vector2(-y - 20, y + 8)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_attacking and body.name.begins_with("Slime"):
		body.take_damage(strength, position)

func heal(amount: int) -> void:
	health += amount
	if health >= max_health:
		health = max_health
	PlayerStats.health = health
	emit_signal("health_changed", health)

func take_damage(amount: int) -> void:
	if alive:
		if take_damage_cooldown.time_left > 0:
			return
		
		take_damage_sound.play(6.0)
		health -= amount
		PlayerStats.health = health
		emit_signal("health_changed", health)
		if health <= 0:
			die()
		
		# Make the player invincible in short time
		take_damage_cooldown.start()
	
func die() -> void:
	animated_sprite_2d.play("dying")
	alive = false
	await animated_sprite_2d.animation_finished
	died.emit()


func _on_hitbox_mining_body_entered(body: Node2D) -> void:
	if body is Rock:
		detected_rocks.append(body)
		
func add_ore(data: OreData) -> bool:
	return true
