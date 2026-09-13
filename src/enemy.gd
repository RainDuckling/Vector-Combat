extends CharacterBody2D

var speed: float 
var gravity: float = 1200.0
var player = null
var wander_dir: float = 1.0

@onready var roof_checker = $RayCast2D

var stuck_timer: float = 0.0
var search_mode: bool = false
var last_floor_y: float = 0.0
var patience_limit: float 
var jump_cooldown: float = 0.0

# 【新增】出生硬直系统
var spawn_stun_timer: float = 0.5

func _ready():
	player = get_tree().get_first_node_in_group("player")
	speed = randf_range(120.0, 180.0)
	patience_limit = randf_range(1.0, 3.0)
	# 确保自己挂着 enemy 牌子
	add_to_group("enemy")
	
	# 1. 把敌人挪到独立的第 3 层 (位值为 4)
	collision_layer = 4
	
	# 2. 敌人的肉体同样只被第 1 层 (平台) 阻挡
	collision_mask = 1
	
	# 3. 【精准索敌】：让敌人的致命雷达，死死盯住第 2 层的玩家！
	if has_node("Hitbox"):
		$Hitbox.collision_layer = 0 # 雷达本身不需要实体
		$Hitbox.collision_mask = 2  # 只扫描位值为 2 的层（即玩家）

func _draw():
	var rect = Rect2(-30.0, -30.0, 60.0, 60.0)
	draw_rect(rect, Color(3.0, 0.0, 0.0))

func _physics_process(delta):
	# ==========================
	# 【新增】防“天降正义”系统
	# ==========================
	if is_instance_valid(player):
		# 如果敌人当前的高度，比玩家高出 700 个像素（意味着绝对在屏幕的最上方之外）
		if global_position.y < player.global_position.y - 700.0:
			queue_free() # 默默地自我销毁，连灰都不留！
			return       # 直接结束运算
			
	# ==========================
	# 【神级机制：出生闪烁与硬直】
	# ==========================
	if spawn_stun_timer > 0:
		spawn_stun_timer -= delta
		
		# 让怪物像接触不良的灯泡一样闪烁（透明度在 0.2 和 1.0 之间切换）
		# 这是动作游戏提示“危险即将降临”的最高级做法！
		if int(spawn_stun_timer * 20) % 2 == 0:
			modulate.a = 0.2
		else:
			modulate.a = 1.0
			
		# 直接 return，剥夺它的移动能力和碰撞致死能力！
		return 
		
	# 计时结束，完全实体化，恢复不透明！
	modulate.a = 1.0
	
	if not is_on_floor():
		velocity.y += gravity * delta

	if jump_cooldown > 0:
		jump_cooldown -= delta

	if is_instance_valid(player): 
		var distance_x = player.global_position.x - global_position.x
		var distance_y = player.global_position.y - global_position.y 
		
		# 判断玩家在上面还是下面
		var player_is_higher = distance_y < -50
		var player_is_lower = distance_y > 50
		
		var is_under_roof = roof_checker.is_colliding()


		# ==========================
		# 2. 正常物理与沮丧系统
		# ==========================
		if is_on_wall(): wander_dir *= -1

		if is_on_floor():
			# 【关键修复】：一旦落地发现高度变了（成功掉下去了或跳上去了），解除寻找模式！
			if abs(global_position.y - last_floor_y) > 20:
				search_mode = false 
				stuck_timer = 0.0
				patience_limit = randf_range(1.0, 3.0)
			last_floor_y = global_position.y 

			# 【终极死锁检测】：不管是在上面还是下面，只要 X 轴重合却够不着，就开始积攒沮丧值！
		if abs(distance_x) < 100 and (player_is_higher or player_is_lower):
			stuck_timer += delta
			if stuck_timer > patience_limit: 
				search_mode = true # 破防了，强行进入找边缘/找台阶模式
		
		if not search_mode:
			stuck_timer = 0.0

			# ==========================
			# 3. 移动决策
			# ==========================
			var target_dir = 0.0
			var wants_to_jump = false

			if is_under_roof and player_is_higher:
				target_dir = wander_dir
			elif search_mode:
				# 【关键修复】：只要在找路模式，必须一条路走到黑，绝不回头看玩家！
				# 这样它就会果断地跳下悬崖边缘！
				target_dir = wander_dir
				if is_on_wall() and is_on_floor(): wants_to_jump = true
			else:
				# 正常追踪
				target_dir = sign(distance_x)
				if target_dir != 0: wander_dir = target_dir
				if (is_on_wall() or player_is_higher) and is_on_floor():
					wants_to_jump = true

			velocity.x = target_dir * speed

			if wants_to_jump and jump_cooldown <= 0:
				velocity.y = randf_range(-600.0, -800.0) 
				jump_cooldown = randf_range(0.1, 0.6)

	else:
		player = get_tree().get_first_node_in_group("player")
		velocity.x = 0

	move_and_slide()

	# 碰撞致死逻辑
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("player"):
			if collider.has_method("die"): collider.die()
			

# ==========================
# 怪物受伤逻辑 (粒子与音效脱离版)
# ==========================
func take_damage():
	# 【新增】：远程呼叫相机进行震动反馈！
	if is_instance_valid(player) and player.has_method("apply_shake"):
		player.apply_shake(20.0) # 20.0 代表中等强度的顿挫感

	if has_node("DeathParticles"):
		var particles = $DeathParticles
		
		# 节点剥离
		particles.reparent(get_tree().current_scene)
		particles.emitting = true
		
		# 触发挂载在粒子节点下的爆炸音效
		if particles.has_node("ExplosionSound"):
			particles.get_node("ExplosionSound").play()
		
		get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

	if has_node("/root/Global"):
		get_node("/root/Global").score += 1
		
	queue_free()

# ==========================
# 致命雷达：与玩家的生死博弈
# ==========================
func _on_hitbox_body_entered(body):
	# 检查撞进来的是不是玩家
	if body.is_in_group("player"):
		
		# 判断玩家当前是不是处于“金色闪电”的冲刺状态？
		if body.is_dashing:
			# 玩家在冲刺！触发【反向击杀】！
			take_damage() 
		else:
			# 玩家没有无敌帧，被怪物直接秒杀！
			if body.has_method("die"):
				body.die()
