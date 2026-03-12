extends SceneTree

var signal_emitted = false

func _init():
	run_tests()
	quit()

func run_tests():
	print("Running Inventory tests...")

	test_add_non_stackable_item()
	test_add_stackable_item_new()
	test_add_stackable_item_existing()
	test_add_item_signal_emitted()

	print("All tests completed successfully.")

func test_add_non_stackable_item():
	var inventory = Inventory.new()
	var item = ItemData.new()
	item.item_id = "sword"
	item.display_name = "Sword"
	item.stackable = false

	inventory.add_item(item)

	if inventory.items.size() != 1:
		print("FAILED: test_add_non_stackable_item - expected size 1, got ", inventory.items.size())
		quit(1)
	if inventory.items[0].item_id != "sword":
		print("FAILED: test_add_non_stackable_item - expected item_id 'sword', got ", inventory.items[0].item_id)
		quit(1)
	print("  - test_add_non_stackable_item: PASSED")

func test_add_stackable_item_new():
	var inventory = Inventory.new()
	var item = ItemData.new()
	item.item_id = "apple"
	item.display_name = "Apple"
	item.stackable = true
	item.quantity = 5

	inventory.add_item(item)

	if inventory.items.size() != 1:
		print("FAILED: test_add_stackable_item_new - expected size 1, got ", inventory.items.size())
		quit(1)
	if inventory.items[0].item_id != "apple":
		print("FAILED: test_add_stackable_item_new - expected item_id 'apple', got ", inventory.items[0].item_id)
		quit(1)
	if inventory.items[0].quantity != 5:
		print("FAILED: test_add_stackable_item_new - expected quantity 5, got ", inventory.items[0].quantity)
		quit(1)
	print("  - test_add_stackable_item_new: PASSED")

func test_add_stackable_item_existing():
	var inventory = Inventory.new()

	var item1 = ItemData.new()
	item1.item_id = "apple"
	item1.display_name = "Apple"
	item1.stackable = true
	item1.quantity = 5
	inventory.add_item(item1)

	var item2 = ItemData.new()
	item2.item_id = "apple"
	item2.display_name = "Apple"
	item2.stackable = true
	item2.quantity = 3
	inventory.add_item(item2)

	if inventory.items.size() != 1:
		print("FAILED: test_add_stackable_item_existing - expected size 1, got ", inventory.items.size())
		quit(1)
	if inventory.items[0].quantity != 8:
		print("FAILED: test_add_stackable_item_existing - expected quantity 8, got ", inventory.items[0].quantity)
		quit(1)
	print("  - test_add_stackable_item_existing: PASSED")

func test_add_item_signal_emitted():
	var inventory = Inventory.new()
	var item = ItemData.new()
	item.item_id = "potion"
	item.display_name = "Potion"

	inventory.item_added.connect(_on_item_added)
	signal_emitted = false
	inventory.add_item(item)

	if not signal_emitted:
		print("FAILED: test_add_item_signal_emitted - signal was not emitted")
		quit(1)
	print("  - test_add_item_signal_emitted: PASSED")

func _on_item_added(_item):
	signal_emitted = true
