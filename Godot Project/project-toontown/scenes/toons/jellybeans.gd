extends RefCounted

## Jellybeans are a toon's money. A new toon carries 40 (QuestRewardCounter).
## ToonTasks raise that jar, and the last reward is 250. DistributedToonAI.addMoney
## puts anything past the jar into the estate bank, which holds up to
## ToontownGlobals.DefaultMaxBankMoney. Beans the bank cannot hold spill into
## the jellybean vault, once Banker Bob has opened one. take_beans is the
## purchase path (takeMoney) and spends the vault after the bank.

const START_POUCH := 40
const POUCH_MAX := 250
const BANK_MAX := 12000
## Each row is the next vault you can buy. capacity is how many jellybeans
## that vault holds, and cost is the price to go from the previous size to
## this one. The first row opens a vault. Later rows are the upgrades.
const VAULT_TIERS: Array[Dictionary] = [
	{"capacity": 25000, "cost": 10000},
]
const _PATH := "user://jellybeans.json"

static var _loaded := false
static var _pouch: Array[int] = []
static var _bank: Array[int] = []
static var _limit: Array[int] = []
static var _vault: Array[int] = []
static var _vault_tier: Array[int] = []


static func pouch() -> int:
	_ensure()
	return _value(_pouch)


static func bank() -> int:
	_ensure()
	return _value(_bank)


static func vault() -> int:
	_ensure()
	return _value(_vault)


static func vault_tier() -> int:
	_ensure()
	return _value(_vault_tier)


static func vault_limit() -> int:
	return _vault_capacity(vault_tier())


## The next size for sale. Empty when this toon already has the biggest vault.
static func next_vault() -> Dictionary:
	_ensure()
	var tier := vault_tier()
	if tier < 0 or tier >= VAULT_TIERS.size():
		return {}
	return VAULT_TIERS[tier]


## Pays for the next vault from the jar, the bank, and the vault already open.
static func buy_next_vault() -> bool:
	var offer := next_vault()
	if offer.is_empty():
		return false
	_ensure()
	var slot := _slot()
	if slot < 0:
		return false
	if not take_beans(int(offer.get("cost", 0)), true):
		return false
	_vault_tier[slot] += 1
	_vault[slot] = mini(_vault[slot], _vault_capacity(_vault_tier[slot]))
	_write()
	return true


## This toon's jar size. The book, the bank, and the trolley all read it.
static func pouch_limit() -> int:
	_ensure()
	var slot := _slot()
	if slot < 0:
		return START_POUCH
	return _limit[slot]


## MaxMoneyReward. The jar grows. Beans already carried stay where they are.
static func set_pouch_limit(amount: int) -> void:
	_ensure()
	var slot := _slot()
	if slot < 0:
		return
	_limit[slot] = clampi(amount, 1, POUCH_MAX)
	if _pouch[slot] > _limit[slot]:
		_pouch[slot] = _limit[slot]
	_write()


## ~max fills the jar, the way MaxToon calls b_setMoney(maxMoney).
static func fill_pouch() -> void:
	_ensure()
	var slot := _slot()
	if slot < 0:
		return
	_pouch[slot] = _limit[slot]
	_write()


## ~max. The biggest jar, a full bank, and the biggest vault, filled.
static func max_beans() -> void:
	_ensure()
	var slot := _slot()
	if slot < 0:
		return
	_limit[slot] = POUCH_MAX
	_pouch[slot] = POUCH_MAX
	_bank[slot] = BANK_MAX
	_vault_tier[slot] = VAULT_TIERS.size()
	_vault[slot] = _vault_capacity(_vault_tier[slot])
	_write()


