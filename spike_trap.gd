extends Area2D
class_name SpikeTrap

# --- ENUMERASI (State) ---
enum TrapState { HIDDEN, ACTIVE }

# --- PARAMETER (No Magic Numbers) ---
@export_category("Siklus Waktu")
@export var hidden_duration: float = 2.0
@export var active_duration: float = 2.0
@export var animation_speed: float = 0.2

@export_category("Kalkulasi Damage")
@export var damage_amount: float = 10.0
@export var damage_interval: float = 0.5 # Kecepatan hit jika player diam di atas duri

# --- PRIVATE VARIABLES ---
var _current_state: TrapState = TrapState.HIDDEN
var _players_in_trap: Array[Node2D] = []

# --- NODE REFERENCES ---
# DIUBAH: Menyesuaikan nama dan tipe node dengan yang ada di Scene Tree Anda
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var cycle_timer: Timer = $CycleTimer
@onready var damage_timer: Timer = $DamageTimer
@onready var spike_sfx: AudioStreamPlayer2D = $SpikeSfx

func _ready() -> void:
	# Set animasi ke "spike" dan pastikan mulai dari frame 0 (tertutup)
	anim_sprite.animation = "spike"
	anim_sprite.frame = 0
	
	# Setup Cycle Timer
	cycle_timer.wait_time = hidden_duration
	cycle_timer.timeout.connect(_on_cycle_timeout)
	cycle_timer.start()
	
	# Setup Damage Timer (Untuk efek racun/DoT)
	damage_timer.wait_time = damage_interval
	damage_timer.timeout.connect(_apply_damage_to_occupants)
	if spike_sfx:
		spike_sfx.max_distance = 240.0
		spike_sfx.attenuation = 2.0
	
	# Setup Area Signal
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# --- CORE LOGIC ---
func _on_cycle_timeout() -> void:
	if _current_state == TrapState.HIDDEN:
		_change_state(TrapState.ACTIVE)
	else:
		_change_state(TrapState.HIDDEN)

func _change_state(new_state: TrapState) -> void:
	_current_state = new_state
	
	if _current_state == TrapState.ACTIVE:
		# Bergerak dari frame 0 ke frame 4
		if spike_sfx and _players_in_trap.size() > 0:
			spike_sfx.play()
		_animate_spikes(4)
		cycle_timer.start(active_duration)
		damage_timer.start()
		_apply_damage_to_occupants() # Berikan damage instan saat duri pertama kali keluar
	else:
		# Bergerak mundur dari frame 4 ke frame 0
		_animate_spikes(0)
		cycle_timer.start(hidden_duration)
		damage_timer.stop()

# --- ANIMATION (TWEEN) ---
func _animate_spikes(target_frame: int) -> void:
	var tween: Tween = create_tween()
	# DIUBAH: Menggunakan tween_property untuk mengubah nilai "frame" pada AnimatedSprite2D
	tween.tween_property(anim_sprite, "frame", target_frame, animation_speed)

# --- COLLISION & DAMAGE ---
func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_players_in_trap.append(body)
		
		# Jika player masuk saat duri sedang naik, langsung terkena damage
		if _current_state == TrapState.ACTIVE:
			if spike_sfx:
				spike_sfx.play()
			_damage_entity(body)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_players_in_trap.erase(body)

func _apply_damage_to_occupants() -> void:
	for entity in _players_in_trap:
		_damage_entity(entity)

func _damage_entity(entity: Node2D) -> void:
	if entity.has_method("take_damage"):
		entity.take_damage(damage_amount)
