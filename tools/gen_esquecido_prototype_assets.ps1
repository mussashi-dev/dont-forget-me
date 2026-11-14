# Gera os assets autorais do protótipo visual v0.2 (Esquecido).
# Uso (na raiz do projeto): powershell -File tools/gen_esquecido_prototype_assets.ps1
# Saídas novas (nada existente é sobrescrito):
#   assets/characters/pablita/v2/*.png      (Pablita reduzida a partir da referência, escala 0.40)
#   assets/environments/esquecido/*.png      (tiles de chão e props originais, grade de 16 px)
$csharp = @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

public static class Gen {
    static Random R = new Random(1337);
    static Color C(string h) { return ColorTranslator.FromHtml(h); }
    static Color[] Tones(string a, string b, string c, string d) { return new Color[] { C(a), C(b), C(c), C(d) }; }

    // Paleta do Esquecido: roxos, lilases, violetas, azuis arroxeados, magenta discreto, luz quente rara.
    static Color DEEP = C("#120b1c");
    static Color[] PUR = Tones("#2b1b45", "#3f2a63", "#5a3d86", "#7d5aa8");
    static Color[] LIL = Tones("#4a3a6e", "#6b5896", "#8f7bb8", "#b9a6d9");
    static Color[] MAG = Tones("#4a1f4d", "#6d2b6b", "#8f3a8a", "#b457a8");
    static Color[] BLU = Tones("#232a5c", "#34408a", "#4b5cb0", "#7381d4");
    static Color[] MOS = Tones("#1f2352", "#2f3a78", "#44579c", "#6a7fc0");
    static Color[] PLUSH = Tones("#4a3262", "#6e4d7f", "#8f6b9a", "#b58fb5");
    static Color[] WOOD = Tones("#2e1d3f", "#47305a", "#634877", "#82659a");
    static Color WARM = C("#ffcf70");
    static Color PALE = C("#d9c9ef");

    static Bitmap New(int w, int h) { return new Bitmap(w, h, PixelFormat.Format32bppArgb); }
    static void P(Bitmap b, int x, int y, Color c) { if (x >= 0 && y >= 0 && x < b.Width && y < b.Height) b.SetPixel(x, y, c); }
    static void Rect(Bitmap b, int x, int y, int w, int h, Color c) { for (int j = 0; j < h; j++) for (int i = 0; i < w; i++) P(b, x + i, y + j, c); }
    static void Blob(Bitmap b, double cx, double cy, double rx, double ry, Color[] t) {
        for (int y = (int)(cy - ry - 1); y <= (int)(cy + ry + 1); y++)
            for (int x = (int)(cx - rx - 1); x <= (int)(cx + rx + 1); x++) {
                double nx = (x + 0.5 - cx) / rx, ny = (y + 0.5 - cy) / ry;
                if (nx * nx + ny * ny > 1.0) continue;
                double l = -0.55 * nx - 0.75 * ny;
                int i = l > 0.55 ? 3 : (l > 0.1 ? 2 : (l > -0.4 ? 1 : 0));
                P(b, x, y, t[i]);
            }
    }
    static void Outline(Bitmap b, Color o) {
        Bitmap src = (Bitmap)b.Clone();
        for (int y = 0; y < b.Height; y++) for (int x = 0; x < b.Width; x++) {
            if (src.GetPixel(x, y).A > 0) continue;
            bool adj = false;
            if (x > 0 && src.GetPixel(x - 1, y).A > 0) adj = true;
            if (x < b.Width - 1 && src.GetPixel(x + 1, y).A > 0) adj = true;
            if (y > 0 && src.GetPixel(x, y - 1).A > 0) adj = true;
            if (y < b.Height - 1 && src.GetPixel(x, y + 1).A > 0) adj = true;
            if (adj) b.SetPixel(x, y, o);
        }
        src.Dispose();
    }
    static void Save(Bitmap b, string dir, string name) { Directory.CreateDirectory(dir); b.Save(Path.Combine(dir, name + ".png"), ImageFormat.Png); b.Dispose(); }

