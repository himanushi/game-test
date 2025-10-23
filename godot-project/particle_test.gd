extends Node2D

# パーティクルエフェクトのテスト
# 数字キー1-5でそれぞれのエフェクトを発射

var effect_positions = []
var current_effect_index = 0

func _ready():
	print("==================================================")
	print("パーティクルエフェクトテスト")
	print("==================================================")
	print("1キー: 火の玉      2キー: 氷の弾     3キー: 雷撃")
	print("4キー: 風の渦      5キー: 聖なる光   6キー: 闇の波動")
	print("7キー: 毒の霧      8キー: 爆発       9キー: ヒール範囲")
	print("0キー: バリア      Qキー: 炎の渦     Wキー: 氷の嵐")
	print("Eキー: 血しぶき    Rキー: バフ       Tキー: 全部一斉")
	print("クリック: ランダムエフェクト")
	print("==================================================")

	# エフェクト配置位置を設定（3行x5列）
	for row in range(3):
		for col in range(5):
			effect_positions.append(Vector2(150 + col * 150, 150 + row * 150))

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				spawn_effect_at_position("fire", effect_positions[0])
			KEY_2:
				spawn_effect_at_position("ice", effect_positions[1])
			KEY_3:
				spawn_effect_at_position("lightning", effect_positions[2])
			KEY_4:
				spawn_effect_at_position("wind", effect_positions[3])
			KEY_5:
				spawn_effect_at_position("holy", effect_positions[4])
			KEY_6:
				spawn_effect_at_position("dark", effect_positions[5])
			KEY_7:
				spawn_effect_at_position("poison", effect_positions[6])
			KEY_8:
				spawn_effect_at_position("explosion", effect_positions[7])
			KEY_9:
				spawn_effect_at_position("heal", effect_positions[8])
			KEY_0:
				spawn_effect_at_position("barrier", effect_positions[9])
			KEY_Q:
				spawn_effect_at_position("fire_vortex", effect_positions[10])
			KEY_W:
				spawn_effect_at_position("ice_storm", effect_positions[11])
			KEY_E:
				spawn_effect_at_position("blood", effect_positions[12])
			KEY_R:
				spawn_effect_at_position("buff", effect_positions[13])
			KEY_T:
				# 全エフェクトを一斉発射
				var types = ["fire", "ice", "lightning", "wind", "holy", "dark", "poison",
							 "explosion", "heal", "barrier", "fire_vortex", "ice_storm", "blood", "buff"]
				for i in range(min(types.size(), effect_positions.size())):
					spawn_effect_at_position(types[i], effect_positions[i])

	# マウスクリックでランダムエフェクト発射
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var types = ["fire", "ice", "lightning", "wind", "holy", "dark", "poison",
					 "explosion", "heal", "barrier", "fire_vortex", "ice_storm", "blood", "buff"]
		var random_type = types[randi() % types.size()]
		spawn_effect_at_position(random_type, event.position)

# 指定位置にエフェクトを生成
func spawn_effect_at_position(effect_type: String, pos: Vector2):
	var particles = create_effect(effect_type)
	add_child(particles)
	particles.position = pos
	particles.emitting = true

	print("エフェクト発射: ", effect_type, " at ", pos)

	# 3秒後に削除
	await get_tree().create_timer(3.0).timeout
	particles.queue_free()

# エフェクトを作成
func create_effect(effect_type: String) -> GPUParticles2D:
	match effect_type:
		"fire":
			return create_fire_effect()
		"ice":
			return create_ice_effect()
		"lightning":
			return create_lightning_effect()
		"wind":
			return create_wind_effect()
		"holy":
			return create_holy_effect()
		"dark":
			return create_dark_effect()
		"poison":
			return create_poison_effect()
		"explosion":
			return create_explosion_effect()
		"heal":
			return create_heal_effect()
		"barrier":
			return create_barrier_effect()
		"fire_vortex":
			return create_fire_vortex_effect()
		"ice_storm":
			return create_ice_storm_effect()
		"blood":
			return create_blood_effect()
		"buff":
			return create_buff_effect()
		_:
			return create_fire_effect()

