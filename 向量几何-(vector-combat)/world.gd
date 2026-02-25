extends Node2D

var platform_scene = preload("res://platform.tscn")
var spawner_scene = preload("res://spawner.tscn")

var current_y: float = 0.0          
var generate_ahead: float = 1200.0  
var viewport_width: float = 1152.0  

@onready var player = $Player
@onready var title_label = $TitleLabel

# ==========================
# 【新增】两堵空气墙的引用
# ==========================
var left_wall: StaticBody2D
var right_wall: StaticBody2D

func _ready():
	spawn_platform(viewport_width / 2.0, 400.0, 600.0)
	current_y = 400.0
	
	for i in range(5):
		generate_next_chunk()

	# ==========================
	# 【新增】游戏开始时，用代码手搓两堵墙！
	# 分别放在屏幕最左边（-50）和最右边（宽度+50）的屏幕外
	# ==========================
	left_wall = create_air_wall(0)
	right_wall = create_air_wall(viewport_width)

func _process(delta):
	if is_instance_valid(player):
		if player.global_position.y + generate_ahead > current_y:
			generate_next_chunk()
			cleanup_old_platforms()
			
		# ==========================
		# 【神级机制：电梯空气墙】
		# 每一帧都把这两堵墙的 Y 坐标硬生生拽到玩家的高度！
		# 玩家永远飞不出这两堵墙的手掌心。
		# ==========================
		if is_instance_valid(left_wall) and is_instance_valid(right_wall):
			left_wall.global_position.y = player.global_position.y
			right_wall.global_position.y = player.global_position.y
			
		if player.global_position.y > 600.0:
			if is_instance_valid(title_label):
				title_label.modulate.a -= delta * 2.0
				if title_label.modulate.a <= 0:
					title_label.queue_free()
					
		# ==========================
		# 【深渊印记】：实时更新背景的巨型分数
		# ==========================
		if has_node("/root/Global") and has_node("BackgroundUI/ScoreLabel"):
			$BackgroundUI/ScoreLabel.text = str(get_node("/root/Global").score)

func generate_next_chunk():
	# ==========================
	# 1. 压缩垂直落差 (让 Y 轴更紧凑)
	# ==========================
	# 以前是 150~250，现在缩短到 100~160，让上下层之间更好跳
	var gap_y = randf_range(100.0, 160.0)
	current_y += gap_y
	
	# ==========================
	# 2. 增加横向密度 (让 X 轴铺满)
	# ==========================
	# 每一层随机生成 2 到 3 个平台
	var platform_count = randi_range(2, 3)
	
	# 【神级算法：分块生成】：把屏幕宽度切成几份，每个区域生成一个，保证平台不会全部挤在一边！
	var safe_margin = 150.0
	var available_width = viewport_width - (safe_margin * 2)
	var section_width = available_width / platform_count
	
	for i in range(platform_count):
		# 计算当前这个平台应该落在哪个大致区间
		var base_x = safe_margin + (i * section_width)
		# 在区间内稍微加点随机偏移，打破死板的网格感
		var random_x = base_x + randf_range(20.0, section_width - 20.0)
		
		# 平台的宽度稍微收敛一点，避免全部连死成平地
		var random_scale_x = randf_range(0.6, 1.2) 
		var real_width = 200.0 * random_scale_x
		
		var p = spawn_platform(random_x, current_y, real_width)
		
		# ==========================
		# 3. 动态平衡刷怪率
		# ==========================
		# 因为现在的平台数量翻了 2~3 倍，如果还是 30% 概率刷怪，满屏都会是怪！
		# 所以把单个平台的刷怪笼概率降到 15% 左右，保持总怪物数量合理。
		if randf() < 0.15:
			var s = spawner_scene.instantiate()
			s.global_position = Vector2(random_x, current_y - 80) # 稍微降低一点刷怪笼高度，贴近地面
			add_child(s)

# 升级生成函数，让它调用平台的塑形方法
func spawn_platform(x: float, y: float, width: float) -> Node2D:
	var p = platform_scene.instantiate()
	p.global_position = Vector2(x, y)
	add_child(p)
	
	# 【神级修复】：在这里调用平台的真实塑形函数！
	if p.has_method("set_width"):
		p.set_width(width)
		
	return p
func cleanup_old_platforms():
	for child in get_children():
		if child is Node2D and child != player:
			if child.global_position.y < player.global_position.y - 800.0:
				child.queue_free()

# ==========================
# 【新增】纯代码生成巨型空气墙的函数
# ==========================
func create_air_wall(pos_x: float) -> StaticBody2D:
	var wall = StaticBody2D.new()
	# 碰撞层设为 1，确保玩家和敌人（之前的幽灵AI）都能撞到并反弹
	wall.collision_layer = 1
	wall.collision_mask = 0

	var collision_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	# 形状大小：宽 100，高 3000！像一根擎天柱一样长，绝对无死角
	rect_shape.size = Vector2(100.0, 3000.0)
	collision_shape.shape = rect_shape

	wall.add_child(collision_shape)
	wall.global_position = Vector2(pos_x, 0)
	add_child(wall)
	
	return wall