static func add_beans(amount: int) -> void:
	if amount == 0:
		return
	_ensure()
	var slot := _slot()
	if slot < 0:
		return
	var cap := _limit[slot]
	var money := _pouch[slot] + amount
	var pocket := mini(money, cap)
	_pouch[slot] = maxi(pocket, 0)
	var overflow := money - cap
	if overflow > 0:
		var bank_room := maxi(BANK_MAX - _bank[slot], 0)
		var into_bank := mini(overflow, bank_room)
		_bank[slot] += into_bank
		overflow -= into_bank
		if overflow > 0:
			var vault_room := maxi(_vault_capacity(_vault_tier[slot]) - _vault[slot], 0)
			_vault[slot] += mini(overflow, vault_room)
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
		total += _bank[slot] + _vault[slot]
	if amount > total:
		return false
	if use_bank and amount > _pouch[slot]:
		var rest := amount - _pouch[slot]
		_pouch[slot] = 0
		var from_bank := mini(rest, _bank[slot])
		_bank[slot] -= from_bank
		_vault[slot] -= rest - from_bank
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
	if moved > 0:
		var into_bank := mini(moved, BANK_MAX - _bank[slot])
		_bank[slot] += into_bank
		_vault[slot] += moved - into_bank
		_pouch[slot] -= moved
	else:
		var out := -moved
		var from_bank := mini(out, _bank[slot])
		_bank[slot] -= from_bank
		_vault[slot] -= out - from_bank
		_pouch[slot] += out
	_write()


static func clamp_transfer(amount: int) -> int:
	_ensure()
	var slot := _slot()
	if slot < 0:
		return 0
	var carried := _pouch[slot]
	var saved := _bank[slot]
	var stored := _vault[slot]
	var vault_room := maxi(_vault_capacity(_vault_tier[slot]) - stored, 0)
	if amount > 0:
		amount = mini(amount, carried)
		amount = mini(amount, maxi(BANK_MAX - saved, 0) + vault_room)
		return amount
	amount = -mini(-amount, _limit[slot] - carried)
	amount = -mini(-amount, saved + stored)
	return amount


static func set_saved(pouch_amount: int, bank_amount: int, pouch_cap: int = -1, vault_amount: int = -1, vault_level: int = -1) -> void:
	_ensure()
	var slot := _slot()
	if slot < 0:
		return
	if pouch_cap >= 0:
		_limit[slot] = clampi(pouch_cap, 1, POUCH_MAX)
	_pouch[slot] = clampi(pouch_amount, 0, _limit[slot])
	_bank[slot] = clampi(bank_amount, 0, BANK_MAX)
	if vault_level >= 0:
		_vault_tier[slot] = clampi(vault_level, 0, VAULT_TIERS.size())
	if vault_amount >= 0:
		_vault[slot] = clampi(vault_amount, 0, _vault_capacity(_vault_tier[slot]))
	_write()


static func reset_slot(index: int) -> void:
	_ensure()
	if index < 0 or index >= ToonRoster.SLOT_COUNT:
		return
	_pouch[index] = 0
	_bank[index] = 0
	_limit[index] = START_POUCH
	_vault[index] = 0
	_vault_tier[index] = 0
	_write()


static func _vault_capacity(tier: int) -> int:
	if tier <= 0 or tier > VAULT_TIERS.size():
		return 0
	return int(VAULT_TIERS[tier - 1].get("capacity", 0))


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
	_limit.resize(ToonRoster.SLOT_COUNT)
	_vault.resize(ToonRoster.SLOT_COUNT)
	_vault_tier.resize(ToonRoster.SLOT_COUNT)
	_pouch.fill(0)
	_bank.fill(0)
	_limit.fill(START_POUCH)
	_vault.fill(0)
	_vault_tier.fill(0)
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
		_limit[index] = clampi(int(row.get("max", START_POUCH)), 1, POUCH_MAX)
		_pouch[index] = clampi(int(row.get("pouch", 0)), 0, _limit[index])
		_bank[index] = clampi(int(row.get("bank", 0)), 0, BANK_MAX)
		_vault_tier[index] = clampi(int(row.get("vault_tier", 0)), 0, VAULT_TIERS.size())
		_vault[index] = clampi(int(row.get("vault", 0)), 0, _vault_capacity(_vault_tier[index]))


static func _write() -> void:
	var slots: Array = []
	for index in ToonRoster.SLOT_COUNT:
		slots.append({
			"pouch": _pouch[index],
			"bank": _bank[index],
			"max": _limit[index],
			"vault": _vault[index],
			"vault_tier": _vault_tier[index],
		})
	var file := FileAccess.open(_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"slots": slots}))
	file.close()
	ToonNet.keep_toon()
