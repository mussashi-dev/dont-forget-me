param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [int]$TargetWidth = 32,
    [int]$TargetHeight = 32,
    [ValidateSet("auto", "magenta", "corner", "none")][string]$BgMode = "auto",
    [ValidateSet("center", "bottom")][string]$Align = "center",
    [int]$Padding = 1,
    [int]$QuantizeStep = 8
)

$ErrorActionPreference = "Stop"

$csharp = @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

public static class DfmImageProcessor {
    private static bool IsMagenta(Color c) {
        if (c.A < 128) return true;
        int minRB = Math.Min((int)c.R, (int)c.B);
        int diffRB = Math.Abs((int)c.R - (int)c.B);
        // Magenta chroma key (#FF00FF) with tolerance for JPEG compression & anti-aliased fringe
        if (c.R >= 160 && c.B >= 160 && c.G <= 95 && diffRB <= 70) return true;
        if (c.R >= 115 && c.B >= 115 && c.G <= (int)(minRB * 0.48) && diffRB <= 55) return true;
        return false;
    }

    private static double ColorDist(Color a, Color b) {
        int dr = a.R - b.R;
        int dg = a.G - b.G;
        int db = a.B - b.B;
        return Math.Sqrt(dr * dr + dg * dg + db * db);
    }

    public static void Process(
        string inputPath,
        string outputPath,
        int targetW,
        int targetH,
        string bgMode,
        string align,
        int padding,
        int quantizeStep
    ) {
        using (Bitmap raw = new Bitmap(inputPath)) {
            int w = raw.Width;
            int h = raw.Height;
            bool[,] opaque = new bool[w, h];
            Color[,] pixels = new Color[w, h];

            int alreadyTransparent = 0;
            int magentaCorners = 0;
            Color[] corners = new Color[] {
                raw.GetPixel(0, 0),
                raw.GetPixel(w - 1, 0),
                raw.GetPixel(0, h - 1),
                raw.GetPixel(w - 1, h - 1)
            };

            for (int cIdx = 0; cIdx < corners.Length; cIdx++) {
                if (IsMagenta(corners[cIdx]) && corners[cIdx].A >= 128) {
                    magentaCorners++;
                }
            }

            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    Color c = raw.GetPixel(x, y);
                    pixels[x, y] = c;
                    if (c.A < 128) {
                        alreadyTransparent++;
                        opaque[x, y] = false;
                    } else {
                        opaque[x, y] = true;
                    }
                }
            }

            string effectiveMode = bgMode;
            if (effectiveMode == "auto") {
                if (alreadyTransparent > (w * h) / 20) {
                    effectiveMode = "none";
                } else if (magentaCorners >= 2) {
                    effectiveMode = "magenta";
                } else {
                    effectiveMode = "corner";
                }
            }

            if (effectiveMode == "magenta") {
                for (int y = 0; y < h; y++) {
                    for (int x = 0; x < w; x++) {
                        if (opaque[x, y] && IsMagenta(pixels[x, y])) {
                            opaque[x, y] = false;
                        }
                    }
                }
                // Remove 1px dark-magenta compression halo adjacent to transparent pixels
                bool[,] haloStrip = (bool[,])opaque.Clone();
                for (int y = 0; y < h; y++) {
                    for (int x = 0; x < w; x++) {
                        if (!opaque[x, y]) continue;
                        bool adjTrans = (x > 0 && !opaque[x - 1, y]) ||
                                        (x < w - 1 && !opaque[x + 1, y]) ||
                                        (y > 0 && !opaque[x, y - 1]) ||
                                        (y < h - 1 && !opaque[x, y + 1]);
                        if (!adjTrans) continue;
                        Color c = pixels[x, y];
                        if (c.R > c.G + 24 && c.B > c.G + 24 && Math.Abs(c.R - c.B) <= 60) {
                            haloStrip[x, y] = false;
                        }
                    }
                }
                opaque = haloStrip;
            } else if (effectiveMode == "corner") {
                Color bg = corners[0];
                bool[,] visited = new bool[w, h];
                Queue<int> qx = new Queue<int>();
                Queue<int> qy = new Queue<int>();
                int[][] seeds = new int[][] {
                    new int[] { 0, 0 },
                    new int[] { w - 1, 0 },
                    new int[] { 0, h - 1 },
                    new int[] { w - 1, h - 1 }
                };
                foreach (int[] s in seeds) {
                    if (ColorDist(pixels[s[0], s[1]], bg) <= 45.0) {
                        visited[s[0], s[1]] = true;
                        qx.Enqueue(s[0]);
                        qy.Enqueue(s[1]);
                    }
                }
                while (qx.Count > 0) {
                    int cx = qx.Dequeue();
                    int cy = qy.Dequeue();
                    opaque[cx, cy] = false;
                    int[] dx = new int[] { -1, 1, 0, 0 };
                    int[] dy = new int[] { 0, 0, -1, 1 };
                    for (int k = 0; k < 4; k++) {
                        int nx = cx + dx[k];
                        int ny = cy + dy[k];
                        if (nx >= 0 && nx < w && ny >= 0 && ny < h && !visited[nx, ny]) {
                            visited[nx, ny] = true;
                            if (ColorDist(pixels[nx, ny], bg) <= 45.0) {
                                qx.Enqueue(nx);
                                qy.Enqueue(ny);
                            }
                        }
                    }
                }
            }

