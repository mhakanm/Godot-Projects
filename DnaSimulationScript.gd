extends Node3D

# DNA model parametreleri
@export var base_pairs: int = 60  # Baz çiftleri sayısı
@export var turns: float = 2.0  # Sarmalın dönüş sayısı
@export var radius: float = 1.0  # Sarmalın yarıçapı
@export var vertical_spacing: float = 0.3  # Dikey aralık
@export var rotation_speed: float = 0.5  # Dönüş hızı

# Bileşen boyutları
@export var sugar_size: float = 0.25  # Şeker molekülü boyutu
@export var phosphate_size: float = 0.2  # Fosfat molekülü boyutu
@export var base_size: float = 0.3  # Baz molekülü boyutu

# Renk parametreleri
@export var phosphate_color: Color = Color(1.0, 0.5, 0.0)  # Fosfat (turuncu)
@export var sugar_color: Color = Color(0.8, 0.8, 0.8)  # Şeker (gri)
@export var adenine_color: Color = Color(0.8, 0.0, 0.0)  # Adenin (kırmızı)
@export var thymine_color: Color = Color(0.0, 0.8, 0.0)  # Timin (yeşil)
@export var guanine_color: Color = Color(0.0, 0.0, 0.8)  # Guanin (mavi)
@export var cytosine_color: Color = Color(0.8, 0.8, 0.0)  # Sitozin (sarı)

# DNA yapısı için düğümler
var dna_container: Node3D

# Materyal ve mesh kaynakları
var phosphate_material: StandardMaterial3D
var sugar_material: StandardMaterial3D
var adenine_material: StandardMaterial3D
var thymine_material: StandardMaterial3D
var guanine_material: StandardMaterial3D
var cytosine_material: StandardMaterial3D
var hydrogen_bond_material: StandardMaterial3D

var sphere_mesh: SphereMesh
var cylinder_mesh: CylinderMesh

# Baz çiftleri dizilimi (rastgele veya özel)
var base_sequence = []

# Kamera referansı
var camera: Camera3D

# Zoom parametreleri
var min_zoom_distance: float = 5.0  # Minimum zoom mesafesi
var max_zoom_distance: float = 25.0  # Maximum zoom mesafesi
var zoom_sensitivity: float = 0.1  # Zoom hassasiyeti
var camera_distance: float = 15.0  # Başlangıç kamera mesafesi

# Dikey sürükleme parametreleri
var vertical_pan_sensitivity: float = 0.05  # Dikey kaydırma hassasiyeti
var min_vertical_position: float = 0.0  # Minimum dikey pozisyon
var max_vertical_position: float = 0.0  # Maximum dikey pozisyon (hazır fonksiyonunda değeri atanacak)

# Pinch zoom için değişkenler
var touch_points = {}  # Dokunma noktalarını takip etmek için
var last_pinch_distance: float = 0.0  # Son parmak aralığı mesafesi
var last_touch_position: Vector2 = Vector2.ZERO  # Son dokunma pozisyonu (tek parmak kaydırma için)

func _ready():
	# Materyalleri oluştur
	phosphate_material = StandardMaterial3D.new()
	phosphate_material.albedo_color = phosphate_color
	
	sugar_material = StandardMaterial3D.new()
	sugar_material.albedo_color = sugar_color
	
	adenine_material = StandardMaterial3D.new()
	adenine_material.albedo_color = adenine_color
	
	thymine_material = StandardMaterial3D.new()
	thymine_material.albedo_color = thymine_color
	
	guanine_material = StandardMaterial3D.new()
	guanine_material.albedo_color = guanine_color
	
	cytosine_material = StandardMaterial3D.new()
	cytosine_material.albedo_color = cytosine_color
	
	# Hidrojen bağı materyali (daha ince ve çizgili görünüm için)
	hydrogen_bond_material = StandardMaterial3D.new()
	hydrogen_bond_material.albedo_color = Color(0.9, 0.9, 0.9, 0.7)  # Beyazımsı ve yarı saydam
	hydrogen_bond_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Çizgili görünüm için texture ekleme
	var dash_texture = create_dash_texture()
	hydrogen_bond_material.albedo_texture = dash_texture
	hydrogen_bond_material.uv1_scale = Vector3(1.0, 10.0, 1.0)  # Texture'ı y ekseninde tekrarla
	
	# Geometrik şekilleri oluştur
	sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.2
	sphere_mesh.height = 0.4
	
	cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = 0.05
	cylinder_mesh.bottom_radius = 0.05
	cylinder_mesh.height = 1.0
	
	# Baz dizilimini oluştur (A-T, G-C eşleşmelerine dikkat ederek)
	generate_base_sequence()
	
	# DNA modelini oluştur
	dna_container = Node3D.new()
	# Modeli dikey olarak ortalamak için konumunu ayarla
	dna_container.transform.origin = Vector3(0, -base_pairs * vertical_spacing / 2, 0)
	add_child(dna_container)
	create_dna_model()
	
	# Maximum dikey pozisyonu ayarla
	max_vertical_position = base_pairs * vertical_spacing
	
	# Kamerayı ayarla (portrait mod için)
	camera = Camera3D.new()
	camera.transform.origin = Vector3(0, base_pairs * vertical_spacing / 2, camera_distance)
	camera.look_at(Vector3(0, base_pairs * vertical_spacing / 2, 0))
	camera.current = true
	add_child(camera)
	
	# Işıkları ekle - modelin ortasına doğru yönlendirilmiş
	add_light(Vector3(10, base_pairs * vertical_spacing / 2, 10))
	add_light(Vector3(-10, base_pairs * vertical_spacing / 2, 10))
	
	# Ortam ışığı ekleyerek tüm modelin görünür olmasını sağla
	var ambient_light = OmniLight3D.new()
	ambient_light.transform.origin = Vector3(0, base_pairs * vertical_spacing / 2, 0)
	ambient_light.omni_range = 20
	ambient_light.light_energy = 0.3
	add_child(ambient_light)
	
	# Dokunmatik girdi etkinleştirme
	Input.use_accumulated_input = false

