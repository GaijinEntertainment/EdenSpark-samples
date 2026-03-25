require engine.core

var private topScoreStorage : GenericStorage

def set_top_score(score : int) {
    topScoreStorage.set("top_score", score)
}

def get_top_score() {
    return topScoreStorage.get_or("top_score", 0)
}

[export]
def on_initialize() {
    topScoreStorage = load_storage("top_score")
}

[export]
def on_exit() {
    save_storage(topScoreStorage, "top_score")
}