    // ---------- Chão ----------
    static void GroundTile(string dir, string name, string baseHex, string lightHex, string darkHex, int specks, int lint, bool path) {
        Bitmap b = New(16, 16);
        Rect(b, 0, 0, 16, 16, C(baseHex));
        for (int i = 0; i < specks; i++) { P(b, R.Next(16), R.Next(16), R.Next(2) == 0 ? C(lightHex) : C(darkHex)); }
        for (int i = 0; i < lint; i++) { int x = R.Next(2, 12), y = R.Next(16); int len = R.Next(2, 5); for (int k = 0; k < len; k++) P(b, x + k, y + (k == 2 ? 1 : 0), C(lightHex)); }
        if (path && R.Next(2) == 0) { P(b, R.Next(16), R.Next(16), PALE); }
        Save(b, dir, name);
    }
    static void GroundDetail(string dir) {
        Bitmap b = New(7, 7); // botão
        Blob(b, 3.5, 3.5, 3, 3, LIL); P(b, 2, 3, DEEP); P(b, 4, 3, DEEP); P(b, 3, 2, DEEP); P(b, 3, 4, DEEP); Outline(b, DEEP); Save(b, dir, "detail_button");
        b = New(9, 7); // novelo de linha
        Blob(b, 4.5, 3.5, 3.5, 3, MAG); for (int i = 0; i < 4; i++) P(b, 4 + i, 3, MAG[3]); P(b, 7, 5, MAG[2]); Outline(b, DEEP); Save(b, dir, "detail_yarn");
        b = New(8, 8); // bloquinho
        Rect(b, 1, 2, 5, 5, BLU[2]); Rect(b, 1, 1, 5, 1, BLU[3]); Rect(b, 1, 6, 5, 1, BLU[0]); Rect(b, 6, 2, 1, 5, BLU[1]); P(b, 3, 4, PALE); Outline(b, DEEP); Save(b, dir, "detail_block");
        b = New(5, 5); // pontinho de luz (poeira brilhante)
        P(b, 2, 2, WARM); P(b, 2, 1, C("#a8793a")); P(b, 1, 2, C("#a8793a")); P(b, 3, 2, C("#a8793a")); P(b, 2, 3, C("#a8793a")); Save(b, dir, "detail_glint");
    }

