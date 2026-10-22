extends RefCounted

## The best star count earned on each level, kept between sessions. A level is identified
## by its entry in the level list: a scene's res:// path, or a level file's name.

const FILE := "user://progress.cfg"
const SECTION := "stars"


static func stars(entry: String) -> int:
	var config := ConfigFile.new()
	if config.load(FILE) != OK:
		return 0
	return clampi(int(config.get_value(SECTION, entry, 0)), 0, 3)


## Remembers `count` stars for the level if it beats the best so far.
static func record(entry: String, count: int) -> void:
	if entry.is_empty() or count <= stars(entry):
		return
	var config := ConfigFile.new()
	config.load(FILE)
	config.set_value(SECTION, entry, clampi(count, 0, 3))
	config.save(FILE)
