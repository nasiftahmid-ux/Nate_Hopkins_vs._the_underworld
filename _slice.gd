extends SceneTree
## Slices AI-generated label+frames sprite sheets into uniform, bleed-free atlases
## plus SpriteFrames resources.
##
## Strategy (tuned for these sheets):
##  1. Detect horizontal bands from the row-ink profile; drop bands far shorter than
##     the median band (stray speck rows). Detection uses a strict alpha threshold so
##     faint anti-aliasing cannot bridge two rows into one band.
##  2. Strip the left-hand label by consuming leading columns whose vertical ink span
##     is small relative to the band height. Empty columns inside the label text are
##     tolerated, so this works for solid bars, real glyph text, and labels fused to
##     frame 1.
##  3. Cut the remaining content into exactly N frames at the N-1 widest internal
##     empty gaps, ignoring the empty margin outside the content. These sheets have
##     irregular spacing, so a fixed gap width is unreliable; "widest N-1 gaps" is
##     stable and is cross-checked against the frame counts we asked the generator for.
##  4. Repack left-aligned on a shared bottom baseline, so feet never drift and an
##     attack can extend to the right without shifting the body.

const ALPHA_MIN := 24                  ## detection threshold; loose enough to ignore faint AA
const BAND_JUNK_RATIO := 0.35          ## bands shorter than this * median band height are junk
const LABEL_SPAN_RATIO := 0.45         ## a column counts as label if its ink spans < this * band height
const LABEL_MAX_WIDTH_RATIO := 0.55    ## the label may never exceed this fraction of the content width

const JOBS := {
	"cinder_imp": {
		"src": "res://assets/cinder_imp.png",
		"sheet": "res://assets/cinder_imp_sheet.png",
		"tres": "res://scenes/enemies/cinder_imp_frames.tres",
		"rows": [
			{"name": "idle", "n": 4, "speed": 8.0, "loop": true},
			{"name": "run", "n": 6, "speed": 12.0, "loop": true},
			{"name": "attack", "n": 4, "speed": 14.0, "loop": false},
			{"name": "dodge", "n": 4, "speed": 14.0, "loop": false},
			{"name": "hurt", "n": 2, "speed": 10.0, "loop": false},
			{"name": "death", "n": 5, "speed": 8.0, "loop": false},
		],
	},
	"teardrop_shooter": {
		"src": "res://assets/teardrop_shooter.png",
		"sheet": "res://assets/teardrop_shooter_sheet.png",
		"tres": "res://scenes/enemies/teardrop_shooter_frames.tres",
		"rows": [
			{"name": "idle", "n": 4, "speed": 8.0, "loop": true},
			{"name": "run", "n": 6, "speed": 12.0, "loop": true},
			{"name": "shoot", "n": 5, "speed": 12.0, "loop": false},
			{"name": "retreat", "n": 4, "speed": 12.0, "loop": true},
			{"name": "hurt", "n": 2, "speed": 10.0, "loop": false},
			{"name": "death", "n": 5, "speed": 8.0, "loop": false},
		],
	},
	"sorrow_knight": {
		"src": "res://assets/sorrow_knight.png",
		"sheet": "res://assets/sorrow_knight_sheet.png",
		"tres": "res://scenes/enemies/sorrow_knight_frames.tres",
		## The generator returned 6 rows where 8 were asked for. Measured content
		## puts them at: 0 idle, 1 walk, 2 attack (holds the widest frame), 3
		## recovery (the distinctly short row), 4 hurt, 5 death. There is no
		## separate guard row, so blocking reuses idle, and the windup replays the
		## swing backwards to get the coil-then-strike anticipation.
		"rows": [
			{"name": "idle", "band": 0, "n": 4, "speed": 7.0, "loop": true},
			{"name": "walk", "band": 1, "n": 7, "speed": 12.0, "loop": true},
			{"name": "windup", "band": 2, "n": 4, "reverse": true, "speed": 13.0, "loop": false},
			{"name": "swing", "band": 2, "n": 4, "speed": 20.0, "loop": false},
			{"name": "recovery", "band": 3, "n": 4, "speed": 7.0, "loop": true},
			{"name": "hurt", "band": 4, "n": 2, "speed": 10.0, "loop": false},
			{"name": "death", "band": 5, "n": 6, "speed": 8.0, "loop": false},
		],
	},
}


func _initialize() -> void:
	var only: Array = OS.get_cmdline_user_args()
	for key in JOBS.keys():
		if only.is_empty() or only.has(key):
			sheetify(String(key), JOBS[key])
	quit()


func _has_ink(d: PackedByteArray, w: int, y: int, x: int) -> bool:
	return d[(y * w + x) * 4 + 3] > ALPHA_MIN