    // ---------- Props ----------
    static void ToyTree(string dir) {
        Bitmap b = New(58, 84);
        int cx = 29;
        // tronco: pilha de livros/caixas
        int y = 80; int k = 0;
        Color[][] stack = new Color[][] { WOOD, MAG, PUR, BLU, LIL };
        while (y > 46) {
            int h = 4 + R.Next(2); int jitter = R.Next(-1, 2);
            int w = 12 + R.Next(0, 3) + (y > 72 ? 4 : 0);
            Color[] t = stack[k % stack.Length];
            Rect(b, cx - w / 2 + jitter, y - h, w, h, t[2]);
            Rect(b, cx - w / 2 + jitter, y - h, w, 1, t[3]);
            Rect(b, cx - w / 2 + jitter, y - 1, w, 1, t[0]);
            Rect(b, cx + w / 2 - 2 + jitter, y - h + 1, 2, h - 1, t[1]);
            if (R.Next(2) == 0) P(b, cx - w / 2 + 2 + jitter, y - 3, PALE);
            y -= h; k++;
        }
        // copa: pelúcias e retalhos
        Blob(b, 29, 26, 19, 14, PUR);
        Blob(b, 15, 34, 12, 10, BLU);
        Blob(b, 43, 34, 12, 10, LIL);
        Blob(b, 29, 40, 15, 8, MAG);
        Blob(b, 20, 16, 10, 9, LIL);
        Blob(b, 38, 15, 10, 9, PUR);
        Blob(b, 29, 24, 12, 9, BLU);
        // cabeça de urso no meio da copa
        Blob(b, 29, 25, 5, 5, PLUSH); Blob(b, 24, 20, 2.5, 2.5, PLUSH); Blob(b, 34, 20, 2.5, 2.5, PLUSH);
        P(b, 27, 24, DEEP); P(b, 31, 24, DEEP); P(b, 28, 27, DEEP); P(b, 29, 27, DEEP); P(b, 30, 27, DEEP);
        // blocos de brinquedo na copa
        int[][] bl = new int[][] { new int[]{12,28}, new int[]{44,26}, new int[]{35,36}, new int[]{19,38}, new int[]{26,12} };
        Color[][] bc = new Color[][] { MAG, BLU, LIL, MAG, BLU };
        for (int i = 0; i < bl.Length; i++) { Color[] t = bc[i]; int x = bl[i][0], yy = bl[i][1]; Rect(b, x, yy, 6, 6, t[2]); Rect(b, x, yy, 6, 1, t[3]); Rect(b, x, yy + 5, 6, 1, t[0]); Rect(b, x + 5, yy, 1, 6, t[1]); P(b, x + 2, yy + 2, PALE); }
        // fios caindo da copa
        int[] fx = new int[] { 12, 22, 36, 47 };
        for (int i = 0; i < fx.Length; i++) { int len = 8 + R.Next(8); for (int j = 0; j < len; j++) P(b, fx[i] + ((j / 3) % 2), 42 + j, j % 5 == 4 ? MAG[3] : MAG[2]); }
        // luzinhas quentes escondidas (pontos raros)
        P(b, 23, 14, WARM); P(b, 41, 30, WARM);
        Outline(b, DEEP); Save(b, dir, "tree_toypile");
    }
    static void Bush(string dir) {
        Bitmap b = New(34, 24);
        Blob(b, 10, 15, 8, 6, BLU); Blob(b, 23, 15, 9, 6, PUR); Blob(b, 16, 10, 9, 7, LIL); Blob(b, 17, 16, 14, 5, PUR);
        // retalhos de tecido e fios (sem rosto acidental)
        Rect(b, 6, 12, 4, 3, MAG[2]); Rect(b, 6, 12, 4, 1, MAG[3]);
        Rect(b, 20, 9, 3, 4, BLU[3]); Rect(b, 14, 15, 5, 2, LIL[3]);
        P(b, 12, 8, PALE); P(b, 26, 14, PALE); P(b, 9, 17, PALE);
        for (int j = 0; j < 5; j++) P(b, 27 + (j / 2), 6 + j, MAG[3]);
        Outline(b, DEEP); Save(b, dir, "bush_plushpile");
    }
    static void ClothesVine(string dir) {
        Bitmap b = New(16, 46);
        for (int y = 0; y < 44; y++) P(b, 7 + ((y / 6) % 2), y, LIL[1]);
        Rect(b, 4, 9, 5, 9, LIL[2]); Rect(b, 4, 9, 5, 3, MAG[2]); Rect(b, 6, 17, 4, 3, LIL[2]); P(b, 7, 8, PALE);
        Rect(b, 3, 24, 10, 8, BLU[2]); Rect(b, 1, 24, 3, 4, BLU[2]); Rect(b, 12, 24, 3, 4, BLU[2]); Rect(b, 3, 24, 10, 1, BLU[3]); P(b, 8, 23, PALE);
        Rect(b, 6, 36, 3, 8, MAG[3]); Rect(b, 5, 34, 5, 3, MAG[2]); P(b, 7, 33, PALE);
        Outline(b, DEEP); Save(b, dir, "vine_clothes");
    }
    static void Teddy(string dir) {
        Bitmap b = New(30, 26);
        Blob(b, 15, 13, 9, 8, PLUSH); Blob(b, 7, 6, 3.4, 3.4, PLUSH); Blob(b, 23, 6, 3.4, 3.4, PLUSH);
        Blob(b, 7, 6, 1.6, 1.6, new Color[]{PLUSH[0],PLUSH[0],PLUSH[0],PLUSH[0]}); Blob(b, 23, 6, 1.6, 1.6, new Color[]{PLUSH[0],PLUSH[0],PLUSH[0],PLUSH[0]});
        Blob(b, 15, 17, 4.5, 3.4, LIL);
        P(b, 14, 15, DEEP); P(b, 15, 15, DEEP); P(b, 16, 15, DEEP);
        Rect(b, 10, 10, 3, 3, PALE); P(b, 11, 11, DEEP); // olho de botão
        P(b, 18, 10, DEEP); P(b, 20, 10, DEEP); P(b, 19, 11, DEEP); P(b, 18, 12, DEEP); P(b, 20, 12, DEEP); // olho costurado
        Rect(b, 12, 8, 2, 1, MAG[2]); Rect(b, 13, 7, 2, 1, MAG[2]); // remendo
        Blob(b, 15, 23, 14, 4.5, PUR); // montinho de terra cobrindo o corpo
        Outline(b, DEEP); Save(b, dir, "teddy_buried");
    }
    static void Doll(string dir) {
        Bitmap b = New(18, 30);
        Blob(b, 9, 8, 7, 7, MAG);                       // cabelo
        Blob(b, 9, 9, 4.5, 4.8, new Color[]{LIL[1],LIL[2],LIL[3],PALE}); // rosto
        P(b, 7, 9, DEEP); P(b, 11, 9, DEEP); P(b, 9, 12, MAG[3]);
        for (int y = 15; y < 28; y++) { int w = 4 + (y - 15) / 2; Rect(b, 9 - w / 2 - 1, y, w + 2, 1, y % 5 == 0 ? BLU[3] : BLU[2]); }
        Rect(b, 2, 17, 3, 7, LIL[2]); Rect(b, 13, 17, 3, 6, LIL[2]);
        P(b, 6, 27, DEEP); P(b, 11, 27, DEEP);
        Outline(b, DEEP); Save(b, dir, "doll_forgotten");
    }
    static void Furniture(string dir, string name, int w, int h, bool wardrobe) {
        int top = 8;
        Bitmap b = new Bitmap(w + 2, h + top + 2, PixelFormat.Format32bppArgb);
        int x0 = 1, y0 = 1;
        Rect(b, x0, y0, w, top, WOOD[3]);                           // tampo (face de cima)
        Rect(b, x0, y0, w, 1, LIL[2]);
        Rect(b, x0, y0 + top, w, h - 3, WOOD[2]);                  // frente
        Rect(b, x0, y0 + top, 2, h - 3, WOOD[3]);                  // luz à esquerda
        Rect(b, x0 + w - 3, y0 + top, 3, h - 3, WOOD[1]);          // sombra à direita
        Rect(b, x0 + 1, y0 + h + top - 4, 3, 3, WOOD[0]); Rect(b, x0 + w - 4, y0 + h + top - 4, 3, 3, WOOD[0]); // pés
        if (wardrobe) {
            Rect(b, x0 + w / 2 - 1, y0 + top, 2, h - 3, DEEP);     // fresta entre as portas
            Rect(b, x0 + w / 2 - 5, y0 + top + h / 2 - 2, 2, 5, WARM); Rect(b, x0 + w / 2 + 3, y0 + top + h / 2 - 2, 2, 5, WARM);
            Rect(b, x0 + 3, y0 + top + 3, w / 2 - 6, h - 12, WOOD[1]); Rect(b, x0 + w / 2 + 3, y0 + top + 3, w / 2 - 6, h - 12, WOOD[1]);
        } else {
            Rect(b, x0 + 2, y0 + top + (h - 3) / 2, w - 5, 1, DEEP);
            Rect(b, x0 + w / 2 - 2, y0 + top + 5, 4, 2, WARM); Rect(b, x0 + w / 2 - 2, y0 + top + (h - 3) / 2 + 5, 4, 2, WARM);
        }
        // musgo e poeira
        for (int i = 0; i < w / 3; i++) Blob(b, x0 + 2 + R.Next(w - 4), y0 + 1 + R.Next(top - 2), 3, 2, MOS);
        Blob(b, x0 + w - 4, y0 + top + 3, 3, 5, MOS); Blob(b, x0 + 4, y0 + top + 2, 3, 3, MOS);
        for (int i = 0; i < 6; i++) P(b, x0 + 2 + R.Next(w - 4), y0 + 1 + R.Next(top - 2), PALE);
        Outline(b, DEEP); Save(b, dir, name);
    }
    static void Mushroom(string dir) {
        Bitmap b = New(18, 20);
        Rect(b, 6, 9, 6, 9, LIL[2]); Rect(b, 6, 9, 2, 9, LIL[3]); Rect(b, 10, 9, 2, 9, LIL[1]);
        Rect(b, 7, 14, 4, 1, LIL[1]);
        Blob(b, 9, 7, 8, 5.5, MAG); P(b, 6, 6, PALE); P(b, 10, 4, PALE); P(b, 12, 8, PALE); P(b, 8, 9, PALE);
        Rect(b, 7, 1, 2, 2, MAG[3]); Rect(b, 10, 1, 2, 2, MAG[3]); // pinos tipo peça de montar
        Outline(b, DEEP); Save(b, dir, "mushroom_block");
    }
    static void Teacup(string dir) {
        Bitmap b = New(12, 12);
        Rect(b, 2, 7, 6, 4, LIL[3]); Rect(b, 2, 7, 6, 1, PALE); Rect(b, 2, 10, 6, 1, LIL[1]); Rect(b, 8, 8, 2, 2, LIL[3]);
        Rect(b, 4, 4, 2, 3, C("#c9b79a"));
        Rect(b, 4, 2, 2, 2, WARM); P(b, 4, 2, C("#fff2c2"));
        Outline(b, DEEP); Save(b, dir, "teacup_candle");
    }

