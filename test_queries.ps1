$queries = @('hello','assalam o alaikum','recommend best earbuds','best phone under 50000','i need bigger battery phone','i need best camera phone','i need gaming phone','i need flagship phone','i want snapdragon 8 phone','i need 12gb ram phone 256gb','cheapest 5g phone','best laptop under 150000','gaming laptop with strong gpu','i need laptop for coding and battery backup','i need core i7 laptop','i need rtx 4060 laptop','lightweight laptop for office','best budget laptop under 100k','i need macbook style premium laptop','i need tablet for study')
$results = @()
foreach ($q in $queries) {
  try {
    $body = @{ message = $q } | ConvertTo-Json -Compress
    $res = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:8000/chat/send-message' -ContentType 'application/json' -Body $body -TimeoutSec 30
    $p = @()
    if ($res.PSObject.Properties.Name -contains 'products' -and $res.products) { $p = @($res.products) }
    $t = @($p | Select-Object -First 3 | ForEach-Object { [PSCustomObject]@{ n=$_.name; p=$_.price; pr=$_.processor; g=$_.gpu; b=$_.battery; s=$_.similarity_score } })
    $results += [PSCustomObject]@{ q=$q; ok=$true; r=[string]$res.reply; count=$p.Count; top3=$t }
  } catch {
    $results += [PSCustomObject]@{ q=$q; ok=$false; r=$_.Exception.Message; count=-1; top3=@() }
  }
}
$results | ConvertTo-Json -Depth 8