            // Compute tight bounding box
            int minX = w, minY = h, maxX = -1, maxY = -1;
            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    if (!opaque[x, y]) continue;
                    if (x < minX) minX = x;
                    if (x > maxX) maxX = x;
                    if (y < minY) minY = y;
                    if (y > maxY) maxY = y;
                }
            }

            if (maxX < minX || maxY < minY) {
                throw new InvalidOperationException("No opaque foreground pixels found after background removal.");
            }

            int bw = maxX - minX + 1;
            int bh = maxY - minY + 1;
            int availW = Math.Max(1, targetW - padding * 2);
            int availH = Math.Max(1, targetH - padding * 2);
            double scale = Math.Min((double)availW / bw, (double)availH / bh);

            int outW = Math.Max(1, (int)Math.Round(bw * scale));
            int outH = Math.Max(1, (int)Math.Round(bh * scale));
            int ox = (targetW - outW) / 2;
            int oy = (align == "bottom") ? (targetH - padding - outH) : ((targetH - outH) / 2);

            using (Bitmap outBmp = new Bitmap(targetW, targetH, PixelFormat.Format32bppArgb)) {
                for (int py = 0; py < targetH; py++) {
                    for (int px = 0; px < targetW; px++) {
                        outBmp.SetPixel(px, py, Color.FromArgb(0, 0, 0, 0));
                    }
                }

                for (int y = 0; y < outH; y++) {
                    for (int x = 0; x < outW; x++) {
                        int sx0 = minX + (int)Math.Floor(x / scale);
                        int sx1 = minX + (int)Math.Ceiling((x + 1) / scale);
                        int sy0 = minY + (int)Math.Floor(y / scale);
                        int sy1 = minY + (int)Math.Ceiling((y + 1) / scale);
                        sx0 = Math.Max(minX, Math.Min(maxX, sx0));
                        sx1 = Math.Max(sx0 + 1, Math.Min(maxX + 1, sx1));
                        sy0 = Math.Max(minY, Math.Min(maxY, sy0));
                        sy1 = Math.Max(sy0 + 1, Math.Min(maxY + 1, sy1));

                        int total = 0;
                        int nOpaque = 0;
                        for (int yy = sy0; yy < sy1; yy++) {
                            for (int xx = sx0; xx < sx1; xx++) {
                                total++;
                                if (opaque[xx, yy]) nOpaque++;
                            }
                        }

                        if (total == 0 || nOpaque * 2 < total) continue;

                        // Sample center 50% sub-window to preserve crisp pixel-art outlines
                        int cx0 = sx0 + (sx1 - sx0) / 4;
                        int cx1 = Math.Max(cx0 + 1, sx1 - (sx1 - sx0) / 4);
                        int cy0 = sy0 + (sy1 - sy0) / 4;
                        int cy1 = Math.Max(cy0 + 1, sy1 - (sy1 - sy0) / 4);

                        long rSum = 0, gSum = 0, bSum = 0;
                        int cCount = 0;
                        for (int yy = cy0; yy < cy1; yy++) {
                            for (int xx = cx0; xx < cx1; xx++) {
                                if (!opaque[xx, yy]) continue;
                                Color c = pixels[xx, yy];
                                rSum += c.R;
                                gSum += c.G;
                                bSum += c.B;
                                cCount++;
                            }
                        }

                        if (cCount == 0) {
                            for (int yy = sy0; yy < sy1; yy++) {
                                for (int xx = sx0; xx < sx1; xx++) {
                                    if (!opaque[xx, yy]) continue;
                                    Color c = pixels[xx, yy];
                                    rSum += c.R;
                                    gSum += c.G;
                                    bSum += c.B;
                                    cCount++;
                                }
                            }
                        }

                        if (cCount == 0) continue;

                        int rr = (int)Math.Round((double)rSum / cCount);
                        int gg = (int)Math.Round((double)gSum / cCount);
                        int bb = (int)Math.Round((double)bSum / cCount);

                        if (quantizeStep > 1) {
                            rr = Math.Min(255, (int)Math.Round((double)rr / quantizeStep) * quantizeStep);
                            gg = Math.Min(255, (int)Math.Round((double)gg / quantizeStep) * quantizeStep);
                            bb = Math.Min(255, (int)Math.Round((double)bb / quantizeStep) * quantizeStep);
                        }

                        int dstX = ox + x;
                        int dstY = oy + y;
                        if (dstX >= 0 && dstX < targetW && dstY >= 0 && dstY < targetH) {
                            outBmp.SetPixel(dstX, dstY, Color.FromArgb(255, rr, gg, bb));
                        }
                    }
                }

                string outDir = Path.GetDirectoryName(outputPath);
                if (!string.IsNullOrEmpty(outDir)) Directory.CreateDirectory(outDir);
                outBmp.Save(outputPath, ImageFormat.Png);
            }
        }
    }
}
"@

Add-Type -TypeDefinition $csharp -ReferencedAssemblies System.Drawing
$resolvedIn = (Resolve-Path $InputPath).Path
$resolvedOut = [System.IO.Path]::GetFullPath($OutputPath)
[DfmImageProcessor]::Process($resolvedIn, $resolvedOut, $TargetWidth, $TargetHeight, $BgMode, $Align, $Padding, $QuantizeStep)
Write-Output "CONVERTED: $resolvedOut (${TargetWidth}x${TargetHeight}, mode=$BgMode, align=$Align)"
