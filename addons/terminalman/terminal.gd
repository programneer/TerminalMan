extends Panel

var canOpen = true
var opened = false
var fullScr = false
var dontType = false
@onready var log = $ScrollContainer/Log
var eol = false
@onready var scroll = log.get_v_scroll_bar()
@onready var input = $Input
var cursor = '_'
var dontTickCursor = false
var timeToTickCur = .3
var cursorTime = timeToTickCur
var cursorOn = false
var inputPrefix = "> "
var commands = {}
var history = []
var historyIndex = 0

class ConsoleCommand:
	var function:Callable
	var description:String
	var param_count:int
	func _init(in_function:Callable,in_description:String,in_param_count:int):
		function = in_function
		description = in_description
		param_count = in_param_count

signal terminalOpened
signal terminalClosed

func registerCmd(cmd,function:Callable,description="",param_count=0): commands[cmd] = ConsoleCommand.new(function,description,param_count)
func unregisterCmd(cmd): commands.erase(cmd)

func open(fullScreen=false,force=false,dontTickCur=false):
	terminalOpened.emit()
	opened = true
	visible = true
	input.text = inputPrefix
	if fullScreen: fullScr = true
	if force:
		if fullScr: anchor_bottom = 1
		else: anchor_bottom = .5
	if !dontTickCur:
		input.text += cursor
		cursorOn = true
		cursorTime = timeToTickCur

func close(force=false):
	terminalClosed.emit()
	opened = false
	input.text = ""
	if fullScr: fullScr = false
	if force: anchor_bottom = 0
	if cursorOn: cursorOn = false
	cursorTime = timeToTickCur

func resetCursor():
	cursorTime = timeToTickCur
	if !cursorOn:
		input.text += cursor
		cursorOn = true

func _input(event):
	if event is InputEventKey && event.is_pressed():
		if event.keycode == KEY_QUOTELEFT:
			if !canOpen: return
			if !opened: open(event.is_shift_pressed())
			else:
				if event.is_shift_pressed():
					fullScr = !fullScr
					return
				close()
		if opened && !dontType:
			var keystr = event.as_text()
			if event.is_shift_pressed(): keystr = keystr.substr(6)
			else: keystr = keystr.to_lower()
			if len(keystr) == 1:
				if input.text.length() > inputPrefix.length() && cursorOn: input.text = input.text.substr(0, input.text.length() - cursor.length())+keystr+cursor
				else: input.text += keystr
				resetCursor()
			elif event.keycode == KEY_SPACE:
				if input.text.length() > inputPrefix.length() && cursorOn: input.text = input.text.substr(0, input.text.length() - cursor.length())+' '+cursor
				else: input.text += ' '
				resetCursor()
			elif event.is_shift_pressed() && event.keycode == KEY_MINUS:
				if input.text.length() > inputPrefix.length() && cursorOn: input.text = input.text.substr(0, input.text.length() - cursor.length())+'_'+cursor
				else: input.text += '_'
				resetCursor()
			elif event.keycode == KEY_PERIOD:
				if input.text.length() > inputPrefix.length() && cursorOn: input.text = input.text.substr(0, input.text.length() - cursor.length())+'.'+cursor
				else: input.text += '.'
				resetCursor()
			elif event.keycode == KEY_BACKSPACE:
				if input.text.length() > inputPrefix.length():
					if cursorOn:
						if input.text.length() <= inputPrefix.length() + cursor.length(): return
						input.text = input.text.substr(0, input.text.length() - 2)
						input.text += cursor
					else: input.text = input.text.substr(0, input.text.length() - 1)
					resetCursor()
			elif event.keycode == KEY_ENTER:
				if input.text == inputPrefix || cursorOn && input.text == inputPrefix + cursor: return
				input.text = input.text.substr(inputPrefix.length())
				if cursorOn: input.text = input.text.substr(0, input.text.length() - cursor.length())
				command(input.text)
				input.text = inputPrefix
				if !dontTickCursor:
					if cursorOn: input.text += cursor
					resetCursor()
				else: dontTickCursor = false
			elif event.keycode == KEY_UP:
				if historyIndex > 0:
					historyIndex -= 1
					if historyIndex >= 0:
						if cursorOn: input.text = inputPrefix+history[historyIndex]+cursor
						else: input.text = inputPrefix+history[historyIndex]
					resetCursor()
			elif event.keycode == KEY_DOWN:
				if historyIndex < history.size():
					historyIndex += 1
					if historyIndex < history.size():
						if cursorOn: input.text = inputPrefix+history[historyIndex]+cursor
						else: input.text = inputPrefix+history[historyIndex]
					else:
						if cursorOn: input.text = inputPrefix+cursor
						else: input.text = inputPrefix
					resetCursor()

