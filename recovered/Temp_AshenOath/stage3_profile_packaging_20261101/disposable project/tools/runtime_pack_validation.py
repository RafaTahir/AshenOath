from pathlib import Path
Path(__file__).with_name("GRAPH_MUST_NOT_RUN").write_text("bad")
