shader_type canvas_item;

// Warna efek di pinggir layar (Merah Gelap)
uniform vec4 vignette_color : source_color = vec4(0.8, 0.0, 0.0, 1.0);

// Area tengah yang benar-benar bening (0.0 sampai 1.0)
uniform float inner_radius = 0.35; 

// Batas pinggir tempat warna merah paling pekat
uniform float outer_radius = 0.85; 

void fragment() {
	// Menghitung jarak dari titik tengah layar (UV 0.5, 0.5)
	float dist = distance(UV, vec2(0.5, 0.5));
	
	// Membuat gradasi halus dari tengah ke pinggir
	float vignette = smoothstep(inner_radius, outer_radius, dist);
	
	// Hasil akhir: Warna merah di pinggir, dikalikan dengan animasi transparansi dari Skrip Tween Anda (COLOR.a)
	COLOR = vec4(vignette_color.rgb, vignette * COLOR.a);
}