func _col_ink(d: PackedByteArray, w: int, y0: int, y1: int, x: int) -> int:
	var n := 0
	for y in range(y0, y1 + 1):
		if _has_ink(d, w, y, x):
			n += 1
	return n


func _col_span(d: PackedByteArray, w: int, y0: int, y1: int, x: int) -> int:
	var lo := -1
	var hi := -1
	for y in range(y0, y1 + 1):
		if _has_ink(d, w, y, x):
			if lo < 0:
				lo = y
			hi = y
	if lo < 0:
		return 0
	return hi - lo + 1


func _content_x(d: PackedByteArray, w: int, y0: int, y1: int) -> Array:
	var first := -1
	var last := -1
	for x in range(w):
		if _col_ink(d, w, y0, y1, x) > 0:
			if first < 0:
				first = x
			last = x
	return [first, last]


func _find_bands(d: PackedByteArray, w: int, h: int) -> Array:
	var raw: Array = []
	var start := -1
	for y in range(h):
		var any := false
		for x in range(w):
			if _has_ink(d, w, y, x):
				any = true
				break
		if any:
			if start < 0:
				start = y
		elif start >= 0:
			raw.append([start, y - 1])
			start = -1
	if start >= 0:
		raw.append([start, h - 1])

	var heights: Array = []
	for b in raw:
		heights.append(b[1] - b[0] + 1)
	heights.sort()
	var median: float = heights[heights.size() / 2]

	var out: Array = []
	for b in raw:
		var bh: float = b[1] - b[0] + 1
		if bh >= median * BAND_JUNK_RATIO:
			out.append(b)
		else:
			print("      (dropping junk band y=%d..%d h=%d)" % [b[0], b[1], int(bh)])
	return out


func _label_end(d: PackedByteArray, w: int, y0: int, y1: int, first: int, last: int) -> int:
	## First x that belongs to real frame content.
	## Label columns have a small vertical ink span. Take the FIRST connected group of
	## such columns (bridging small gaps so glyphs stay one group) and stop at its end.
	## We deliberately do not walk past empty columns: that would run through the gap
	## after the label and nibble into frame 0.
	var bh: float = y1 - y0 + 1
	var bridge: int = int(bh * 0.15)
	var group_start := -1
	var group_end := -1
	var pending_end := -1
	for x in range(first, last + 1):
		var is_label := false
		if _col_ink(d, w, y0, y1, x) > 0 and _col_span(d, w, y0, y1, x) < bh * LABEL_SPAN_RATIO:
			is_label = true
		if is_label:
			if group_start < 0:
				group_start = x
			group_end = x
			pending_end = x
		elif group_start >= 0 and x - pending_end > bridge:
			break
	if group_start < 0:
		return first
	if group_end - group_start + 1 < 3:
		return first
	if (group_end - group_start + 1) > (last - first + 1) * LABEL_MAX_WIDTH_RATIO:
		return first
	return _trim_label(d, w, y0, y1, first, group_end + 1)


func _trim_label(d: PackedByteArray, w: int, y0: int, y1: int, first: int, cut: int) -> int:
	## Second label pass, walking backwards.
	## A label can be fused to frame 0, and a low ink span alone overshoots: a
	## raised sword or a cape edge is thin enough to read as text. So take the
	## y-range of the label core (far left, definitely caption) and walk back from
	## the candidate cut, dropping any column whose ink escapes that y-range.
	var bh: float = y1 - y0 + 1
	var core_end: int = mini(cut, first + 150)
	var cy0 := -1
	var cy1 := -1
	for x in range(first, core_end):
		var yr := _col_y_range(d, w, y0, y1, x)
		if yr[0] < 0:
			continue
		if cy0 < 0 or yr[0] < cy0:
			cy0 = yr[0]
		if yr[1] > cy1:
			cy1 = yr[1]
	if cy0 < 0:
		return cut
	var tol: int = int(bh * 0.08)
	var lo: int = cy0 - tol
	var hi: int = cy1 + tol
	var out := cut
	for x in range(cut - 1, first - 1, -1):
		var yr := _col_y_range(d, w, y0, y1, x)
		if yr[0] < 0:
			continue  # empty column: keep walking back toward the core
		if yr[0] < lo or yr[1] > hi:
			out = x + 1
			break
	return out


## [y_min, y_max] of the ink in a column, or [-1, -1] when the column is empty.
func _col_y_range(d: PackedByteArray, w: int, y0: int, y1: int, x: int) -> Array:
	var mn := -1
	var mx := -1
	for y in range(y0, y1 + 1):
		if _has_ink(d, w, y, x):
			if mn < 0:
				mn = y
			mx = y
	return [mn, mx]


