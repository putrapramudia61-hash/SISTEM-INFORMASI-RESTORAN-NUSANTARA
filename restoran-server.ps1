$ErrorActionPreference = "Stop"

$HostName = "127.0.0.1"
$Port = 8001
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$OrdersFile = Join-Path $Root "restoran-orders.json"

$Menus = @(
    @{ id = "rendang"; name = "Rendang Daging"; origin = "Sumatera Barat"; category = "makanan"; price = 42000; spice = "Pedas gurih"; icon = "rendang"; image = "assets/restoran/rendang-daging.jpg"; description = "Daging sapi empuk dimasak perlahan dengan santan, cabai, dan rempah Minang." },
    @{ id = "sate"; name = "Sate Ayam Madura"; origin = "Madura"; category = "makanan"; price = 32000; spice = "Manis pedas"; icon = "sate"; image = "assets/restoran/sate-ayam-madura.webp"; description = "Sate ayam bakar arang dengan bumbu kacang, kecap, lontong, dan acar." },
    @{ id = "rawon"; name = "Rawon Surabaya"; origin = "Jawa Timur"; category = "makanan"; price = 38000; spice = "Hangat rempah"; icon = "soup"; image = "assets/restoran/rawon-surabaya.jpg"; description = "Sup daging kuah kluwek berwarna hitam dengan tauge pendek dan telur asin." },
    @{ id = "gudeg"; name = "Gudeg Jogja"; origin = "Yogyakarta"; category = "makanan"; price = 35000; spice = "Manis legit"; icon = "rice"; image = "assets/restoran/gudeg-jogja.jpg"; description = "Nangka muda, ayam opor, telur pindang, krecek, dan nasi hangat." },
    @{ id = "soto"; name = "Soto Betawi"; origin = "Jakarta"; category = "makanan"; price = 40000; spice = "Gurih santan"; icon = "soup"; image = "assets/restoran/soto-betawi.jpg"; description = "Kuah santan susu dengan daging sapi, kentang, tomat, dan emping." },
    @{ id = "nasi-liwet"; name = "Nasi Liwet Solo"; origin = "Jawa Tengah"; category = "makanan"; price = 34000; spice = "Gurih lembut"; icon = "rice"; image = "assets/restoran/nasi-liwet-solo.jpg"; description = "Nasi gurih, suwiran ayam, sayur labu, telur, dan areh santan." },
    @{ id = "ayam-taliwang"; name = "Ayam Taliwang"; origin = "Lombok"; category = "makanan"; price = 45000; spice = "Pedas kuat"; icon = "chicken"; image = "assets/restoran/ayam-taliwang.jpg"; description = "Ayam bakar bumbu cabai Lombok dengan plecing kangkung dan nasi putih." },
    @{ id = "pempek"; name = "Pempek Kapal Selam"; origin = "Palembang"; category = "makanan"; price = 30000; spice = "Asam pedas"; icon = "snack"; image = "assets/restoran/pempek-kapal-selam.jpg"; description = "Pempek isi telur dengan kuah cuko, timun, dan mi kuning." },
    @{ id = "cendol"; name = "Es Cendol Dawet"; origin = "Jawa"; category = "minuman"; price = 18000; spice = "Segar manis"; icon = "drink"; image = "assets/restoran/es-cendol-dawet.jpg"; description = "Cendol pandan, santan, gula aren cair, dan es serut." },
    @{ id = "wedang"; name = "Wedang Jahe"; origin = "Nusantara"; category = "minuman"; price = 16000; spice = "Hangat"; icon = "tea"; image = "assets/restoran/es_cendol_nangka.jpg"; description = "Minuman jahe, serai, gula batu, dan kayu manis." },
    @{ id = "beras-kencur"; name = "Es Beras Kencur"; origin = "Jawa"; category = "minuman"; price = 17000; spice = "Herbal segar"; icon = "drink"; image = "assets/restoran/beras-kencur.jpeg"; description = "Jamu beras kencur dingin dengan rasa manis, wangi, dan menyegarkan." },
    @{ id = "paket-nusantara"; name = "Paket Lengkap Nusantara"; origin = "Pilihan chef"; category = "paket"; price = 72000; spice = "Komplet"; icon = "package"; image = "assets/restoran/paket-lengkap-nusantara.jpeg"; description = "Rendang mini, sate ayam, nasi liwet, sambal, lalapan, dan es cendol." }
)

function Send-Text($Context, [int]$StatusCode, [string]$ContentType, [string]$Text) {
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $Context.Response.StatusCode = $StatusCode
    $Context.Response.ContentType = "$ContentType; charset=utf-8"
    $Context.Response.Headers["Access-Control-Allow-Origin"] = "*"
    $Context.Response.Headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    $Context.Response.Headers["Access-Control-Allow-Headers"] = "Content-Type"
    $Context.Response.ContentLength64 = $Bytes.Length
    $Context.Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
    $Context.Response.OutputStream.Close()
}

function Send-Json($Context, [int]$StatusCode, $Payload) {
    Send-Text $Context $StatusCode "application/json" ($Payload | ConvertTo-Json -Depth 10)
}

function Read-JsonArray([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }
    $Content = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($Content)) {
        return @()
    }
    return $Content | ConvertFrom-Json
}

function Get-Orders {
    return Read-JsonArray $OrdersFile
}

function Save-Orders($Orders) {
    $Orders | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OrdersFile -Encoding UTF8
}

function Normalize-Order($Order) {
    if ($null -eq $Order) {
        return $null
    }
    if ($null -eq $Order.payment_method -or [string]::IsNullOrWhiteSpace([string]$Order.payment_method)) {
        $Order | Add-Member -NotePropertyName payment_method -NotePropertyValue "cash" -Force
    }
    if ($null -eq $Order.items) {
        $Order | Add-Member -NotePropertyName items -NotePropertyValue @() -Force
    }
    return $Order
}


