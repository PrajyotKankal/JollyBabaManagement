$body = @{variantGbColor='Red'} | ConvertTo-Json
$response = Invoke-WebRequest -Uri 'http://192.168.1.16:5000/api/inventory/26' -Method PATCH -Body $body -ContentType 'application/json'
Write-Output $response.Content
