extends Node

## 시작 시 세션 기본값만 확인하고 메인 메뉴로 넘긴다.


func _ready() -> void:
	GameSession.get_session().ensure_defaults()
	SceneFader.get_fader().go_to_main_menu()