# ========================================
# 火の玉エフェクト
# ========================================
func create_fire_effect() -> GPUParticles2D:
	var particles = GPUParticles2D.new()

	# 基本設定
	particles.amount = 100
	particles.lifetime = 1.0
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.3

	# プロセスマテリアル
	var material = ParticleProcessMaterial.new()

	# 発射方向（右向き）
	material.direction = Vector3(1, 0, 0)
	material.spread = 15.0
	material.initial_velocity_min = 150.0
	material.initial_velocity_max = 200.0

	# 重力（少し上向き）
	material.gravity = Vector3(0, -50, 0)

	# サイズ
	material.scale_min = 3.0
	material.scale_max = 8.0

	# 色のグラデーション（黄色→オレンジ→赤→黒）
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 0.5, 1.0))  # 明るい黄色
	gradient.add_point(0.3, Color(1.0, 0.6, 0.0, 1.0))  # オレンジ
	gradient.add_point(0.7, Color(1.0, 0.2, 0.0, 0.8))  # 赤
	gradient.add_point(1.0, Color(0.3, 0.0, 0.0, 0.0))  # 暗い赤（透明）

	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture

	# ダンピング（空気抵抗）
	material.damping_min = 20.0
	material.damping_max = 40.0

	particles.process_material = material

	return particles

# ========================================
# 氷の弾エフェクト
# ========================================
func create_ice_effect() -> GPUParticles2D:
	var particles = GPUParticles2D.new()

	# 基本設定
	particles.amount = 80
	particles.lifetime = 1.2
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.2

	# プロセスマテリアル
	var material = ParticleProcessMaterial.new()

	# 発射方向（右向き）
	material.direction = Vector3(1, 0, 0)
	material.spread = 10.0
	material.initial_velocity_min = 200.0
	material.initial_velocity_max = 250.0

	# 重力なし
	material.gravity = Vector3(0, 0, 0)

	# サイズ（氷の結晶風に小さめ）
	material.scale_min = 2.0
	material.scale_max = 5.0

	# 色のグラデーション（水色→青→透明）
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.8, 1.0, 1.0, 1.0))  # 明るい水色
	gradient.add_point(0.4, Color(0.4, 0.8, 1.0, 1.0))  # 水色
	gradient.add_point(0.7, Color(0.0, 0.5, 1.0, 0.8))  # 青
	gradient.add_point(1.0, Color(0.0, 0.3, 0.8, 0.0))  # 暗い青（透明）

	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture

	# ダンピング（氷なので少し）
	material.damping_min = 10.0
	material.damping_max = 20.0

	particles.process_material = material

	return particles

# ========================================
# 雷撃エフェクト
# ========================================
func create_lightning_effect() -> GPUParticles2D:
	var particles = GPUParticles2D.new()

	# 基本設定（雷なので一瞬で爆発）
	particles.amount = 150
	particles.lifetime = 0.5
	particles.one_shot = false
	particles.explosiveness = 0.9
	particles.randomness = 0.5

	# プロセスマテリアル
	var material = ParticleProcessMaterial.new()

	# 全方向に発射
	material.direction = Vector3(1, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 100.0
	material.initial_velocity_max = 300.0

	# 重力なし
	material.gravity = Vector3(0, 0, 0)

	# サイズ
	material.scale_min = 2.0
	material.scale_max = 6.0

	# 色のグラデーション（白→黄色→透明）
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))  # 白
	gradient.add_point(0.3, Color(1.0, 1.0, 0.3, 1.0))  # 黄色
	gradient.add_point(0.6, Color(1.0, 0.8, 0.0, 0.6))  # オレンジ黄色
	gradient.add_point(1.0, Color(0.8, 0.6, 0.0, 0.0))  # 透明

	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture

	# ダンピングは強め（すぐ消える）
	material.damping_min = 50.0
	material.damping_max = 100.0

	particles.process_material = material

	return particles