func _internal_gaps(d: PackedByteArray, w: int, y0: int, y1: int, x_from: int, x_to: int) -> Array:
	## [[width, start, end_exclusive], ...] for every empty column run inside the content.
	var out: Array = []
	var run := -1
	for x in range(x_from, x_to + 1):
		var empty := _col_ink(d, w, y0, y1, x) == 0
		if empty and run < 0:
			run = x
		elif not empty and run >= 0:
			out.append([x - run, run, x])
			run = -1
	if run >= 0:
		out.append([x_to - run + 1, run, x_to + 1])
	return out


func sheetify(key: String, job: Dictionary) -> void:
	print("\n########## ", key, " ##########")
	var img := Image.load_from_file(job["src"])
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var d := img.get_data()
	print("   source %dx%d" % [w, h])

	var bands := _find_bands(d, w, h)
	print("   usable bands: %d" % bands.size())

	var rows: Array = job["rows"]
	var claimed := {}
	for i in range(rows.size()):
		claimed[int(rows[i].get("band", i))] = true
	if bands.size() != claimed.size():
		printerr("   !! %d usable bands vs %d distinct band claims" % [bands.size(), claimed.size()])

	# A band is sliced once, on the first row that claims it. Later rows may claim
	# the same band to reuse those frames (the knight's windup replays the swing
	# backwards), which is why rows carry an explicit "band".
	var frames: Array = []
	var sliced: Dictionary = {}
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var bi: int = int(row.get("band", i))
		if sliced.has(bi):
			continue
		if bi >= bands.size():
			printerr("   !! %s: band %d does not exist" % [row["name"], bi])
			continue
		var y0: int = bands[bi][0]
		var y1: int = bands[bi][1]
		var n: int = row["n"]

		var cx: Array = _content_x(d, w, y0, y1)
		var first: int = cx[0]
		var last: int = cx[1]
		if first < 0:
			printerr("   !! %s: empty band" % row["name"])
			continue
		var cut := _label_end(d, w, y0, y1, first, last)
		var content_first := -1
		var content_last := -1
		for x in range(cut, last + 1):
			if _col_ink(d, w, y0, y1, x) > 0:
				if content_first < 0:
					content_first = x
				content_last = x
		if content_first < 0:
			printerr("   !! %s: no content after label" % row["name"])
			continue

		var gaps := _internal_gaps(d, w, y0, y1, content_first, content_last)
		print("   band %d (%s)  label x%d..%d  content x%d..%d  gaps=%d (want %d)"
			% [bi, row["name"], first, cut - 1, content_first, content_last, gaps.size(), n - 1])
		if gaps.size() != n - 1:
			printerr("   !! band %d: %d internal gaps for %d frames" % [bi, gaps.size(), n])

		gaps.sort_custom(func(a, b): return a[0] > b[0])
		var chosen: Array = gaps.slice(0, mini(n - 1, gaps.size()))
		chosen.sort_custom(func(a, b): return a[1] < b[1])

		var bounds: Array = []
		var edge := content_first
		for g in chosen:
			bounds.append([edge, g[1] - 1])
			edge = g[2]
		bounds.append([edge, content_last])

		var got := 0
		var band_frames: Array = []
		for bd in bounds:
			var fy0 := -1
			var fy1 := -1
			var fx0 := -1
			var fx1 := -1
			for x in range(bd[0], bd[1] + 1):
				if _col_ink(d, w, y0, y1, x) > 0:
					if fx0 < 0:
						fx0 = x
					fx1 = x
			if fx0 < 0:
				continue
			for y in range(y0, y1 + 1):
				var any := false
				for x in range(fx0, fx1 + 1):
					if _has_ink(d, w, y, x):
						any = true
						break
				if any:
					if fy0 < 0:
						fy0 = y
					fy1 = y
			var fw: int = fx1 - fx0 + 1
			var fh: int = fy1 - fy0 + 1
			print("         frame %d  x=%4d..%4d y=%4d..%4d  %dx%d" % [got, fx0, fx1, fy0, fy1, fw, fh])
			band_frames.append({"name": String(row["name"]), "band": bi, "x0": fx0, "y0": fy0, "w": fw, "h": fh})
			got += 1
		sliced[bi] = band_frames
		frames.append_array(band_frames)
		if got != n:
			printerr("   !! %s: produced %d frames, expected %d" % [row["name"], got, n])

	# ---- pack -----------------------------------------------------------
	if frames.is_empty():
		printerr("   !! no frames extracted")
		return
	var cell_w := 0
	var cell_h := 0
	for f in frames:
		cell_w = maxi(cell_w, f["w"])
		cell_h = maxi(cell_h, f["h"])
	var cols: int = maxi(1, int(ceil(sqrt(float(frames.size())))))
	var grid_rows: int = int(ceil(float(frames.size()) / float(cols)))
	print("   cell %dx%d  frames=%d  grid %dx%d" % [cell_w, cell_h, frames.size(), cols, grid_rows])

	var out := Image.create_empty(cell_w * cols, cell_h * grid_rows, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))

	var placed: Array = []
	for i in range(frames.size()):
		var f: Dictionary = frames[i]
		var cx: int = (i % cols) * cell_w
		var cy: int = int(i / cols) * cell_h
		var ox: int = cx + int((cell_w - int(f["w"])) / 2.0)  # centred: keeps the body on the node origin
		var oy: int = cy + cell_h - int(f["h"])               # bottom aligned: feet on one line
		out.blit_rect(img, Rect2i(f["x0"], f["y0"], f["w"], f["h"]), Vector2i(ox, oy))
		placed.append({"cx": cx, "cy": cy, "band": f["band"], "name": f["name"]})
		print("      band%d %-9s cell(%4d,%4d) src(%4d,%4d %dx%d)" % [f["band"], f["name"], cx, cy, f["x0"], f["y0"], f["w"], f["h"]])

	print("   wrote %s (%dx%d)" % [ProjectSettings.globalize_path(job["sheet"]), out.get_width(), out.get_height()])
	out.save_png(ProjectSettings.globalize_path(job["sheet"]))

	# ---- verify pixel-exactness ----------------------------------------
	var bad := 0
	for i in range(frames.size()):
		var f: Dictionary = frames[i]
		var p: Dictionary = placed[i]
		var ox: int = int(p["cx"]) + int((cell_w - int(f["w"])) / 2.0)
		var oy: int = int(p["cy"]) + cell_h - int(f["h"])
		for yy in range(int(f["h"])):
			for xx in range(int(f["w"])):
				if img.get_pixel(int(f["x0"]) + xx, int(f["y0"]) + yy) != out.get_pixel(ox + xx, oy + yy):
					bad += 1
	print("   pixel mismatches: %d  (0 == lossless)" % bad)

	write_tres(job, placed, cell_w, cell_h)


