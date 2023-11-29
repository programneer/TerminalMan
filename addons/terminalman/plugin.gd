@tool
extends EditorPlugin
const NAME = "Terminal"

func _enter_tree():
	add_autoload_singleton(NAME,"res://addons/terminalman/terminal.tscn")
	pass

func _exit_tree():
	remove_autoload_singleton(NAME)
	pass