# ========================================
# 風の渦エフェクト
# ========================================
func create_wind_effect() -> GPUParticles2D:
	var particles = GPUParticles2D.new()

	# 基本設定
	particles.amount = 120
	particles.lifetime = 1.5
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.4

	# プロセスマテリアル
	var material = ParticleProcessMaterial.new()

	# 発射方向（右向き、広がる）
	material.direction = Vector3(1, 0, 0)
	material.spread = 30.0
	material.initial_velocity_min = 100.0
	material.initial_velocity_max = 180.0

	# 横向きの重力（風の流れ）
	material.gravity = Vector3(50, 0, 0)

	# サイズ
	material.scale_min = 3.0
	material.scale_max = 7.0

	# 色のグラデーション（緑→薄緑→透明）
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.8, 1.0, 0.8, 0.8))  # 薄い緑
	gradient.add_point(0.4, Color(0.5, 1.0, 0.5, 0.7))  # 緑
	gradient.add_point(0.7, Color(0.3, 0.8, 0.3, 0.4))  # 濃い緑
	gradient.add_point(1.0, Color(0.2, 0.6, 0.2, 0.0))  # 透明

	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture

	# ダンピング（風なので少し）
	material.damping_min = 15.0
	material.damping_max = 30.0

	particles.process_material = material

	return particles

# ========================================
# 聖なる光エフェクト
# ========================================
func create_holy_effect() -> GPUParticles2D:
	var particles = GPUParticles2D.new()

	# 基本設定
	particles.amount = 100
	particles.lifetime = 1.8
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.3

	# プロセスマテリアル
	var material = ParticleProcessMaterial.new()

	# 発射方向（上向き）
	material.direction = Vector3(0, -1, 0)
	material.spread = 20.0
	material.initial_velocity_min = 80.0
	material.initial_velocity_max = 150.0

	# 重力（少し下向き）
	material.gravity = Vector3(0, 30, 0)

	# サイズ
	material.scale_min = 4.0
	material.scale_max = 8.0

	# 色のグラデーション（白→ゴールド→透明）
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))  # 白
	gradient.add_point(0.3, Color(1.0, 1.0, 0.8, 1.0))  # ほぼ白
	gradient.add_point(0.6, Color(1.0, 0.9, 0.5, 0.8))  # ゴールド
	gradient.add_point(1.0, Color(1.0, 0.8, 0.3, 0.0))  # 透明

	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture

	# ダンピング
	material.damping_min = 20.0
	material.damping_max = 40.0

	particles.process_material = material

	return particles