# Çizgili (kesikli) texture oluştur
func create_dash_texture() -> ImageTexture:
	var img = Image.create(4, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))  # Tüm image'ı saydam yap
	
	# Kesikli çizgi oluştur (her 8 pikselde 4 piksel dolu, 4 piksel boş)
	for y in range(0, 8):
		for x in range(0, 4):
			img.set_pixel(x, y, Color(1, 1, 1, 1))  # Beyaz, opak
	
	var texture = ImageTexture.create_from_image(img)
	return texture

func _input(event):
	# Dokunmatik girdileri işle
	if event is InputEventScreenTouch:
		_handle_touch_event(event)
	elif event is InputEventScreenDrag:
		_handle_drag_event(event)

func _handle_touch_event(event: InputEventScreenTouch):
	# Dokunma başladığında veya bittiğinde parmak pozisyonlarını güncelle
	if event.pressed:
		# Yeni dokunma başladı, kaydet
		touch_points[event.index] = event.position
		
		# Tek parmak dokunması ise, pozisyonu kaydet
		if touch_points.size() == 1:
			last_touch_position = event.position
	else:
		# Dokunma bitti, kaldır
		touch_points.erase(event.index)
		
	# Eğer iki parmak dokunuyor ise, ilk mesafeyi kaydet
	if touch_points.size() == 2:
		var touch_positions = touch_points.values()
		last_pinch_distance = touch_positions[0].distance_to(touch_positions[1])

func _handle_drag_event(event: InputEventScreenDrag):
	# Sürükleme olayını güncelle
	touch_points[event.index] = event.position
	
	# İki parmakla sürükleme (pinch zoom)
	if touch_points.size() == 2:
		var touch_positions = touch_points.values()
		var current_pinch_distance = touch_positions[0].distance_to(touch_positions[1])
		
		# Son pinch mesafesi ile karşılaştır ve zoom uygula
		if last_pinch_distance > 0:
			var zoom_factor = (current_pinch_distance - last_pinch_distance) * zoom_sensitivity
			apply_zoom(zoom_factor)
		
		last_pinch_distance = current_pinch_distance
	
	# Tek parmakla dikey sürükleme
	elif touch_points.size() == 1:
		var delta_y = event.position.y - last_touch_position.y
		apply_vertical_pan(delta_y)
		last_touch_position = event.position

func apply_zoom(zoom_factor: float):
	# Kamera mesafesini güncelle (negatif faktör = yakınlaş, pozitif faktör = uzaklaş)
	camera_distance -= zoom_factor
	
	# Minimum ve maksimum sınırlar arasında tut
	camera_distance = clamp(camera_distance, min_zoom_distance, max_zoom_distance)
	
	# Kamera pozisyonunu güncelle (mesafeyi koruyarak)
	var camera_dir = (camera.transform.origin - Vector3(0, base_pairs * vertical_spacing / 2, 0)).normalized()
	camera.transform.origin = Vector3(0, base_pairs * vertical_spacing / 2, 0) + camera_dir * camera_distance
	
	# Her zaman merkeze bak
	camera.look_at(Vector3(0, base_pairs * vertical_spacing / 2, 0))

func apply_vertical_pan(delta_y: float):
	# Delta değerini ters çevir (aşağı sürükleme = yukarı hareket)
	var vertical_offset = delta_y * vertical_pan_sensitivity
	
	# DNA konteyneri pozisyonunu güncelle
	dna_container.transform.origin.y -= vertical_offset
	
	# Sınırları kontrol et
	var current_y = dna_container.transform.origin.y
	dna_container.transform.origin.y = clamp(current_y, -max_vertical_position, min_vertical_position)
	
	# Kameranın bakış yönünü güncelle
	update_camera_target()

