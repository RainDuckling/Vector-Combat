extends AnimatableBody2D

@onready var color_rect = $ColorRect
@onready var collision_shape = $CollisionShape2D

var is_moving: bool = false
var speed: float = 0.0
var direction: float = 1.0

# ==========================
# 【新增】往复运动核心变量
# ==========================
var start_x: float = 0.0
var move_range: float = 0.0

func _ready():
	collision_mask = 0
	
	# 记录平台出生时的初始坐标（它的老家）
	start_x = global_position.x
	
	if randf() < 0.3:
		is_moving = true
		# 速度可以稍微放慢一点，方便玩家瞄准落脚
		speed = randf_range(80.0, 180.0) 
		direction = 1.0 if randf() > 0.5 else -1.0
		
		# 【新增】随机决定这个平台要巡逻多远（比如偏离中心 100 到 250 像素）
		move_range = randf_range(100.0, 250.0)
		
		if has_node("ColorRect"):
			$ColorRect.color = Color(1.0, 0.8, 0.0)

func _physics_process(delta):
	if is_moving:
		global_position.x += speed * direction * delta
		
		# ==========================
		# 【核心逻辑】：测量离家的距离
		# ==========================
		var distance_from_home = abs(global_position.x - start_x)
		
		# 1. 如果走出了设定的巡逻范围，立刻回头！
		if distance_from_home >= move_range:
			direction *= -1
			# 【防鬼畜保护】：强行把它拉回边界线上，防止它在边界线外反复横跳
			global_position.x = start_x + move_range * sign(global_position.x - start_x)
			
		# 2. 【兜底保护】：虽然有巡逻范围，但如果它生成的离屏幕边缘太近，
		# 还没走完巡逻范围就要撞墙了，也必须强制它回头！
		if global_position.x < 150 and direction < 0:
			direction = 1.0
		elif global_position.x > 1002 and direction > 0:
			direction = -1.0

# ==========================
# 【神级修复】动态重塑尺寸，绝不使用 scale！
# ==========================
func set_width(new_width: float):
	# 假设我们平台的标准高度是 30
	var height = 30.0 
	
	if color_rect and collision_shape:
		# 1. 真实改变图形的大小，并重新居中对齐
		color_rect.size = Vector2(new_width, height)
		color_rect.position = Vector2(-new_width / 2.0, -height / 2.0)
		
		# 2. 真实改变物理碰撞箱的大小！
		var new_shape = RectangleShape2D.new()
		new_shape.size = Vector2(new_width, height)
		collision_shape.shape = new_shape