# ========================================
# 闇の波動エフェクト
# ========================================
func create_dark_effect() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 120
	particles.lifetime = 1.5
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.4

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(1, 0, 0)
	material.spread = 25.0
	material.initial_velocity_min = 120.0
	material.initial_velocity_max = 180.0
	material.gravity = Vector3(0, 0, 0)
	material.scale_min = 5.0
	material.scale_max = 10.0

	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.6, 0.2, 0.8, 1.0))
	gradient.add_point(0.5, Color(0.4, 0.0, 0.6, 0.9))
	gradient.add_point(1.0, Color(0.2, 0.0, 0.3, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture
	material.damping_min = 25.0
	material.damping_max = 45.0
	particles.process_material = material
	return particles

# ========================================
# 毒の霧エフェクト
# ========================================
func create_poison_effect() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 150
	particles.lifetime = 2.0
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.6

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 30.0
	material.initial_velocity_max = 60.0
	material.gravity = Vector3(0, -20, 0)
	material.scale_min = 6.0
	material.scale_max = 12.0

	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.5, 0.8, 0.2, 0.7))
	gradient.add_point(0.5, Color(0.3, 0.6, 0.1, 0.6))
	gradient.add_point(1.0, Color(0.2, 0.4, 0.0, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture
	material.damping_min = 10.0
	material.damping_max = 20.0
	particles.process_material = material
	return particles

# ========================================
# 爆発エフェクト
# ========================================
func create_explosion_effect() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 200
	particles.lifetime = 0.8
	particles.one_shot = false
	particles.explosiveness = 1.0
	particles.randomness = 0.3

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 150.0
	material.initial_velocity_max = 300.0
	material.gravity = Vector3(0, 50, 0)
	material.scale_min = 4.0
	material.scale_max = 10.0

	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.2, Color(1.0, 1.0, 0.3, 1.0))
	gradient.add_point(0.4, Color(1.0, 0.6, 0.0, 0.9))
	gradient.add_point(0.7, Color(1.0, 0.2, 0.0, 0.6))
	gradient.add_point(1.0, Color(0.3, 0.1, 0.0, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture
	material.damping_min = 30.0
	material.damping_max = 60.0
	particles.process_material = material
	return particles

# ========================================
# ヒール範囲エフェクト
# ========================================
func create_heal_effect() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 80
	particles.lifetime = 2.0
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.3

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 30.0
	material.initial_velocity_min = 60.0
	material.initial_velocity_max = 120.0
	material.gravity = Vector3(0, -30, 0)
	material.scale_min = 3.0
	material.scale_max = 7.0

	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.7, 0.8, 1.0))
	gradient.add_point(0.4, Color(1.0, 0.9, 0.9, 1.0))
	gradient.add_point(0.7, Color(1.0, 1.0, 1.0, 0.7))
	gradient.add_point(1.0, Color(1.0, 0.9, 0.9, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture
	material.damping_min = 15.0
	material.damping_max = 30.0
	particles.process_material = material
	return particles

# ========================================
# バリアエフェクト
# ========================================
func create_barrier_effect() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 100
	particles.lifetime = 1.5
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.2

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 80.0
	material.initial_velocity_max = 120.0
	material.gravity = Vector3(0, 0, 0)
	material.scale_min = 4.0
	material.scale_max = 8.0

	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.7, 0.9, 1.0, 0.9))
	gradient.add_point(0.5, Color(0.5, 0.7, 1.0, 0.7))
	gradient.add_point(1.0, Color(0.3, 0.5, 0.9, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture
	material.damping_min = 40.0
	material.damping_max = 70.0
	particles.process_material = material
	return particles

# ========================================
# 炎の渦エフェクト
# ========================================
func create_fire_vortex_effect() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 180
	particles.lifetime = 1.8
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.3

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 40.0
	material.initial_velocity_min = 150.0
	material.initial_velocity_max = 250.0
	material.gravity = Vector3(0, -100, 0)
	material.scale_min = 5.0
	material.scale_max = 12.0

	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 0.3, 1.0))
	gradient.add_point(0.3, Color(1.0, 0.7, 0.0, 1.0))
	gradient.add_point(0.6, Color(1.0, 0.3, 0.0, 0.8))
	gradient.add_point(1.0, Color(0.4, 0.1, 0.0, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture
	material.damping_min = 20.0
	material.damping_max = 40.0
	particles.process_material = material
	return particles

# ========================================
# 氷の嵐エフェクト
# ========================================
func create_ice_storm_effect() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 200
	particles.lifetime = 1.5
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.5

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(1, 0, 0)
	material.spread = 60.0
	material.initial_velocity_min = 180.0
	material.initial_velocity_max = 280.0
	material.gravity = Vector3(50, 0, 0)
	material.scale_min = 2.0
	material.scale_max = 6.0

	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.3, Color(0.8, 1.0, 1.0, 1.0))
	gradient.add_point(0.6, Color(0.4, 0.8, 1.0, 0.8))
	gradient.add_point(1.0, Color(0.2, 0.6, 0.9, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture
	material.damping_min = 15.0
	material.damping_max = 30.0
	particles.process_material = material
	return particles

# ========================================
# 血しぶきエフェクト
# ========================================
func create_blood_effect() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 120
	particles.lifetime = 1.0
	particles.one_shot = false
	particles.explosiveness = 0.7
	particles.randomness = 0.4

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 120.0
	material.initial_velocity_min = 100.0
	material.initial_velocity_max = 200.0
	material.gravity = Vector3(0, 200, 0)
	material.scale_min = 2.0
	material.scale_max = 5.0

	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.1, 0.1, 1.0))
	gradient.add_point(0.5, Color(0.8, 0.0, 0.0, 0.9))
	gradient.add_point(1.0, Color(0.4, 0.0, 0.0, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture
	material.damping_min = 25.0
	material.damping_max = 50.0
	particles.process_material = material
	return particles

# ========================================
# バフエフェクト（キラキラ）
# ========================================
func create_buff_effect() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 60
	particles.lifetime = 2.0
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.5

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 25.0
	material.initial_velocity_min = 40.0
	material.initial_velocity_max = 80.0
	material.gravity = Vector3(0, -20, 0)
	material.scale_min = 3.0
	material.scale_max = 7.0

	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 0.5, 1.0))
	gradient.add_point(0.3, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.6, Color(1.0, 0.9, 0.5, 0.7))
	gradient.add_point(1.0, Color(1.0, 1.0, 0.8, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture
	material.damping_min = 20.0
	material.damping_max = 40.0
	particles.process_material = material
	return particles