    // ---------- Pablita reduzida a partir da referência ----------
    static Bitmap Downscale(Bitmap src, double f, int cw, int ch) {
        int minx = src.Width, miny = src.Height, maxx = -1, maxy = -1;
        for (int y = 0; y < src.Height; y++) for (int x = 0; x < src.Width; x++) if (src.GetPixel(x, y).A > 20) { if (x < minx) minx = x; if (x > maxx) maxx = x; if (y < miny) miny = y; if (y > maxy) maxy = y; }
        int bw = maxx - minx + 1, bh = maxy - miny + 1;
        int w = (int)Math.Round(bw * f), h = (int)Math.Round(bh * f);
        Bitmap o = New(cw, ch);
        int ox = (cw - w) / 2, oy = ch - 3 - h + 1; // base do sprite na linha ch-3 (pés em y = ch-2)
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
            int sx0 = minx + (int)Math.Floor(x / f), sx1 = minx + (int)Math.Ceiling((x + 1) / f);
            int sy0 = miny + (int)Math.Floor(y / f), sy1 = miny + (int)Math.Ceiling((y + 1) / f);
            double r = 0, g = 0, bl = 0; int n = 0, tot = 0;
            for (int yy = sy0; yy < sy1; yy++) for (int xx = sx0; xx < sx1; xx++) {
                if (xx >= src.Width || yy >= src.Height) continue; tot++;
                Color c = src.GetPixel(xx, yy);
                if (c.A > 40) { r += c.R; g += c.G; bl += c.B; n++; }
            }
            if (tot == 0 || n * 2 < tot) continue;
            int rr = (int)(r / n) / 24 * 24, gg = (int)(g / n) / 24 * 24, bb = (int)(bl / n) / 24 * 24; // quantiza p/ reduzir ruído
            P(o, ox + x, oy + y, Color.FromArgb(255, Math.Min(255, rr + 12), Math.Min(255, gg + 12), Math.Min(255, bb + 12)));
        }
        return o;
    }

    public static void Run(string pablitaSrc, string pablitaOut, string envOut) {
        string[] names = new string[] { "idle_down","idle_up","idle_side","walk_down_0","walk_down_1","walk_down_2","walk_side_0","walk_side_1","walk_up_0","walk_up_1" };
        foreach (string n in names) {
            using (Bitmap s = new Bitmap(Path.Combine(pablitaSrc, n + ".png"))) { Save(Downscale(s, 0.40, 32, 32), pablitaOut, n); }
        }
        GroundTile(envOut, "ground_a", "#26173d", "#31204f", "#1d1230", 14, 1, false);
        GroundTile(envOut, "ground_b", "#281940", "#33224f", "#1e1332", 12, 2, false);
        GroundTile(envOut, "ground_c", "#24163a", "#2f1f4a", "#1b102e", 16, 0, false);
        GroundTile(envOut, "path_a", "#3a2a5c", "#4a3873", "#2f2150", 12, 3, true);
        GroundTile(envOut, "path_b", "#38285a", "#483670", "#2d1f4c", 10, 2, true);
        GroundDetail(envOut);
        ToyTree(envOut); Bush(envOut); ClothesVine(envOut); Teddy(envOut); Doll(envOut);
        Furniture(envOut, "dresser_mossy", 30, 22, false);
        Furniture(envOut, "wardrobe_mossy", 36, 40, true);
        Mushroom(envOut); Teacup(envOut);
    }
}
"@
Add-Type -TypeDefinition $csharp -ReferencedAssemblies System.Drawing
[Gen]::Run("assets/characters/pablita", "assets/characters/pablita/v2", "assets/environments/esquecido")
Get-ChildItem assets/environments/esquecido, assets/characters/pablita/v2 | Select-Object Name, Length | Format-Table -AutoSize | Out-String
