extends Node
## Coin balance and power-up inventory (thin layer over SaveManager).

signal coins_changed(total: int)
signal powers_changed


func balance() -> int:
	return int(SaveManager.data["coins"])


func add(amount: int) -> void:
	if amount <= 0:
		return
	SaveManager.data["coins"] = clampi(balance() + amount, 0, 99999999)
	SaveManager.save_game()
	coins_changed.emit(balance())


func spend(amount: int) -> bool:
	if amount < 0 or balance() < amount:
		return false
	SaveManager.data["coins"] = balance() - amount
	SaveManager.save_game()
	coins_changed.emit(balance())
	return true


func power_count(id: String) -> int:
	return int(SaveManager.data["powers"].get(id, 0))


func add_power(id: String, n: int = 1) -> void:
	if not SaveManager.data["powers"].has(id):
		return
	SaveManager.data["powers"][id] = clampi(power_count(id) + n, 0, 999)
	SaveManager.save_game()
	powers_changed.emit()


func consume_power(id: String) -> bool:
	if power_count(id) <= 0:
		return false
	SaveManager.data["powers"][id] = power_count(id) - 1
	SaveManager.data["stats"]["powers_used"] = int(SaveManager.data["stats"]["powers_used"]) + 1
	SaveManager.save_game()
	powers_changed.emit()
	return true


func power_price(id: String) -> int:
	return int(GameManager.config_get(["powers", id, "price"], 100))


func buy_power(id: String) -> bool:
	if not spend(power_price(id)):
		return false
	add_power(id, 1)
	return true