func _process(delta):
	if opened:
		if anchor_bottom != .5 && !fullScr || anchor_bottom != 1:
			anchor_bottom = move_toward(anchor_bottom, 1 if fullScr else .5, delta * 4)
			if anchor_top < 0: anchor_top = 0
			if !fullScr && eol && anchor_bottom > .5: scrollToBottom()
		if !dontType:
			cursorTime -= delta
			if cursorOn and cursorTime < 0:
				input.text = input.text.substr(0, input.text.length() - cursor.length())
				cursorOn = false
			elif cursorTime < 0:
				input.text += cursor
				cursorOn = true
			if cursorTime < 0: cursorTime = timeToTickCur
		if scroll.value == scroll.max_value - scroll.page && !eol: eol = true
		elif scroll.value != scroll.max_value - scroll.page && eol && anchor_bottom <= .5 || anchor_bottom == 1: eol = false
	else:
		if anchor_bottom > 0: anchor_bottom -= delta * 4
		elif visible: visible = false

func printLine(mesg):
	if log.text == "": log.text += mesg
	else: log.text += '\n' + mesg

func _ready():
	registerCmd("help",help,"Show this help message")
	registerCmd("quit",quit,"Quit the game")
	registerCmd("clear",clear,"Clear the log")
	registerCmd("version",version,"Show the engine version")
	registerCmd("delete_history",resetHistory,"Reset the command history")
	registerCmd("cheese",spamLog,"Prints [color=yellow]cheese[/color] in specified or 100 times",1)

func scrollToBottom():
	await get_tree().create_timer(0.01).timeout # We need to delay to fix scroll issue.
	scroll.value = scroll.max_value - scroll.page

var args
var cmd
func command(text):
	text = text.to_lower()
	args = text.split(' ', true)
	cmd = args[0]
	if cmd != "clear": printLine("[color=gray][ "+text+"[/color]")
	if cmd != "delete_history": addInputHistory(text)
	if commands.has(cmd):
		var commandEntry = commands[cmd]
		match commandEntry.param_count:
			0: commandEntry.function.call()
			1: commandEntry.function.call(args[1] if args.size() > 1 else "")
			2: commandEntry.function.call(args[1] if args.size() > 1 else "", args[2] if args.size() > 2 else "")
			3: commandEntry.function.call(args[1] if args.size() > 1 else "", args[2] if args.size() > 2 else "", args[3] if args.size() > 3 else "")
			_: printLine("Commands with more than 3 parameters not supported.")
	else: printLine("Invalid command")
	scrollToBottom()
	args.clear()
	cmd = null

func addInputHistory(text):
	# Don't add consecutive duplicates
	if !history.size() || text != history.back(): history.append(text)
	historyIndex = history.size()

func _enter_tree():
	var historyFile = FileAccess.open("user://console_history.txt", FileAccess.READ)
	if historyFile:
		while !historyFile.eof_reached():
			var line = historyFile.get_line()
			if line.length(): addInputHistory(line)

func _exit_tree():
	var historyFile = FileAccess.open("user://console_history.txt", FileAccess.WRITE)
	if historyFile:
		var write_index = 0
		var start_write_index = history.size() - 50 # Max lines to write
		for line in history:
			if write_index >= start_write_index: historyFile.store_line(line)
			write_index += 1

#Built-in commands
func help():
	for cmd in commands:
		var commandEntry = commands[cmd]
		if commandEntry.description != "": printLine("[b]"+cmd+"[/b]: "+commandEntry.description)
		else: printLine(cmd)
func quit(): get_tree().quit()
func clear(): log.text = ""
func version():
	var engineVer = Engine.get_version_info()
	printLine("Godot %s.%s.%s.%s.%s" % [engineVer.major,engineVer.minor,engineVer.patch,engineVer.status,engineVer.build])
func resetHistory():
	history = []
	if historyIndex > 0: historyIndex = 0
	if FileAccess.file_exists("user://console_history.txt"): DirAccess.remove_absolute("user://console_history.txt")
func spamLog(arg):
	var i = float(arg) if arg != "" else 100
	while i > 0:
		printLine("[color=yellow]cheese[/color]")
		i -= 1