function Create-Order($Payload) {
    $Items = @($Payload.items)
    if ($Items.Count -eq 0) {
        throw [System.Exception]::new("Pesanan masih kosong.")
    }

    $PaymentMethod = [string]$Payload.payment_method
    if ([string]::IsNullOrWhiteSpace($PaymentMethod)) {
        $PaymentMethod = "cash"
    }
    if ($PaymentMethod -notin @("cash", "qris", "debit")) {
        throw [System.Exception]::new("Metode pembayaran tidak valid.")
    }

    $OrderItems = @()
    $Total = 0
    foreach ($Item in $Items) {
        $Menu = $Menus | Where-Object { $_.id -eq $Item.id } | Select-Object -First 1
        $Quantity = [int]$Item.quantity
        if ($null -ne $Menu -and $Quantity -gt 0) {
            $Subtotal = [int]$Menu.price * $Quantity
            $Total += $Subtotal
            $OrderItems += @{
                menu_id = $Menu.id
                menu_name = $Menu.name
                price = [int]$Menu.price
                quantity = $Quantity
                subtotal = $Subtotal
            }
        }
    }

    if ($OrderItems.Count -eq 0) {
        throw [System.Exception]::new("Jumlah menu tidak valid.")
    }

    $Orders = Get-Orders
    $MaxId = 0
    foreach ($ExistingOrder in $Orders) {
        if ($null -ne $ExistingOrder.id -and [int]$ExistingOrder.id -gt $MaxId) {
            $MaxId = [int]$ExistingOrder.id
        }
    }

    $Order = @{
        id = $MaxId + 1
        total = $Total
        payment_method = $PaymentMethod
        created_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        items = $OrderItems
    }

    $Orders += $Order
    Save-Orders $Orders
    return $Order
}

function Get-RecentOrders {
    $Orders = Get-Orders

    $Result = @()
    foreach ($Order in ($Orders | Sort-Object -Property id -Descending | Select-Object -First 20)) {
        $Normalized = Normalize-Order $Order
        $Result += $Normalized
    }

    return $Result
}

function Get-ContentType([string]$Path) {
    switch ([IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        ".html" { "text/html" }
        ".css" { "text/css" }
        ".js" { "application/javascript" }
        ".json" { "application/json" }
        ".png" { "image/png" }
        ".jpg" { "image/jpeg" }
        ".jpeg" { "image/jpeg" }
        ".webp" { "image/webp" }
        default { "text/plain" }
    }
}

$Listener = [System.Net.HttpListener]::new()
$Listener.Prefixes.Add("http://$HostName`:$Port/")
$Listener.Start()

Write-Host "Server restoran aktif: http://$HostName`:$Port/restoran.html"
Write-Host "Tekan Ctrl+C untuk berhenti."

try {
    while ($Listener.IsListening) {
        $Context = $Listener.GetContext()
        $Request = $Context.Request
        $Path = $Request.Url.AbsolutePath

        try {
            if ($Request.HttpMethod -eq "OPTIONS") {
                $Context.Response.StatusCode = 204
                $Context.Response.Headers["Access-Control-Allow-Origin"] = "*"
                $Context.Response.Headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
                $Context.Response.Headers["Access-Control-Allow-Headers"] = "Content-Type"
                $Context.Response.OutputStream.Close()
                continue
            }

            if ($Request.HttpMethod -eq "GET" -and $Path -eq "/api/menus") {
                Send-Json $Context 200 @{ menus = $Menus }
                continue
            }

            if ($Request.HttpMethod -eq "GET" -and $Path -eq "/api/orders") {
                Send-Json $Context 200 @{ orders = Get-RecentOrders }
                continue
            }

            if ($Request.HttpMethod -eq "POST" -and $Path -eq "/api/orders") {
                $Reader = [IO.StreamReader]::new($Request.InputStream, $Request.ContentEncoding)
                $Payload = $Reader.ReadToEnd() | ConvertFrom-Json
                $Reader.Close()

                $Order = Create-Order $Payload
                Send-Json $Context 201 @{ message = "Pesanan tersimpan."; order = @{ id = $Order.id; total = $Order.total; items = $Order.items.Count; payment_method = $Order.payment_method } }
                continue
            }

            if ($Path -eq "/") {
                $Path = "/restoran.html"
            }

            $Relative = [Uri]::UnescapeDataString($Path.TrimStart("/")).Replace("/", [IO.Path]::DirectorySeparatorChar)
            $FilePath = Join-Path $Root $Relative
            $FullPath = [IO.Path]::GetFullPath($FilePath)
            $FullRoot = [IO.Path]::GetFullPath($Root)

            if (-not $FullPath.StartsWith($FullRoot) -or -not (Test-Path -LiteralPath $FullPath -PathType Leaf)) {
                Send-Json $Context 404 @{ error = "File tidak ditemukan." }
                continue
            }

            $Bytes = [IO.File]::ReadAllBytes($FullPath)
            $Context.Response.StatusCode = 200
            $Context.Response.ContentType = "$(Get-ContentType $FullPath); charset=utf-8"
            $Context.Response.Headers["Access-Control-Allow-Origin"] = "*"
            $Context.Response.ContentLength64 = $Bytes.Length
            $Context.Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
            $Context.Response.OutputStream.Close()
        } catch {
            Send-Json $Context 500 @{ error = $_.Exception.Message }
        }
    }
} finally {
    $Listener.Stop()
    $Listener.Close()
}