## Builds the SpriteFrames text. Sub-resources are derived per animation row so a
## row can reuse another band's cells (optionally reversed) and still get its own
## ordered list of frames.
func write_tres(job: Dictionary, placed: Array, cell_w: int, cell_h: int) -> void:
	var subs: Array = []
	var blocks: Array = []
	var total_subs := 0
	for i in range(job["rows"].size()):
		var row: Dictionary = job["rows"][i]
		var name: String = row["name"]
		var bi: int = int(row.get("band", i))
		var members: Array = placed.filter(func(p): return int(p["band"]) == bi)
		if members.is_empty():
			printerr("   !! row '%s' has no frames (band %d)" % [name, bi])
			continue
		if bool(row.get("reverse", false)):
			members.reverse()
		var refs: Array = []
		for j in range(members.size()):
			var id := "AT_%s_%d" % [name, j]
			subs.append({
				"id": id,
				"cx": int(members[j]["cx"]),
				"cy": int(members[j]["cy"]),
			})
			refs.append("{\"duration\":1.0,\"texture\":SubResource(\"%s\")}" % id)
			total_subs += 1
		blocks.append("\n".join([
			"\"frames\":[%s]," % ", ".join(refs),
			"\"loop\":%s," % ("true" if row["loop"] else "false"),
			"\"name\":&\"%s\"," % name,
			"\"speed\":%.1f" % row["speed"],
		]) + "\n}")
		print("   anim %-9s %d frames%s  speed=%.1f loop=%s"
			% [name, members.size(), " (reversed)" if bool(row.get("reverse", false)) else "", row["speed"], str(row["loop"])])

	var lines: Array = []
	lines.append("[gd_resource type=\"SpriteFrames\" load_steps=%d format=3]" % (total_subs + 2))
	lines.append("")
	lines.append("[ext_resource type=\"Texture2D\" path=\"%s\" id=\"tex1\"]" % job["sheet"])
	lines.append("")
	for s in subs:
		lines.append("[sub_resource type=\"AtlasTexture\" id=\"%s\"]" % s["id"])
		lines.append("atlas = ExtResource(\"tex1\")")
		lines.append("region = Rect2(%d, %d, %d, %d)" % [s["cx"], s["cy"], cell_w, cell_h])
		lines.append("filter_clip = true")
		lines.append("")
	lines.append("[resource]")
	lines.append("animations=[{")
	lines.append(",\n{".join(blocks))
	lines.append("]")

	var abs_path := ProjectSettings.globalize_path(job["tres"])
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("   wrote %s" % abs_path)
