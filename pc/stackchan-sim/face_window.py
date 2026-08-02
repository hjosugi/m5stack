"""StackChan の顔＋吹き出し＋入力欄のミニ窓（tkinter）。host側でチャットできる。

sim.py --gui から使う。tkinterは標準ライブラリだが、ヘッドレス環境では import が
失敗しうるので、このモジュールは GUI 起動時のみ読み込む（sim.py 側で遅延import）。
"""

import threading
import tkinter as tk

W, H = 380, 320
FACE_CX, FACE_CY = W // 2, 90
BALLOON = (16, 168, W - 16, 232)  # x0,y0,x1,y1
SCROLL_PXPS = 40


class FaceWindow:
    def __init__(self, brain):
        self.brain = brain
        self.root = tk.Tk()
        self.root.title("StackChan (sim)")
        self.root.geometry(f"{W}x{H}")
        self.root.configure(bg="#101014")

        self.canvas = tk.Canvas(self.root, width=W, height=250, bg="#101014", highlightthickness=0)
        self.canvas.pack()

        entry_row = tk.Frame(self.root, bg="#101014")
        entry_row.pack(fill="x", padx=8, pady=6)
        self.entry = tk.Entry(entry_row, font=("", 14))
        self.entry.pack(side="left", fill="x", expand=True)
        self.entry.bind("<Return>", lambda _e: self._send())
        tk.Button(entry_row, text="はなす", command=self._send).pack(side="left", padx=6)
        self.entry.focus_set()

        self.speech = "こんにちは！ タイプして はなしかけてね"
        self.scroll_x = 0.0
        self.blink = False
        self.busy = False
        self._blink_loop()
        self._tick()

    # --- 描画 ---
    def _mouth(self):
        mood = self.brain.mood
        x0, x1 = FACE_CX - 26, FACE_CX + 26
        y = FACE_CY + 34
        if mood > 0.2:  # わらい
            self.canvas.create_arc(x0, y - 16, x1, y + 12, start=200, extent=140,
                                   style="arc", outline="#e8e8ee", width=4)
        elif mood < -0.2:  # しょんぼり
            self.canvas.create_arc(x0, y, x1, y + 28, start=20, extent=140,
                                   style="arc", outline="#e8e8ee", width=4)
        else:  # ふつう
            self.canvas.create_line(x0, y, x1, y, fill="#e8e8ee", width=4)

    def _draw_face(self):
        c = self.canvas
        c.delete("all")
        # あたま
        c.create_oval(FACE_CX - 70, FACE_CY - 70, FACE_CX + 70, FACE_CY + 70,
                      outline="#3a3a44", width=2)
        # め（まばたき）
        for dx in (-30, 30):
            ex, ey = FACE_CX + dx, FACE_CY - 6
            if self.blink:
                c.create_line(ex - 12, ey, ex + 12, ey, fill="#e8e8ee", width=4)
            else:
                c.create_oval(ex - 12, ey - 16, ex + 12, ey + 16, fill="#e8e8ee", outline="")
        self._mouth()
        self._draw_balloon()

    def _draw_balloon(self):
        c = self.canvas
        x0, y0, x1, y1 = BALLOON
        c.create_rectangle(x0, y0, x1, y1, fill="#f4f4f8", outline="#f4f4f8")
        c.create_polygon(x0 + 26, y0, x0 + 10, y0 - 16, x0 + 46, y0, fill="#f4f4f8", outline="")
        cy = (y0 + y1) // 2
        text = self.speech
        item = c.create_text(x0 + 10 - int(self.scroll_x), cy, text=text, anchor="w",
                             font=("", 15), fill="#141418")
        bbox = c.bbox(item)
        text_w = (bbox[2] - bbox[0]) if bbox else 0
        inner_w = (x1 - x0) - 20
        if text_w <= inner_w:
            # 収まる: 中央寄せ・スクロールなし
            c.coords(item, (x0 + x1) // 2, cy)
            c.itemconfig(item, anchor="center")
            self.scroll_x = 0.0
        else:
            # はみ出す: 電光掲示板のように流す。左右をマスクで隠す。
            c.create_rectangle(0, y0, x0, y1, fill="#101014", outline="")
            c.create_rectangle(x1, y0, W, y1, fill="#101014", outline="")
        self._text_w = text_w
        self._inner_w = inner_w

    # --- ループ ---
    def _tick(self):
        # マーキー: 長文のとき scroll_x を進める。
        tw = getattr(self, "_text_w", 0)
        iw = getattr(self, "_inner_w", 1)
        if tw > iw:
            self.scroll_x += SCROLL_PXPS / 30.0
            if self.scroll_x > tw + iw:
                self.scroll_x = 0.0
        self._draw_face()
        self.root.after(33, self._tick)

    def _blink_loop(self):
        self.blink = not self.blink
        self.root.after(180 if self.blink else 2600, self._blink_loop)

    # --- 会話 ---
    def _send(self):
        if self.busy:
            return
        q = self.entry.get().strip()
        if not q:
            return
        self.entry.delete(0, "end")
        self.speech = "かんがえ中…"
        self.scroll_x = 0.0
        self.busy = True
        threading.Thread(target=self._ask, args=(q,), daemon=True).start()

    def _ask(self, q):
        try:
            reply = self.brain.respond(q)
        except Exception as exc:  # noqa: BLE001  表示のため全部拾う
            reply = f"エラー: {exc}"
        self.root.after(0, lambda: self._show(reply))

    def _show(self, reply):
        self.speech = reply or "…"
        self.scroll_x = 0.0
        self.busy = False

    def run(self):
        self.root.mainloop()
