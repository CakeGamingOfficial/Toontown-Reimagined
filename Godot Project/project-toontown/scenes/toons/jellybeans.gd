extends RefCounted

## Jellybeans are a toon's money. The pouch (DistributedToon.money) holds up to
## 40. DistributedToonAI.addMoney puts anything past that into the estate bank,
## which holds up to ToontownGlobals.DefaultMaxBankMoney. The catalog spends
## these later. take_beans is the purchase path (takeMoney).

const POUCH_MAX := 40
const BANK_MAX := 12000
const _PATH := "user://jellybeans.json"

static var _loaded := false
static var _pouch: Array[int] = []
static var _bank: Array[int] = []


static func pouch() -> int:
	_ensure()
	return _value(_pouch)


static func bank() -> int:
	_ensure()
	return _value(_bank)


static func add_beans(amount: int) -> void:
	if amount == 0:
		return
	_ensure()
	var slot := _slot()
	if slot < 0:
		return
	var money := _pouch[slot] + amount
	var pocket := mini(money, POUCH_MAX)
	_pouch[slot] = maxi(pocket, 0)
	var overflow := money - POUCH_MAX
	if overflow > 0:
		_bank[slot] = mini(_bank[slot] + overflow, BANK_MAX)
	_write()


static func take_beans(amount: int, use_bank: bool = true) -> bool:
	if amount <= 0:
		return true
	_ensure()
	var slot := _slot()
	if slot < 0:
		return false
	var total := _pouch[slot]
	if use_bank:
		total += _bank[slot]
	if amount > total:
		return false
	if use_bank and amount > _pouch[slot]:
		_bank[slot] -= amount - _pouch[slot]
		_pouch[slot] = 0
	else:
		_pouch[slot] -= amount
	_write()
	return true


## BankGui.__updateTransaction. Positive moves jellybeans from the pouch into
## the bank. Negative withdraws them back into the pouch.
static func transfer(amount: int) -> void:
	var moved := clamp_transfer(amount)
	if moved == 0:
		return
	var slot := _slot()
	_pouch[slot] -= moved
	_bank[slot] += moved
	_write()


static func clamp_transfer(amount: int) -> int:
	_ensure()
	var slot := _slot()
	if slot < 0:
		return 0
	var carried := _pouch[slot]
	var saved := _bank[slot]
	amount = mini(amount, carried)
	amount = mini(amount, BANK_MAX - saved)
	amount = -mini(-amount, POUCH_MAX - carried)
	amount = -mini(-amount, saved)
	return amount


static func reset_slot(index: int) -> void:
	_ensure()
	if index < 0 or index >= ToonRoster.SLOT_COUNT:
		return
	_pouch[index] = 0
	_bank[index] = 0
	_write()


static func _value(values: Array[int]) -> int:
	var slot := _slot()
	if slot < 0:
		return 0
	return values[slot]


static func _slot() -> int:
	var index := ToonRoster.selected_index()
	if index < 0 or index >= ToonRoster.SLOT_COUNT:
		return -1
	return index


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_pouch.resize(ToonRoster.SLOT_COUNT)
	_bank.resize(ToonRoster.SLOT_COUNT)
	_pouch.fill(0)
	_bank.fill(0)
	if not FileAccess.file_exists(_PATH):
		return
	var file := FileAccess.open(_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var root: Dictionary = parsed
	var stored: Array = root.get("slots", [])
	for index in mini(stored.size(), ToonRoster.SLOT_COUNT):
		var entry: Variant = stored[index]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = entry
		_pouch[index] = clampi(int(row.get("pouch", 0)), 0, POUCH_MAX)
		_bank[index] = clampi(int(row.get("bank", 0)), 0, BANK_MAX)


static func _write() -> void:
	var slots: Array = []
	for index in ToonRoster.SLOT_COUNT:
		slots.append({"pouch": _pouch[index], "bank": _bank[index]})
	var file := FileAccess.open(_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"slots": slots}))
