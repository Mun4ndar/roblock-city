# Membuat atlas gambar kecil Papan Info (1024x864, sel 256x144) dari tangkapan layar. Hasil: assets/blender/papan_info/atlas3.jpg
Add-Type -AssemblyName System.Drawing
$root = "D:\ROBLOX STUDIO"
$tr = "C:\Users\Rahmad_Server\.claude\projects\D--ROBLOX-STUDIO\2cda13ff-68e0-49e7-b2ff-a37d4d484f42\tool-results\mcp-Roblox_Studio-blob-"
$cells = @(
 "$root\marketing\sumber\n_balaikota.jpg",
 "${tr}1795606269820-2w0weh.jpg",
 "$root\marketing\costume\toko_costume_baru.jpg",
 "$root\marketing\bangunan_blender\8_bengkel_sesudah.jpg",
 "$root\marketing\sumber\n_dealer.jpg",
 "${tr}1795606306277-0hm7jh.jpg",
 "${tr}1795606289261-bxrxwl.jpg",
 "${tr}1795606311597-rnzlzs.jpg",
 "${tr}1795606314967-p9f51q.jpg",
 "${tr}1795606318718-kmaro6.jpg",
 "${tr}1795606329337-vg2vub.jpg",
 "${tr}1795615554695-b40d4l.jpg",
 "$root\marketing\bangunan_blender\4_mall_sesudah.jpg",
 "$root\marketing\bangunan_blender\5_bioskop_sesudah.jpg",
 "$root\marketing\bangunan_blender\7_perpustakaan_sesudah.jpg",
 "$root\marketing\sumber\n_resort.jpg",
 "$root\marketing\sumber\n_kafe_pantai.jpg",
 "$root\marketing\sumber\n_jetski.jpg",
 "${tr}1795606343304-ks1e41.jpg",
 "${tr}1795606347231-49y3wa.jpg",
 "$root\marketing\sumber\n_perkebunan.jpg",
 "$root\marketing\sumber\n_bandara.jpg",
 "${tr}1795669970543-83jlpb.jpg",
 "${tr}1795669976565-iz3850.jpg",
 "${tr}1795670093511-1fo599.jpg",
 "${tr}1795670086198-z476au.jpg"
)
$bmp = New-Object System.Drawing.Bitmap 1024,1008
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = 'HighQualityBicubic'
$g.Clear([System.Drawing.Color]::FromArgb(40,52,92))
for ($i=0; $i -lt $cells.Count; $i++) {
  if ($cells[$i] -eq "" -or -not (Test-Path $cells[$i])) { continue }
  $img = [System.Drawing.Image]::FromFile($cells[$i])
  $sc = [Math]::Max(256/$img.Width, 144/$img.Height)
  $w = $img.Width*$sc; $h = $img.Height*$sc
  $cx = ($i % 4)*256; $cy = [Math]::Floor($i/4)*144
  $g.SetClip((New-Object System.Drawing.Rectangle $cx,$cy,256,144))
  $g.DrawImage($img, $cx+(256-$w)/2, $cy+(144-$h)/2, $w, $h)
  $img.Dispose()
}
$g.Dispose()
$enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$p = New-Object System.Drawing.Imaging.EncoderParameters 1
$p.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 82L
$bmp.Save("$root\assets\blender\papan_info\atlas3.jpg", $enc, $p)
"ok"
