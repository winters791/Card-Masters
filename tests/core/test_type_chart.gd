extends GutTest

const G := Element.Type.GRASS
const W := Element.Type.WATER
const F := Element.Type.FIRE
const N := Element.Type.NORMAL


func test_cycle_is_strong() -> void:
	assert_eq(TypeChart.multiplier(G, W), 2.0, "Grass beats Water")
	assert_eq(TypeChart.multiplier(W, F), 2.0, "Water beats Fire")
	assert_eq(TypeChart.multiplier(F, G), 2.0, "Fire beats Grass")


func test_reverse_cycle_is_resisted() -> void:
	assert_eq(TypeChart.multiplier(W, G), 0.5)
	assert_eq(TypeChart.multiplier(F, W), 0.5)
	assert_eq(TypeChart.multiplier(G, F), 0.5)


func test_same_type_is_neutral() -> void:
	for t: Element.Type in [G, W, F, N]:
		assert_eq(TypeChart.multiplier(t, t), 1.0)


func test_normal_is_neutral_both_ways() -> void:
	for t: Element.Type in [G, W, F]:
		assert_eq(TypeChart.multiplier(N, t), 1.0, "Normal attacking")
		assert_eq(TypeChart.multiplier(t, N), 1.0, "Normal defending")


func test_apply_rounds_fractional_damage_down() -> void:
	assert_eq(TypeChart.apply(15, F, W), 7)
	assert_eq(TypeChart.apply(15, F, G), 30)
	assert_eq(TypeChart.apply(20, N, F), 20)
