extends Node2D

var enemy_scene = preload("res://enemy.tscn")
var timer: float = 0.0
var player = null

func _ready():
	player = get_tree().get_first_node_in_group("player")
	# 错开初始刷怪时间，防止多个笼子同时爆兵
	timer = randf_range(1.0, 3.0) 

func _process(delta):
	timer -= delta
	if timer <= 0:
		timer = randf_range(2.0, 4.0) # 重置下一次刷怪的时间
		
		if is_instance_valid(player):
			# 计算刷怪笼和玩家的绝对距离
			var distance = global_position.distance_to(player.global_position)
			
			# ==========================
			# 【神级机制：防贴脸杀雷达】
			# 距离必须大于 400（绝不贴脸！给玩家反应空间）
			# 且距离小于 1200（不在屏幕外很远的地方瞎刷，节省性能）
			# ==========================
			if distance > 400.0 and distance < 1200.0:
				spawn_enemy()

func spawn_enemy():
	var e = enemy_scene.instantiate()
	e.global_position = global_position
	# 把怪物加到当前关卡根节点，防止刷怪笼被清理时把活着的怪物也删了
	get_tree().current_scene.add_child(e)
