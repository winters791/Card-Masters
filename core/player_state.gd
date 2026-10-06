class_name PlayerState
extends RefCounted

var seat: int
var hp: int = Config.STARTING_HP
var element: Element.Type = Element.Type.NORMAL
var heat: int = 0
var hand: Array[CardData] = []
var is_alive: bool = true


func _init(p_seat: int) -> void:
	seat = p_seat