func update_camera_target():
	# DNA'nın görünür merkez noktasını hesapla
	var dna_visible_center = Vector3(0, -dna_container.transform.origin.y + base_pairs * vertical_spacing / 2, 0)
	
	# Kamerayı bu noktaya baktır
	camera.look_at(dna_visible_center)
	
	# Kameranın pozisyonunu da güncelle (mesafeyi koruyarak)
	var camera_dir = (camera.transform.origin - dna_visible_center).normalized()
	camera.transform.origin = dna_visible_center + camera_dir * camera_distance

func add_light(position: Vector3):
	var light = DirectionalLight3D.new()
	light.transform.origin = position
	# Işığı DNA'nın merkezine yönlendir
	light.look_at(Vector3(0, base_pairs * vertical_spacing / 2, 0), Vector3.UP)
	add_child(light)

func generate_base_sequence():
	# Rastgele bir baz dizilimi oluştur
	base_sequence.clear()
	
	for i in range(base_pairs):
		# Rastgele bir baz çifti seç
		var random_pair = randi() % 2
		
		if random_pair == 0:
			# A-T çifti
			base_sequence.append(["A", "T"])
		else:
			# G-C çifti
			base_sequence.append(["G", "C"])

func create_dna_model():
	# DNA sarmalı oluştur
	for i in range(base_pairs):
		# Sarmalın açısını hesapla
		var angle = (float(i) / base_pairs) * turns * 2.0 * PI
		var height = i * vertical_spacing
		
		# Birinci sarmal noktası
		var strand1_pos = Vector3(
			radius * cos(angle),
			height,
			radius * sin(angle)
		)
		
		# İkinci sarmal noktası (180 derece açıyla)
		var strand2_pos = Vector3(
			radius * cos(angle + PI),
			height,
			radius * sin(angle + PI)
		)
		
		# Şeker ve fosfat pozisyonları (sarmalın biraz içinde)
		var inward_offset = 0.3
		var sugar1_pos = strand1_pos - (strand1_pos.normalized() * inward_offset)
		var sugar2_pos = strand2_pos - (strand2_pos.normalized() * inward_offset)
		
		# Fosfat pozisyonları (şekerden biraz yukarıda)
		var phosphate_offset_y = 0.25
		var phosphate1_pos
		var phosphate2_pos
		
		if i > 0:
			# Bir önceki şeker pozisyonu ile şimdiki arasındaki yönü hesapla
			var prev_sugar1_pos = Vector3(
				radius * cos((float(i-1) / base_pairs) * turns * 2.0 * PI),
				(i-1) * vertical_spacing,
				radius * sin((float(i-1) / base_pairs) * turns * 2.0 * PI)
			) - (Vector3(
				radius * cos((float(i-1) / base_pairs) * turns * 2.0 * PI),
				(i-1) * vertical_spacing,
				radius * sin((float(i-1) / base_pairs) * turns * 2.0 * PI)
			).normalized() * inward_offset)
			
			var prev_sugar2_pos = Vector3(
				radius * cos((float(i-1) / base_pairs) * turns * 2.0 * PI + PI),
				(i-1) * vertical_spacing,
				radius * sin((float(i-1) / base_pairs) * turns * 2.0 * PI + PI)
			) - (Vector3(
				radius * cos((float(i-1) / base_pairs) * turns * 2.0 * PI + PI),
				(i-1) * vertical_spacing,
				radius * sin((float(i-1) / base_pairs) * turns * 2.0 * PI + PI)
			).normalized() * inward_offset)
			
			# Şekerlerden fosfata olan mesafenin ortasını hesapla
			phosphate1_pos = (sugar1_pos + prev_sugar1_pos) / 2
			phosphate2_pos = (sugar2_pos + prev_sugar2_pos) / 2
			
			# Fosfat gruplarını ekle
			add_component(phosphate1_pos, phosphate_size, phosphate_material)
			add_component(phosphate2_pos, phosphate_size, phosphate_material)
			
			# Şeker-fosfat bağlantılarını ekle
			add_bond(sugar1_pos, phosphate1_pos)
			add_bond(prev_sugar1_pos, phosphate1_pos)
			add_bond(sugar2_pos, phosphate2_pos)
			add_bond(prev_sugar2_pos, phosphate2_pos)
		
		# Şeker moleküllerini ekle
		add_component(sugar1_pos, sugar_size, sugar_material)
		add_component(sugar2_pos, sugar_size, sugar_material)
		
		# Baz çiftlerini ekle
		var pair = base_sequence[i]
		
		# Baz pozisyonları (şekerden biraz içeri doğru)
		var base_inward = 0.6
		var base1_pos = sugar1_pos + (strand2_pos - strand1_pos).normalized() * base_inward
		var base2_pos = sugar2_pos + (strand1_pos - strand2_pos).normalized() * base_inward
		
		# Bazları ekle
		add_base(base1_pos, pair[0])
		add_base(base2_pos, pair[1])
		
		# Şeker-baz bağlantılarını ekle
		add_bond(sugar1_pos, base1_pos)
		add_bond(sugar2_pos, base2_pos)
		
		# Baz-baz bağlantılarını ekle (hidrojen bağları)
		add_hydrogen_bonds(base1_pos, base2_pos, pair[0], pair[1])

