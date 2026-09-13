extends Area2D

var speed: float = 1500.0 # 激光速度极快！
var direction: Vector2 = Vector2.ZERO
var lifetime: float = 0.5 # 0.5秒后如果没打中人自动销毁，防止内存泄漏

func _ready():
	# 子弹是虚无的能量体，没有物理实体
	collision_layer = 0
	
	# 【真正的穿墙神技】
	# 根本不去扫描第 1 层的墙壁，直接扫描第 3 层 (位值为 4) 的敌人！
	collision_mask = 4
	
func _process(delta):
	# 没有物理引擎的阻挡，直接修改坐标，实现完美穿墙！
	global_position += direction * speed * delta
	
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

# 当激光接触到任何物体时触发
func _on_body_entered(body):
	# 【穿墙核心】：我们根本不检测墙壁（StaticBody2D）！
	# 只有当撞到的是敌人时，才造成伤害并销毁子弹。撞到墙直接无视穿过去！
	if body.is_in_group("enemy") or body.has_method("take_damage"):
		body.take_damage() # 记得确保你的 enemy.gd 里有这个函数！
		queue_free()       # 击中敌人后激光消散（如果你想连敌人也一起穿透，把这行删了即可！）
