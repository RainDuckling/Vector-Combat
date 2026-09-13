extends CanvasLayer

func _process(delta):
	# 每一帧都去问幕后计分员要最新的分数，并显示在屏幕上
	$ScoreLabel.text = "SCORE: " + str(Global.score)
