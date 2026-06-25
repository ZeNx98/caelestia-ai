#!/usr/bin/env -S uv run
# /// script
# dependencies = [
#   "matplotlib",
# ]
# ///
import sys, os, hashlib, tempfile

def main():
    if len(sys.argv) < 2:
        print("Usage: render_math.py '<latex>' [fg_color] [font_size]", file=sys.stderr)
        sys.exit(1)

    latex = sys.argv[1]
    fg    = sys.argv[2] if len(sys.argv) > 2 else "#ffffff"
    size  = float(sys.argv[3]) if len(sys.argv) > 3 else 15

    if fg.startswith("#") and len(fg) == 9:
        fg = f"#{fg[3:9]}{fg[1:3]}"

    cache_dir = os.path.join(tempfile.gettempdir(), "caelestia_math")
    os.makedirs(cache_dir, exist_ok=True)
    size_str = sys.argv[3] if len(sys.argv) > 3 else "15"
    key  = hashlib.md5(f"{latex}|{fg}|{size_str}".encode()).hexdigest()
    path = os.path.join(cache_dir, f"{key}.png")

    if os.path.exists(path):
        print(path)
        return

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    expr = latex.strip()
    if not (expr.startswith("$") and expr.endswith("$")):
        expr = f"${expr}$"

    fig = plt.figure(figsize=(0.01, 0.01))
    fig.patch.set_alpha(0)

    txt = fig.text(0, 0, expr, fontsize=size, color=fg,
                   ha="left", va="bottom", usetex=False)

    fig.savefig(path, dpi=180, bbox_inches="tight",
                transparent=True, pad_inches=0.02,
                facecolor="none", edgecolor="none")
    plt.close(fig)
    print(path)

if __name__ == "__main__":
    main()
