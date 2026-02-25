extends CharacterBody2D

# ==========================
# 核心移动与物理参数
# ==========================
var speed: float = 300.0
var jump_velocity: float = -600.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var jump_count: int = 0
var max_jumps: int = 2

# ==========================
# 冲刺(Dash)系统参数
# ==========================
var dash_speed: float = 1200.0
var dash_duration: float = 0.2
var dash_cooldown: float = 5.0     
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var is_dashing: bool = false
var dash_vector: Vector2 = Vector2.RIGHT

# ==========================
# 武器系统参数 (新增)
# ==========================
var bullet_scene = preload("res://bullet.tscn") # 确保你有这个场景！
var shoot_cooldown: float = 0.15 # 射速：越小射得越快
var shoot_timer: float = 0.0

var is_dead: bool = false
@onready var dash_particles = $DashParticles

# ==========================
# 屏幕震动系统
# ==========================
var shake_strength: float = 0.0
var shake_fade: float = 120.0 # 震动衰减速度（数值越大，停得越快）
@onready var camera = $Camera2D

func _ready():
	# 确保自己挂着 player 牌子
	add_to_group("player")
	
	# ==========================
	# 【神级机制：物理图层隔离】
	# ==========================
	# 1. 把玩家本体挪到独立的第 2 层 (位值为 2)
	collision_layer = 2
	
	# 2. 玩家的肉体只会被第 1 层 (墙壁、平台) 阻挡。
	# 彻底无视敌人！冲刺时再也不会有任何卡顿和急刹车！
	collision_mask = 1

func _physics_process(delta):
	if is_dead: return

	# 【关键】：每一帧都要求系统重新画图，因为你的鼠标在不断移动，尖角要实时跟着动！
	queue_redraw()

	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	# ==========================
	# 武器开火逻辑 (新增)
	# ==========================
	if shoot_timer > 0:
		shoot_timer -= delta
		
	# 按住左键即可像机枪一样连发！
	if Input.is_action_pressed("shoot") and shoot_timer <= 0 and not is_dashing:
		shoot_timer = shoot_cooldown
		spawn_bullet()

	# ==========================
	# 冲刺状态接管
	# ==========================
	if is_dashing:
		velocity = dash_vector * dash_speed
		move_and_slide()
		
		dash_timer -= delta
		
		# 【修改这里】：把 is_on_wall 等物理阻挡全部删掉！
		# 哪怕撞在实心墙上，也要硬顶着墙把这 0.2 秒的无敌帧耗完！
		if dash_timer <= 0:
			is_dashing = false
			velocity = Vector2.ZERO 
			if has_node("DashParticles"):
				$DashParticles.emitting = false 
			queue_redraw() 
		return

	# ==========================
	# 正常物理与移动
	# ==========================
	if is_on_floor():
		jump_count = 0 
	else:
		velocity.y += gravity * delta 

	if Input.is_action_just_pressed("jump") and jump_count < max_jumps:
		velocity.y = jump_velocity 
		jump_count += 1            

	var direction = Input.get_axis("move_left", "move_right")
	velocity.x = direction * speed
	
	# ==========================
	# 在触发冲刺的逻辑中加入音效
	# ==========================
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0:
		is_dashing = true
		dash_timer = dash_duration
		dash_cooldown_timer = dash_cooldown
		
		dash_vector = (get_global_mouse_position() - global_position).normalized()
		
		dash_particles.rotation = dash_vector.angle()
		dash_particles.emitting = true 
		
		# 触发冲刺音效
		if has_node("DashSound"):
			$DashSound.play()
			
		return 
		
	move_and_slide()

# ==========================
# 在射击函数中加入音效
# ==========================
func spawn_bullet():
	var b = bullet_scene.instantiate()
	b.global_position = global_position
	var mouse_dir = (get_global_mouse_position() - global_position).normalized()
	b.direction = mouse_dir
	b.rotation = mouse_dir.angle() 
	
	get_tree().current_scene.add_child(b)
	
	# 触发射击音效
	if has_node("ShootSound"):
		$ShootSound.play()
		
func apply_shake(strength: float):
	shake_strength = strength

func _process(delta):
	# 只要有震动强度，每一帧都随机偏移相机的 offset
	if shake_strength > 0:
		shake_strength = move_toward(shake_strength, 0, shake_fade * delta)
		var random_offset = Vector2(
			randf_range(-shake_strength, shake_strength), 
			randf_range(-shake_strength, shake_strength)
		)
		if camera:
			camera.offset = random_offset
	# 震动结束，确保镜头立刻回正
	elif camera and camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO
		
# ==========================
# 自绘渲染逻辑
# ==========================
func _draw():
	if is_dead: return 
	
	# ==========================
	# 【神级视线追踪】：计算鼠标角度，只旋转玩家本体！
	# ==========================
	var mouse_angle = (get_local_mouse_position()).angle()
	draw_set_transform(Vector2.ZERO, mouse_angle, Vector2.ONE)
	
	var points = PackedVector2Array([Vector2(20, 0), Vector2(-15, 15), Vector2(-15, -15)])
	var current_color = Color(3.0, 3.0, 0.0) if is_dashing else Color(0.0, 3.0, 3.0) 
	draw_colored_polygon(points, current_color)

	# ==========================
	# 重置画布旋转！保证 UI 和蓄力条永远是水平的！
	# ==========================
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var bar_width = 40.0   
	var bar_height = 4.0   
	var bar_offset_y = -35.0 

	var bg_rect = Rect2(-bar_width / 2.0, bar_offset_y, bar_width, bar_height)
	draw_rect(bg_rect, Color(0.2, 0.2, 0.2))

	var charge_ratio = 1.0
	if dash_cooldown_timer > 0:
		charge_ratio = 1.0 - (dash_cooldown_timer / dash_cooldown)

	if charge_ratio > 0:
		var fg_rect = Rect2(-bar_width / 2.0, bar_offset_y, bar_width * charge_ratio, bar_height)
		var bar_color = Color(3.0, 3.0, 3.0) if charge_ratio >= 1.0 else Color(0.0, 2.0, 2.0)
		draw_rect(fg_rect, bar_color)

# ==========================
# 死亡逻辑 (节点触发版)
# ==========================
func die():
	if is_dashing or is_dead:
		return 
		
	is_dead = true
	velocity = Vector2.ZERO
	queue_redraw()
	
	if has_node("DeathParticles"):
		var particles = $DeathParticles
		
		# 节点剥离
		particles.reparent(get_tree().current_scene)
		particles.emitting = true
		
		# 触发挂载在粒子节点下的爆炸音效
		if particles.has_node("ExplosionSound"):
			particles.get_node("ExplosionSound").play()
		
		get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

	# 【新增】：触发极具毁灭感的剧烈震动！
	apply_shake(40.0)
	print("💥 玩家阵亡，等待重启...")
	
	# 1. 先冻结时间，给子弹 0.8 秒的“复仇时间”
	await get_tree().create_timer(0.8).timeout
	
	# 2. 【核心修复】：在屏幕即将重启的最后一帧，强行抹除一切历史成绩！
	if has_node("/root/Global"):
		get_node("/root/Global").score = 0
		
	# 3. 带着真正的 0 分，干干净净地重生
	get_tree().reload_current_scene()