func add_component(position: Vector3, size: float, material: Material):
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = sphere_mesh
	mesh_instance.material_override = material
	mesh_instance.transform.origin = position
	mesh_instance.scale = Vector3(size, size, size)
	dna_container.add_child(mesh_instance)

func add_base(position: Vector3, base_type: String):
	var material
	var size_multiplier = 1.0
	
	# Baz tipine göre materyal seç
	match base_type:
		"A":
			material = adenine_material
			size_multiplier = 1.2  # Adenin biraz daha büyük
		"T":
			material = thymine_material
		"G":
			material = guanine_material
			size_multiplier = 1.2  # Guanin biraz daha büyük
		"C":
			material = cytosine_material
	
	# Bazı ekle
	add_component(position, base_size * size_multiplier, material)

func add_bond(pos1: Vector3, pos2: Vector3, is_hydrogen: bool = false):
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = cylinder_mesh
	
	# Hidrojen bağları için farklı materyal
	if is_hydrogen:
		mesh_instance.material_override = hydrogen_bond_material
	else:
		var bond_material = StandardMaterial3D.new()
		bond_material.albedo_color = Color(0.7, 0.7, 0.7)  # Gri
		mesh_instance.material_override = bond_material
	
	# İki nokta arasındaki mesafeyi hesapla
	var distance = pos1.distance_to(pos2)
	
	# Yönlendirme için bakmak (look_at) fonksiyonu kullanılamaz, manuel hesaplama gerekli
	var diff = pos2 - pos1
	var center = (pos1 + pos2) / 2
	
	# Silindiri pozisyonla ve döndür
	mesh_instance.transform.origin = center
	
	# Silindirin uzunluğunu ve yönünü ayarla
	var y_axis = diff.normalized()
	var x_axis
	if abs(y_axis.dot(Vector3.UP)) < 0.99:
		x_axis = y_axis.cross(Vector3.UP).normalized()
	else:
		x_axis = y_axis.cross(Vector3.RIGHT).normalized()
	var z_axis = x_axis.cross(y_axis).normalized()
	
	var basis = Basis(x_axis, y_axis, z_axis)
	mesh_instance.transform.basis = basis
	
	# Silindir uzunluğunu ayarla
	mesh_instance.scale.y = distance
	
	# Hidrojen bağları için daha ince silindir
	if is_hydrogen:
		mesh_instance.scale.x = 0.2  # Daha da ince
		mesh_instance.scale.z = 0.2  # Daha da ince
	else:
		mesh_instance.scale.x = 0.5
		mesh_instance.scale.z = 0.5
	
	dna_container.add_child(mesh_instance)

func add_hydrogen_bonds(pos1: Vector3, pos2: Vector3, base1: String, base2: String):
	# Baz çiftine göre hidrojen bağı sayısı
	var num_bonds
	if (base1 == "A" and base2 == "T") or (base1 == "T" and base2 == "A"):
		num_bonds = 2  # A-T çifti 2 hidrojen bağı
	else:
		num_bonds = 3  # G-C çifti 3 hidrojen bağı
	
	# Bağları düzenli aralıklarla yerleştir
	var bond_spacing = 0.15
	var start_offset = -((num_bonds - 1) * bond_spacing) / 2
	
	for i in range(num_bonds):
		# Bazların ortasında bir vektör oluştur
		var mid_vector = (pos2 - pos1).normalized()
		# Ortaya dik bir vektör bul
		var perpendicular
		if abs(mid_vector.dot(Vector3.UP)) < 0.99:
			perpendicular = mid_vector.cross(Vector3.UP).normalized()
		else:
			perpendicular = mid_vector.cross(Vector3.RIGHT).normalized()
		
		# Hidrojen bağının yerini hesapla
		var offset = start_offset + (i * bond_spacing)
		var offset_vector = perpendicular * offset
		
		# Pozisyonları hesapla
		var bond_pos1 = pos1 + offset_vector
		var bond_pos2 = pos2 + offset_vector
		
		# Hidrojen bağını ekle
		add_bond(bond_pos1, bond_pos2, true)

func _process(delta):
	# DNA modelini döndür
	dna_container.rotate_y(rotation_speed * delta)
