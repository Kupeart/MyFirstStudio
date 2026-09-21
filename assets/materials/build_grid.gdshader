shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// רצפת הבנייה של הסטודיו: משטח שקט עם קווי גריד דקים.
//
// חשוב: הקווים מחושבים במיקום *עולמי* (world space), כדי שהרצפה תהיה
// נעולה למרחב ותזוז על המסך יחד עם כל שאר העצמים כשהמצלמה זזה.
// אסור להשתמש ב-VERTEX בתוך fragment(): שם הוא נמצא במרחב המצלמה
// (view space), ואז הגריד נדבק למסך ולא זז עם העולם.
// הקווים גם לא "נמתחים" בזום, כי הרוחב שלהם נמדד בפיקסלים (fwidth).

uniform vec3 base_color : source_color = vec3(0.78, 0.82, 0.74);
uniform vec3 line_color : source_color = vec3(0.45, 0.52, 0.46);
uniform vec3 major_line_color : source_color = vec3(0.32, 0.40, 0.34);

// גודל תא בגריד במטרים - חייב להתאים לגריד ההצמדה של המנוע
uniform float cell_size = 0.5;
// כל כמה תאים מציירים קו מודגש
uniform float major_every = 4.0;
// עוצמת הקווים
uniform float line_strength : hint_range(0.0, 1.0) = 0.75;
// ממרחקים אלה (במטרים) הקווים דוהים, כדי שהמרחב לא ייגמר בקצה חד.
uniform float fade_start = 50.0;
uniform float fade_end = 110.0;

// מיקום הפיקסל במרחב העולם, עובר מהצלעות לפרגמנט.
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cells = world_pos.xz / cell_size;

	// מרחק מהקו הקרוב ביותר, ביחידות פיקסל - עמיד לשינויי זום
	vec2 grid = abs(fract(cells - 0.5) - 0.5) / fwidth(cells);
	float thin = 1.0 - min(min(grid.x, grid.y), 1.0);

	// קווי הגריד המודגשים כל major_every תאים
	vec2 major_cells = cells / major_every;
	vec2 major_grid = abs(fract(major_cells - 0.5) - 0.5) / fwidth(major_cells);
	float major = 1.0 - min(min(major_grid.x, major_grid.y), 1.0);

	// דהייה עם המרחק מהמצלמה, כדי שהרצפה תיבלע באופק ולא תיגמר בקו חד
	float fade = 1.0 - smoothstep(fade_start, fade_end, length(world_pos - CAMERA_POSITION_WORLD));

	vec3 col = mix(base_color, line_color, thin * line_strength * fade);
	col = mix(col, major_line_color, major * 0.5 * fade);

	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
}
